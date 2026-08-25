# Annotation Plan Format

Only Single File Mode and Entry Point Mode use this plan. Git Uncommitted Mode uses its lightweight single confirmation instead.

Before editing, output a structured plan with these sections:

## 1. Target Identification
- What the target is
- Whether it is a single file or an entry point
- What you are treating as the analysis starting point

## 2. Language and Density
- State the resolved comment language (user-specified, auto-defaulted from existing comments, or to be asked)
- State the chosen density level (Detailed or Selective)

## 3. Proposed Scope
- For single file: confirm only that file will be annotated
- For entry point: describe the suggested annotation boundary

## 4. Involved Files and Roles
For each file in scope, explain:
- Why it is included
- What role it plays in the flow
- Whether comments should be added there

## 5. Planned Comment Targets
Describe the intended comment coverage, such as:
- Class or module responsibility
- Method purpose
- Parameter meaning
- Return value meaning
- Field / property / struct-member meaning
- Business flow steps
- Important branches and state changes
- External calls and their purpose
- Key inline comments where the code is non-obvious

## 6. Confirmation Items
Explicitly ask about:
- Whether to expand or shrink the scope
- Whether to include DTO, VO, entity, mapper, repository, or downstream service layers
- Whether to focus only on the core path

## 7. Execution Summary
State:
- Which files will be edited after approval
- What level of comment detail will be used

---

## Filled Mini Example (Entry Point Mode, abridged)

1. **Target**: `POST /report/template/save` → `ReportTemplateController#save`; entry point mode; analysis starts from the controller method.
2. **Language and Density**: existing comments in scope are Chinese → defaulting to Chinese; user chose Detailed.
3. **Proposed Scope**: controller method + `ReportTemplateService.save` + `ReportTemplateVO`; stop above the mapper layer.
4. **Involved Files and Roles**:
   - `ReportTemplateController.java` — HTTP entry and parameter binding → annotate
   - `ReportTemplateService.java` — business validation and insert-vs-update branching → annotate
   - `ReportTemplateVO.java` — request payload fields → annotate
   - `ReportTemplateMapper.java` — plain MyBatis interface outside the boundary → skip
5. **Planned Comment Targets**: class responsibilities; `save()` purpose / params / return / throws; VO field meanings; validation steps and the insert-vs-update branch.
6. **Confirmation Items**: include the mapper layer? include the entity? core path only?
7. **Execution Summary**: 3 files edited after approval, Detailed density.
