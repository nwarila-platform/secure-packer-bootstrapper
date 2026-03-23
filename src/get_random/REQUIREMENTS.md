# Requirements: `get_random`

## 1. Overview

`get_random` is a hardened random integer generator for Bash. It reads raw
bytes from `/dev/urandom`, parses them via `od`, and applies rejection
sampling to produce unbiased integers in a caller-specified range. It is the
sole entropy primitive for the entire secure-packer-bootstrapper project —
no other module may access `/dev/urandom` or any other randomness source
directly.

---

## 2. Module Location

```
src/
└── get_random/
    ├── get_random.sh    # function source (subshell-isolated)
    ├── REQUIREMENTS.md  # this document
    └── get_random.bats  # 100% code-path coverage tests
```

---

## 3. Function Signature

```
get_random COUNT [MIN MAX]
```

### 3.1 Modes

| Mode | Invocation | Output |
|---|---|---|
| **Raw bytes** | `get_random COUNT` | COUNT integers in `[0, 256)` (0–255), one per line. |
| **Ranged** | `get_random COUNT MIN MAX` | COUNT integers in `[MIN, MAX)`, one per line. |

When only COUNT is provided, MIN defaults to `0` and MAX defaults to `256`.

### 3.2 Parameter Constraints

| Parameter | Type | Range | Default |
|---|---|---|---|
| `COUNT` | int | 1–999 (no leading zeros) | *(required)* |
| `MIN` | int | 0–254 (no leading zeros) | `0` |
| `MAX` | int | 1–255 (no leading zeros) | `256` |

Additional constraints:
- `MIN < MAX` (strict inequality).
- `MAX - MIN` defines the span. Span MUST be in `[1, 256]`.

---

## 4. Algorithm

```
┌────────────────────────────────────────────────────┐
│ 1. HARDEN ENVIRONMENT                              │
│    - set +x  (disable xtrace)                      │
│    - set -f  (disable globbing)                    │
└─────────────────────┬──────────────────────────────┘
                      │
                      ▼
┌────────────────────────────────────────────────────┐
│ 2. RESOLVE DEPENDENCIES                            │
│    - Resolve od to absolute path via type -P        │
│    - Verify /dev/urandom is readable               │
└─────────────────────┬──────────────────────────────┘
                      │
                      ▼
┌────────────────────────────────────────────────────┐
│ 3. PARSE & VALIDATE ARGUMENTS                      │
│    - Parse COUNT, MIN, MAX as base-10 integers     │
│    - Validate ranges (see §3.2)                    │
│    - Assert MIN < MAX                              │
└─────────────────────┬──────────────────────────────┘
                      │
                      ▼
┌────────────────────────────────────────────────────┐
│ 4. COMPUTE REJECTION THRESHOLD                     │
│    span  = MAX - MIN                               │
│    limit = 256 - (256 % span)                      │
│    Any raw byte >= limit is rejected (avoids       │
│    modulo bias).                                   │
└─────────────────────┬──────────────────────────────┘
                      │
                      ▼
┌────────────────────────────────────────────────────┐
│ 5. GENERATE LOOP                                   │
│    While produced < COUNT:                         │
│      Read a chunk of bytes from /dev/urandom via   │
│        od -v -A n -N chunk -t u1                   │
│      For each byte in chunk:                       │
│        If span == 256: accept directly             │
│        Else if byte < limit: accept (MIN + byte%span) │
│        Else: reject (modulo bias)                  │
│      Verify parsed count == requested chunk size   │
└─────────────────────┬──────────────────────────────┘
                      │
                      ▼
┌────────────────────────────────────────────────────┐
│ 6. ATOMIC EMIT                                     │
│    Print all values to stdout at once.             │
│    No partial output on failure.                   │
└────────────────────────────────────────────────────┘
```

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
| `remaining <= 64` | `min(remaining × 4, 256)` with floor of 64 |

The 256-byte ceiling comes from POSIX `random(4)`: reads ≤256 bytes are
guaranteed not to be interrupted by signal handlers.

### 4.3 Short Read Detection

After each `od` invocation, the function counts the number of parsed byte
values and compares against the requested chunk size. A mismatch (short read)
is treated as a fatal error — the function MUST NOT silently produce fewer
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
| Bash ≥ 3.2 | Yes | Uses local variables, arrays, `[[ ]]`, arithmetic `(( ))`. |

No other modules are required. `get_random` is a leaf dependency.

---

## 9. Test Coverage Requirements

### 9.1 Happy Path

| ID | Test |
|---|---|
| HP-01 | `get_random 1` → one integer in [0, 256). |
| HP-02 | `get_random 10` → exactly 10 lines, each in [0, 256). |
| HP-03 | `get_random 1 0 10` → one integer in [0, 10). |
| HP-04 | `get_random 100 0 10` → 100 integers, all in [0, 10). |
| HP-05 | `get_random 1 0 256` → one integer in [0, 256) (full span, no rejection). |
| HP-06 | `get_random 1 100 200` → one integer in [100, 200). |
| HP-07 | `get_random 999` → exactly 999 lines (maximum COUNT). |
| HP-08 | `get_random 1 0 1` → always 0 (span=1, only one possible value). |
| HP-09 | `get_random 1 254 255` → always 254 (span=1 at top of range). |

### 9.2 Validation Errors (exit 2)

| ID | Test |
|---|---|
| VE-01 | `get_random 0` → error (COUNT below 1). |
| VE-02 | `get_random 1000` → error (COUNT above 999). |
| VE-03 | `get_random -1` → error (negative). |
| VE-04 | `get_random abc` → error (non-integer). |
| VE-05 | `get_random 01` → error (leading zero). |
| VE-06 | `get_random 1 255 256` → error (MIN=255, invalid). |
| VE-07 | `get_random 1 0 0` → error (MAX=0, invalid). |
| VE-08 | `get_random 1 10 10` → error (MIN == MAX). |
| VE-09 | `get_random 1 10 5` → error (MIN > MAX). |
| VE-10 | `get_random 1 abc 10` → error (non-integer MIN). |
| VE-11 | `get_random 1 0 abc` → error (non-integer MAX). |

### 9.3 Dependency / Runtime Errors

| ID | Test | Method |
|---|---|---|
| DE-01 | `od` not in PATH → exit 127 | Temporarily override PATH |
| DE-02 | `/dev/urandom` not readable → exit 1 | Mock/skip on systems where this can't be simulated |
| DE-03 | `od` produces unexpected output → exit 1 | Mock `od` to return a value > 255 |
| DE-04 | Short read from `od` → exit 1 | Mock `od` to return fewer bytes than requested |
| DE-05 | Stdout write failure → exit 1 | Redirect stdout to a closed file descriptor |

### 9.4 Statistical Tests

| ID | Test | Method |
|---|---|---|
| ST-01 | No value outside [MIN, MAX) in 1000 draws | `get_random 1000 0 10`, assert all in [0,10) |
| ST-02 | All values in range appear over 10000 draws | `get_random 10000 0 10`, assert each of 0–9 appears at least once |
| ST-03 | Rejection sampling produces no bias (chi-squared) | `get_random 10000 0 7`, chi-squared test that distribution is uniform within p>0.01 |

### 9.5 Edge Cases

| ID | Test |
|---|---|
| EC-01 | `get_random 1 0 256` — full span, rejection sampling disabled. |
| EC-02 | `get_random 1 0 128` — span evenly divides 256, no rejections needed. |
| EC-03 | `get_random 1 0 3` — high rejection rate (limit=255, only 0-254 accepted). |
| EC-04 | `get_random 256` — chunk size exactly hits CHUNK_MAX. |
| EC-05 | `get_random 257` — requires multiple chunks. |

---

## 10. Non-Requirements

- **Floating point** — integer output only.
- **Cryptographic key derivation** — this produces random integers, not key material.
- **Seeding** — `/dev/urandom` is self-seeding; no seed management.
- **Thread safety** — Bash is single-threaded; not applicable.
