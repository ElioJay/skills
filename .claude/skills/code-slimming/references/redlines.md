# Redlines — never delete

A redline hit is never deleted. It is recorded in `[跳过]` with the redline's name, always
expanded, never summarized. Redlines protect **existence**, not **contents**: a log statement
survives, but the `try/catch` wrapped around it purely to log is still a J-tier judgment call.

Redlines apply to deletion only. Inlining, merging duplicate branches, and comment cleanup are
unaffected.

## 1. External contract

| Signal | How to detect |
|---|---|
| Exported public API | Go: identifier starts uppercase. TS: `export` on a path reachable from `package.json` `exports`/`main`/`types`. Java: `public` under an `api` / `sdk` / `client` package. Python: listed in `__all__`, or a module-level name without a `_` prefix. |
| Referenced by tests | Symbol appears in `*_test.go`, `test_*.py`, `*_test.py`, `*.test.ts`, `*.spec.ts`, `src/test/java/**`. |

Callers can live outside this repository. "No references found in the repo" is not proof.

## 2. Explicitly marked intent

`TODO`, `FIXME`, `XXX`, `HACK`, `@Deprecated`, `Deprecated:`, `预留`, `reserved` — on the symbol,
above it, or inline. Someone left that marker on purpose; it has its own timeline.

## 3. Compatibility traces

Comment contains `compat`, `backward`, `workaround`, `兼容`, `绕过`, `临时`, `see issue #`, or a
link. Defensive code with a story behind it — the story is usually not in the diff.

## 4. Observability

`log.`, `logger.`, `slog.`, `Metrics`, `Counter`, `Gauge`, `Histogram`, `Span`, `Tracer`,
`@Timed`, `prometheus`, `otel`. Looks like noise; is the only evidence when something breaks at
3am. General-purpose simplifiers delete these more often than anything else.

## 5. Runtime-resolved resources

- **DB migrations** — anything under `migrations/`, `db/migrate/`, `flyway`, `liquibase`, `alembic`.
  History is immutable.
- **i18n** — `messages*.properties`, `locales/`, `i18n/`, `*.po`, and any key reached through
  `t()`, `gettext()`, `MessageSource`. Keys are assembled at runtime; static analysis is blind.

## 6. Framework boilerplate

Per-language lists live in `lang-java.md`, `lang-go.md`, `lang-typescript.md`, `lang-python.md`
(section C of each). Read the one matching the file before deleting anything in it.

The recurring trap across all four: **code with no visible caller that the framework calls by
convention** — pytest fixtures, Spring `@Bean` methods, Next.js route files, Go side-effect
imports, decorator-registered handlers. Grep finds nothing; the framework finds it fine.

## 7. Never-delete regardless of tier

- Anything in the `[附注]` bucket (swallowed exceptions, `catch`-log-return-success, `as any`,
  comment-only rules). These are correctness problems; editing them hides the problem.
- Whole files and orphaned static assets — **report only**, never auto-delete. Dynamic imports,
  convention-based routing, build-config references, and string-built CSS class names are all
  invisible to static analysis, and a wrong file deletion may only surface in production.
- Anything the project's own CLAUDE.md requires.

## The single-implementation-interface switch

`JV1` (Java) / `GO3` (Go) / `TS2` (TypeScript) / `PY8` (Python) are one rule in four dialects, and
they share exemptions:

1. A mock implementation exists → the test **is** the second implementation. Keep.
2. Multiple implementations registered, or DI selects by name/qualifier → keep.
3. The framework requires the interface form (Feign, gRPC stubs, plugin contracts) → keep.
4. A project coding standard mandates it → disabled by the Step 1 CLAUDE.md gate.

This is simultaneously the highest-yield check and the one most likely to collide with team
convention. When any exemption is uncertain, drop it to J-tier rather than deleting.
