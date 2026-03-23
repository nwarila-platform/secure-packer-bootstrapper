# Requirements: `fisher_yates_shuffle`

## 1. Overview

`fisher_yates_shuffle` performs an in-place, unbiased permutation of a Bash
array using the modern Durstenfeld/Knuth variant of the Fisher-Yates shuffle.
It draws all randomness from `get_random` and is the sole shuffling primitive
for the entire project.

---

## 2. Module Location

```
src/
└── fisher_yates_shuffle/
    ├── fisher_yates_shuffle.sh    # function source
    ├── REQUIREMENTS.md            # this document
    └── fisher_yates_shuffle.bats  # 100% code-path coverage tests
```

---

## 3. Function Signature

```bash
fisher_yates_shuffle ARRAY_NAME
```

### 3.1 Parameters

| Parameter | Type | Description |
|---|---|---|
| `ARRAY_NAME` | string | Name of a Bash indexed array variable. The array is shuffled **in-place** via nameref. |

### 3.2 Behavior by Array Size

| Array size (n) | Behavior |
|---|---|
| `n = 0` | No-op. Array remains empty. Exit 0. |
| `n = 1` | No-op. Single element unchanged. Exit 0. No `get_random` calls. |
| `n >= 2` | Perform `n - 1` swaps. Each swap uses one `get_random` call. |

---

## 4. Algorithm

```
┌────────────────────────────────────────────────────┐
│ 1. VALIDATE                                        │
│    - Verify ARRAY_NAME is provided                 │
│    - Verify ARRAY_NAME refers to a set variable    │
│    - Verify get_random is a loaded function         │
└─────────────────────┬──────────────────────────────┘
                      │
                      ▼
┌────────────────────────────────────────────────────┐
│ 2. GET ARRAY LENGTH                                │
│    n = ${#array[@]}                                │
│    If n <= 1: return 0 (no work to do)             │
└─────────────────────┬──────────────────────────────┘
                      │
                      ▼
┌────────────────────────────────────────────────────┐
│ 3. BATCH RANDOM VALUES                             │
│    Call get_random (n-1) 0 0  — but with           │
│    per-iteration max values. See §4.2 for detail.  │
└─────────────────────┬──────────────────────────────┘
                      │
                      ▼
┌────────────────────────────────────────────────────┐
│ 4. SHUFFLE (Durstenfeld/Knuth)                     │
│    for i from (n-1) downto 1:                      │
│      j ← random_value[i] mapped to [0, i]         │
│      swap array[i], array[j]                       │
└────────────────────────────────────────────────────┘
```

### 4.1 Core Algorithm

The shuffle MUST be the **modern** (Durstenfeld/Knuth) variant:

```
for i in (n-1) downto 1:
    j ← get_random 1 0 (i+1)    # uniform integer in [0, i]
    swap array[i], array[j]
```

**Correctness properties:**
- Iterates from the last index down to index 1 (inclusive).
- At each step, `j` is drawn uniformly from `[0, i]`.
- The swap is unconditional (even when `j == i`, the swap is a no-op but
  MUST still occur — skipping it would bias the distribution).
- After completion, every permutation of the original array is equally
  likely, given that `get_random` provides uniform output.

### 4.2 Random Value Generation

Each iteration `i` requires one random integer in `[0, i]`, which means
a different range for each step. There are two valid implementation
strategies:

**Strategy A — Per-iteration calls:**
```
for i in (n-1) downto 1:
    j = $(get_random 1 0 $((i+1)))
    swap array[i], array[j]
```

This is simple but incurs one subshell + one `get_random` call per iteration.

**Strategy B — Batch with raw bytes + per-iteration rejection:**
```
raw_bytes = $(get_random $((n-1)))        # n-1 values in [0,255]
idx = 0
for i in (n-1) downto 1:
    # Use raw_bytes[idx] to derive j in [0, i] via rejection
    # May need additional get_random calls if all raw bytes rejected
    ...
```

This minimizes subshell overhead at the cost of implementing rejection
sampling locally. The implementation MAY use either strategy. Strategy A is
RECOMMENDED for clarity unless profiling demonstrates a bottleneck.

### 4.3 In-Place Modification

The function modifies the caller's array **in-place** via Bash nameref
(`local -n ref=$1`). It MUST NOT:
- Create a copy of the array.
- Write to stdout (stdout is reserved for errors-only/future use).
- Create temporary files.

---

## 5. Input Validation

All validation failures print to stderr and return the appropriate exit code.

| Rule | Exit code | Error message |
|---|---|---|
| No arguments provided | 2 | `error: fisher_yates_shuffle requires an array name argument` |
| More than 1 argument | 2 | `error: fisher_yates_shuffle takes exactly 1 argument (got N)` |
| Variable not set | 2 | `error: variable 'NAME' is not set` |
| `get_random` not loaded | 127 | `error: fisher_yates_shuffle requires get_random but it is not loaded` |

### 5.1 What Is NOT Validated

- **Array element types** — the shuffle is type-agnostic. Elements can be
  strings, integers, or empty strings. The function permutes indices, not
  values.
- **Sparse arrays** — behavior with sparse (non-contiguous) arrays is
  undefined. Callers MUST provide dense indexed arrays.

---

## 6. Security Properties

| Property | Mechanism |
|---|---|
| Unbiased permutation | Durstenfeld/Knuth algorithm with uniform random source. |
| Entropy source | `get_random` only (which uses `/dev/urandom` + rejection sampling). |
| No information leakage | No stdout output. No trace (`set +x`). Local variables only. |
| No temp files | All state in the caller's array + local variables. |

---

## 7. Exit Codes

| Code | Meaning |
|---|---|
| `0` | Success. Array has been shuffled in-place. |
| `1` | Runtime failure (`get_random` returned an error). |
| `2` | Usage / validation error (missing or invalid arguments). |
| `127` | Missing dependency (`get_random` not loaded). |

---

## 8. Stdout / Stderr Contract

**Stdout:** Nothing. Ever. The function communicates its result by modifying
the array in-place, not by printing.

**Stderr:** Diagnostic messages on failure only.

---

## 9. Dependencies

| Dependency | Required | Resolution |
|---|---|---|
| `get_random` | Yes | MUST be a loaded function (`type -t get_random` == `function`). Verified at entry. |
| Bash ≥ 4.3 | Yes | Required for `local -n` (nameref). |

---

## 10. Test Coverage Requirements

### 10.1 Happy Path

| ID | Test |
|---|---|
| HP-01 | Shuffle a 10-element array — all original elements still present (permutation, not loss). |
| HP-02 | Shuffle a 2-element array — both possible orderings appear over 100 runs. |
| HP-03 | Shuffle preserves array length. |
| HP-04 | Shuffle with string elements (not just integers). |
| HP-05 | Shuffle with duplicate values — all instances preserved. |
| HP-06 | Shuffle with empty-string elements — elements preserved. |

### 10.2 No-Op Cases

| ID | Test |
|---|---|
| NO-01 | Empty array (n=0) — remains empty, exit 0. |
| NO-02 | Single element (n=1) — element unchanged, exit 0. |

### 10.3 Validation Errors (exit 2)

| ID | Test |
|---|---|
| VE-01 | No arguments → exit 2 with error message. |
| VE-02 | Two arguments → exit 2 with error message. |
| VE-03 | Unset variable name → exit 2 with error message. |

### 10.4 Dependency Errors

| ID | Test |
|---|---|
| DE-01 | `get_random` not loaded → exit 127. |
| DE-02 | `get_random` fails during shuffle → exit 1 (partial shuffle state is acceptable since the operation failed). |

### 10.5 Statistical Tests

| ID | Test | Method |
|---|---|---|
| ST-01 | Uniformity for n=3 | Shuffle `[A, B, C]` 6000 times. Count each of 6 permutations. Chi-squared test with p>0.01. |
| ST-02 | Uniformity for n=2 | Shuffle `[A, B]` 1000 times. Assert each ordering appears 400–600 times (within 5σ). |
| ST-03 | Not identity-biased | Shuffle a 10-element array 100 times. Assert that at least 95 results differ from the original ordering. |
| ST-04 | Position coverage | Shuffle `[0,1,2,3,4]` 500 times. Assert element `0` has appeared in every position at least once. |

### 10.6 Edge Cases

| ID | Test |
|---|---|
| EC-01 | Large array (n=256) — shuffles without error, all elements preserved. |
| EC-02 | Array where all elements are identical — shuffle is no-op in effect, exit 0. |
| EC-03 | Array with special characters (`$`, `'`, `"`, `\`, space, newline) — elements preserved exactly. |

---

## 11. Non-Requirements

- **Partial shuffle** — the entire array is shuffled. No "shuffle first k" mode.
- **Return value** — result is communicated via in-place modification, not stdout.
- **Associative arrays** — only indexed arrays are supported.
- **Sparse arrays** — behavior is undefined for non-contiguous indices.
- **Thread safety** — Bash is single-threaded; not applicable.
