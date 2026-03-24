# Requirements: `bootstrap_credentials`

## Overview

`bootstrap_credentials` is the repo-level orchestrator. It owns the minimal
bootstrap contract for this repo:

- generate a plaintext deploy-user password
- generate a SHA-512 crypt password hash with `rounds=10000`
- generate a passphrase-protected SSH keypair
- keep only the SSH private/public key files on disk
- emit only the three secret values and the two key-file paths needed by the
  current shell step

It intentionally does not own downstream Packer, Kickstart, or Ansible wiring.
The calling shell must map the emitted values into its own `PKR_VAR_*` or
tool-specific contracts.

## Function Signature

```bash
bootstrap_credentials [OPTIONS]
```

## Supported Options

- `--output-dir DIR`
- `--password-length N`
- `--passphrase-length N`
- `--ssh-key-type rsa|ecdsa`
- `--ssh-key-bits N`
- `--ssh-key-name BASENAME`
- `--ssh-key-comment TEXT`

## Active Output Contract

On disk:

- `ssh/<keyname>`
- `ssh/<keyname>.pub`

On stdout:

- `export SPB_DEPLOY_USER_PASSWORD=...`
- `export SPB_DEPLOY_USER_PASSWORD_HASH=...`
- `export SPB_SSH_KEY_PASSPHRASE=...`
- `export SPB_SSH_PRIVATE_KEY_FILE=...`
- `export SPB_SSH_PUBLIC_KEY_FILE=...`

The intended caller pattern is:

```bash
eval "$(bin/secure-packer-bootstrapper --output-dir artifacts/bootstrap)"
```

## Removed Contract Elements

The following outputs and behaviors are intentionally no longer part of the
public contract:

- `bootstrap.env`
- `packer.auto.pkrvars.json`
- `manifest.json`
- `secrets/`
- `GITHUB_ENV` writes
- `GITHUB_OUTPUT` writes
- bootstrap-managed `ssh-agent` session setup
- `--deploy-user`
- `--github-actions`
- `--skip-agent`

## Behavioral Rules

- `bootstrap_credentials` MUST remain the only module that knows about
  downstream-facing `SPB_*` names.
- Lower-level generators MUST stay consumer-agnostic and continue returning
  values through stdout or explicit file paths.
- The plaintext password, password hash, and SSH key passphrase MUST NOT be
  written to convenience files on disk by this module.
- The private key and public key MUST remain on disk as files because that is
  the simplest safe contract for downstream SSH tooling.
- The bootstrap step MUST emit shell-safe `export ...` lines on stdout so the
  caller can capture them in the same shell with `eval "$( ... )"`.
- The repo MUST treat stdout from `bootstrap_credentials` as sensitive data and
  document that callers should avoid `set -x` or log-forwarding for that call.
- This module MUST rely on lower-level argument validation to prevent insecure
  settings rather than probing host FIPS state or other external compliance
  markers.
- The calling shell owns all `PKR_VAR_*`, Kickstart, and provisioning mapping.

## Exit Codes

- `0`: success
- `1`: runtime failure
- `2`: usage error
- `127`: missing dependency

## Detailed Audit Requirements

## REQ-BOOTSTRAP-001

Status: Satisfied
Priority: P1
Severity: Medium
Domain: orchestrator-boundary
Applies to: ownership of the downstream bootstrap contract
Affected files/lines:
- `src/bootstrap_credentials/bootstrap_credentials.sh`
- `src/generate_password/generate_password.sh`
- `src/generate_password_hash/generate_password_hash.sh`
- `src/generate_ssh_keypair/generate_ssh_keypair.sh`
Requirement:
- `bootstrap_credentials` MUST remain the only module that translates primitive
  generator outputs into the repo's public bootstrap contract. Lower-level
  modules MUST stay consumer-agnostic.
Rationale:
- This keeps downstream coupling in one place and prevents the primitive
  modules from growing repo-specific export semantics.
Verification:
- Search lower-level modules for `SPB_`, `PKR_VAR_`, or shell-export handling.
  Only `bootstrap_credentials` should own those concerns.

## REQ-BOOTSTRAP-002

Status: Satisfied
Priority: P1
Severity: High
Domain: output-minimalism
Applies to: generated artifact surface
Affected files/lines:
- `src/bootstrap_credentials/bootstrap_credentials.sh`
- `test/bootstrap_credentials_test.sh`
- `test/release_bundle_verify.sh`
Requirement:
- The bootstrap flow MUST keep its persisted output surface to the SSH private
  key and SSH public key only. It MUST NOT write `bootstrap.env`,
  `packer.auto.pkrvars.json`, `manifest.json`, or retained secret-value files.
Rationale:
- The old file-heavy contract duplicated sensitive data without adding
  security.
Verification:
- Run the bootstrap tests and confirm the convenience files and `secrets/`
  directory are absent in both source and bundled execution.

## REQ-BOOTSTRAP-003

Status: Satisfied
Priority: P1
Severity: Medium
Domain: downstream-boundary
Applies to: ownership split between this repo and the calling shell
Affected files/lines:
- `src/bootstrap_credentials/bootstrap_credentials.sh`
- `README.md`
- `docs/DOWNSTREAM-MIGRATION.md`
Requirement:
- This repo MUST stop at generating the three secret values and the two key-file
  paths. The calling shell or downstream repo MUST own mapping those values into
  `PKR_VAR_*`, Kickstart, Packer, or provisioning-specific contracts.
Rationale:
- That boundary keeps this repo generic and prevents it from accumulating
  downstream-specific convenience layers.
Verification:
- Read the README and downstream migration doc and confirm they describe the
  mapping step as a caller responsibility.

## REQ-BOOTSTRAP-004

Status: Satisfied
Priority: P2
Severity: Medium
Domain: security-boundary
Applies to: bootstrap-layer security guarantees
Affected files/lines:
- `src/bootstrap_credentials/bootstrap_credentials.sh`
- `src/generate_password_hash/generate_password_hash.sh`
- `src/generate_ssh_keypair/generate_ssh_keypair.sh`
Requirement:
- `bootstrap_credentials` MUST rely on restrictive lower-level validation and
  fixed safe defaults to prevent insecure settings. It MUST NOT claim or gate
  on host-side FIPS state as part of its active runtime contract.
Rationale:
- The script can control its own algorithms, sizes, and hash parameters, but it
  cannot meaningfully prove downstream platform compliance through a bootstrap
  flag.
Verification:
- Confirm the bootstrap CLI no longer accepts `--require-fips`, and confirm the
  lower-level generators still reject insecure key settings and keep
  `rounds=10000` for password hashes.

## REQ-BOOTSTRAP-005

Status: Satisfied
Priority: P1
Severity: High
Domain: same-step-shell-contract
Applies to: shell export contract
Affected files/lines:
- `src/bootstrap_credentials/bootstrap_credentials.sh`
- `README.md`
- `docs/DOWNSTREAM-MIGRATION.md`
- `test/bootstrap_credentials_test.sh`
- `test/release_bundle_verify.sh`
Requirement:
- The bootstrap flow MUST emit only shell-safe `export` assignments for
  `SPB_DEPLOY_USER_PASSWORD`, `SPB_DEPLOY_USER_PASSWORD_HASH`,
  `SPB_SSH_KEY_PASSPHRASE`, `SPB_SSH_PRIVATE_KEY_FILE`, and
  `SPB_SSH_PUBLIC_KEY_FILE` to stdout.
Rationale:
- This keeps bootstrap and Packer in the same shell step and removes cross-step
  GitHub environment-file attack surface.
Verification:
- Run the bootstrap tests and confirm stdout contains only the documented
  `export ...` contract needed for same-step use.

## REQ-BOOTSTRAP-006

Status: Satisfied
Priority: P1
Severity: High
Domain: secret-lifecycle
Applies to: plaintext and secret-value retention
Affected files/lines:
- `src/bootstrap_credentials/bootstrap_credentials.sh`
- `README.md`
- `docs/DOWNSTREAM-MIGRATION.md`
Requirement:
- The plaintext password, password hash, and SSH key passphrase MUST stay in
  memory and stdout only. They MUST NOT be persisted to convenience files or
  cross-step environment files by this module.
Rationale:
- Persisting those values adds storage risk without adding real operational
  value for the same-step contract.
Verification:
- Inspect the bootstrap output directory and confirm no retained secret-value
  files exist.

## REQ-BOOTSTRAP-007

Status: Satisfied
Priority: P2
Severity: Medium
Domain: dead-feature-removal
Applies to: legacy option and helper removal
Affected files/lines:
- `src/bootstrap_credentials/bootstrap_credentials.sh`
- `test/bootstrap_credentials_test.sh`
- `test/release_bundle_verify.sh`
Requirement:
- Legacy bootstrap options that no longer affect the real contract, such as
  `--deploy-user`, `--github-actions`, and `--skip-agent`, MUST NOT remain part
  of the active public contract.
Rationale:
- Leaving dead compatibility paths behind keeps unnecessary code and confusing
  surface area alive after the contract has been simplified.
Verification:
- Run the bootstrap tests and confirm those removed options now fail as unknown
  options.

## REQ-BOOTSTRAP-008

Status: Satisfied
Priority: P1
Severity: Medium
Domain: release-bundle-equivalence
Applies to: parity between source execution and bundled execution
Affected files/lines:
- `scripts/build-release.sh`
- `scripts/verify.sh`
- `test/bootstrap_credentials_test.sh`
- `test/release_bundle_verify.sh`
Requirement:
- The bundled release script MUST preserve the same minimal bootstrap contract
  as the source modules: two key files on disk, five shell-exported values on
  stdout, no convenience files, and no source-only dependency-loader scaffolding
  copied from the `src/` modules.
Rationale:
- The published bundle is the downstream consumption path, so contract drift
  between source and bundle would defeat the simplification work.
Verification:
- Run `bash scripts/verify.sh` and confirm the release-bundle verification test
  passes against the documented minimal contract and asserts the bundle omits
  top-of-file source-loader guards.
