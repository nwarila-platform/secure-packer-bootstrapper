# Student-First Standards

## Purpose

This repo is a teaching repo first and a utility repo second.

That does not mean we relax security, reliability, or correctness. It means we
prefer the clearest correct solution over the cleverest correct solution.

## The Standard

Every new change should satisfy these rules.

### 1. Code must read top to bottom

A student should be able to follow the control flow without jumping through
layers of indirection.

Prefer:

- small functions
- clear phase ordering
- descriptive variable names
- straightforward loops and conditionals

Avoid:

- hidden side effects
- dense one-liners
- unnecessary abstractions
- "smart" tricks that save a few lines but cost comprehension

### 2. Every module must explain its contract

Each public module should document:

- what problem it solves
- what inputs it accepts
- what outputs it produces
- which exit codes it returns
- which dependencies it requires
- why the chosen algorithm is appropriate

For this repo, the normal home for that explanation is the module's
`REQUIREMENTS.md`.

### 3. Important decisions must be written down

If a choice is not obvious, document it.

Examples:

- why a module exists
- why a retry loop is capped
- why a helper uses a specific shell feature
- why we accept a small amount of duplication instead of adding abstraction
- why a security constraint is required

Put documentation in the smallest useful place:

- near the code when the detail is local
- in `REQUIREMENTS.md` when it defines module behavior
- in `docs/` when it affects the whole repo

### 4. Names should teach

Choose names that explain intent, not just mechanics.

Prefer names like:

- `target_length`
- `processed_candidates`
- `public_key_contents`

Avoid names like:

- `x`
- `tmp2`
- `buf`

Short names are acceptable only when they are standard and obvious in context,
such as loop indices in a tiny local block.

### 5. Comments should explain "why" or "what this phase does"

Good comments answer questions a student is likely to ask:

- Why are we turning off globbing here?
- Why do we shuffle before enforcing the run limit?
- Why do we clear the result array before writing to it?

Avoid comments that simply restate the next line.

### 6. Error messages are part of the teaching surface

A good error message should help the learner recover.

Prefer:

- saying which argument failed
- showing the invalid value
- stating the allowed range or contract

### 7. Prefer duplication over indirection when it improves clarity

In production code, removing repetition is often a good instinct.

In a teaching repo, small, deliberate duplication is sometimes better because
it keeps the full behavior visible in one place. We should still refactor when
duplication starts hiding bugs or making changes unsafe.

### 8. Use plain ASCII unless a file truly needs something else

ASCII is easier to copy, search, and read in more terminals and editors.

Prefer:

- `x 2` instead of multiplication symbols
- `->` instead of arrow symbols
- simple lists and tables instead of box-drawing diagrams

### 9. Tests should read like examples

A beginner should be able to read a test and learn:

- how a function is called
- what success looks like
- what failure looks like

Keep tests explicit and avoid overly magical test helpers.

### 10. Security, reliability, and performance still matter

We simplify only until the next simplification would weaken the system.

Do not remove:

- input validation
- unbiased randomness
- explicit dependency checks
- atomic output behavior
- defensive shell settings

If a safer approach is harder to understand, explain it instead of deleting it.

## Review Checklist

Before merging a change, ask:

1. Can a first-year student explain this file back to us after reading it once?
2. Is every non-obvious decision documented somewhere nearby?
3. Did we keep the safest practical behavior?
4. Did we choose the clearest implementation that still meets performance and reliability needs?
5. Would the tests help a learner understand the code instead of only catching regressions?
