# Requirements: `generate_ssh_keypair`

## Overview

`generate_ssh_keypair` creates a passphrase-protected SSH keypair for image
build automation. The default profile is conservative and compatibility-first:
RSA with a 4096-bit modulus and the modern OpenSSH private-key format.

## Function Signature

```bash
generate_ssh_keypair \
  --output-dir DIR \
  --name BASENAME \
  --passphrase VALUE \
  [--comment TEXT] \
  [--type rsa|ecdsa] \
  [--bits N] \
  [--force]
```

## Defaults

- `--type rsa`
- `--bits 4096` for RSA
- `--bits 384` for ECDSA
- `--comment builder@secure-packer-bootstrapper`

## Output Contract

On success, stdout prints:

1. Private key path
2. Public key path

## Validation Rules

- `--output-dir` is required
- `--passphrase` is required
- RSA bits must be between `3072` and `8192`
- ECDSA bits must be one of `256`, `384`, or `521`
- Existing key files must not be overwritten unless `--force` is set

## Security Rules

- The private key file must end with mode `600`
- The public key file may be mode `644`
- Temporary key files must be removed on normal failure paths
- Because OpenSSH key generation takes the passphrase through `ssh-keygen -N`,
  the repo must explicitly document the resulting external-process argv
  exposure and the operator constraints around it

## Exit Codes

- `0`: success
- `1`: runtime failure
- `2`: usage error
- `127`: missing dependency

## Detailed Audit Requirements

## REQ-SSHKEY-001

Status: Satisfied
Priority: P1
Severity: High
Domain: secret-process-boundary
Applies to: passphrase handling at the `ssh-keygen` process boundary
Affected files/lines:
- `src/generate_ssh_keypair/generate_ssh_keypair.sh:13-19`
- `src/generate_ssh_keypair/generate_ssh_keypair.sh:54-64`
- `src/generate_ssh_keypair/generate_ssh_keypair.sh:168-176`
- `src/generate_ssh_keypair/REQUIREMENTS.md:36-48`
Authoritative sources:
- OpenSSH `ssh-keygen(1)` manual page. https://www.man7.org/linux/man-pages/man1/ssh-keygen.1@@openssh.html
- GitHub Docs, "Using secrets in GitHub Actions". https://docs.github.com/en/actions/how-tos/write-workflows/choose-what-workflows-do/use-secrets
- Linux `proc_pid_cmdline(5)` manual page. https://man7.org/linux/man-pages/man5/proc_pid_cmdline.5.html
Repository evidence:
- The function requires `--passphrase`.
- It invokes `ssh-keygen` with `-N "${passphrase}"`.
- The module does not print the passphrase, and the repo docs now explain that
  this value crosses an external process boundary through argv and should be
  generated only on trusted runners in temporary workspaces.
Applicability analysis:
- This repository targets Linux and invokes `ssh-keygen` as an external process.
- Linux documents that a process's command-line arguments are visible through
  `/proc/pid/cmdline`, and GitHub's secret-handling guidance says to avoid
  passing secrets between processes on the command line whenever possible.
- OpenSSH documents `-N new_passphrase` as the non-interactive passphrase input
  interface used here, so the current exposure appears to be tool-constrained
  rather than an accidental extra copy.
Upstream / vendor example:
- OpenSSH documents `ssh-keygen ... -N new_passphrase` as the option that
  provides the passphrase during key generation.
- GitHub's workflow guidance explicitly warns that command-line processes may be
  visible to other users via `ps`.
Requirement:
- Whenever a secret crosses an external process boundary, the repo MUST avoid
  command-line transmission if the tool supports a safer mechanism. If the
  documented non-interactive interface still requires argv exposure, as with the
  current `ssh-keygen -N` path, the repo MUST explicitly document that
  exposure, keep the logging surface minimal, and explain the intended operator
  constraints such as trusted runners, temporary workspaces, and avoiding
  multi-tenant shared hosts for this step.
Rationale:
- The current implementation is quiet and short-lived, but reviewers and
  operators still need an honest account of the remaining local-host exposure.
Acceptance criteria:
- The module docs state that the passphrase is not logged but does pass through
  the `ssh-keygen` argv boundary during generation.
- No additional stdout, stderr, or trace output reveals the passphrase.
- Higher-level docs explain the trusted-runner / temp-workspace expectation for
  this step, or document a narrower threat model.
Recommended change:
- Add explicit module and downstream guidance for the `ssh-keygen -N`
  passphrase exposure, and re-evaluate safer non-argv techniques if OpenSSH
  adds one in the future.
Verification method:
- Inspect the `ssh-keygen` invocation and confirm whether the passphrase is sent
  through `-N`.
- Review module and repo docs for an explicit explanation of the exposure and
  operator guidance.
- Run the module and confirm the passphrase is not printed to stdout or stderr
  under the normal success path.
Counterpoints / reasons to reject:
- Reject only if the repo explicitly narrows its threat model to fully trusted,
  single-user Linux hosts and documents that scope clearly enough that the argv
  exposure is no longer presented as a general-safe default.

## REQ-SSHKEY-002

Status: Satisfied
Priority: P1
Severity: High
Domain: verification-coverage
Applies to: algorithm validation, overwrite semantics, and failure cleanup
Affected files/lines:
- `src/generate_ssh_keypair/generate_ssh_keypair.sh:13-26`
- `src/generate_ssh_keypair/generate_ssh_keypair.sh:113-194`
- `test/generate_ssh_keypair_test.sh:9-24`
- `test/testlib.sh:19-87`
Authoritative sources:
- OpenSSH `ssh-keygen(1)` manual page. https://www.man7.org/linux/man-pages/man1/ssh-keygen.1@@openssh.html
- GNU Bash Reference Manual. https://www.gnu.org/software/bash/manual/bash.html
- `docs/STUDENT-FIRST-STANDARDS.md`
Repository evidence:
- The module validates required inputs, key type, and bit ranges, supports
  `--force`, sets restrictive file modes, and removes temporary key files on
  normal failure paths.
- The automated test now covers successful generation, overwrite refusal,
  overwrite with `--force`, invalid `--type`, invalid `--bits`, missing
  `ssh-keygen`, and cleanup after injected generation failure.
Applicability analysis:
- This module creates one of the repo's most security-sensitive artifacts.
  Tests should therefore cover not only "files exist" but also the validation
  and failure paths that protect operators from weak or stale key material.
- OpenSSH documents the key-type, bit-size, and passphrase options used here,
  so these branches are stable public behavior rather than incidental internals.
Upstream / vendor example:
- `ssh-keygen(1)` documents `-t` for key type, `-b` for key size, and `-N` for
  passphrase input, which match the module's public options.
Requirement:
- Automated tests for `generate_ssh_keypair` MUST cover successful generation,
  validation failures, overwrite semantics, and at least one injected runtime
  failure path. At minimum, the suite MUST verify invalid key-type or bit-range
  rejection, refusal to overwrite without `--force`, successful overwrite with
  `--force`, and cleanup of temporary key files when `ssh-keygen` fails or is
  unavailable.
Rationale:
- Key generation is security-critical, and the current test surface is too small
  to support the module's broader contract around safe defaults and cleanup.
Acceptance criteria:
- Tests assert successful key generation produces both output paths and the
  expected on-disk files.
- Tests cover invalid `--type` or `--bits` values for the supported algorithms.
- Tests cover both overwrite refusal and `--force` overwrite behavior.
- Tests inject a missing or failing `ssh-keygen` path and confirm expected
  status, stderr, and cleanup of temporary files.
- On Linux verification hosts, tests assert the private key ends with mode
  `600` and the public key with mode `644`, or the ledger explicitly narrows
  that check to Linux-only verification environments.
Recommended change:
- Expand `test/generate_ssh_keypair_test.sh` using a temporary directory and the
  existing `GENERATE_SSH_KEYPAIR_SSH_KEYGEN_BIN` override so both validation and
  cleanup paths are exercised.
Verification method:
- Run the SSH-key module tests on Linux and inspect the output files and
  temporary directory after both success and injected failure paths.
- Compare the test file against the public option and security rules in this
  ledger.
Counterpoints / reasons to reject:
- Reject only if the module is intentionally reduced to a best-effort wrapper
  with a narrower documented contract and fewer promises about validation or
  cleanup than it currently makes.
