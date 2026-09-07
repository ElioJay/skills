# J-tier — needs judgment

A check lands here when the right answer depends on something the diff cannot show: whether this
input is trusted, where the system boundary is, whether a second implementation is actually
coming. **Default action is report-only.** Even under `--auto`, every J-tier item is presented and
confirmed before anything is edited.

Each finding must state the judgment call the user has to make, not just the smell name.

Two items from the source list are deliberately not here:
- **Altitude** ("patched a symptom instead of the root cause") — an architectural judgment that
  needs business context and evolution history the diff does not carry. Belongs to
  `code-review-deep` / `design-pattern-advisor`.
- **Rule asserted only by a comment** — routed to the `[附注]` bucket instead; it is a correctness
  inconsistency, not redundancy.

## Pass 1 — Dead code

| # | Check | Hit signal | The call to make |
|---|---|---|---|
| J1 | Permanently on/off feature flag | Only one branch of the flag is ever executed | Is the rollout finished? Needs release records, not code |
| J2 | Migration shim after the migration completed | Naming or comment contains `legacy`, `v1`, `old`, and the new path is fully rolled out | Is the old path really dead everywhere, including other services? |
| J3 | Stale TODO migration marker | `TODO: remove after X` with git blame older than 3 months | Did X happen? Redline "explicitly marked intent" wins on ties — report, do not delete |

## Pass 2 — Duplicate implementation

| # | Check | Hit signal | The call to make |
|---|---|---|---|
| J4 | Re-implements something the repo already has | A new function overlaps semantically with a helper in the diff's own directories or in a `utils` / `common` / `shared` / `helper` / `lib` module | Are the edge-case semantics genuinely identical? If yes this is pure subtraction: delete the new one, call the existing one. If the behaviors differ at the boundaries, keep both |
| J5 | Copy-paste variant inside one file | Two blocks in the same file with identical structure and a few differing literals | Is the difference incidental or meaningful? **Merge only within one file — never across files** |

## Pass 3 — Redundant abstraction

| # | Check | Hit signal | The call to make |
|---|---|---|---|
| J6 | Layer with no logic of its own | More than half of a layer's method bodies are single-line delegations with identical arguments | Will this layer ever carry transactions, authorization, or auditing? If not, it is decoration |
| J7 | Seam with only one adapter | An interface exists purely for testability; production has one implementation and a simple stub would do | One adapter is a hypothetical seam; two is a real one |
| J8 | Middle Man class | More than half the class's methods are single-line delegations | Report only — collapsing it touches every caller |
| J9 | Lazy Class | No state, at most two methods, used in one place | Does the name carry a concept worth a type? |
| J10 | Speculative Generality | Unused classes, methods, fields, parameters, generic parameters, or hooks kept "for the future" | Is there any concrete, named second use case? "Might need it" is the definition of the smell |
| J11 | Abstracted on the second occurrence | A helper added in this diff serves exactly two similar call sites | **Rule of Three.** A premature abstraction is the *wrong* abstraction, and wrong abstractions cost more to fix than duplication. Prefer keeping the duplication |
| J12 | Shallow Module | Interface complexity is close to implementation complexity | **The deletion test**: if this were removed, does the complexity vanish (it was a pass-through) or reappear at N call sites (it was earning its keep)? |
| J13 | Same concept implemented 5+ different ways | Count the variants | A simplification-cascade signal: one insight may collapse many components. Report only — the fix is a redesign |
| J14 | Redundant or derivable state | `items` and `itemCount` both maintained; a value stored alongside what it is derived from | Can the derived one be computed at read time cheaply enough? |
| J15 | Options/Config struct with one call site and all defaults | Struct or functional-options set constructed once, every field left at its default | Internal API — delete the mechanism, pass fields directly. Public library — configurability is the product; keep. Also a scope-creep signal (S4) |
| J16 | Boolean parameter on a public API | Signature takes a bool; call sites read as `f(x, true)` | Replacing it with an enum is addition — report only |
| J17 | Global config import creating a hidden dependency | `from config import settings` and equivalents outside the composition root | Report only — rewiring is addition |
| J18 | Repeated computation or I/O | The same expression or the same query evaluated twice in one scope | **Within a single function only.** Is the second call load-bearing (fresh read intended)? |

## Pass 4 — Defensive paranoia

| # | Check | Hit signal | The call to make |
|---|---|---|---|
| J19 | Validation inside an internal function | Null/range/format checks in a non-entry-point function | Validation belongs at the system boundary. Is this function actually a boundary? |
| J20 | The same validation at several layers | Identical check in controller **and** service **and** repository | Keep the outermost one. Confirm no layer is reachable independently |
| J21 | try/catch around code that cannot throw | The block does no I/O, no parsing, no external calls | Confirm nothing inside can throw on any input |
| J22 | One catch collapsing every error class | Network, auth, parse and server errors all take the same recovery path | Do these genuinely deserve the same handling, or is the distinction being lost? |
| J23 | Retry with no cap and no backoff | Retry loop missing max attempts / backoff / jitter / cancellation | Frequently scope creep (S1 + S6). Was retry requested at all? If yes, missing bounds is a separate defect — report it |

## Pass 5 — Comments

| # | Check | Hit signal | The call to make |
|---|---|---|---|
| J24 | Comment density out of line with the file | The diff's added-line comment rate is markedly higher than the file's own baseline | The most robust available criterion: not "is this comment good" (subjective) but "does it match this file" (measurable). Read the outliers and judge individually |

## Pass 6 — Naming and control flow

| # | Check | Hit signal | The call to make |
|---|---|---|---|
| J25 | Nesting deeper than 3 levels | Count | Flatten with guard clauses **inside the same function**. Confirm the early returns preserve cleanup and finally semantics |
| J26 | Giant orchestration function | One function mixing parsing, business logic, persistence, network and formatting, over 80 lines | **Report only** — splitting a function is addition, and the highest-frequency smell in LLM output |
| J27 | Verbose name | Name longer than the concept it denotes | Renaming reaches every call site — report only |
| J28 | Name leaks implementation | `getUserDataFromDatabase` where `getUser` would do | Report only — same reason |
| J29 | Vague name | `data`, `result`, `item`, `handler`, `tmp` in a domain-critical function | Report only |

## Test-specific

| # | Check | Hit signal | The call to make |
|---|---|---|---|
| J30 | Tautological test | The test recomputes the implementation's formula and compares | It cannot fail for the right reason. Report; rewriting it is addition |
| J31 | Snapshot without behavioral assertion | Only `toMatchSnapshot()` | Does any real behavior get asserted anywhere? |
| J32 | Mock setup dominates the test | Setup exceeds the logic being tested | A missing-seam signal, not a deletion target |
| J33 | Incomplete mock | The mock has fewer fields than the real response, and downstream code reads the missing ones | The test passes for the wrong reason |
| J34 | Mocked away the side effect the test depends on | e.g. config writes are mocked, so duplicate detection cannot be exercised | The test passes for the wrong reason |

## Batching order

Do not run all of J at once. Order by change risk against information gain, and **run
verification between batches. If a batch fails, revert the whole batch — do not bisect inside
it**: within one batch the changes are of one kind, so a whole-batch revert costs little and a
mixed failing state is undebuggable.

| Batch | Contents | Why |
|---|---|---|
| 1 — low risk, local | J14, J18, J25, J27, J28, J29 | All inside a single function; a mistake is immediately visible |
| 2 — medium, follow the call chain | J4, J5, J11, J19, J20, J21, J22 | Needs the caller set and the boundary location confirmed |
| 3 — report only | J6, J7, J8, J12, J13, J16, J17, J26 | All involve cross-file reach or addition — out of scope for editing |
| 4 — needs external evidence | J1, J2, J3 | The answer is not in the code; it is in release records, monitoring, issues |
| Tests — independent | J30–J34 | Does not interact with production cleanup; can run in parallel |
