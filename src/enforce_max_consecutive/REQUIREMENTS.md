# Requirements: `enforce_max_consecutive`

## 1. Overview

`enforce_max_consecutive` enforces a maximum-consecutive-same-class constraint
on an array of ASCII characters. It uses a single-pass, move-to-end algorithm:
characters that would violate the constraint are displaced to the end of the
array (the "reserve") and may be reconsidered later in a position where they
no longer cause a violation.

This module is **pure logic** - it has no dependencies on randomness, I/O, or
external tools. It operates entirely on in-memory arrays, making it fully
deterministic and trivially testable with constructed inputs.

---

## 2. Module Location

```text
src/
\-- enforce_max_consecutive/
    |-- enforce_max_consecutive.sh    # function source
    |-- REQUIREMENTS.md               # this document
    \-- ../../test/enforce_max_consecutive_test.sh  # current Bash test file
```

---

## 3. Function Signature

```bash
enforce_max_consecutive INPUT_ARRAY_NAME RESULT_ARRAY_NAME TARGET_LENGTH MAX_CONSECUTIVE
```

### 3.1 Parameters

| Parameter | Type | Description |
|---|---|---|
| `INPUT_ARRAY_NAME` | string | Name of a Bash indexed array containing candidate characters. Length MUST be >= TARGET_LENGTH. |
| `RESULT_ARRAY_NAME` | string | Name of a Bash indexed array to receive the output. Will be cleared and populated. |
| `TARGET_LENGTH` | int | Number of characters to produce. Range: 1-512. |
| `MAX_CONSECUTIVE` | int | Maximum consecutive characters from the same class. 0 = disabled (no enforcement). Range: 0-512. |

### 3.2 Behavior by MAX_CONSECUTIVE Value

| Value | Behavior |
|---|---|
| `0` | **Disabled.** Copy the first TARGET_LENGTH elements from input to result. No classification or enforcement. |
| `1` | No two adjacent characters may be from the same class. |
| `2` | At most 2 consecutive same-class characters. |
| `n` | At most n consecutive same-class characters. |

---

## 4. Character Classification

Classification is performed using fixed ASCII ranges. This is an **internal**
function and is NOT exported.

```
classify_char(char):
    code = ASCII value of char
    if code >= 65 AND code <= 90:   return "upper"    # A-Z
    if code >= 97 AND code <= 122:  return "lower"    # a-z
    if code >= 48 AND code <= 57:   return "digit"    # 0-9
    else:                           return "special"  # all other printable ASCII
```

### 4.1 Classification Invariants

- Every printable ASCII character (0x21-0x7E) maps to exactly one class.
- Classification is deterministic - the same input always produces the same class.
- The four class ranges are disjoint: `[A-Z]`, `[a-z]`, `[0-9]`, and
  everything else.
- Classification does NOT depend on any user-configurable character sets.
  This is intentional: the caller (`generate_password`) validates that
  characters in each class belong to the correct ASCII range (see
  `generate_password` requirements section 3.3), so classification here is always
  consistent.

---

## 5. Algorithm

1. Validate the arguments.
   - Require all four arguments.
   - Require that both array names refer to set indexed arrays.
   - Require integer `TARGET_LENGTH` and `MAX_CONSECUTIVE`.
   - Require the input array length to be at least `TARGET_LENGTH`.
2. Short-circuit the disabled mode.
   - If `MAX_CONSECUTIVE == 0`, copy the first `TARGET_LENGTH` items to the
     result array and return success.
3. Run the move-to-end pass.
   - Track `read_cursor`, `write_cursor`, `end_cursor`, `run_length`, and
     `prev_class`.
   - Read each candidate character in order.
   - If placing that character would exceed the class run limit, append it to
     the logical end of the candidate array instead of dropping it.
   - Otherwise write it to the result and update the current run state.
4. Finish with an explicit completion check.
   - If `write_cursor < TARGET_LENGTH`, the reserve is exhausted and the
     function returns exit code `1`.
   - Otherwise the result array is complete and the function returns `0`.

### 5.1 Move-to-End Pass Detail

**Input:** An array of `N` characters (where `N >= TARGET_LENGTH`), typically
`2 x TARGET_LENGTH` as provided by `generate_password`.

**Two-cursor scan:**

```
read_cursor  -> advances through all candidates (original + displaced)
write_cursor -> advances through the result array (only on accepted chars)
end_cursor   -> logical end of the candidate array (grows as chars are displaced)
```

**Displacement mechanics:**
- When a character at `read_cursor` would extend a same-class run beyond
  `MAX_CONSECUTIVE`, it is appended to position `end_cursor` in the input
  array, and `end_cursor` is incremented.
- The displaced character is **not lost**. As `read_cursor` advances, it will
  eventually reach the displaced character's new position. At that point, the
  preceding context will be different, and the character may no longer cause
  a violation.
- This "recycling" is what makes the algorithm effective without retries.

**Termination conditions:**
- **Success:** `write_cursor == TARGET_LENGTH`. The result array contains
  exactly TARGET_LENGTH characters satisfying the constraint.
- **Failure:** `read_cursor == end_cursor` while `write_cursor < TARGET_LENGTH`.
  All candidates (original + displaced) have been consumed without filling
  the result. This means the constraint is unsatisfiable for this input.

### 5.2 Complexity

| Metric | Bound |
|---|---|
| Time | O(N + D) where N = input length, D = number of displacements. D <= N, so worst case O(2N). |
| Space | O(TARGET_LENGTH) for the result array. Input array is extended in-place. |
| Iterations | At most N + D. Each character is read at most twice (once in original position, once if displaced). |

### 5.3 Why Not a Retry Loop

The move-to-end approach is superior to "shuffle then check, retry on failure":

| Property | Move-to-end | Shuffle-retry |
|---|---|---|
| Time complexity | O(n) deterministic | O(n) per attempt x unbounded attempts |
| Worst case | Linear scan, definitive pass/fail | May never terminate without a retry cap |
| Bias | Slight position bias for displaced chars | Unbiased over valid permutations |
| Testability | Fully deterministic given input array | Depends on random shuffle output |

The slight position bias is acceptable because the input array has already
been Fisher-Yates shuffled by the caller, providing the primary randomness.
The enforcement pass is a **filter**, not a generator.

---

## 6. Exit Codes

| Code | Meaning |
|---|---|
| `0` | Success. RESULT_ARRAY populated with TARGET_LENGTH characters satisfying the constraint. |
| `1` | Constraint unsatisfiable. Reserve exhausted before TARGET_LENGTH characters could be placed. |
| `2` | Usage / validation error. |

---

## 7. Stdout / Stderr Contract

**Stdout:** Nothing. Result is communicated via the RESULT_ARRAY nameref.

**Stderr:** Diagnostic messages on failure only.

| Exit code | Stderr message |
|---|---|
| `1` | `error: enforce_max_consecutive: reserve exhausted after N candidates (need M more characters)` |
| `2` | `error: enforce_max_consecutive: ...` (specific validation error) |

---

## 8. Dependencies

| Dependency | Required | Resolution |
|---|---|---|
| Bash >= 4.3 | Yes | Required for `local -n` (nameref). |

**No external dependencies.** This module does not use `get_random`, `od`,
`/dev/urandom`, or any other module. It is pure logic operating on arrays.

---

## 9. Test Coverage Requirements

### 9.1 Happy Path

| ID | Test |
|---|---|
| HP-01 | No violations in input - result matches first TARGET_LENGTH chars of input. |
| HP-02 | `max_consecutive=2`, input `[A,B,a,b,1,2,!,@]` - accepted as-is. |
| HP-03 | `max_consecutive=1`, well-interleaved input - accepted as-is. |
| HP-04 | Result length equals TARGET_LENGTH exactly. |

### 9.2 Displacement Tests

| ID | Test |
|---|---|
| DT-01 | Single displacement: `[A,A,b,c]`, target=3, max=1 -> second `A` displaced, `b` takes its place. |
| DT-02 | Multiple displacements: `[A,A,A,b,c,d]`, target=3, max=1 -> result interleaves `A` with others. |
| DT-03 | Displaced char reused later: `[A,A,B,C,x,y,z,z]`, target=6, max=1 -> displaced `A` fits after `B` or `C`. |
| DT-04 | Chain displacement: `[A,B,B,B,C,C,C,x]`, target=6, max=1 -> multiple classes displaced and recycled. |
| DT-05 | All chars from same class with reserve from different class: `[A,A,A,b,b,b]`, target=4, max=1 -> alternates. |

### 9.3 Disabled (max_consecutive = 0)

| ID | Test |
|---|---|
| DC-01 | `max_consecutive=0` copies first TARGET_LENGTH elements unchanged. |
| DC-02 | `max_consecutive=0` with long same-class runs in input - no enforcement applied. |

### 9.4 Reserve Exhaustion (exit 1)

| ID | Test |
|---|---|
| RE-01 | `[A,A,A,A]`, target=3, max=1 -> exhausted (only one class available). |
| RE-02 | `[A,A,A,A,A,A,b]`, target=4, max=1 -> exhausted (not enough `b` to interleave). |
| RE-03 | `[A,A,B,B]`, target=4, max=1 -> exactly satisfiable (alternating ABAB). Verify success. |
| RE-04 | `[A,A,A,B]`, target=4, max=1 -> exhausted (cannot place 3 A's with only 1 B to break). |

### 9.5 Validation Errors (exit 2)

| ID | Test |
|---|---|
| VE-01 | Missing arguments -> exit 2. |
| VE-02 | TARGET_LENGTH not an integer -> exit 2. |
| VE-03 | MAX_CONSECUTIVE not an integer -> exit 2. |
| VE-04 | Input array shorter than TARGET_LENGTH -> exit 2. |
| VE-05 | Unset INPUT_ARRAY_NAME -> exit 2. |
| VE-06 | Unset RESULT_ARRAY_NAME -> exit 2. |
| VE-07 | TARGET_LENGTH = 0 -> exit 2. |
| VE-08 | TARGET_LENGTH negative -> exit 2. |
| VE-09 | MAX_CONSECUTIVE negative -> exit 2. |

### 9.6 Edge Cases

| ID | Test |
|---|---|
| EC-01 | TARGET_LENGTH = 1 - single char, no consecutive check possible. Always succeeds. |
| EC-02 | MAX_CONSECUTIVE = 1, single class in input, target=1 - succeeds (run of 1 is ok). |
| EC-03 | MAX_CONSECUTIVE >= TARGET_LENGTH - the constraint can never be violated; equivalent to disabled. |
| EC-04 | Input exactly equals TARGET_LENGTH (no reserve at all). Any violation -> immediate exhaustion. |
| EC-05 | Input length = 2 x TARGET_LENGTH - standard case from `generate_password`. |
| EC-06 | All elements are the same character, max=TARGET_LENGTH - succeeds (run equals max). |
| EC-07 | All elements are the same character, max=TARGET_LENGTH-1 - fails (run would be TARGET_LENGTH). |
| EC-08 | Special characters (`!@#$%`) - classified as "special", displacement works correctly. |
| EC-09 | Mixed case: displacement of chars from all 4 classes in one pass. |

### 9.7 Classification Tests

| ID | Test |
|---|---|
| CL-01 | Each of `A`, `Z` classified as "upper". |
| CL-02 | Each of `a`, `z` classified as "lower". |
| CL-03 | Each of `0`, `9` classified as "digit". |
| CL-04 | Each of `!`, `~`, `@`, `#` classified as "special". |
| CL-05 | Boundary: `@` (64, just below A) -> "special". |
| CL-06 | Boundary: `[` (91, just above Z) -> "special". |
| CL-07 | Boundary: `` ` `` (96, just below a) -> "special". |
| CL-08 | Boundary: `{` (123, just above z) -> "special". |
| CL-09 | Boundary: `/` (47, just below 0) -> "special". |
| CL-10 | Boundary: `:` (58, just above 9) -> "special". |

---

## 10. Non-Requirements

- **Randomness** - this module is deterministic. Randomness is the caller's
  responsibility (via Fisher-Yates shuffle before calling this function).
- **Character set awareness** - classification uses fixed ASCII ranges, not
  user-customized character sets.
- **Minimum enforcement** - this module does NOT verify class minimums. That
  is the caller's responsibility after enforcement.
- **Stdout output** - result is via nameref array, not stdout.
