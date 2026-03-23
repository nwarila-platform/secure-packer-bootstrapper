# Module Decomposition Analysis

## The Problem with a Single Module

If `generate_password` is one monolithic function, consider what 100% path
coverage requires for the consecutive-class enforcement alone:

| Code path | How to trigger in a monolith |
|---|---|
| No violations found (clean pass) | Hope the random shuffle produces no runs > max |
| Violations resolved via reserve | Hope the shuffle produces runs > max but reserve has different-class chars nearby |
| Reserve exhausted → error | Construct pathological min/length/max-consecutive combo AND hope random data cooperates |
| `max_consecutive = 0` (skip) | Easy — just pass the flag |
| Single active class (enforcement no-op) | Easy — disable 3 classes |
| Displaced chars reconsidered later | Need a specific array state where a displaced char is valid at a later position |

Paths 1–3 and 6 depend on the **internal array state after shuffling**, which
is a function of random data you cannot control without mocking `get_random`
and reverse-engineering which values produce a specific permutation. That's
fragile, hard to maintain, and defeats the purpose of testing.

**The same problem applies to Fisher-Yates itself.** Testing that the shuffle
is unbiased, handles edge cases (0/1/2-element arrays), and actually permutes
correctly is trivial with direct input — but requires controlling random
outputs to verify through a wrapper.

## Recommended Decomposition

```
src/
├── get_random/                      # EXISTING — entropy primitive
│   ├── get_random.sh
│   ├── get_random.bats
│   └── README.md
│
├── fisher_yates_shuffle/            # NEW — reusable shuffle primitive
│   ├── fisher_yates_shuffle.sh
│   ├── fisher_yates_shuffle.bats
│   └── README.md
│
├── enforce_max_consecutive/         # NEW — constraint enforcement
│   ├── enforce_max_consecutive.sh
│   ├── enforce_max_consecutive.bats
│   └── README.md
│
└── generate_password/               # NEW — orchestrator
    ├── generate_password.sh
    ├── generate_password.bats
    └── README.md
```

### Module 1: `get_random` (existing)

**Responsibility:** Produce unbiased random integers from `/dev/urandom`.

Already exists. Move to `src/get_random/`, add README and tests.

**Code paths:** 7 (urandom unreadable, od missing, arg validation ×3,
rejection sampling, success)

**Testability:** All paths reachable via direct invocation — no isolation
issues.

---

### Module 2: `fisher_yates_shuffle`

**Responsibility:** In-place shuffle of a bash array using the modern
Durstenfeld/Knuth algorithm, with `get_random` as entropy source.

**Interface:**
```bash
# Shuffles array variable IN PLACE via nameref.
# Usage: fisher_yates_shuffle ARRAY_NAME
#
# Exit codes:
#   0   success (array shuffled in-place)
#   1   runtime failure (get_random failed)
#   2   usage error (bad arguments)
#   127 missing dependency (get_random not loaded)
fisher_yates_shuffle ARRAY_NAME
```

**Code paths to cover:**

| Path | Trigger |
|---|---|
| Empty array (n=0) | Pass empty array — should be a no-op, exit 0 |
| Single element (n=1) | No swaps needed — exit 0 |
| Two elements (n=2) | One swap — simplest real case |
| General case (n>2) | Normal shuffle |
| `get_random` not loaded | Don't source it — exit 127 |
| `get_random` fails mid-shuffle | Mock a failing `get_random` — exit 1 |
| No array name provided | Missing arg — exit 2 |
| Invalid nameref (unset variable) | Bad array name — exit 2 |

**Testability:** All paths directly reachable. Feed it known arrays, verify
permutation properties. No randomness-mocking needed for correctness tests
(statistical tests verify uniformity over many runs).

**Reuse:** The SSH passphrase generator will need this too. Any future module
that needs unbiased permutation draws from it.

---

### Module 3: `enforce_max_consecutive`

**Responsibility:** Given an array of characters and a max-consecutive limit,
enforce the constraint using the move-to-end algorithm. Pure logic — no
randomness, no I/O beyond the array.

**Interface:**
```bash
# Enforces max-consecutive-same-class constraint on a character array.
# Reads from CANDIDATE_ARRAY, writes passing chars to RESULT_ARRAY.
#
# Arguments:
#   $1  — name of input array (chars, length >= target_length)
#   $2  — target output length
#   $3  — max consecutive same-class chars (0 = disabled/unlimited)
#
# Exit codes:
#   0   success (RESULT_ARRAY populated via nameref stdout protocol)
#   1   constraint unsatisfiable (reserve exhausted)
#   2   usage error
enforce_max_consecutive INPUT_ARRAY_NAME TARGET_LENGTH MAX_CONSECUTIVE
```

**Code paths to cover:**

| Path | Trigger |
|---|---|
| `max_consecutive = 0` (disabled) | Pass 0 — copies first target_length chars, no enforcement |
| Clean pass (no violations) | `['A','b','1','!','C','d','2','@']` with max=3 |
| Violation resolved from reserve | `['A','B','C','D','x','y','z','!']` with max=2 — `D` displaced, `x` takes its place |
| Multiple displacements in sequence | `['A','B','C','D','E','x']` with max=1 |
| Displaced char reused later | `['A','A','B','A','x','x','x','x']` with max=1 — first `A` displaced, fits later |
| Reserve exhausted → error | `['A','A','A','A']` input, target=3, max=1 — not enough different-class chars |
| Single class present | `['A','B','C','D']` with max=3 — enforcement is fine as long as run ≤ max |
| Input shorter than target | Edge case — exit 2 |
| Empty input | Edge case — exit 2 (or 0 if target=0?) |

**Testability: This is the key win.** Every path is reachable by constructing
a specific input array. No randomness. No mocking. You hand it
`['A','B','C','D','x']` and assert exactly what comes out. This is the module
that would be **hardest to test at 100% through `generate_password`** and
**easiest to test in isolation**.

**Reuse:** Potentially useful for passphrase generation if similar constraints
apply (e.g., no two consecutive words from same category).

---

### Module 4: `generate_password` (orchestrator)

**Responsibility:** Parse options, validate inputs, build pools, generate
candidates, invoke `fisher_yates_shuffle` and `enforce_max_consecutive`,
verify minimums, emit password.

**What it owns (NOT delegated):**
- Option parsing and validation (§3, §5 of requirements)
- Class membership validation (§3.3)
- Pool construction (Vigenère-style — §4.1)
- Character generation from pools (§4.2 steps 3a/3b)
- Post-enforcement minimum verification (§4.5)
- Atomic output (§9)
- Security hardening (subshell, `set +x`, `set -f`)

**What it delegates:**
- Shuffling → `fisher_yates_shuffle`
- Consecutive enforcement → `enforce_max_consecutive`
- Random bytes → `get_random`

**Code paths to cover:**

| Path | Trigger |
|---|---|
| All validation errors (§5) | Pass bad args — ~14 cases, all directly reachable |
| Happy path (defaults) | No args |
| Custom class chars | `--upper 'XYZ'` etc. |
| Disabled classes | `--special '' --min-special 0` |
| `--exclude-chars` partial | Removes some chars |
| `--exclude-chars` total | Removes all chars — error |
| Post-enforcement min check passes | Normal operation |
| Post-enforcement min check fails | Pathological constraints — exit 1 |
| Missing dependencies | Don't source `get_random` / `fisher_yates_shuffle` / `enforce_max_consecutive` |

**Testability:** With shuffle and enforcement extracted, the orchestrator's
own code paths are all about **option parsing, pool building, and assembly** —
things controlled entirely by the arguments you pass. No internal state you
can't reach.

The one remaining "hard" path — post-enforcement minimum verification
failing — can be tested by using extreme constraints
(`--min-upper 20 --length 24 --max-consecutive 1`) that statistically force
the enforcement pass to displace enough minimum-guaranteed chars. Over
multiple runs this will trigger reliably, or you can mock
`enforce_max_consecutive` to return a known array missing minimums.

---

## Dependency Graph

```
generate_password
├── get_random
├── fisher_yates_shuffle
│   └── get_random
└── enforce_max_consecutive
    └── (no dependencies — pure logic)
```

## Why Not Fewer Modules?

| Alternative | Problem |
|---|---|
| Merge `fisher_yates_shuffle` into `generate_password` | Can't test shuffle edge cases (0/1/2 elements, mid-shuffle failure) without going through the full password pipeline. Also blocks reuse by SSH passphrase module. |
| Merge `enforce_max_consecutive` into `generate_password` | Can't construct specific array states to test displacement/reserve-exhaustion paths. Would need to mock `get_random` to produce specific shuffle outputs, which means reverse-engineering the Fisher-Yates swap sequence — brittle and unmaintainable. |
| Merge both back in | Combines both problems. 100% path coverage becomes a game of "find the magic random seed." |

## Why Not More Modules?

| Candidate | Why NOT separate |
|---|---|
| `classify_char` | 4 lines, no branching complexity. Lives inside `enforce_max_consecutive` where it's used. Tested transitively. |
| `validate_options` / `parse_options` | Password-specific, not reusable. All validation paths are reachable through `generate_password`'s public interface by passing bad args. Splitting adds a module with zero reuse value. |
| `build_pools` | Tightly coupled to `generate_password`'s class definitions and option parsing. Not reusable. Tested through the orchestrator. |

## Summary

Four modules. Each owns exactly one testable concern:

| Module | Concern | Paths | Testable in isolation? |
|---|---|---|---|
| `get_random` | Entropy | ~7 | Yes (existing) |
| `fisher_yates_shuffle` | Permutation | ~8 | Yes (feed arrays, check output) |
| `enforce_max_consecutive` | Constraint enforcement | ~9 | Yes (construct exact inputs) |
| `generate_password` | Orchestration + validation | ~15 | Yes (args control all paths) |

Total: ~39 code paths, all reachable through each module's public interface
without mocking randomness or reverse-engineering internal state.
