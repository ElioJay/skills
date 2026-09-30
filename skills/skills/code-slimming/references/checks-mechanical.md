# M-tier — mechanically decidable

A check belongs here only if AST, grep, type information, or a compiler warning settles it
**without knowing what the code does for the business**. Everything else is J-tier.

Every hit passes `redlines.md` first. Action column: **删** delete · **内联** inline in place ·
**上报** report only, never edit.

Grouped by the six passes of Step 3. Run them in this order; never mix categories in one pass.

## Pass 1 — Dead code

| # | Check | Hit condition | Action |
|---|---|---|---|
| M1 | Unused import | Compiler/linter flags it, or zero references in the file | 删 |
| M2 | Unused local variable | Assigned, never read | 删 |
| M3 | Unused parameter | Zero references in the body, **and** not required by an interface impl or callback signature | 删 |
| M4 | Unused private field/method | Zero references inside the class, not public API | 删 |
| M5 | Zero-call-site function/method/class | Take the symbol from the diff, grep the **whole repo**, count == 0, passes redlines | 删 |
| M6 | Commented-out code | Two or more consecutive comment lines that parse as statements once the comment markers are stripped | 删 |
| M7 | Always-true / always-false branch | Condition is a literal constant, or a null check on a type the type system already guarantees non-null (`!= nil`, `is not None`, `!== undefined`) | 删 branch, keep the reachable arm |
| M8 | Orphan helper from an abandoned approach | Function added in this diff, referenced zero times **within the diff** | 删 |
| M9 | New config key never read | env var / config key added in this diff, repo-wide read sites == 0 | 删 |
| M10 | Config key that only ever takes its default | Read sites exist, but every caller passes the default | 删 |
| M11 | Branch reserved for an unshipped feature | Branch condition depends on a flag/config that is constantly false | 删 |
| M12 | Whole file nobody imports | No import anywhere | **上报** |
| M13 | Orphaned static asset | Unreferenced image, CSS rule, config file | **上报** |

M12/M13 are report-only on purpose: dynamic imports, convention-based routing, build-config
references and string-built class names are invisible to static analysis, and a wrong file
deletion can survive to production. The user deletes it — one extra step, worth it.

## Pass 2 — Duplicate implementation

No M-tier checks. Deciding "this re-implements an existing helper" always needs semantic
judgment — see `checks-judgment.md` J11/J12.

## Pass 3 — Redundant abstraction

| # | Check | Hit condition | Action |
|---|---|---|---|
| M14 | One-call wrapper | Wrapper's parameter list **and** return type are identical to the callee's, body is a single forwarding call | 内联 |
| M15 | Single-call-site private helper | Repo-wide symbol count == 1, not exported, **body 5 lines or fewer**, **and** the name carries no meaning beyond what the code already says (e.g. `_get_name()` whose body is `return self.name`) | 内联 |
| M16 | Pass-through method | Does nothing but hand its arguments to another method with the same signature | 内联 |
| M17 | Single-implementation interface / abstract class / Protocol | Implementation count == 1, no mock implementation, no multi-impl DI registration. See the exemption switch in `redlines.md` | 删 interface, callers use the concrete type. **Do not rename the impl file** |
| M18 | Factory that only ever produces one type | Every return statement yields the same concrete type | 内联 |
| M19 | Single-member enum / single-registration strategy table | Enum member count == 1; registry put/register call sites == 1 | 内联 to a constant or a direct call |
| M20 | Single-call-site Builder | `.builder()` call sites == 1 and every field is passed | 内联 to a constructor call |

M15 is deliberately narrow. A 30-line `_normalize_phone_number()` called once is **not** redundant —
its name is documentation, and inlining it turns the call site into 30 lines of anonymous logic.
Anything above the line threshold, or whose name adds meaning, drops to J-tier.

## Pass 4 — Defensive paranoia

| # | Check | Hit condition | Action |
|---|---|---|---|
| M21 | Catch that rethrows unchanged | The catch block contains only `throw e` / `raise e` / `return err`; caught type equals thrown type; no transformation, no added context | 删 the whole try/catch |
| M22 | Adjacent duplicate guard | The same null/length check on the same expression appears twice or more within 5 lines | 删 the later one |
| M23 | Redundant cast / identity conversion | `as` to its own type, `Optional.ofNullable(x).orElse(null)`, `list(already_a_list)`, `String(already_a_string)` | 删 |
| M24 | Fallback default on a required field | `?? default` / `orElse` / `or default` applied to a field that cannot be absent | 删 |
| M25 | Null check on a statically non-null value | Requires type information, not regex | 删 |

## Pass 5 — Comments

Only two kinds are deleted. Everything else stays. See "What always stays" below.

| # | Check | Hit condition | Action |
|---|---|---|---|
| M26 | Comment restating the code | High token overlap with the adjacent line **and** contains no intent word (`因为`, `为了`, `避免`, `防止`, `注意`, `because`, `why`, `avoid`, `must`, `NOTE`) | 删 |
| M27 | AI filler comment | `# Step N`, `// 步骤 N`, `// --- x ---` pure separators, `Let us`, `Now we`, `First, we`, `Great`, `这里我们`; plus docstring/JSDoc that restates the signature verbatim (parameter names and types already in the annotations, no constraint, unit, or exception info) | 删 |
| M28 | Decorative section banner | `// ===`, `# ---`, `/* Helper Functions */` and similar pure ornament | 删 |

**What always stays**: comments explaining *why*; non-obvious constraints; recorded trade-offs;
links to external docs or issues; units, time zones, precision; pitfall warnings. This is the
mirror image of the `code-annotating` skill's rule — that one adds the valuable comments, this
one removes the worthless ones. They do not conflict.

## Pass 6 — Naming / filler

| # | Check | Hit condition | Action |
|---|---|---|---|
| M29 | Emoji and debug leftovers | Emoji in code or comments; newly added `console.log`, `print(`, `fmt.Println`, `System.out.print` outside a CLI output path | 删 |
| M30 | Drive-by reformatting | Every hunk in a file is pure whitespace / quote-style / import-order churn unrelated to the task | Revert that file |
| M31 | Violates an explicit project CLAUDE.md rule | **Must be able to quote both the rule text and the offending line.** Vague "against the spirit of the doc" inferences are not accepted | 删 / fix per the rule |
| M32 | Name repeats the scope it already sits in | `userAccountStatus` inside class `User`; prefix equals owning type name | **上报** — renaming touches every call site, possibly across files |

Deliberately excluded from this tier: nested ternary rewritten as if/else (it adds lines; this
skill subtracts), removing inferable type annotations, and dropping the `f` on a
placeholder-free f-string. They are style preferences, not redundancy, and they drown the real
signal in the findings list.

## Test-specific (runs alongside, does not block the production passes)

| # | Check | Hit condition | Action |
|---|---|---|---|
| M33 | Asserting a mock exists | The asserted object is itself the mock — `getByTestId('sidebar-mock')` | 删 the assertion |
| M34 | Production method only called by tests | Every call site is inside a test file | **上报** (the fix is moving it to a test util — cross-file, out of scope) |
| M35 | Skipped test in the same diff as an implementation change | `.skip()` / `.todo()` / `@Ignore` and the change both present in this diff | **上报** |
| M36 | Snapshot-everything with no behavioral assertion | Only `toMatchSnapshot()`, no semantic assertion | 删 / 上报 |
| M37 | Mock setup exceeds half the test | Line ratio | **上报** |
| M38 | A single test mocks more than 3 dependencies | Count | **上报** — a missing-seam signal; building a seam is addition |
| M39 | Boolean parameter run of two or more | Signature scan | **上报** — switching to an enum is addition |
