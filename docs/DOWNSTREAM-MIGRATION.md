# Downstream Migration

## Purpose

This repo now targets a same-step bootstrap contract:

- plaintext passwords are generated at runtime and kept out of Packer install
  arguments
- SSH private keys stay on disk as passphrase-protected files
- the bootstrap step emits only the secret values and key paths that the
  current shell actually needs
- the calling shell is responsible for mapping those values into Packer and the
  rest of the step

That keeps this repo generic while still giving downstream workflows a secure,
repeatable way to mint the secrets they need.

## Preferred Downstream Pattern

For GitHub Actions consumers running bootstrap and Packer in the same step:

1. Download the reviewed release asset into `$RUNNER_TEMP`
2. Verify the script against the pinned checksum
3. Run `eval "$(...)"` against the script in the same shell step that will run Packer
4. Map `SPB_DEPLOY_USER_PASSWORD_HASH` into the downstream `PKR_VAR_*` contract
5. Use generated file paths for the SSH keypair
6. Delete the temporary bootstrap directory in an `always()` cleanup step

Example:

```bash
eval "$("${RUNNER_TEMP}/secure-packer-bootstrapper.sh" --output-dir "${RUNNER_TEMP}/spb")"
export PKR_VAR_deploy_user_password_hash="${SPB_DEPLOY_USER_PASSWORD_HASH}"
packer build .
```

Important:

- do not run the bootstrap command under `set -x`
- do not forward its stdout to logs
- keep bootstrap and Packer in the same shell step
- clean up the bootstrap directory after the build

## Bootstrap Contract

These are the only shell exports emitted by the bootstrap step:

- `SPB_DEPLOY_USER_PASSWORD`
- `SPB_DEPLOY_USER_PASSWORD_HASH`
- `SPB_SSH_KEY_PASSPHRASE`
- `SPB_SSH_PRIVATE_KEY_FILE`
- `SPB_SSH_PUBLIC_KEY_FILE`

No `GITHUB_ENV`, `GITHUB_OUTPUT`, `bootstrap.env`, `packer.auto.pkrvars.json`,
`manifest.json`, or secret-value convenience files are part of the active
contract.

## Consumer Responsibilities

This repo intentionally stops at bootstrap generation. Downstream repos own:

- the mapping from `SPB_DEPLOY_USER_PASSWORD_HASH` into the downstream
  `PKR_VAR_*` contract
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

Map `SPB_DEPLOY_USER_PASSWORD_HASH` into the downstream
`PKR_VAR_deploy_user_password_hash` shell environment variable instead of
passing the hash through `-var` command arguments or long-lived static secret
stores.

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
- GitHub build provenance attestations for those release assets

Recommended update flow:

1. Watch the latest published release on a schedule or dispatch
2. Compare the latest tag with the currently pinned tag
3. Download the script and checksum from that release
4. Verify the checksum and the GitHub attestation
5. Open a PR updating the pinned tag and checksum together
6. Merge only after review

Example verification flow after download:

```bash
sha256sum -c secure-packer-bootstrapper.sh.sha256
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
  log forwarding for that call.
- The checksum proves file equality after download. The GitHub attestation
  proves the asset came from this repo's release workflow. Neither one should
  be described as immutable-release protection unless that GitHub setting is
  actually enabled for the repository.
- SSH key generation still relies on `ssh-keygen -N`, so the passphrase crosses
  the local argv boundary briefly during generation. Run that step only on
  trusted runners in temporary workspaces.
- Private keys remain on disk as files because that is the simplest safe shape
  for downstream SSH tooling.
- Self-hosted runners increase the importance of cleanup because files can
  outlive the job if the workspace is reused.
