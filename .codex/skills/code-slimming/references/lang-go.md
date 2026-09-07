# Go

**The signature redundancy: error wrapping that carries no information, plus interfaces defined
ahead of a second implementation that never arrives.**

## A. Mechanical

### GO1 — Error wrapping with no added information *(highest value in this language)*

Hit: `return fmt.Errorf("%w", err)` or `errors.Wrap(err, "")` — the format string contains nothing
but the verb.

Action: `return err`.

### GO2 — Duplicated error prefix

Hit: `fmt.Errorf("failed to X: %w", err)` where the wrapped error text already says "failed to X".
The message reads `failed to X: failed to X: ...` at the top of the stack.

Action: drop the outer wrap.

### GO3 — Single-implementation interface *(second highest value)*

Hit: interface declared in the **producer** package, implementation count == 1, no mock
implementation, no cross-package polymorphic use.

Action: delete the interface, use the struct directly. Go convention is to accept interfaces at
the consumer and return structs — an interface at the producer with one implementation is the
Java habit transplanted.

Exemption: an interface carrying `//go:generate mockgen` has a generated mock, which counts as a
second implementation. Keep it.

### GO4 — Unused `context.Context` parameter

Hit: the `ctx` parameter is never referenced and the function calls nothing downstream that takes
a context. Exported functions fall under the public-API redline.

### GO5 — Hand-rolled generics the standard library already ships

Hit: a private `Contains`/`Min`/`Max`/`Keys`/`SortSlice` while `go.mod` targets 1.21+, which
provides `slices`, `maps`, and builtin `min`/`max`.

### GO6 — Redundant nil checks

Hit: `if s != nil { for range s }`, `if m != nil { len(m) }`. A nil slice ranges fine; a nil map
reads and lens fine.

### GO7 — Forward-only logger/client wrapper

Hit: every method on the type is a one-line forward to an embedded field, with no added logic.
Inline **within the same package**.

### GO8 — Redundant error-check chain

Hit: `if err != nil { return err }` immediately following a call whose error was already checked,
or a check on a function that cannot return a non-nil error.

### GO9 — Unused named return values

Hit: named results declared in the signature but never assigned by name and never used by a naked
`return`. They only add noise to the signature.

## B. Judgment

### GO10 — Functional options with one call site

`WithXxx` set used in exactly one place with every option at its default. Internal API: inline to
direct field assignment. Public package: keep — configurability is the contract. Also scope-creep
signal S4.

### GO11 — `init()` with a single consumer

Registration or initialization inside `init()` read from exactly one place. The call to make: is
there an import-ordering dependency that makes `init()` load-bearing?

### GO12 — Generated `String()` nobody calls

No `%s`/`%v` formatting of the type, no explicit `.String()`. `fmt` calls it implicitly — treat
with care.

### GO13 — Error swallowed in `defer`

`defer func(){ _ = f.Close() }()`. Acceptable for read paths; on a write path an unchecked `Close`
loses data, which makes it a defect — route to the `[附注]` bucket rather than deleting.

### GO14 — Excessive type assertions and type switches

A type switch over types that only ever take one branch in practice. Ask whether the polymorphism
is real.

## C. Framework boilerplate — never delete

- Blank side-effect imports: `_ "github.com/lib/pq"`, `_ "embed"`
- Directive comments: `//go:generate`, `//go:embed`, `//go:build`, `//nolint`
- Compile-time interface assertions: `var _ SomeInterface = (*MyType)(nil)`
- Exported identifiers (leading uppercase)
- `TestMain`
- Struct tags: `json:`, `db:`, `validate:`, `yaml:`
- **Interfaces carrying `//go:generate mockgen`** — the GO3 exemption
