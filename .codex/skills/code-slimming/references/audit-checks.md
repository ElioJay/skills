# Audit mode — checking the cleanup, not the code

`--audit` reviews a cleanup that already happened. Its subject is **the change**, not the source.

**Do not re-run the M/J checks here.** Re-running them against post-cleanup code yields the same
verdicts the first pass produced and carries no new information. Audit asks a different question:
*was the cleanup itself done correctly?* The checks below are the only ones that belong in this mode.

## Input

`--audit` (no argument) → `git diff HEAD`, the uncommitted cleanup.
`--audit <rev>` or `--audit <rev-range>` → that commit or range.

Audit needs both sides of the change. If only one side is available, say so and stop — there is
nothing to audit against.

## A1 — Did behavior change?

A subtraction pass produces deletions and in-place inlines. Anything else is suspect.

Flag every changed line that alters a condition, an operator, a comparison bound, a return value,
a default, an exception type, or an order of operations. Deleting a branch is fine **only** if the
remaining arm is provably the one that always executed.

The hardest case to spot: a guard deleted as a "redundant null check" whose type was actually
nullable on one code path.

## A2 — Was a redline deleted?

Run the `redlines.md` detectors against the **deleted lines**, not the surviving file. Any deleted
line that would have hit a redline is a violation, and the report must name which redline.

This is the highest-value check in audit mode — it is the only pass that looks at what is gone.

## A3 — What was missed?

Run the M-tier checks against the post-cleanup code. Anything still hitting an M-tier check that
does **not** appear in the recorded skip list is a miss, not a decision.

This is the one place audit overlaps the normal checks, and it is deliberately narrow: only
M-tier, only to find gaps, only for items with no recorded skip reason.

## A4 — Are the skip records complete?

Every item the cleanup declined to act on should carry a reason: a named redline, or an explicit
false-positive judgment. Skips with no reason are gaps in the record, and the skip record is the
user's only calibration channel.

## A5 — Did it leave its lane?

- Files touched outside the declared scope
- Code moved between files
- Files renamed, directories restructured
- Symbols renamed where callers live outside the edited file
- Pure style churn: whitespace, quote style, import reordering

Any of these breaks the subtraction-only contract, however good the result looks.

## A6 — Was verification real?

Did a static check run? Did tests run? If neither could run, was **未验证** stated plainly?

A cleanup that claims verification it did not perform is worse than one that admits the gap — flag
the claim, not just the gap.

## A7 — Did it add anything?

A subtraction pass should end net-negative on lines, with no new symbols. Flag any newly
introduced function, type, import, config key, or abstraction. "I extracted a helper while I was
in there" is out of contract.

## A8 — Were the right comments deleted?

Check every deleted comment for an intent word (`因为`, `为了`, `避免`, `防止`, `注意`, `because`,
`why`, `avoid`, `must`, `NOTE`), a unit or time zone, a link, or an issue reference. Any of those
means the comment carried information and should have survived.

Deleting a comment is cheap to do and expensive to notice — this check exists because nobody
re-reads deleted comments.

## A9 — Did an inline hurt readability?

Flag an inline that pushed its host function past ~50 lines, or that removed a name carrying
meaning the surrounding code does not restate. Fewer lines is not the goal; less to understand is.

## A10 — Did it quietly fix a bug?

The `[附注]` items — swallowed exceptions, catch-log-return-success, `as any`, comment-only rules —
must be byte-identical before and after. Any edit inside those blocks violates the contract, even
when the new behavior is better. Behavior changes belong to their own task with their own tests.

## Output

Terminal only, in Chinese, grouped by severity:

- **违约** — A1, A2, A5, A7, A10. The cleanup did something it promised not to do.
- **遗漏** — A3, A4. The cleanup should have caught or recorded this.
- **可疑** — A6, A8, A9. Needs a human look.

Each finding cites its check number and the specific lines, before and after. If nothing fires,
say so plainly — a clean audit is a real result, not a failure to find something.
