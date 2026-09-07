# TypeScript

**The signature redundancy: `any` sprawl, generic parameters that appear once, and `IXxx`
single-implementation interfaces.** The first is the model's escape hatch when typing gets hard;
the other two are C#/Java habits carried into TS.

## A. Mechanical

### TS1 — Generic parameter that appears once *(highest value in this language)*

```ts
function f<T>(x: T): void { }        // T appears once → equivalent to unknown
function g<T>(x: T[]): number { }    // T appears once → equivalent to unknown[]
class C<T> { private x: number }     // T unused entirely
```

Hit: the type parameter occurs once or zero times in the signature, so it relates nothing to
anything. A generic's whole job is to tie two positions together; appearing once, it expresses no
constraint.

Action: drop the parameter, use `unknown` where a type is still needed.

### TS2 — Single-implementation interface

Hit: `implements XxxService` count == 1, no mock implementation, not used inside a union, not the
target of a `satisfies` across several objects. Delete the interface, use the class or an object
type.

Note that the `IXxx` Hungarian prefix is itself against TypeScript's own coding guidelines.

### TS3 — `as unknown as T` double assertion

Hit: regex on `as unknown as` / `as any as`. **Report to the `[附注]` bucket, never edit.** This
bypasses the type system entirely — a correctness issue, not redundancy.

### TS4 — Redundant optional chaining

Hit: `a?.b` where the static type of `a` excludes `null | undefined`. Needs real type information
(TS Compiler API, or the type-aware `@typescript-eslint/no-unnecessary-condition`); regex is not
enough.

### TS5 — Redundant non-null assertion

Hit: `x!` where `x` is already statically non-nullable.

### TS6 — Explicit annotation the inference already covers

`const x: string = "a"`, `const n: number = 42`, a function returning a single literal.

**Exempt** when the project enables `@typescript-eslint/explicit-function-return-type` or
`explicit-module-boundary-types`. Return-type annotations on exported functions have documentation
value — prefer keeping those regardless.

### TS7 — Hand-rolled lodash / native utilities

Hit: a local `isEmpty`/`isNil`/`pick`/`omit`/`groupBy`/`uniq`/`chunk`/`debounce` while the project
already depends on lodash or ramda, or the capability landed in the language
(`Object.groupBy`, `Array.prototype.at`, `structuredClone`).

Semantics diverge sharply between libraries — lodash's `isEmpty(0)` is `true`. If the edge cases
do not match, do not switch.

### TS8 — Props defined three times

Same component carries optional fields in `interface Props`, destructuring defaults `({ a = 1 })`,
**and** `Component.defaultProps`. Keep the destructuring defaults; drop `defaultProps`, which
React 19 deprecated for function components.

### TS9 — Unused export

Hit: reported unused, **and** not on the `package.json` `exports`/`main`/`types` path, and not in
the transitive re-export chain of a public `index.ts`.

### TS10 — Custom hook with one call site

`useXxx` used once. Inline when it lives in the same file; report only when it is cross-file.
A hook's value is sometimes separation of concerns rather than reuse — if it is substantial and
self-contained, keep it.

### TS11 — Redundant Promise wrapping

```ts
return new Promise(resolve => resolve(x));   // → Promise.resolve(x), or just x inside async
async function f() { return await g(); }      // → return g()
```

**`return await` inside a `try` block is not redundant** — removing the `await` lets the rejection
escape the `try`. When a `try` wraps it, leave it alone.

### TS12 — Template literal with no placeholder

Backtick string containing no `${}`. Convert to a plain string, following the project's `quotes`
rule if it has one.

### TS13 — Redundant type assertion

```ts
const x = y as string;   // y is already string
const n = <number>m;     // m is already number
foo(bar as Bar);         // bar is already Bar
```

Covered by `@typescript-eslint/no-unnecessary-type-assertion`. Distinct from TS3 — that one is a
type-system escape hatch and gets reported, this one is pure noise and gets deleted.

### TS14 — Over-typed props and single-use type aliases

```tsx
type ButtonLabel = string;          // referenced once
type ButtonDisabled = boolean;      // referenced once
interface ButtonProps { label: ButtonLabel; disabled: ButtonDisabled; }
```

Hit: `type X = <primitive>` referenced exactly once — inline it. Also: prop types spelled out
longhand where a React built-in is equivalent, e.g.
`(event: React.MouseEvent<HTMLButtonElement, MouseEvent>) => void` where
`React.MouseEventHandler<HTMLButtonElement>` says the same thing.

### TS15 — Duplicate type definitions

Two `interface`/`type` declarations **in the same file** with identical field names and types, or a
type that is exactly the `Pick`/`Omit`/`Partial` of an existing one.

The classic AI shape: `User`, `UserDTO`, `UserResponse`, `UserModel` — four names, one structure.

**Merge only within a single file.** Cross-file duplicates are **report only**: merging them
creates a new cross-file dependency, which is addition, not subtraction.

## B. Judgment

### TS16 — `any` sprawl

Two or more explicit `any` added in this diff, including `catch (e: any)` and
`Record<string, any>`.

`catch (e: any)` should be `catch (e: unknown)` plus narrowing on TS 4.4+ — a safety improvement.
If the value is only passed around and never dereferenced, `unknown` is a zero-risk swap. If
properties get accessed, a type guard is needed and that is addition — report only.

### TS17 — Type guard used once

`function isX(v: unknown): v is X` with one call site. Type guards carry real readability value;
inlining produces `if (typeof v === 'object' && v !== null && 'id' in v)`. **Lean toward keeping**
unless the guard body is a single trivial check.

### TS18 — Barrel file re-exporting one module

`index.ts` containing only `export * from './x'`. Barrels cost bundle size, invite circular
imports, and add an IDE hop — but deleting one touches every importer. **Report only.** If the
barrel is in `package.json` `exports`, it is public API.

### TS19 — State that should be derived

```tsx
const [total, setTotal] = useState(0);
useEffect(() => { setTotal(items.reduce(...)); }, [items]);
```

An effect doing nothing but a pure computation and a setState. Should be
`const total = items.reduce(...)`, or `useMemo` when the computation is expensive. Within one
component, so in scope — but confirm the effect really has no other side effect.

### TS20 — Redundant `useCallback` / `useMemo`

Wrapping a cheap computation, or a callback never handed to a memoized child. Both have real cost
(dependency comparison plus closure retention) and only pay off when the result reaches a
`React.memo` child or another hook's dependency array. Judging that needs the call site —
**report only**.

### TS21 — Over-nested conditional / mapped types

Three or more nested `extends ? :`. The type-level equivalent of a giant function, taxing both
compile time and readability. Splitting into named aliases is addition — **report only**.

### TS22 — `async` on a function with no `await`

```ts
async function f() { return 1; }            // async only wraps the return in a Promise
async function k() { return Promise.resolve(x); }   // double wrapping
```

Judgment rather than mechanical: dropping `async` changes the return type from `Promise<T>` to `T`.
Existing `await` at the call sites keeps working, but the contract shifted. **Check every caller
before proposing it.** The plain `return await` case inside a non-`try` block stays in TS11.

### TS23 — Redundant enum

Hit: an `enum` with a single member, or an `enum` used only as string constants with no reverse
lookup (`MyEnum[value]`).

A single-member enum collapses to a literal type. A string-constant-only enum should be an
`as const` object plus `keyof typeof` — enums carry runtime cost and `const enum` breaks across
modules. But changing it touches every use site, so **report only**.

### TS24 — Type duplicated between a hand-written interface and a schema

Hit: the same structure declared both as an `interface` and as a zod (or similar) schema, fields
identical.

The fix is `type X = z.infer<typeof xSchema>` — deleting the hand-written interface. That is a net
reduction *and* removes the risk of the two drifting apart, so it is in scope. Confirm first that
the interface holds nothing the schema cannot express (method signatures, generics).

## C. Framework boilerplate — never delete

| Category | Details |
|---|---|
| Declarations | Everything in `*.d.ts`; `declare module` / `declare global`; declaration merging (same-named interfaces merge — deleting one loses fields) |
| Package entry | Files reached from `package.json` `exports` / `main` / `module` / `types` / `bin`, and their transitive re-export chain |
| Type-system markers | `// @ts-expect-error` — **deleting it causes a compile error**, since it requires an error on the next line; `satisfies`; `as const` |
| React | `key`; `displayName`; ref forwarding; `propTypes` where still used |
| Decorators and metadata | NestJS / TypeORM / Angular decorators; `reflect-metadata` import; type annotations that `emitDecoratorMetadata` depends on — removing them breaks runtime metadata |
| Build and test config | Files named by `setupFiles` / `globalSetup` in vitest/jest config; barrels targeted by `tsconfig` `paths`; modules referenced from `next.config` / `vite.config` |
| Side-effect imports | `import './polyfills'`, `import 'reflect-metadata'`, `import './styles.css'` — no binding, so they look unused |
| Enums and constant objects | `const enum` (inlined at call sites, so grep finds no runtime reference); constant objects referenced via `keyof typeof` |
| Convention-routed files | Next.js `page.tsx` / `layout.tsx` / `route.ts` / `middleware.ts`, and `app/api/**` — zero explicit imports by design |
| JSDoc types | `/** @type {...} */` in JS projects is not a comment, it is the type |
