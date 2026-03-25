# Downstream Migration

## Purpose

This repo now targets a same-step bootstrap contract:

- plaintext passwords are generated at runtime and kept out of Packer install
  arguments
- SSH private keys stay on disk as passphrase-protected files
- the bootstrap step emits both the remaining `SPB_*` same-step values and the
  shared `PKR_VAR_*` inputs Packer can consume directly
- the calling shell remains responsible only for repo-specific extras such as
  `PKR_VAR_deploy_user_name`

That keeps this repo generic while still giving downstream workflows a secure,
repeatable way to mint the secrets they need.

## Preferred Downstream Pattern

For GitHub Actions consumers running bootstrap and Packer in the same step:

1. Download the reviewed release asset into `$RUNNER_TEMP`
2. Verify the script against the pinned checksum
3. Run `eval "$(...)"` against the script in the same shell step that will run Packer
4. Export only any repo-specific extras the script cannot know, such as
   `PKR_VAR_deploy_user_name`
5. Use generated file paths for the SSH keypair
6. Delete the temporary bootstrap directory in an `always()` cleanup step

Example:

```bash
eval "$("${RUNNER_TEMP}/secure-packer-bootstrapper.sh")"
packer build .
```

Important:

- do not run the bootstrap command under `set -x`
- do not forward its stdout to logs
- keep bootstrap and Packer in the same shell step
- pass `--output-dir` only when you need a location other than
  `artifacts/bootstrap`
- clean up the bootstrap directory after the build

## Bootstrap Contract

These are the only shell exports emitted by the bootstrap step:

- conditional GitHub Actions `::add-mask::` registrations for:
  - `SPB_DEPLOY_USER_PASSWORD`
  - `SPB_DEPLOY_USER_PASSWORD_HASH`
  - `SPB_SSH_KEY_PASSPHRASE`
- `SPB_DEPLOY_USER_PASSWORD`
- `SPB_DEPLOY_USER_PASSWORD_HASH`
- `SPB_SSH_KEY_PASSPHRASE`
- `SPB_SSH_PRIVATE_KEY_FILE`
- `SPB_SSH_PUBLIC_KEY_FILE`
- `PKR_VAR_deploy_user_password`
- `PKR_VAR_deploy_user_password_hash`
- `PKR_VAR_deploy_user_key`

No `GITHUB_ENV`, `GITHUB_OUTPUT`, `bootstrap.env`, `packer.auto.pkrvars.json`,
`manifest.json`, or secret-value convenience files are part of the active
contract.

## Consumer Responsibilities

This repo intentionally stops at bootstrap generation. Downstream repos own:

- repo-specific `PKR_VAR_*` values that this repo cannot know, such as
  `PKR_VAR_deploy_user_name`
- Kickstart authoring
- Ansible communicator and become wiring
- cleanup policy outside the bootstrap directory
- any downstream hardening or compliance guarantees for the built operating
  system

## Required Changes In Consumers

### Kickstart

Stop using plaintext installer passwords.

Current pattern:

```hcl
user --name=${deploy_user_name} --plaintext --password=${deploy_user_password}
```

Target pattern:

```hcl
user --name=${deploy_user_name} --iscrypted --password=${deploy_user_password_hash}
```

### Packer

Consume the directly exported:

- `PKR_VAR_deploy_user_password`
- `PKR_VAR_deploy_user_password_hash`
- `PKR_VAR_deploy_user_key`

without re-exporting them from wrapper glue. Keep any remaining repo-specific
Packer variables, such as `PKR_VAR_deploy_user_name`, outside this bootstrapper.

### Provisioning

Use:

- `SPB_SSH_PRIVATE_KEY_FILE` for SSH login
- `SPB_SSH_KEY_PASSPHRASE` to unlock the key
- `SPB_DEPLOY_USER_PASSWORD` for sudo / become only

## Release Consumption

If a downstream repo consumes the built standalone script, it should monitor
published releases rather than raw commits.

Published release assets:

- `secure-packer-bootstrapper.sh`
- `secure-packer-bootstrapper.sh.sha256`
- `secure-packer-bootstrapper.release.json`
- GitHub build provenance attestations for those release assets

Recommended update flow:

1. Watch the latest published release on a schedule or dispatch
2. Compare the latest tag with the currently pinned tag
3. Download the script, checksum, and metadata manifest from that release
4. Verify the checksum, inspect the metadata manifest, and verify the GitHub
   attestation
5. Open a PR updating the pinned tag and checksum together
6. Merge only after review

Example verification flow after download:

```bash
sha256sum -c secure-packer-bootstrapper.sh.sha256
cat secure-packer-bootstrapper.release.json
gh attestation verify secure-packer-bootstrapper.sh \
  --repo NWarila/secure-packer-bootstrapper \
  --signer-workflow NWarila/secure-packer-bootstrapper/.github/workflows/release-artifact.yml
```

If you want a downstream PR for every change in this repo, this repo must
publish a release or prerelease for every change you care about.

## Security Notes

- A password hash is still sensitive because offline cracking is possible.
- A plaintext password used only for `become` is still a real secret.
- The bootstrapper now emits shell exports on stdout, so callers must capture
  them in the same shell with `eval "$( ... )"` and avoid command tracing or
  log forwarding for that call. An executed child script still cannot export
  directly into the parent shell without that `eval` or an equivalent `source`
  pattern.
- In GitHub Actions, the emitted shell snippet automatically registers the
  plaintext password, password hash, and SSH key passphrase with
  `::add-mask::` before exporting them, so later accidental log output is more
  likely to be redacted. The script uses `GITHUB_ACTIONS=true` as the primary
  signal and falls back to other GitHub runner variables so this remains on by
  default in real workflows.
- The checksum proves file equality after download.
- The metadata manifest gives reviewers one place to confirm the intended tag,
  commit, workflow reference, and bundle digest.
- The GitHub attestation proves the asset came from this repo's release
  workflow.
- None of those should be described as immutable-release protection unless
  that GitHub setting is actually enabled for the repository.
- SSH key generation still relies on `ssh-keygen -N`, so the passphrase crosses
  the local argv boundary briefly during generation. Run that step only on
  trusted runners in temporary workspaces.
- Private keys remain on disk as files because that is the simplest safe shape
  for downstream SSH tooling.
- Self-hosted runners increase the importance of cleanup because files can
  outlive the job if the workspace is reused.
