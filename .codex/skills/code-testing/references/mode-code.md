# Code Mode

## Scope

**A named target** — `Class.method`, `package.Func`, `receiver.Method`, a class, or a file. Only that target is tested. Callers and callees are read for oracle evidence and to understand the dependencies, never tested unless named.

**Git changes.**
1. Repo: the cwd's repo. Not inside one → ask for the path.
2. Changes: uncommitted by default — `git status --porcelain` (staged, unstaged, untracked) and `git diff HEAD -- <file>`; an untracked file is entirely new. A commit range when the user gives one — `git diff <A>..<B>`, with `git log <A>..<B>` for the messages.
3. Keep source files. Changed test files are read as existing tests, not as targets. Config, resources and generated files are out.
4. The behavior under test is each changed hunk's enclosing function or method; a new file contributes all of its public behavior. Unchanged functions in a changed file get no new cases.
5. The intent of a change comes from, in order: what the user says about it, the commit messages, comments and docstrings changed in the diff — then 推断. The diff itself is implementation, not intent.

**Endpoints.** A controller, a handler, or the operations of an OpenAPI spec that an existing service implements: Code mode with in-process API tests. The spec is the 需求 source, and the list gains the 关联需求 column.

## Oracle

**Intent** (the default):
1. Gather the evidence: requirements the user gave, doc comments, repo docs, callers — how they consume the result, which errors they handle — and names.
2. Draft each case's expected result from that evidence alone.
3. Only then read the implementation. Its branches show which cases are missing; each place where it disagrees with step 2 is a ⚠.

Reading the implementation first anchors the expected results on the code, and the ⚠ list comes out empty — the defects end up certified by the tests.

**Lock** (only on the user's explicit request):
- 依据 is `实现` on every row; no ⚠ rulings are asked for.
- Chinese descriptions start with `现状：`, so a later reader knows the test pins behavior, not a specification.
- Behavior that looks wrong is still pinned, and listed in the report under 附注 — 已按现状锁定，建议另行确认.
- Every test must pass; a failure is the test's fault.
- The confirmation round still happens.

## Existing tests

Find them by the project's naming (`XxxTest`, `test_xxx.py`, `xxx_test.go`, `xxx.test.ts`, `__tests__/`) and by searching the test tree for the target's symbols.
- A scenario an existing test already covers → 已有覆盖; no new case.
- An assertion the change makes stale → 需更新, with the evidence: the diff changes exactly what it asserts. Rewritten only after confirmation, to the new behavior, keeping the test's name while it still fits.
- An existing test that fails for another reason, or breaks the quality floor → reported only.

## Level

- Unit tests by default, boundaries mocked (`quality-floor.md` rule 3).
- The project already has integration infrastructure (Testcontainers, an embedded DB, a test profile) and the case is about persistence or SQL → an integration test in the project's existing style.
- An HTTP layer → in-process API tests with the tool the language file names. Never start a server on a port, and never depend on one that is already running.

## Running

Commands, output patterns and the right-reason signals per language are in `lang-*.md`; the outcome table is SKILL.md Step 6. In addition:
- Type-check first only where the runner would not catch type errors itself (TypeScript under Vitest, `@swc/jest` or `babel-jest`).
- Re-run right after each fix to the test's own fault; the same failure three times → stop and report what was tried.
