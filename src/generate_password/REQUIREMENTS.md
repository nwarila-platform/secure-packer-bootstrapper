# Requirements: `generate_password`

## Overview

`generate_password` generates a printable-ASCII password from four fixed
classes:

- uppercase letters
- lowercase letters
- digits
- special characters

It validates the caller's requested class sets and minimum counts, then uses
exact rejection sampling over the active character alphabet. Candidate
passwords are drawn uniformly from the active alphabet, and prefixes that can
no longer reach any valid completion are rejected immediately. This keeps the
accepted output uniform over the constrained password space while preventing
random false failures for satisfiable requests.

This module is intentionally narrower than a generic password-policy engine. It
does not support global character-exclusion overlays or arbitrary class
definitions.

## Function Signature

```bash
generate_password [OPTIONS]
```

## Supported Options

- `-l, --length N`
- `--upper STRING`
- `--lower STRING`
- `--digit STRING`
- `--special STRING`
- `--min-upper N`
- `--min-lower N`
- `--min-digit N`
- `--min-special N`
- `--max-consecutive N`

## Removed Options

The following option is intentionally no longer part of the active public
contract:

- `--exclude-chars`

Callers that need a narrower character set must provide it directly through
`--upper`, `--lower`, `--digit`, or `--special`.

## Defaults

- `--length 24`
- `--upper ABCDEFGHIJKLMNOPQRSTUVWXYZ`
- `--lower abcdefghijklmnopqrstuvwxyz`
- `--digit 0123456789`
- `--special !@#$%^&*()-_=+[]{}|;:',.<>?/\\\`~`
- `--min-upper 1`
- `--min-lower 1`
- `--min-digit 1`
- `--min-special 1`
- `--max-consecutive 3`

## Output Contract

On success, stdout contains exactly one newline-terminated password string.

## Validation Rules

- `--length` must be an integer between `8` and `256`
- each `--min-*` value must be an integer between `0` and `256`
- `--max-consecutive` must be an integer between `0` and `256`
- each overridden class string must contain only characters valid for that
  class
- each overridden class string must not contain duplicate characters
- any class with a positive minimum must remain non-empty
- the sum of all minimums must not exceed `--length`

Class ranges:

- `upper`: ASCII `A-Z`
- `lower`: ASCII `a-z`
- `digit`: ASCII `0-9`
- `special`: printable ASCII that is not alphanumeric

## Algorithm

1. Parse and validate options.
2. Build one character pool per active class.
3. Build a memoized feasibility map that answers whether a given generation
   state still has any valid completion.
4. Draw candidate characters uniformly from the active alphabet.
5. Reject the candidate immediately when it would violate the run limit or
   leave no valid completion for the remaining suffix.
6. Emit the first fully valid candidate password.

This module no longer depends on `fisher_yates_shuffle` or
`enforce_max_consecutive`.

## Security Rules

- randomness must come only from `/dev/urandom` read through `od` and the
  module's rejection-sampled draw helpers
- no `$RANDOM`, `shuf`, or ad hoc external randomness sources are allowed
- the function must run with `set +x`, `set -f`, and `LC_ALL=C`
- no intermediate password material may be written to disk
- output must be atomic and appear only once on stdout

## Exit Codes

- `0`: success
- `1`: runtime failure or unsatisfiable constraints
- `2`: usage or validation error
- `127`: missing dependency

## Dependencies

- `od`
- `/dev/urandom` or the configured `GET_RANDOM_URANDOM_PATH`

## Detailed Audit Requirements

## REQ-PASSWORD-001

Status: Satisfied
Priority: P1
Severity: High
Domain: option-surface-minimalism
Applies to: public feature scope
Affected files/lines:
- `src/generate_password/generate_password.sh`
- `test/generate_password_test.sh`
Requirement:
- `generate_password` MUST expose only the option surface needed for the
  current fixed-class password contract. Generic overlay features such as
  `--exclude-chars` MUST NOT remain part of the active public interface.
Rationale:
- Direct class overrides already cover the real use case, while overlay options
  widen the attack and maintenance surface without adding essential capability.
Verification:
- Run the password tests and confirm `--exclude-chars` fails as an unknown
  option.

## REQ-PASSWORD-002

Status: Satisfied
Priority: P1
Severity: High
Domain: secure-generation
Applies to: randomness, validation, and output behavior
Affected files/lines:
- `src/generate_password/generate_password.sh`
- `test/generate_password_test.sh`
Requirement:
- `generate_password` MUST validate class ranges and counts before generation,
  draw randomness only through its `/dev/urandom`-backed rejection-sampled
  helpers, and emit exactly one newline-terminated password on stdout.
Rationale:
- The module's security story depends on strict validation, unbiased random
  draws, and minimal output surface.
Verification:
- Run the password tests and confirm success paths, invalid-class rejections,
  run-limit behavior, and repeated-run variation all pass.

## REQ-PASSWORD-003

Status: Satisfied
Priority: P1
Severity: High
Domain: constrained-sampling-correctness
Applies to: `--max-consecutive` handling
Affected files/lines:
- `src/generate_password/generate_password.sh`
- `test/generate_password_test.sh`
- `test/generate_password_exhaustive_test.sh`
Requirement:
- For satisfiable `--max-consecutive` requests, `generate_password` MUST sample
  from the constrained output space without random false failures. The
  implementation MUST preserve exact rejection-sampling semantics over the
  valid password set and MUST reject impossible prefixes as soon as they are
  detected.
Rationale:
- Retry-based or heuristic placement can turn valid requests into flaky
  failures or silently bias the constrained output distribution. Exact
  rejection sampling plus prefix-feasibility pruning keeps the proof story
  clean while remaining implementable in Bash.
Verification:
- Run the password tests and the exhaustive password-space tests. Confirm
  repeated `--max-consecutive 1` requests succeed, intentionally unsatisfiable
  one-class requests still fail, and every emitted password belongs to the
  brute-force valid set for the covered small spaces.
