# secure-packer-bootstrapper

[![Verify](https://github.com/NWarila/secure-packer-bootstrapper/actions/workflows/verify.yml/badge.svg)](https://github.com/NWarila/secure-packer-bootstrapper/actions/workflows/verify.yml)
[![Release Artifact](https://github.com/NWarila/secure-packer-bootstrapper/actions/workflows/release-artifact.yml/badge.svg)](https://github.com/NWarila/secure-packer-bootstrapper/actions/workflows/release-artifact.yml)
[MIT License](LICENSE)

`secure-packer-bootstrapper` is a Bash bootstrapper for Linux image-build
workflows. It generates the short-lived credentials needed to:

- create a deploy user during install time
- export the shared `PKR_VAR_*` install inputs Packer needs immediately
- keep the plaintext password available only for post-install sudo / become
- generate a passphrase-protected SSH keypair for SSH-based provisioning

This repo exists to replace long-lived static GitHub secrets with runtime
bootstrap material that is generated, masked, reviewed, and cleaned up inside
the workflow that needs it.

## At A Glance

- Problem solved: replace long-lived bootstrap secrets with same-step runtime
  credential generation for image builds
- Primary outputs: a plaintext deploy password, a SHA-512 crypt password hash
  with `rounds=10000`, a passphrase-protected SSH keypair, and shell-safe
  exports for immediate downstream use
- Release artifacts: a standalone Bash bundle, a checksum, a machine-readable
  release metadata manifest, and GitHub provenance attestations
- Verified environments: Ubuntu 22.04 and 24.04 GitHub-hosted runners, plus
  Rocky Linux 8, 9, and 10 official container jobs
- Reviewer story: security boundaries, portability claims, and release trust
  guarantees are documented explicitly instead of implied

## Supported Platforms

This repo intentionally supports a narrow, truthful platform contract:

- GNU Bash 4.3+
- CI-verified environments:
  - GitHub-hosted Ubuntu 22.04 LTS and 24.04 LTS runners
  - official Rocky Linux 8, 9, and 10 container jobs in GitHub Actions
- downstream consumer focus: Rocky Linux 8, 9, and 10 image-build repos, plus
  Ubuntu 22.04 LTS and 24.04 LTS image-build repos

It does not claim POSIX `sh` compatibility, non-Linux Unix portability, or
full downstream OS hardening compliance by itself.

These support claims track explicitly verified CI versions. The repo does not
claim "all future Rocky 8+" or "all future Ubuntu 22.04+" behavior unless CI
and docs are updated to prove those exact versions.

The evidence model is explicit rather than flattened:

- Ubuntu is verified on GitHub-hosted runners
- Rocky is verified in official Rocky-maintained containers on GitHub Actions

Those are different execution surfaces, and the docs call them out separately
instead of pretending they are identical.

## Dependency Contract

| Surface | Required items | Notes |
|---|---|---|
| Mandatory runtime | Bash 4.3+, `/dev/urandom`, `od`, `openssl`, `ssh-keygen`, `mkdir`, `chmod`, `mv` | Needed to generate hashes, keys, and the minimal bootstrap output set |
| Optional runtime | none | The bootstrap flow no longer depends on `ssh-agent` or distro-specific helper commands |
| Developer and test | `mktemp`, `grep`, `find`, `sed`, `sort`, `stat` | Used by the Bash test suite and local verification helpers |
| CI and release | `sudo`, distro package manager, `sha256sum`, `gh` | Workflow-surface dependencies, not runtime CLI prerequisites for downstream consumers |

The workflow files show CI installation recipes for Ubuntu runners and Rocky
containers, not the generic Linux setup story for the runtime CLI itself.

## Security Scope

This repo only makes claims about the script and the artifacts it generates.

- It enforces safe key-generation settings through argument validation:
  only RSA and ECDSA are exposed, and insecure key sizes are rejected.
- It generates SHA-512 crypt password hashes with `rounds=10000`.
- SSH key generation still uses `ssh-keygen -N`, so the key passphrase crosses
  the local argv boundary briefly during generation. Use trusted runners and
  temporary workspaces for that step.
- It does not claim that the downstream operating system, image, or workflow is
  compliant with any external hardening benchmark by itself.

## What It Generates

The bootstrap flow produces:

- a deploy-user plaintext password
- a SHA-512 crypt password hash with `rounds=10000`
- a passphrase-protected SSH private key and matching public key

The bootstrap shell-export contract is:

- GitHub Actions mask-registration commands for:
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

The intended downstream model is:

- Kickstart uses the password hash with `user --iscrypted`
- Packer reads the directly exported `PKR_VAR_*` values without a manual mapping step
- SSH key authentication is used for login
- the plaintext password is retained only for sudo / become

## Learning Goal

This repo is also a teaching repo for first-year computer science students.
The project-wide readability rules live in
`[docs/STUDENT-FIRST-STANDARDS.md](docs/STUDENT-FIRST-STANDARDS.md)`.

If you are new to the repo, read these in order:

1. `README.md`
2. `docs/STUDENT-FIRST-STANDARDS.md`
3. `docs/MODULE-DECOMPOSITION.md`
4. the relevant `src/<module>/REQUIREMENTS.md`
5. the matching source file
6. the matching test file

## Local Demo Use

Run the full verification flow:

```bash
bash scripts/verify.sh
```

Generate a local artifact set in the workspace and export the secret values
into the current shell:

```bash
eval "$(bin/secure-packer-bootstrapper)"
```

These examples are for local learning and review. They intentionally write
artifacts into the workspace so you can inspect them.

## Same-Step Use

The bootstrapper is intended to run in the same shell step as Packer.

Example:

```bash
eval "$("${RUNNER_TEMP}/secure-packer-bootstrapper.sh")"
packer build .
```

The script prints shell-safe `export ...` lines to stdout, including the
shared `PKR_VAR_*` values Packer needs. In GitHub Actions, that same stdout
stream automatically emits `::add-mask::` commands for the generated plaintext
password, password hash, and SSH key passphrase before exporting them. The
script treats `GITHUB_ACTIONS=true` as the primary signal and also falls back
to other GitHub runner variables so masking stays on by default in real
workflows. Capture that stdout with `eval "$( ... )"` in the same shell that
will launch Packer. A normally executed child script cannot mutate its parent
shell environment directly, so that `eval` step is the narrowest safe form of
"run bootstrap, then run Packer" in one shell. The no-argument form writes the
generated keypair under `artifacts/bootstrap`; pass `--output-dir` only if you
want a different location. Do not run it under `set -x`, and do not pipe the
output through logging commands.

## Artifact Sensitivity

Treat every generated artifact as sensitive unless it is obviously public.

| Artifact or value | Sensitivity | Intended use |
|---|---|---|
| `SPB_DEPLOY_USER_PASSWORD` | secret | sudo / become only |
| `SPB_DEPLOY_USER_PASSWORD_HASH` | sensitive | install-time password hash |
| `SPB_SSH_KEY_PASSPHRASE` | secret | unlock generated private key |
| `ssh/<keyname>` | secret | provisioning login key |
| `ssh/<keyname>.pub` | low | public key distribution |

For CI:

- generate artifacts under `$RUNNER_TEMP`
- evaluate the script output directly in the shell that will run Packer
- delete the bootstrap directory in a cleanup step
- keep the generated private key on disk and let downstream tooling decide how
  to load it

## Release Assets

Published releases provide:

- `secure-packer-bootstrapper.sh`
- `secure-packer-bootstrapper.sh.sha256`
- `secure-packer-bootstrapper.release.json`
- GitHub build provenance attestations for those release assets

Downstream repos should monitor published releases, pin a reviewed release tag
and checksum, and update them through pull requests rather than following
branches directly.

The release workflow now creates the release with all three files attached at
creation time and publishes GitHub build provenance attestations for them.

- The checksum proves file equality after download.
- The metadata manifest records the release tag, commit SHA, bundle checksum,
  workflow reference, and generation timestamp in one review-friendly file.
- The attestation proves the asset came from this repo's release workflow.

This repo still does not claim immutable-release protection unless that GitHub
repository setting is enabled.

Example verification flow after download:

```bash
sha256sum -c secure-packer-bootstrapper.sh.sha256
cat secure-packer-bootstrapper.release.json
gh attestation verify secure-packer-bootstrapper.sh \
  --repo NWarila/secure-packer-bootstrapper \
  --signer-workflow NWarila/secure-packer-bootstrapper/.github/workflows/release-artifact.yml
```

The deeper downstream migration work is documented in
`[docs/DOWNSTREAM-MIGRATION.md](docs/DOWNSTREAM-MIGRATION.md)`.

## Quality Gates

- Bash syntax checks
- self-contained Bash tests under `test/`
- release bundle build and execution verification
- GitHub Actions verification on Ubuntu 22.04 and Ubuntu 24.04
- GitHub Actions verification in official Rocky Linux 8, 9, and 10 containers
- SHA-pinned external GitHub Actions
- explicit least-privilege workflow permissions
