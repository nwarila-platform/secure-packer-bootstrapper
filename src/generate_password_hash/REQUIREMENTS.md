# Requirements: `generate_password_hash`

## Overview

`generate_password_hash` turns a plaintext password into a Linux-compatible
SHA-512 crypt hash suitable for Kickstart `user --iscrypted` usage. The
current contract fixes the SHA-512 crypt work factor at `rounds=10000`.

## Function Signature

```bash
generate_password_hash [--password VALUE] [--salt-length N]
```

If `--password` is omitted, the function reads one password line from stdin.

## Defaults

- Algorithm: SHA-512 crypt via `openssl passwd -6`
- Rounds: `10000`
- Salt length: `16`

## Validation Rules

- `--salt-length` must be an integer between `8` and `16`
- A password value must be supplied either with `--password` or stdin

## Security Rules

- Salt characters must come from `get_random`
- The function must never pass the password to `openssl` on the command line
- The hash must be written only to stdout on success

## Exit Codes

- `0`: success
- `1`: runtime failure
- `2`: usage error
- `127`: missing dependency

## Detailed Audit Requirements

## REQ-HASH-001

Status: Satisfied
Priority: P1
Severity: Medium
Domain: secret-process-boundary
Applies to: plaintext password handling at the OpenSSL process boundary
Affected files/lines:
- `src/generate_password_hash/generate_password_hash.sh:15-21`
- `src/generate_password_hash/generate_password_hash.sh:62-70`
- `src/generate_password_hash/generate_password_hash.sh:84-99`
- `src/generate_password_hash/REQUIREMENTS.md:26-30`
Authoritative sources:
- OpenSSL Documentation, `openssl-passwd`. https://docs.openssl.org/3.3/man1/openssl-passwd/
- GitHub Docs, "Using secrets in GitHub Actions". https://docs.github.com/en/actions/how-tos/write-workflows/choose-what-workflows-do/use-secrets
- Linux `proc_pid_cmdline(5)` manual page. https://man7.org/linux/man-pages/man5/proc_pid_cmdline.5.html
Repository evidence:
- The function accepts a password via `--password` or reads one line from stdin.
- It invokes `openssl passwd -6 -stdin -salt "rounds=10000\$${salt}"`, piping
  the password through stdin rather than passing it as an OpenSSL command-line
  argument.
- On success, the only value emitted to stdout is the password hash.
Applicability analysis:
- This module crosses a process boundary when it invokes `openssl`.
- GitHub's security guidance explicitly says to avoid passing secrets between
  processes on the command line whenever possible, and Linux documents that a
  running process's command-line arguments are exposed through
  `/proc/pid/cmdline`.
- OpenSSL's documented `-stdin` option applies directly here, so avoiding argv
  exposure is both relevant and achievable.
Upstream / vendor example:
- OpenSSL documents `-stdin` as the supported way to read the password from
  standard input instead of from arguments.
- GitHub's workflow security guidance prefers environment variables, stdin, or
  other non-command-line mechanisms for secrets.
Requirement:
- The plaintext password MUST continue to cross the OpenSSL process boundary via
  stdin, not via OpenSSL command-line arguments, and the module MUST emit only
  the derived hash on stdout.
Rationale:
- This is the cleanest currently available boundary for the hashing step: it
  avoids argv exposure while keeping the function simple and teachable.
Acceptance criteria:
- The OpenSSL invocation uses `-stdin`.
- No plaintext password value appears in the OpenSSL argv list in code review.
- The module's success stdout contains only the resulting hash.
Recommended change:
- Preserve the current stdin-based design and apply the same rule to any future
  hash backend added to the repo.
Verification method:
- Inspect the OpenSSL invocation and confirm the password is piped on stdin.
- Run the module and confirm stdout contains a SHA-512 crypt hash, not the
  plaintext password.
Counterpoints / reasons to reject:
- Reject only if a future hash backend lacks any non-argv secret input
  mechanism, in which case the repo would need an explicitly documented
  exception and threat-model justification.

## REQ-HASH-002

Status: Satisfied
Priority: P2
Severity: Medium
Domain: verification-coverage
Applies to: stdin behavior, dependency failures, and output-shape invariants
Affected files/lines:
- `src/generate_password_hash/generate_password_hash.sh:15-26`
- `src/generate_password_hash/generate_password_hash.sh:62-99`
- `test/generate_password_hash_test.sh:9-17`
- `test/testlib.sh:19-79`
Authoritative sources:
- OpenSSL Documentation, `openssl-passwd`. https://docs.openssl.org/3.3/man1/openssl-passwd/
- GNU Bash Reference Manual. https://www.gnu.org/software/bash/manual/bash.html
- `docs/STUDENT-FIRST-STANDARDS.md`
Repository evidence:
- `generate_password_hash` accepts the password either via `--password` or by
  reading one line from stdin when stdin is not a terminal.
- The module validates `--salt-length`, depends on both `get_random` and
  `openssl`, and reports a runtime error if `openssl passwd` fails.
- The automated test now covers `--password` success, stdin success, invalid
  salt-length handling, a failing `openssl` path, and a missing `openssl` path.
Applicability analysis:
- This module is small, but it defines a security-critical boundary between a
  plaintext password and an install-time password hash. Its documented input
  modes and dependency behavior are part of the public contract.
- Because the module already exposes injectable dependency paths
  (`GENERATE_PASSWORD_HASH_OPENSSL_BIN`) and depends on a sourceable function
  (`get_random`), the missing negative-path tests are feasible without adding
  large harness complexity.
Upstream / vendor example:
- OpenSSL documents both `-6` and `-stdin`, which correspond directly to the
  module's algorithm and stdin code path.
Requirement:
- Automated tests for `generate_password_hash` MUST cover both public password
  input modes and at least one injected dependency or runtime failure path. At
  minimum, the suite MUST verify `--password` success, stdin success, invalid
  `--salt-length` handling, and either missing or failing `openssl`.
  Salt-generation failure remains target coverage rather than current verified
  coverage.
Rationale:
- A single happy-path assertion is not enough evidence for a module that
  transforms plaintext into a downstream security artifact.
Acceptance criteria:
- The test suite confirms a successful stdin-driven invocation emits a SHA-512
  crypt hash on stdout.
- The test suite confirms invalid salt-length values fail with a usage error.
- The test suite injects a missing or failing `openssl` path and asserts the
  expected failure status and message.
- Salt-generation failure is either tested directly or explicitly documented as
  target coverage rather than current verified coverage.
Recommended change:
- Expand `test/generate_password_hash_test.sh` using the existing command-path
  override and a temporary `get_random` override so the module's documented
  paths are exercised directly.
Verification method:
- Run the hash-module test file on Linux and confirm each documented branch
  returns the expected status, stderr, and stdout shape.
- Compare the test file against the public function contract in this ledger.
Counterpoints / reasons to reject:
- Reject only if the repo intentionally narrows this module to a thin,
  minimally-documented wrapper around `openssl passwd` and removes the current
  stdin and dependency-behavior promises.
