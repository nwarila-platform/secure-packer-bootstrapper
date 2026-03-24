# Requirements: `get_random`

## 1. Overview

`get_random` is a Linux-specific random integer generator for Bash. It reads raw
bytes from `/dev/urandom`, parses them with `od`, and applies rejection
sampling to produce integers in a caller-specified range. It is the
sole entropy primitive for the entire secure-packer-bootstrapper project -
no other module may access `/dev/urandom` or any other randomness source
directly.

---

## 2. Module Location

```text
src/
\-- get_random/
    |-- get_random.sh    # function source (subshell-isolated)
    |-- REQUIREMENTS.md  # this document
    \-- ../../test/get_random_test.sh  # current Bash test file
```

---

## 3. Function Signature

```
get_random COUNT [MIN MAX]
```

### 3.1 Modes

| Mode | Invocation | Output |
|---|---|---|
| **Raw bytes** | `get_random COUNT` | COUNT integers in `[0, 256)` (0-255), one per line. |
| **Ranged** | `get_random COUNT MIN MAX` | COUNT integers in `[MIN, MAX)`, one per line. |

When only COUNT is provided, MIN defaults to `0` and MAX defaults to `256`.

### 3.2 Parameter Constraints

| Parameter | Type | Range | Default |
|---|---|---|---|
| `COUNT` | int | 1-999 (no leading zeros) | *(required)* |
| `MIN` | int | 0-254 (no leading zeros) | `0` |
| `MAX` | int | 1-255 (no leading zeros) | `256` |

Additional constraints:
- `MIN < MAX` (strict inequality).
- `MAX - MIN` defines the span. Span MUST be in `[1, 256]`.

---

## 4. Algorithm

1. Harden the environment.
   - Disable xtrace with `set +x`.
   - Disable globbing with `set -f`.
2. Resolve dependencies.
   - Resolve `od` to an absolute path with `type -P`.
   - Verify `/dev/urandom` is readable.
3. Parse and validate arguments.
   - Parse `COUNT`, `MIN`, and `MAX` as base-10 integers.
   - Validate the ranges listed in section 3.2.
   - Require `MIN < MAX`.
4. Compute the rejection threshold.
   - `span = MAX - MIN`
   - `limit = 256 - (256 % span)`
   - Reject any raw byte `>= limit` to avoid modulo bias.
5. Generate values until `COUNT` outputs are accepted.
   - Read a chunk of bytes from `/dev/urandom` with `od -v -A n -N chunk -t u1`.
   - If `span == 256`, accept each byte directly.
   - Otherwise accept only bytes `< limit`, then map with `MIN + (byte % span)`.
   - Verify that the parsed byte count matches the requested chunk size.
6. Emit output atomically.
   - Print all accepted values to stdout only after the full request succeeds.
   - Do not emit partial output on failure.

### 4.1 Rejection Sampling

For a span that does not evenly divide 256, some byte values would map to
lower indices more often than higher ones (modulo bias). The rejection
threshold `limit = 256 - (256 % span)` ensures that only byte values in
`[0, limit)` are accepted, giving each index in `[0, span)` exactly
`floor(256 / span)` representations.

When `span == 256`, all byte values are accepted directly (no rejection
needed).

### 4.2 Chunk Sizing Heuristic

To minimize round-trips to `/dev/urandom`, the function reads bytes in chunks:

| Condition | Chunk size |
|---|---|
| `span == 256` (no rejections) | `min(remaining, 256)` |
| `remaining > 64` | `256` (maximum safe read) |
| `remaining <= 64` | `min(remaining x 4, 256)` with floor of 64 |

The 256-byte ceiling comes from the Linux `random(4)` / `getrandom(2)`
interfaces: reads from the urandom source of up to 256 bytes are documented to
return the requested number of bytes without signal interruption. This is a
Linux-specific contract, not a POSIX one.

### 4.3 Short Read Detection

After each `od` invocation, the function counts the number of parsed byte
values and compares against the requested chunk size. A mismatch (short read)
is treated as a fatal error - the function MUST NOT silently produce fewer
values than expected.

---

## 5. Security Properties

| Property | Mechanism |
|---|---|
| Entropy source | `/dev/urandom` only. No `$RANDOM`, no fallbacks. |
| No modulo bias | Rejection sampling with computed threshold. |
| No information leakage | Runs in subshell `()`. `set +x` disables tracing. All variables are local. |
| Atomic output | Values buffered in array, emitted only on complete success. |
| No temp files | All state in memory. |
| Binary hardening | `od` resolved via `type -P` (bypasses aliases/functions). |
| Defensive parsing | All integers parsed as explicit base-10 (`10#$var`). `set -f` disables globbing. `IFS` explicitly set. |

---

## 6. Exit Codes

| Code | Meaning |
|---|---|
| `0` | Success. Exactly COUNT lines on stdout, each a base-10 integer in the requested range. |
| `1` | Runtime failure (`/dev/urandom` unreadable, `od` failed, short read, unexpected byte value >255, stdout write failed). |
| `2` | Usage / validation error (bad COUNT, MIN, MAX, or MIN >= MAX). |
| `127` | Missing dependency (`od` not found in PATH). |

---

## 7. Stdout Contract

**On success (exit 0):**
- Exactly COUNT lines on stdout.
- Each line is a single base-10 integer.
- Each integer is in `[MIN, MAX)`.
- No output is produced until all values are generated and validated (atomic
  emit).

**On failure (exit != 0):**
- **Nothing** on stdout.
- Diagnostic message on stderr.

---

## 8. Dependencies

| Dependency | Required | Resolution |
|---|---|---|
| `od` | Yes | Resolved to absolute path via `type -P od`. |
| `/dev/urandom` | Yes | Verified readable at function entry. |
| Bash >= 4.3 | Yes | Repo-wide supported baseline. |

No other modules are required. `get_random` is a leaf dependency.

---

## 9. Test Coverage Requirements

These are target coverage requirements for the module ledger. The current
`test/get_random_test.sh` suite does not yet implement every statistical item
listed below.

### 9.1 Happy Path

| ID | Test |
|---|---|
| HP-01 | `get_random 1` -> one integer in [0, 256). |
| HP-02 | `get_random 10` -> exactly 10 lines, each in [0, 256). |
| HP-03 | `get_random 1 0 10` -> one integer in [0, 10). |
| HP-04 | `get_random 100 0 10` -> 100 integers, all in [0, 10). |
| HP-05 | `get_random 1 0 256` -> one integer in [0, 256) (full span, no rejection). |
| HP-06 | `get_random 1 100 200` -> one integer in [100, 200). |
| HP-07 | `get_random 999` -> exactly 999 lines (maximum COUNT). |
| HP-08 | `get_random 1 0 1` -> always 0 (span=1, only one possible value). |
| HP-09 | `get_random 1 254 255` -> always 254 (span=1 at top of range). |

### 9.2 Validation Errors (exit 2)

| ID | Test |
|---|---|
| VE-01 | `get_random 0` -> error (COUNT below 1). |
| VE-02 | `get_random 1000` -> error (COUNT above 999). |
| VE-03 | `get_random -1` -> error (negative). |
| VE-04 | `get_random abc` -> error (non-integer). |
| VE-05 | `get_random 01` -> error (leading zero). |
| VE-06 | `get_random 1 255 256` -> error (MIN=255, invalid). |
| VE-07 | `get_random 1 0 0` -> error (MAX=0, invalid). |
| VE-08 | `get_random 1 10 10` -> error (MIN == MAX). |
| VE-09 | `get_random 1 10 5` -> error (MIN > MAX). |
| VE-10 | `get_random 1 abc 10` -> error (non-integer MIN). |
| VE-11 | `get_random 1 0 abc` -> error (non-integer MAX). |

### 9.3 Dependency / Runtime Errors

| ID | Test | Method |
|---|---|---|
| DE-01 | `od` not in PATH -> exit 127 | Temporarily override PATH |
| DE-02 | `/dev/urandom` not readable -> exit 1 | Mock/skip on systems where this can't be simulated |
| DE-03 | `od` produces unexpected output -> exit 1 | Mock `od` to return a value > 255 |
| DE-04 | Short read from `od` -> exit 1 | Mock `od` to return fewer bytes than requested |
| DE-05 | Stdout write failure -> exit 1 | Redirect stdout to a closed file descriptor |

### 9.4 Statistical Tests

| ID | Test | Method |
|---|---|---|
| ST-01 | No value outside [MIN, MAX) in 1000 draws | `get_random 1000 0 10`, assert all in [0,10) |
| ST-02 | Bucket smoke test for `[0, 10)` | `get_random 900 0 10`, assert each bucket count stays within broad smoke-test bounds |
| ST-03 | Rejection sampling produces no bias (chi-squared) | `get_random 10000 0 7`, chi-squared test that distribution is uniform within p>0.01 |

### 9.5 Edge Cases

| ID | Test |
|---|---|
| EC-01 | `get_random 1 0 256` - full span, rejection sampling disabled. |
| EC-02 | `get_random 1 0 128` - span evenly divides 256, no rejections needed. |
| EC-03 | `get_random 1 0 3` - high rejection rate (limit=255, only 0-254 accepted). |
| EC-04 | `get_random 256` - chunk size exactly hits CHUNK_MAX. |
| EC-05 | `get_random 257` - requires multiple chunks. |

---

## 10. Non-Requirements

- **Floating point** - integer output only.
- **Cryptographic key derivation** - this produces random integers, not key material.
- **Seeding** - `/dev/urandom` is self-seeding; no seed management.
- **Thread safety** - Bash is single-threaded; not applicable.

---

## 11. Detailed Audit Requirements

## REQ-RNG-001

Status: Satisfied
Priority: P1
Severity: High
Domain: rng-source-contract
Applies to: Linux RNG semantics, chunk-sizing rationale, and entropy-source claim precision
Affected files/lines:
- `src/get_random/get_random.sh:11-137`
- `src/get_random/REQUIREMENTS.md:5-10`
- `src/get_random/REQUIREMENTS.md:120-138`
- `src/get_random/REQUIREMENTS.md:182-190`
- `README.md:38-46`
Authoritative sources:
- Linux `random(4)` manual page. https://www.man7.org/linux/man-pages/man4/random.4.html
- Linux `getrandom(2)` manual page. https://man7.org/linux/man-pages/man2/getrandom.2.html
- Linux `random(7)` manual page. https://man7.org/linux/man-pages/man7/random.7.html
Repository evidence:
- The implementation reads entropy only from `${GET_RANDOM_URANDOM_PATH:-/dev/urandom}`.
- It caps each `od` read at 256 bytes and explains that choice in this ledger.
- README and this ledger now describe the module as a Linux-specific
  `/dev/urandom` + rejection-sampling primitive.
Applicability analysis:
- This repository explicitly targets Linux and uses the Linux `/dev/urandom` device interface.
- Linux documents `/dev/urandom` as the preferred interface for almost all use
  cases, with the important exception of early-boot randomness, where
  `getrandom(2)` is the recommended interface.
- Linux, not POSIX, documents the read-size behavior that justifies the current
  256-byte chunk ceiling.
Requirement:
- The repository MUST describe `get_random` as a Linux-specific
  `/dev/urandom` + rejection-sampling primitive. Documentation for chunk sizing
  and security properties MUST cite Linux RNG interfaces, not POSIX, and MUST
  state that early-boot randomness is outside the current supported runtime
  contract unless the implementation is changed and re-verified for that case.
Rationale:
- The current implementation is reasonable for GitHub workflow and image-build
  hosts, but the review story becomes misleading if Linux-specific guarantees
  are presented as generic Unix or POSIX behavior.
Acceptance criteria:
- The ledger no longer attributes `/dev/urandom` read guarantees to POSIX.
- The repo describes `get_random` as Linux-specific rather than generic shell
  or generic Unix behavior.
- Early-boot randomness is either explicitly out of scope or separately
  evidenced.
Recommended change:
- Keep the current `/dev/urandom` design, but anchor its rationale to Linux
  `random(4)` / `getrandom(2)` and document the early-boot boundary plainly.
Verification method:
- Inspect the implementation and confirm it still reads `/dev/urandom` through
  `od` with a 256-byte maximum chunk size.
- Review README and module docs and confirm they cite Linux semantics rather
  than POSIX semantics.
Counterpoints / reasons to reject:
- Reject only if the repository deliberately narrows itself to a different RNG
  contract, such as a direct `getrandom(2)` implementation, and documents that
  new contract with equal or stronger evidence.

## REQ-RNG-002

Status: Satisfied
Priority: P1
Severity: High
Domain: stochastic-verification
Applies to: evidence for "unbiased" RNG claims and statistical-test traceability
Affected files/lines:
- `src/get_random/REQUIREMENTS.md:236-243`
- `test/get_random_test.sh:9-47`
- `README.md:40`
Authoritative sources:
- `docs/STUDENT-FIRST-STANDARDS.md`
- Linux `random(7)` manual page. https://man7.org/linux/man-pages/man7/random.7.html
Repository evidence:
- README currently describes `get_random` as producing unbiased random integers.
- This ledger now lists lightweight distribution smoke checks that match the
  current verification surface.
- `test/get_random_test.sh` now includes a repeated-run bucket-distribution
  smoke test for `[0, 10)` in addition to range checks and failure modes.
Applicability analysis:
- Because `get_random` is the sole entropy primitive for the repo, words such as
  "unbiased" carry more weight than a normal convenience helper would.
- This repository also presents itself as a learning and portfolio artifact, so
  reviewers need to be able to distinguish algorithmic reasoning from measured
  evidence.
Requirement:
- When `get_random` is described as "unbiased" or when its ledger lists
  statistical tests, the verification surface MUST match that wording. The repo
  MUST either implement representative automated distribution checks for the
  documented claims, or it MUST label those statistical items as planned
  coverage and present the current claim as algorithmically reasoned rather than
  empirically verified.
Rationale:
- The implementation's rejection-sampling design is strong, and the test suite
  now includes a lightweight repeated-run smoke test that matches the wording
  used here.
Acceptance criteria:
- `test/get_random_test.sh` includes a representative repeated-run distribution
  smoke test that matches the ledger's stated evidence level.
- Statistical-test sections are not written as if already implemented when they
  are still future coverage.
Recommended change:
- Keep the lightweight distribution smoke tests aligned with the ledger's
  wording, and only add stronger statistical claims when stronger evidence is
  added.
Verification method:
- Review `test/get_random_test.sh` for statistical checks and compare it against
  the ledger's stated coverage.
- Review README and module wording for whether the current evidence level is
  presented honestly.
Counterpoints / reasons to reject:
- Reject only if maintainers intentionally choose code-review-only assurance for
  distribution properties and document that decision explicitly enough that
  readers are not led to assume empirical proof exists today.
