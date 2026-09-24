# Spec Modes — Spec → Doc and Spec → Test-first

## Reading the input

| Input | How |
|---|---|
| md / txt | read directly |
| pdf | read directly; long files by page range |
| docx | through the `docx` skill (or `pandoc` when installed) |
| pasted text | as given |
| OpenAPI 2.0 / 3.x, yaml or json | read directly; resolve `$ref`s before designing |
| screenshots, prototypes, online systems (Jira, TAPD, 飞书) | out of scope — ask the user to paste the text |

## Requirement items

1. Number the items. Use the document's own numbering; without one, assign `R1`, `R2` … and show the mapping once.
2. Per item, extract the acceptance criteria, business rules, validation rules and limits, states and transitions, roles and permissions, error messages.
3. Anything a case needs that the text does not settle — a missing timeout, an undefined limit, a rule that reads two ways — is a `待确认` row plus a question. Never fill the gap silently; a proposal is fine when it is visibly marked as one.
4. Items outside this skill — performance targets, visual design, compatibility — appear in the coverage matrix as 未覆盖, with the reason.

Use 场景法 on flows: the basic flow, each alternative flow, each exception flow. Then walk `test-design.md` for every item. OpenAPI: the per-operation checklist in `test-design.md`; 关联需求 is `METHOD /path`.

Coverage rule: every requirement item has at least one case, or an explicit 未覆盖 row with its reason.

## Spec → Doc

- **Structure**: `assets/test-case-doc-template.md` — summary table, per-case details, coverage matrix, 刻意不测, and 遗留问题 only when a 待确认 was left open. A test-case template the project already uses replaces it, as long as it keeps: case id, 关联需求, preconditions, steps, expected results, priority.
- **Details**: numbered steps a tester can carry out; numbered expected results paired with the steps; concrete test data.
- **Ids**: exactly the confirmed list's ids — no renumbering, no cases that were not confirmed.
- **Path**, confirmed in the round:
  - `.docs/` exists → `.docs/50-测试验证/51-测试设计/<需求编号>-测试用例.md`;
  - otherwise → `docs/test-cases/<需求编号或主题>-测试用例.md`.
- **A file already exists at the path** → never overwrite silently. Offer: 在原文件上更新（保留已有编号，追加新用例）/ 另存为新文件.
- **Format**: Markdown, always. When the user accepted the `.docx` export, generate it from the finished Markdown through the `docx` skill — same directory, same base name, same content and table layout. The Markdown is the source of truth: edits go to the `.md`, then the `.docx` is regenerated. No `docx` skill on this host → the Markdown only, and say so. Other formats only when the user asks for them explicitly.

## Spec → Test-first

1. **Entry points.** For each case, the seam it calls: an existing class, method or endpoint when there is one; otherwise the signature to create, following the project's layering and naming. Entry points are confirmed together with the list.
2. **Level.** A service seam → unit tests. An HTTP contract (OpenAPI) → in-process API tests.
3. **Minimal stubs.** Only what the tests need to compile: the types and signatures they reference, with bodies that throw or return the language's "not implemented" (`lang-*.md`); data carriers get only the fields the tests touch. Nothing else — no validation, no logic. A stub that changes an **existing** type — a new enum constant, a new method on an existing class — is called out as such in the round. A missing route needs no stub: a 404 is a valid failure.
4. **Run.** Every new test must fail, and for the right reason: an assertion, the stub's not-implemented error, or a 404 / 501 for a missing route. A compile error in the test code itself, a missing import, a fixture or setup error is the wrong reason — fix the test. A test that passes before any implementation is suspect: the behavior may already exist (then this is Code mode), or the assertion is vacuous. Report it either way.
5. **Hand-off.** The failing tests are the implementation to-do list. The report lists them with the stubs and their paths, and suggests that the user or `code-vibe-workflow` implements next. No implementation is written here.
