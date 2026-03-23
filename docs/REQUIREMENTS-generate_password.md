# Requirements: `generate_password`

## 1. Overview

`generate_password` produces cryptographically secure passwords suitable for
Packer/Kickstart build-user credentials. It guarantees configurable complexity
constraints — minimum representation per character class, customizable character
sets within fixed classes, and bounded consecutive same-class runs — while
drawing all entropy from `/dev/urandom` via the existing `get_random` primitive.

---

## 2. Module Location

```
src/
└── generate_password/
    ├── generate_password.sh   # function source
    ├── README.md              # this spec (human-readable)
    └── generate_password.bats # 100% branch/line coverage tests
```

The function file MUST source its dependency (`get_random`) explicitly.
It MUST be usable via `source generate_password.sh` followed by a call to
`generate_password [OPTIONS]`.

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
| `--upper` | str | `A-Z` | Override the character set for the `upper` class. |
| `--lower` | str | `a-z` | Override the character set for the `lower` class. |
| `--digit` | str | `0-9` | Override the character set for the `digit` class. |
| `--special` | str | `` !@#$%^&*()-_=+[]{}\|;:',.<>?/` `` | Override the character set for the `special` class. |
| `--min-upper` | int | `1` | Minimum number of `upper` characters. Range: 0–256. |
| `--min-lower` | int | `1` | Minimum number of `lower` characters. Range: 0–256. |
| `--min-digit` | int | `1` | Minimum number of `digit` characters. Range: 0–256. |
| `--min-special` | int | `1` | Minimum number of `special` characters. Range: 0–256. |
| `--max-consecutive` | int | `3` | Max consecutive characters from the **same** class. 0 = unlimited. Range: 0–256. |
| `--exclude-chars` | str | `""` | Characters to strip from **every** class (e.g., ambiguous chars `0O1lI`). Applied after `--upper/--lower/--digit/--special` overrides. |

### 3.2 Fixed Character Classes

There are exactly **four** character classes. Their names are fixed and cannot
be added to or removed. Users may only customize the character set within each
class.

| Class | Default Characters | Allowed Characters (validation rule) |
|---|---|---|
| `upper` | `ABCDEFGHIJKLMNOPQRSTUVWXYZ` | Only ASCII uppercase letters: `[A-Z]` |
| `lower` | `abcdefghijklmnopqrstuvwxyz` | Only ASCII lowercase letters: `[a-z]` |
| `digit` | `0123456789` | Only ASCII digits: `[0-9]` |
| `special` | `` !@#$%^&*()-_=+[]{}\|;:',.<>?/`~ `` | Only ASCII printable non-alphanumeric: `[!-/:-@[-`{-~]` (i.e., `0x21–0x7E` minus `[A-Za-z0-9]`) |

Setting a class to an empty string (e.g., `--special ''`) disables that class.
Its `--min-*` MUST also be 0, or validation fails.

### 3.3 Character-Class Membership Validation

When a user overrides a class's character set, every character in the provided
string MUST belong to that class's allowed character range (see table above).
This prevents nonsensical configurations like putting `+` in the `lower` class
or `a` in the `digit` class.

Validation rules:

| Scenario | Result |
|---|---|
| `--lower 'abcxyz'` | Valid — all chars are `[a-z]`. |
| `--lower 'abc123'` | **Error** — `1`, `2`, `3` are not lowercase letters. |
| `--upper 'ABC!'` | **Error** — `!` is not an uppercase letter. |
| `--digit '0123+'` | **Error** — `+` is not a digit. |
| `--special 'abc'` | **Error** — `a`, `b`, `c` are lowercase letters, not special chars. |
| `--lower ''` | Valid — disables the class (but `--min-lower` must be 0). |

Error message format:
```
error: --CLASS contains characters not valid for that class: 'INVALID_CHARS'
```

Where `INVALID_CHARS` is the de-duplicated set of offending characters.

### 3.4 No Cross-Class Overlap

Even with customization, each character MUST appear in **at most one** class.
Since the allowed-character ranges for the four classes are disjoint by
definition (`[A-Z]`, `[a-z]`, `[0-9]`, everything else), this invariant is
**automatically enforced** by the membership validation in §3.3 — no separate
overlap check is needed.

---

## 4. Algorithm

### 4.1 Design Rationale

The algorithm uses two key techniques:

**Vigenère-style pool mapping.** Each character class's character set is
Fisher-Yates shuffled into a lookup table (a "pool"). Random bytes from
`get_random` are used as indices into these pre-shuffled pools to select
characters. This is analogous to a Vigenère cipher's shifted alphabet — the
random byte is the "coordinate" and the shuffled pool is the "cipher
alphabet." A fifth pool is constructed from the union of all active classes
and also shuffled. This yields 5 pools:

| Pool | Source | Used for |
|---|---|---|
| `pool_upper` | Fisher-Yates shuffle of `--upper` chars | Satisfying `--min-upper` |
| `pool_lower` | Fisher-Yates shuffle of `--lower` chars | Satisfying `--min-lower` |
| `pool_digit` | Fisher-Yates shuffle of `--digit` chars | Satisfying `--min-digit` |
| `pool_special` | Fisher-Yates shuffle of `--special` chars | Satisfying `--min-special` |
| `pool_combined` | Fisher-Yates shuffle of all active class chars | Filling remaining slots |

**2x overgeneration with move-to-end.** Instead of generating exactly `length`
characters and retrying shuffles when consecutive-class violations occur, we
generate `2 × length` characters up front. A single linear pass enforces the
consecutive-class constraint: violating characters are moved to the end of
the array (the "reserve"), and the next character from the reserve shifts in
to take its place. This resolves nearly all violations in one O(n) pass
without re-shuffling or retry loops.

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
│      Fisher-Yates shuffle the array (see §4.3)       │
│    Build combined pool from union of all active       │
│      class chars, then Fisher-Yates shuffle it        │
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
│ 4. FISHER-YATES SHUFFLE THE CANDIDATE ARRAY          │
│    Shuffle the full 2×length array in-place           │
│    (see §4.3 for shuffle specification)               │
└──────────────────────┬────────────────────────────────┘
                       │
                       ▼
┌──────────────────────────────────────────────────────┐
│ 5. CONSECUTIVE-CLASS ENFORCEMENT (move-to-end)       │
│    (see §4.4 for full specification)                 │
│                                                      │
│    write_cursor = 0                                  │
│    read_cursor  = 0                                  │
│    run_length   = 0                                  │
│    end_cursor   = 2 × length                         │
│                                                      │
│    While write_cursor < length AND                    │
│          read_cursor < end_cursor:                    │
│                                                      │
│      char = array[read_cursor]                       │
│      read_cursor++                                   │
│                                                      │
│      IF write_cursor > 0 AND                         │
│         classify(char) == classify(result[w-1]) AND  │
│         run_length >= max_consecutive:               │
│           Move char to end of array (reserve)        │
│           end_cursor++ (reserve grows by 1)          │
│           CONTINUE                                   │
│                                                      │
│      result[write_cursor] = char                     │
│      Update run_length                               │
│      write_cursor++                                  │
│                                                      │
│    IF write_cursor < length:                         │
│      → Reserve exhausted. Return error (exit 1).     │
└──────────────────────┬────────────────────────────────┘
                       │
                       ▼
┌──────────────────────────────────────────────────────┐
│ 6. VERIFY MINIMUMS SURVIVED ENFORCEMENT              │
│    Count chars per class in result[0..length-1].     │
│    If any class count < its minimum:                 │
│      → Return error (exit 1). Constraint set is      │
│        unsatisfiable with this random draw.          │
│    (See §4.5 for why this check is necessary.)       │
└──────────────────────┬────────────────────────────────┘
                       │
                       ▼
┌──────────────────────────────────────────────────────┐
│ 7. OUTPUT                                            │
│    Print result[0..length-1] as a single line to      │
│    stdout. No trailing whitespace. Exactly one \n.    │
│    Atomic emit: no output until this point.           │
└──────────────────────────────────────────────────────┘
```

### 4.3 Fisher-Yates Shuffle Specification

All shuffles (pool construction and candidate array) MUST use the **modern**
(Durstenfeld/Knuth) variant:

```
fisher_yates_shuffle(array, n):
    for i in (n-1) downto 1:
        j ← get_random 0 (i+1)    # uniform in [0, i]
        swap array[i], array[j]
```

This yields an unbiased permutation when `get_random` provides uniform output,
which it does via rejection sampling.

The shuffle is applied to:
1. Each of the 4 class pools (up to 4 shuffles of small arrays)
2. The combined pool (1 shuffle)
3. The 2×length candidate array (1 shuffle of the large array)

Total: up to 6 Fisher-Yates shuffles per invocation.

### 4.4 Consecutive-Class Enforcement Detail

**Classification** is O(1) per character using the fixed ASCII ranges:

```
classify(char):
    if char in [A-Z] → "upper"
    if char in [a-z] → "lower"
    if char in [0-9] → "digit"
    else             → "special"
```

Note: `classify()` uses the fixed ASCII ranges, not the user-customized sets.
This is correct because §3.3 guarantees every character in a class belongs to
that class's ASCII range.

**Move-to-end pass** — a single linear scan with two cursors:

```
Input:  shuffled array of 2×length characters
Output: result array of exactly length characters (or error)

write_cursor = 0       # next position to fill in result
read_cursor  = 0       # next position to read from candidates
end_cursor   = 2 × length  # logical end of candidate array
run_length   = 1       # current consecutive same-class run
prev_class   = ""      # class of the last written character

while write_cursor < length AND read_cursor < end_cursor:
    char = candidates[read_cursor]
    read_cursor++
    cur_class = classify(char)

    if max_consecutive > 0 AND
       write_cursor > 0 AND
       cur_class == prev_class AND
       run_length >= max_consecutive:
        # Violation: move this char to the reserve (end of array)
        candidates[end_cursor] = char
        end_cursor++
        continue

    result[write_cursor] = char
    write_cursor++

    if cur_class == prev_class:
        run_length++
    else:
        run_length = 1
        prev_class = cur_class

if write_cursor < length:
    # Could not fill the password — reserve exhausted
    error "consecutive-class constraint unsatisfiable" → exit 1
```

**Key properties:**
- Characters moved to the end are **not lost** — they rejoin the candidate
  stream as the read cursor advances past the original 2×length boundary.
  This means a character displaced early can be reconsidered later in a
  position where it no longer causes a violation.
- The pass is O(n) where n = number of candidates consumed (at most
  2×length + number of displaced characters, bounded by 3×length worst case).
- `max_consecutive = 0` disables this step entirely (no enforcement).

### 4.5 Post-Enforcement Minimum Verification

The move-to-end pass may displace characters that were generated in step 3a
to satisfy class minimums. For example, if `--min-upper 5` caused 5 uppercase
characters to be placed, the enforcement pass might move some of those to the
reserve and replace them with fill characters from the combined pool.

After enforcement, the function MUST verify that the final `length` characters
still satisfy all `--min-*` constraints. If not, the function returns exit
code 1 with a diagnostic. This failure indicates the constraints are
collectively difficult to satisfy (e.g., `--min-upper 20 --length 24
--max-consecutive 1` — not enough other-class chars to break up the runs).

### 4.6 Entropy Budget

All `get_random` calls can be **batched** because the count needed at each
stage is known before generation begins:

| Stage | Bytes needed |
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
`(94 - 5) + (96 - 1)` = **184 random values**, all obtainable in a single
`get_random 184` call. The function MAY issue a single bulk `get_random` call
and consume values from the result sequentially, or MAY issue separate calls
per stage — both are correct.

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

Validation MUST proceed in this order so that error messages are deterministic
and the most fundamental issues are reported first:

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
| Uniform shuffle | Fisher-Yates with unbiased random source. |
| No information leakage | Function runs in a subshell `()`. No trace output (`set +x`). Variables are local. Password only appears on stdout at the end (atomic emit). |
| No temp files | All intermediate state in memory (bash arrays). |
| Defensive coding | `set -f` (no globbing), `LC_ALL=C`, `IFS` controlled. |

---

## 7. Exit Codes

| Code | Meaning |
|---|---|
| `0` | Success. Exactly one line on stdout containing the password. |
| `1` | Runtime failure (entropy source unavailable, constraint unsatisfiable after retries, write failure). |
| `2` | Usage / input validation error. |
| `127` | Missing dependency (`get_random` not loaded, `od` not found). |

---

## 8. Dependencies

| Dependency | How resolved |
|---|---|
| `get_random` | MUST be sourced before `generate_password` is called. Function existence is verified at entry. |
| `od` | Resolved transitively through `get_random`. |
| `/dev/urandom` | Verified transitively through `get_random`. |
| Bash ≥ 4.0 | Required for associative arrays (`declare -A`). |

---

## 9. Stdout Contract

On success (exit 0):

- Exactly **one line** is written to stdout.
- The line contains exactly `--length` printable ASCII characters.
- No leading/trailing whitespace (unless space is in a character class — space is not in any default class).
- Terminated by a single `\n`.
- No output is produced until the password passes all constraints (atomic emit).

On failure (exit != 0):

- **Nothing** is written to stdout.
- Diagnostic is written to stderr.

---

## 10. Test Coverage Requirements

The test file (`generate_password.bats`) MUST provide 100% branch coverage
across the following categories:

### 10.1 Happy Path

| ID | Test |
|---|---|
| HP-01 | Default invocation produces a 24-char password with at least 1 upper, 1 lower, 1 digit, 1 special. |
| HP-02 | `--length 8` produces exactly 8 characters. |
| HP-03 | `--length 256` produces exactly 256 characters. |
| HP-04 | Custom minimums: `--min-upper 5 --min-digit 5` are satisfied. |
| HP-05 | `--max-consecutive 1` produces no two adjacent same-class chars. |
| HP-06 | `--max-consecutive 0` (unlimited) allows any arrangement. |
| HP-07 | `--exclude-chars '0O1lI'` — none of those chars appear in output. |
| HP-08 | Custom upper set: `--upper 'ABCDEF'` — output upper chars are only from that subset. |
| HP-09 | Disable special class: `--special '' --min-special 0` — no special chars in output. |
| HP-10 | All output characters belong to a defined class. |

### 10.2 Validation Errors (exit 2)

| ID | Test |
|---|---|
| VE-01 | `--length 7` → error (below minimum 8). |
| VE-02 | `--length 257` → error (above maximum 256). |
| VE-03 | Non-integer `--length` → error. |
| VE-04 | `--length 8` with `--min-upper 3 --min-lower 3 --min-digit 3` (sum=10 > 8) → error. |
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

### 10.3 Statistical / Distribution Tests

| ID | Test | Method |
|---|---|---|
| ST-01 | Minimum counts are met across 50 invocations | Assert each class count >= min on every run |
| ST-02 | Fisher-Yates produces varied orderings | Generate 20 passwords, assert not all identical |
| ST-03 | Max-consecutive constraint holds across 50 invocations | Scan each output for violations |
| ST-04 | Fill characters are drawn from all active classes | Over 100 runs with `--length 100`, all 4 classes appear above their minimums |
| ST-05 | Pool shuffle produces varied character mappings | Generate 10 passwords with `--upper 'ABCDEF'`, verify not all first-upper-chars are identical |

### 10.4 Algorithm-Specific Tests

| ID | Test |
|---|---|
| AL-01 | 2x overgeneration: with `--max-consecutive 1`, password succeeds without retry even with skewed class distribution. |
| AL-02 | Move-to-end correctly recycles displaced characters (single class dominant, `--max-consecutive 2`, length 64). |
| AL-03 | Post-enforcement minimum verification catches unsatisfiable constraints (e.g., `--min-upper 20 --length 24 --max-consecutive 1`) → exit 1. |
| AL-04 | Reserve exhaustion: pathological input where 2x buffer is insufficient → exit 1 with diagnostic. |
| AL-05 | `--max-consecutive 0` skips enforcement pass entirely (all arrangements accepted). |
| AL-06 | Characters from custom class subsets only appear from that subset (e.g., `--upper 'XYZ'` → no `A-W` in output). |
| AL-07 | Combined pool contains characters from all active classes (disable one class, verify combined pool excludes it). |

### 10.5 Edge Cases

| ID | Test |
|---|---|
| EC-01 | `--length` exactly equals sum of minimums (no fill slots, all from class pools). |
| EC-02 | Only one class active (other three disabled), min = length. |
| EC-03 | `--max-consecutive 1` with even class distribution (should succeed reliably via move-to-end). |
| EC-04 | `get_random` not sourced → exit 127. |
| EC-05 | Class with a single character (e.g., `--upper 'X'`) and min > 0. |
| EC-06 | `--exclude-chars` removes some but not all chars from a class with min > 0 (still valid). |
| EC-07 | All four `--min-*` set to 0 — password is entirely from the combined fill pool. |
| EC-08 | Only one class active with `--max-consecutive 1` — enforcement pass is a no-op (only one class exists). |

### 10.6 Class Membership Validation Tests

| ID | Test |
|---|---|
| CM-01 | Valid subset override for each class succeeds (4 tests). |
| CM-02 | Each class rejects characters from each of the other 3 classes (12 tests). |
| CM-03 | Each class rejects control characters (ASCII < 0x21). |
| CM-04 | Each class rejects DEL (0x7F) and chars above 0x7E. |

---

## 11. Example Invocations

```bash
# Default: 24-char password, at least 1 of each class
source src/get_random/get_random.sh
source src/generate_password/generate_password.sh
generate_password
# → e.g., k8$Qm2!xNp4@rW7&jL9#bY1

# Shorter password
generate_password --length 16

# High-entropy server password with strict consecutive limits
generate_password --length 64 --min-upper 8 --min-lower 8 \
  --min-digit 8 --min-special 8 --max-consecutive 2

# Alphanumeric only (no special characters)
generate_password --special '' --min-special 0

# Restricted character sets (e.g., for systems with limited special char support)
generate_password --special '!@#$%'

# Remove ambiguous characters
generate_password --exclude-chars '0O1lI|'

# Hex-style: digits + uppercase A-F only
generate_password --length 32 --upper 'ABCDEF' --lower '' --special '' \
  --min-lower 0 --min-special 0 --max-consecutive 0
```

---

## 12. Non-Requirements (Explicit Exclusions)

- **Additional character classes** — the four classes (upper, lower, digit, special) are fixed.
- **Password strength estimation** — this function generates, it does not score.
- **Clipboard integration** — out of scope; caller handles output.
- **Interactive prompts** — purely non-interactive.
- **Persistence / storage** — the password is emitted to stdout and forgotten.
- **Unicode** — all characters are printable ASCII (0x21–0x7E). No space in defaults.
