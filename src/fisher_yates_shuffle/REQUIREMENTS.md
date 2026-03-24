# Requirements: `fisher_yates_shuffle`

## 1. Overview

`fisher_yates_shuffle` performs an in-place, unbiased permutation of a Bash
array using the modern Durstenfeld/Knuth variant of the Fisher-Yates shuffle.
It draws all randomness from `get_random` and is the sole shuffling primitive
for the entire project.

---

## 2. Module Location

```text
src/
\-- fisher_yates_shuffle/
    |-- fisher_yates_shuffle.sh    # function source
    |-- REQUIREMENTS.md            # this document
    \-- ../../test/fisher_yates_shuffle_test.sh  # current Bash test file
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

1. Validate the public contract.
   - Require exactly one array-name argument.
   - Require that the named variable is a set indexed array.
   - Require that `get_random` is loaded.
2. Measure the array length.
   - If `n <= 1`, return success immediately because there is nothing to shuffle.
3. Shuffle in place.
   - For `i` from `n - 1` down to `1`, call `get_random 1 0 $((i + 1))`.
   - Use the returned value as `j` in `[0, i]`.
   - Swap `array[i]` with `array[j]`.

### 4.1 Core Algorithm

The shuffle MUST be the **modern** (Durstenfeld/Knuth) variant:

```
for i in (n-1) downto 1:
    j <- get_random 1 0 (i+1)    # uniform integer in [0, i]
    swap array[i], array[j]
```

**Correctness properties:**
- Iterates from the last index down to index 1 (inclusive).
- At each step, `j` is drawn uniformly from `[0, i]`.
- The swap is unconditional (even when `j == i`, the swap is a no-op but
  MUST still occur - skipping it would bias the distribution).
- After completion, every permutation of the original array is equally
  likely, given that `get_random` provides uniform output.

### 4.2 Random Value Generation

Each iteration `i` requires one random integer in `[0, i]`, which means
a different range for each step. The current implementation uses the simpler
per-iteration strategy:

**Current implementation - per-iteration calls:**
```
for i in (n-1) downto 1:
    j = $(get_random 1 0 $((i+1)))
    swap array[i], array[j]
```

This is simple, matches the current code, and keeps all bias-avoidance logic in
`get_random`. A future implementation could batch raw bytes and perform local
rejection mapping, but that is not the current design and would need separate
review because it would duplicate entropy-to-range logic outside `get_random`.

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

- **Array element types** - the shuffle is type-agnostic. Elements can be
  strings, integers, or empty strings. The function permutes indices, not
  values.
- **Sparse arrays** - behavior with sparse (non-contiguous) arrays is
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
| Bash >= 4.3 | Yes | Required for `local -n` (nameref). |

---

## 10. Test Coverage Requirements

These are target coverage requirements for the module ledger. The current
`test/fisher_yates_shuffle_test.sh` suite now covers the core contract plus a
small two-element distribution smoke test, but the broader statistical items
below are still target coverage rather than full current evidence.

### 10.1 Happy Path

| ID | Test |
|---|---|
| HP-01 | Shuffle a 10-element array - all original elements still present (permutation, not loss). |
| HP-02 | Shuffle a 2-element array - both possible orderings appear over repeated runs. |
| HP-03 | Shuffle preserves array length. |
| HP-04 | Shuffle with string elements (not just integers). |
| HP-05 | Shuffle with duplicate values - all instances preserved. |
| HP-06 | Shuffle with empty-string elements - elements preserved. |

### 10.2 No-Op Cases

| ID | Test |
|---|---|
| NO-01 | Empty array (n=0) - remains empty, exit 0. |
| NO-02 | Single element (n=1) - element unchanged, exit 0. |

### 10.3 Validation Errors (exit 2)

| ID | Test |
|---|---|
| VE-01 | No arguments -> exit 2 with error message. |
| VE-02 | Two arguments -> exit 2 with error message. |
| VE-03 | Unset variable name -> exit 2 with error message. |

### 10.4 Dependency Errors

| ID | Test |
|---|---|
| DE-01 | `get_random` not loaded -> exit 127. |
| DE-02 | `get_random` fails during shuffle -> exit 1 (partial shuffle state is acceptable since the operation failed). |

### 10.5 Statistical Tests

| ID | Test | Method |
|---|---|---|
| ST-01 | Uniformity for n=3 | Shuffle `[A, B, C]` 6000 times. Count each of 6 permutations. Chi-squared test with p>0.01. |
| ST-02 | Uniformity for n=2 | Shuffle `[A, B]` 400 times. Assert each ordering appears 120-280 times in the smoke test. |
| ST-03 | Not identity-biased | Shuffle a 10-element array 100 times. Assert that at least 95 results differ from the original ordering. |
| ST-04 | Position coverage | Shuffle `[0,1,2,3,4]` 500 times. Assert element `0` has appeared in every position at least once. |

### 10.6 Edge Cases

| ID | Test |
|---|---|
| EC-01 | Large array (n=256) - shuffles without error, all elements preserved. |
| EC-02 | Array where all elements are identical - shuffle is a no-op in effect, exit 0. |
| EC-03 | Array with special characters (`$`, `'`, `"`, `\`, space, newline) - elements preserved exactly. |

---

## 11. Non-Requirements

- **Partial shuffle** - the entire array is shuffled. No "shuffle first k" mode.
- **Return value** - result is communicated via in-place modification, not stdout.
- **Associative arrays** - only indexed arrays are supported.
- **Sparse arrays** - behavior is undefined for non-contiguous indices.
- **Thread safety** - Bash is single-threaded; not applicable.

---

## 12. Detailed Audit Requirements

## REQ-SHUFFLE-001

Status: Satisfied
Priority: P2
Severity: Medium
Domain: stochastic-verification
Applies to: shuffle-uniformity claims, documentation accuracy, and evidence level
Affected files/lines:
- `src/fisher_yates_shuffle/fisher_yates_shuffle.sh:50-62`
- `src/fisher_yates_shuffle/REQUIREMENTS.md:97-124`
- `src/fisher_yates_shuffle/REQUIREMENTS.md:225-232`
- `test/fisher_yates_shuffle_test.sh:13-29`
Authoritative sources:
- `docs/STUDENT-FIRST-STANDARDS.md`
- GNU Bash Reference Manual. https://www.gnu.org/software/bash/manual/bash.html
Repository evidence:
- The implementation performs one `get_random 1 0 $((index + 1))` call per loop
  iteration.
- This ledger previously described both per-iteration and batch strategies
  without clearly stating which one the current code actually uses.
- `test/fisher_yates_shuffle_test.sh` now includes a repeated-run two-element
  distribution smoke test with broad bounds.
Applicability analysis:
- This module is the project's only shuffling primitive, so its documentation
  needs to make the current random-consumption strategy easy to audit.
- Words such as "unbiased permutation" are appropriate for the algorithmic
  design, but readers still need a clear distinction between proof-by-design and
  proof-by-test.
Requirement:
- The `fisher_yates_shuffle` ledger MUST describe the current implementation
  strategy accurately and MUST distinguish algorithmic correctness claims from
  implemented statistical evidence. If permutation-uniformity tests are listed
  as requirements but not yet present in `test/fisher_yates_shuffle_test.sh`,
  they MUST be presented as target coverage rather than as current verified
  coverage.
Rationale:
- Small documentation drift around randomness handling quickly becomes confusing
  in a student-facing security repo because reviewers cannot tell whether a
  claim reflects code, aspiration, or existing evidence.
Acceptance criteria:
- The ledger states that the current code uses per-iteration `get_random` calls.
- Statistical-test sections are clearly identified as target coverage unless
  they are already implemented in the Bash test suite.
- The current implementation continues to keep bias-avoidance logic inside
  `get_random`.
Recommended change:
- Keep the current simple shuffle implementation, keep the existing two-element
  smoke test in place, and add broader permutation tests later only if the repo
  needs stronger empirical support.
Verification method:
- Inspect the shuffle loop in the source file.
- Compare the module ledger's test section against
  `test/fisher_yates_shuffle_test.sh`.
Counterpoints / reasons to reject:
- Reject only if maintainers intentionally collapse the shuffle and RNG logic
  into one module and document that new architecture clearly.
