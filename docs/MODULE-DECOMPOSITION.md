# Module Decomposition

## Why This File Exists

This document explains why the password system is split into several modules
instead of one large function.

The short answer is simple:

- smaller modules are easier to read
- smaller modules are easier to test
- smaller modules make design decisions easier to explain

For a teaching repo, those benefits matter a lot.

## The Problem With One Large Function

Imagine that `generate_password` owned all of this logic by itself:

- random number generation
- array shuffling
- consecutive-class enforcement
- option parsing
- validation
- output formatting

The code would still be possible to write, but it would become much harder to
understand and much harder to test.

For example, the consecutive-class logic depends on the order of characters
after shuffling. If everything lives in one function, a test would have to
control the random draws closely enough to force a specific shuffled array.
That makes the test fragile and difficult for a beginner to reason about.

## The Core Idea

We split the system by responsibility.

Each module should own one job that can be explained, tested, and reused on
its own.

## The Chosen Modules

### 1. `get_random`

Responsibility:

- read bytes from `/dev/urandom`
- turn those bytes into unbiased integers

Why it deserves its own module:

- randomness is security-sensitive
- rejection sampling is easier to teach in isolation
- other modules should not each re-implement entropy handling

What becomes easy to test:

- bad arguments
- missing `od`
- unreadable `/dev/urandom`
- values always stay in range
- rejection sampling behaves correctly

### 2. `fisher_yates_shuffle`

Responsibility:

- shuffle one indexed array in place

Why it deserves its own module:

- Fisher-Yates is a standard algorithm with a clear contract
- it is useful outside password generation
- array shuffling should be teachable without dragging in password rules

What becomes easy to test:

- empty arrays
- one-element arrays
- normal multi-element arrays
- dependency failures from `get_random`

### 3. `enforce_max_consecutive`

Responsibility:

- take a candidate character array
- build a result array that does not exceed the same-class run limit

Why it deserves its own module:

- this is the trickiest logic in the password pipeline
- it is deterministic, so it is ideal for isolated tests
- learners can study the move-to-end algorithm without also reading option
  parsing and randomness code

What becomes easy to test:

- already-valid input
- inputs that need one displacement
- inputs that need many displacements
- reserve exhaustion
- disabled enforcement

### 4. `generate_password`

Responsibility:

- parse options
- validate the requested constraints
- build character pools
- call the shuffle and enforcement modules
- verify the final password still meets all minimums
- print the finished password

Why it stays separate:

- it is the orchestrator
- it should describe the high-level flow, not hide low-level algorithms

What becomes easy to test:

- option validation
- class validation
- minimum-count behavior
- final output shape
- dependency checks

## Dependency Graph

```text
generate_password
|-- get_random
|-- fisher_yates_shuffle
|   `-- get_random
`-- enforce_max_consecutive
```

This graph is intentionally small. A beginner can hold it in their head.

## Why Not Fewer Modules

### If we merged `fisher_yates_shuffle` into `generate_password`

Problems:

- shuffle behavior would be harder to test directly
- the password module would grow longer and noisier
- future reuse would be worse

### If we merged `enforce_max_consecutive` into `generate_password`

Problems:

- the hardest algorithm would be buried inside the busiest file
- tests would need to force specific random states to reach some branches
- it would be much harder to explain the algorithm on its own

### If we merged everything into one file

Problems:

- more cognitive load for the reader
- more hidden coupling
- more fragile tests
- fewer opportunities for reuse

## Why Not More Modules

We also avoid splitting tiny ideas into separate modules when the split would
add more indirection than learning value.

Examples:

- `classify_char` stays in shared helpers because it is tiny and reused
- option parsing stays inside `generate_password` because it is part of that
  function's public behavior
- pool construction stays inside `generate_password` because it is tightly
  coupled to password rules

## Decision Summary

We use four core password-related modules because that is the smallest split
that keeps the code:

- understandable
- testable
- reusable
- teachable

That balance fits the goals of this repo better than either a monolith or a
large maze of tiny files.
