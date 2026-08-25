# Alibaba Java Annotation Reference

Use this checklist when annotating or reviewing Java. It applies the Alibaba Java Manual's annotation requirements first, then records related contract gaps without changing code.

## Core Annotation Rules

- Every class/type gets Javadoc explaining its responsibility, domain role, usage constraints, or protocol position. Do not merely restate the class name.
- Every public method documents its business purpose, parameters, return value, and thrown exceptions. Abstract methods must state the implementation contract.
- Enum members need comments describing their business meaning; enum type documentation should explain when the enumeration applies.
- Fields document domain/business meaning and non-obvious units, ranges, defaults, lifecycle, or persistence behavior—not just the identifier in prose.
- Keep explanatory line comments immediately above the statement or branch. Avoid trailing comments unless extending an existing short one.
- Use a space after `//`, `/*`, and Javadoc delimiters where conventional. Keep comments syntactically valid and readable after formatting.
- Never leave commented-out code as documentation. Remove it only if explicitly authorized; otherwise report it.
- Deprecated members must retain an explanatory replacement path; when adding deprecation notes use Javadoc `@deprecated`.
- TODO/FIXME comments should identify intent and owner/context; missing ownership or rationale is a review signal.
- Business/domain wording may be precise Chinese; API-facing identifiers and established technical terms remain English.

## Authorship Override

The Alibaba manual asks class Javadoc to include creator metadata. This skill intentionally does not add `@author` or `@date`: keep existing tags unchanged and omit them from new comments. This is a deliberate privacy/safety-oriented project override.

## Related Contract Review Signals

Report these instead of changing code:

### Naming
- Mixed pinyin/English identifiers beyond widely accepted terms.
- Abstract or misleading class/method names that make accurate comments difficult.
- Constants not using upper snake case; unclear magic values needing a named constant or stronger explanation.
- POJO boolean properties named with an `is` prefix where serialization conflicts are likely.

### Exceptions
- Swallowed exceptions or empty catches.
- Business errors lacking meaningful, user/actionable context.
- Overly broad catch blocks hiding distinct failure meanings.
- Resources not cleaned in `finally` or equivalent try-with-resource flow.

### Concurrency
- Shared mutable state without a documented synchronization/thread-safety contract.
- Mutable static helpers such as date formatters used concurrently without protection.
- Double-checked lazy initialization missing `volatile`; locks guarding inconsistent boundaries.
- `ThreadLocal` values without a documented cleanup path.

### Logging
- Placeholder-style logging opportunities (`{}`) replaced by string concatenation.
- `System.out`/`System.err` or printStackTrace usage.
- Log text that omits key business identifiers, state transition, or exception stack.

### MySQL
- Tables or important columns without comments.
- Boolean-like columns not following an `is_xxx` convention.
- Money/precision fields using floating-point types rather than DECIMAL.
- Index names that do not communicate columns/purpose.

### Unit Testing
- Test names that do not express scenario and expected result.
- Missing assertion intent or tests relying only on execution success.
- External systems not isolated by mocks/stubs when determinism requires it.
- Test comments contradicting actual setup or expected behavior.

## Reporting Format

Group output into:

1. Added/enhanced comments summary.
2. Contradictions between comment and behavior.
3. Alibaba contract review signals by section above.
4. Bugs or risks observed, reported only.
