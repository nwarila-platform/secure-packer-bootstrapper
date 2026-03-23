# Requirements: `generate_password`

## 1. Overview

`generate_password` is the orchestrator module that produces cryptographically
secure passwords suitable for Packer/Kickstart build-user credentials. It
validates user options, builds Vigenère-style shuffled character pools,
generates candidate characters, delegates shuffling and constraint enforcement
to dedicated modules, verifies the result, and emits the password.

This module owns **option parsing, validation, pool construction, character
generation, post-enforcement verification, and atomic output**. It delegates
shuffling to `fisher_yates_shuffle` and consecutive-class enforcement to
`enforce_max_consecutive`.

---

## 2. Module Location

```
src/
└── generate_password/
    ├── generate_password.sh    # function source (subshell-isolated)
    ├── REQUIREMENTS.md         # this document
    └── generate_password.bats  # 100% code-path coverage tests
```

---

## 3. Function Signature

```
generate_password [OPTIONS]
```

All configuration is via named options (no positional arguments).

### 3.1 Options

| Option | Type | Default | Description |
|---|---|---|---|
| `-l, --length` | int | `24` | Total password length. Must be >= sum of all `--min-*` values. Range: 8–256. |
| `--upper` | str | `ABCDEFGHIJKLMNOPQRSTUVWXYZ` | Override the character set for the `upper` class. |
| `--lower` | str | `abcdefghijklmnopqrstuvwxyz` | Override the character set for the `lower` class. |
| `--digit` | str | `0123456789` | Override the character set for the `digit` class. |
| `--special` | str | `` !@#$%^&*()-_=+[]{}\|;:',.<>?/`~ `` | Override the character set for the `special` class. |
| `--min-upper` | int | `1` | Minimum number of `upper` characters in the password. Range: 0–256. |
| `--min-lower` | int | `1` | Minimum number of `lower` characters in the password. Range: 0–256. |
| `--min-digit` | int | `1` | Minimum number of `digit` characters in the password. Range: 0–256. |
| `--min-special` | int | `1` | Minimum number of `special` characters in the password. Range: 0–256. |
| `--max-consecutive` | int | `3` | Max consecutive characters from the **same** class. 0 = unlimited. Range: 0–256. |
| `--exclude-chars` | str | `""` | Characters to strip from **every** class. Applied after class overrides. |

### 3.2 Fixed Character Classes

There are exactly **four** character classes. Their names are fixed and cannot
be added to or removed. Users may only customize the character set within each
class.

| Class | Default Characters | Allowed Characters (validation) |
|---|---|---|
| `upper` | `ABCDEFGHIJKLMNOPQRSTUVWXYZ` | Only ASCII uppercase letters: `[A-Z]` (0x41–0x5A) |
| `lower` | `abcdefghijklmnopqrstuvwxyz` | Only ASCII lowercase letters: `[a-z]` (0x61–0x7A) |
| `digit` | `0123456789` | Only ASCII digits: `[0-9]` (0x30–0x39) |
| `special` | `` !@#$%^&*()-_=+[]{}\|;:',.<>?/`~ `` | Only ASCII printable non-alphanumeric (0x21–0x7E minus `[A-Za-z0-9]`) |

Setting a class to an empty string (e.g., `--special ''`) disables that class.
Its `--min-*` MUST also be 0, or validation fails.

### 3.3 Character-Class Membership Validation

When a user overrides a class's character set, **every character** in the
provided string MUST belong to that class's allowed ASCII range. This prevents
nonsensical configurations like `+` in the `lower` class or `a` in `digit`.

| Scenario | Result |
|---|---|
| `--lower 'abcxyz'` | Valid — all chars are `[a-z]`. |
| `--lower 'abc123'` | **Error** — `1`, `2`, `3` are not lowercase letters. |
| `--upper 'ABC!'` | **Error** — `!` is not an uppercase letter. |
| `--digit '0123+'` | **Error** — `+` is not a digit. |
| `--special 'abc'` | **Error** — `a`, `b`, `c` are lowercase letters, not special. |
| `--lower ''` | Valid — disables the class (but `--min-lower` must be 0). |

Error message format:
```
error: --CLASS contains characters not valid for that class: 'INVALID_CHARS'
```

### 3.4 No Cross-Class Overlap

The allowed-character ranges for the four classes are disjoint by definition
(`[A-Z]`, `[a-z]`, `[0-9]`, everything else). The membership validation in
§3.3 **automatically enforces** this invariant — no separate overlap check
is needed.

---

## 4. Algorithm

### 4.1 Design Rationale

The algorithm uses two key techniques:

**Vigenère-style pool mapping.** Each character class's character set is
Fisher-Yates shuffled into a lookup table (a "pool"). Random bytes from
`get_random` are used as indices into these pre-shuffled pools to select
characters — the random byte is the "coordinate" and the shuffled pool is
the "cipher alphabet." A fifth pool is constructed from the union of all
active classes and also shuffled. This yields 5 pools:

| Pool | Source | Used for |
|---|---|---|
| `pool_upper` | Fisher-Yates shuffle of `--upper` chars | Satisfying `--min-upper` |
| `pool_lower` | Fisher-Yates shuffle of `--lower` chars | Satisfying `--min-lower` |
| `pool_digit` | Fisher-Yates shuffle of `--digit` chars | Satisfying `--min-digit` |
| `pool_special` | Fisher-Yates shuffle of `--special` chars | Satisfying `--min-special` |
| `pool_combined` | Fisher-Yates shuffle of all active class chars | Filling remaining slots |

**2x overgeneration with move-to-end enforcement.** Instead of generating
exactly `length` characters and retrying when consecutive-class violations
occur, we generate `2 × length` characters up front, shuffle them, then
delegate to `enforce_max_consecutive` which performs a single O(n) pass
to produce a valid sequence.

### 4.2 Algorithm Steps

```
┌──────────────────────────────────────────────────────┐
│ 1. PARSE & VALIDATE OPTIONS                          │
│    - Validate all inputs (see §5)                    │
│    - Validate class membership (see §3.3)            │
│    - Apply --exclude-chars to each class              │
│    - Verify sum(min-*) <= length                      │
│    - Verify every class with min>0 is non-empty       │
└──────────────────────┬────────────────────────────────┘
                       │
                       ▼
┌──────────────────────────────────────────────────────┐
│ 2. BUILD SHUFFLED POOLS (Vigenère-style)             │
│    For each active class:                            │
│      Copy class chars into an array                  │
│      fisher_yates_shuffle the array                  │
│    Build combined pool from union of all active       │
│      class chars, then fisher_yates_shuffle it        │
│    Result: up to 5 shuffled lookup tables             │
└──────────────────────┬────────────────────────────────┘
                       │
                       ▼
┌──────────────────────────────────────────────────────┐
│ 3. GENERATE 2×length CANDIDATE CHARACTERS            │
│                                                      │
│  3a. SATISFY MINIMUMS                                │
│      For each class with min > 0:                    │
│        Call get_random to obtain min random indices   │
│        Map each index → pool_CLASS[index % pool_len] │
│        Append to candidate array                     │
│      Total chars so far: sum(all mins)               │
│                                                      │
│  3b. FILL TO 2×length                                │
│      remaining = (2 × length) - sum(all mins)        │
│      Call get_random to obtain remaining indices      │
│      Map each index → pool_combined[idx % pool_len]  │
│      Append to candidate array                       │
│      Total chars: 2 × length                         │
└──────────────────────┬────────────────────────────────┘
                       │
                       ▼
┌──────────────────────────────────────────────────────┐
│ 4. SHUFFLE THE CANDIDATE ARRAY                       │
│    fisher_yates_shuffle candidate_array               │
│    (full 2×length array shuffled in-place)           │
└──────────────────────┬────────────────────────────────┘
                       │
                       ▼
┌──────────────────────────────────────────────────────┐
│ 5. ENFORCE CONSECUTIVE-CLASS CONSTRAINT              │
│    enforce_max_consecutive candidate result           │
│      length max_consecutive                          │
│    If exit != 0: propagate error                     │
└──────────────────────┬────────────────────────────────┘
                       │
                       ▼
┌──────────────────────────────────────────────────────┐
│ 6. VERIFY MINIMUMS SURVIVED ENFORCEMENT              │
│    Count chars per class in result[0..length-1].     │
│    If any class count < its minimum:                 │
│      → Return error (exit 1).                        │
│    (See §4.4 for why this check is necessary.)       │
└──────────────────────┬────────────────────────────────┘
                       │
                       ▼
┌──────────────────────────────────────────────────────┐
│ 7. OUTPUT                                            │
│    Join result array into a single string.           │
│    Print as one line to stdout. Exactly one \n.      │
│    Atomic emit: no output until this point.          │
└──────────────────────────────────────────────────────┘
```

### 4.3 Entropy Budget

All `get_random` calls can be **batched** because the count needed at each
stage is known before generation begins:

| Stage | Random values needed |
|---|---|
| Shuffle `pool_upper` (len U) | U - 1 |
| Shuffle `pool_lower` (len L) | L - 1 |
| Shuffle `pool_digit` (len D) | D - 1 |
| Shuffle `pool_special` (len S) | S - 1 |
| Shuffle `pool_combined` (len C) | C - 1 |
| Satisfy minimums | sum(all mins) |
| Fill to 2×length | 2 × length - sum(all mins) |
| Shuffle 2×length candidate array | 2 × length - 1 |

**Total: `(U+L+D+S+C-5) + (4 × length - 1)` random values.**

With default settings (U=26, L=26, D=10, S=32, C=94, length=24):
`(94 - 5) + (96 - 1)` = **184 random values**.

The implementation MAY issue a single bulk `get_random` call and consume
values sequentially, or issue separate calls per stage — both are correct.

### 4.4 Post-Enforcement Minimum Verification

The `enforce_max_consecutive` pass may displace characters that were
generated in step 3a to satisfy class minimums. For example, if
`--min-upper 5` caused 5 uppercase characters to be placed, the enforcement
pass might move some of those to the reserve and replace them with fill
characters from the combined pool.

After enforcement, the function MUST count characters per class in the result
and verify all `--min-*` constraints are still met. If not, the function
returns exit code 1 with:
```
error: generate_password: minimums not satisfiable with current constraints (CLASS needs N, got M)
```

This failure indicates the constraints are collectively hard to satisfy
(e.g., `--min-upper 20 --length 24 --max-consecutive 1`).

---

## 5. Input Validation

All validation failures MUST print a message to stderr and return exit code 2.

| Rule | Error message pattern |
|---|---|
| `--length` outside [8, 256] | `error: --length must be between 8 and 256 (got N)` |
| `--length` not an integer | `error: --length must be a valid integer (got 'VALUE')` |
| `--length` < sum of all `--min-*` | `error: --length (N) is less than the sum of minimums (M)` |
| `--min-CLASS` < 0 or > 256 | `error: --min-CLASS must be between 0 and 256 (got N)` |
| `--min-CLASS` not an integer | `error: --min-CLASS must be a valid integer (got 'VALUE')` |
| `--min-CLASS` > 0 but class is empty | `error: class 'CLASS' is empty but --min-CLASS is N` |
| `--max-consecutive` outside [0, 256] | `error: --max-consecutive must be between 0 and 256 (got N)` |
| `--max-consecutive` not an integer | `error: --max-consecutive must be a valid integer (got 'VALUE')` |
| `--CLASS` contains invalid chars | `error: --CLASS contains characters not valid for that class: 'CHARS'` |
| `--CLASS` contains duplicate chars | `error: --CLASS contains duplicate characters: 'CHARS'` |
| `--exclude-chars` empties all classes | `error: --exclude-chars removed all characters from every class` |
| Unknown option | `error: unknown option 'OPT'` |

### 5.1 Validation Order

Validation MUST proceed in this deterministic order:

1. Unknown options
2. Type checks (integer validation for all numeric options)
3. Range checks (`--length`, `--min-*`, `--max-consecutive`)
4. Class membership validation (`--upper`, `--lower`, `--digit`, `--special`)
5. Duplicate character checks within each class
6. Apply `--exclude-chars`
7. Empty-class-with-min-greater-than-zero check
8. Sum-of-minimums vs. length check

---

## 6. Security Properties

| Property | Mechanism |
|---|---|
| Entropy source | `/dev/urandom` via `get_random` only. No `$RANDOM`, no `shuf`, no external tools. |
| No modulo bias | Inherited from `get_random`'s rejection sampling. |
| Uniform shuffle | `fisher_yates_shuffle` with unbiased random source. |
| No information leakage | Function runs in a subshell `()`. No trace output (`set +x`). Variables are local. Password only appears on stdout at the end (atomic emit). |
| No temp files | All intermediate state in memory (bash arrays). |
| Defensive coding | `set -f` (no globbing), `LC_ALL=C`, `IFS` controlled. |

---

## 7. Exit Codes

| Code | Meaning |
|---|---|
| `0` | Success. Exactly one line on stdout containing the password. |
| `1` | Runtime failure (entropy source unavailable, constraint unsatisfiable, enforcement failed, minimums not met post-enforcement). |
| `2` | Usage / input validation error. |
| `127` | Missing dependency (`get_random`, `fisher_yates_shuffle`, or `enforce_max_consecutive` not loaded). |

---

## 8. Dependencies

| Dependency | Required | Resolution |
|---|---|---|
| `get_random` | Yes | Must be a loaded function. Verified at entry. |
| `fisher_yates_shuffle` | Yes | Must be a loaded function. Verified at entry. |
| `enforce_max_consecutive` | Yes | Must be a loaded function. Verified at entry. |
| Bash ≥ 4.3 | Yes | Required for `local -n` (nameref) used by dependencies. |

### 8.1 Dependency Graph

```
generate_password
├── get_random              (entropy)
├── fisher_yates_shuffle    (shuffling)
│   └── get_random
└── enforce_max_consecutive (constraint enforcement — no deps)
```

---

## 9. Stdout Contract

**On success (exit 0):**
- Exactly **one line** on stdout.
- The line contains exactly `--length` printable ASCII characters.
- No leading/trailing whitespace.
- Terminated by a single `\n`.
- No output until the password passes all constraints (atomic emit).

**On failure (exit != 0):**
- **Nothing** on stdout.
- Diagnostic on stderr.

---

## 10. Test Coverage Requirements

### 10.1 Happy Path

| ID | Test |
|---|---|
| HP-01 | Default invocation → 24-char password with at least 1 upper, 1 lower, 1 digit, 1 special. |
| HP-02 | `--length 8` → exactly 8 characters. |
| HP-03 | `--length 256` → exactly 256 characters. |
| HP-04 | Custom minimums: `--min-upper 5 --min-digit 5` are satisfied. |
| HP-05 | `--max-consecutive 1` → no two adjacent same-class chars. |
| HP-06 | `--max-consecutive 0` (unlimited) → any arrangement accepted. |
| HP-07 | `--exclude-chars '0O1lI'` → none of those chars appear in output. |
| HP-08 | Custom upper set: `--upper 'ABCDEF'` → output upper chars only from that subset. |
| HP-09 | Disable special: `--special '' --min-special 0` → no special chars in output. |
| HP-10 | All output characters belong to a defined class. |

### 10.2 Validation Errors (exit 2)

| ID | Test |
|---|---|
| VE-01 | `--length 7` → error (below minimum 8). |
| VE-02 | `--length 257` → error (above maximum 256). |
| VE-03 | Non-integer `--length` → error. |
| VE-04 | `--length 8` with sum of mins = 10 → error. |
| VE-05 | `--lower 'abc123'` → error (digits in lower class). |
| VE-06 | `--upper 'ABC!'` → error (special char in upper class). |
| VE-07 | `--digit '0123+'` → error (special char in digit class). |
| VE-08 | `--special 'abc'` → error (lowercase in special class). |
| VE-09 | `--special '' --min-special 3` → error (empty class with min > 0). |
| VE-10 | `--exclude-chars` removes all chars from all classes → error. |
| VE-11 | Unknown option `--foo` → error. |
| VE-12 | `--upper 'AABBC'` → error (duplicate characters). |
| VE-13 | `--min-upper -1` → error (negative minimum). |
| VE-14 | `--min-lower abc` → error (non-integer minimum). |

### 10.3 Dependency Errors (exit 127)

| ID | Test |
|---|---|
| DP-01 | `get_random` not loaded → exit 127 with message. |
| DP-02 | `fisher_yates_shuffle` not loaded → exit 127 with message. |
| DP-03 | `enforce_max_consecutive` not loaded → exit 127 with message. |

### 10.4 Runtime Failures (exit 1)

| ID | Test |
|---|---|
| RF-01 | Post-enforcement minimum verification fails → exit 1 (use pathological constraints: `--min-upper 20 --length 24 --max-consecutive 1`). |
| RF-02 | `enforce_max_consecutive` returns error → exit 1 propagated. |

### 10.5 Statistical / Distribution Tests

| ID | Test | Method |
|---|---|---|
| ST-01 | Minimum counts met across 50 invocations | Assert each class count >= min on every run. |
| ST-02 | Varied orderings | Generate 20 passwords, assert not all identical. |
| ST-03 | Max-consecutive holds across 50 invocations | Scan each output for violations. |
| ST-04 | Fill chars from all active classes | Over 100 runs with `--length 100`, all 4 classes appear above their minimums. |
| ST-05 | Pool shuffle varies | Generate 10 passwords with `--upper 'ABCDEF'`, verify not all first-upper-chars identical. |

### 10.6 Edge Cases

| ID | Test |
|---|---|
| EC-01 | `--length` exactly equals sum of minimums (no fill slots). |
| EC-02 | Only one class active (other three disabled), min = length. |
| EC-03 | `--max-consecutive 1` with even class distribution — succeeds reliably. |
| EC-04 | Class with a single character (e.g., `--upper 'X'`) and min > 0. |
| EC-05 | `--exclude-chars` removes some but not all chars from a class with min > 0. |
| EC-06 | All four `--min-*` set to 0 — password entirely from combined pool. |
| EC-07 | Only one class active with `--max-consecutive 1` — enforcement is trivially satisfied. |

### 10.7 Class Membership Validation

| ID | Test |
|---|---|
| CM-01 | Valid subset override for each class succeeds (4 tests). |
| CM-02 | Each class rejects characters from each of the other 3 classes (12 tests). |
| CM-03 | Each class rejects control characters (ASCII < 0x21). |
| CM-04 | Each class rejects DEL (0x7F) and chars above 0x7E. |

---

## 11. Example Invocations

```bash
# Source all dependencies
source src/get_random/get_random.sh
source src/fisher_yates_shuffle/fisher_yates_shuffle.sh
source src/enforce_max_consecutive/enforce_max_consecutive.sh
source src/generate_password/generate_password.sh

# Default: 24-char password, at least 1 of each class
generate_password
# → e.g., k8$Qm2!xNp4@rW7&jL9#bY1

# Shorter password
generate_password --length 16

# High-entropy with strict consecutive limits
generate_password --length 64 --min-upper 8 --min-lower 8 \
  --min-digit 8 --min-special 8 --max-consecutive 2

# Alphanumeric only
generate_password --special '' --min-special 0

# Restricted special characters
generate_password --special '!@#$%'

# Remove ambiguous characters
generate_password --exclude-chars '0O1lI|'

# Hex-style: digits + uppercase A-F only
generate_password --length 32 --upper 'ABCDEF' --lower '' --special '' \
  --min-lower 0 --min-special 0 --max-consecutive 0
```

---

## 12. Non-Requirements

- **Additional character classes** — the four classes are fixed.
- **Password strength estimation** — generates, does not score.
- **Clipboard integration** — caller handles output.
- **Interactive prompts** — purely non-interactive.
- **Persistence / storage** — password emitted to stdout and forgotten.
- **Unicode** — printable ASCII only (0x21–0x7E).
- **Shuffling logic** — delegated to `fisher_yates_shuffle`.
- **Consecutive enforcement logic** — delegated to `enforce_max_consecutive`.
