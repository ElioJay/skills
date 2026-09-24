# Test Design Dimensions

Walk this list for every target before drafting the case list. The five core dimensions are always walked; the three conditional ones only when one of their triggers is present. Every dimension ends in exactly one state: covered by cases, 不适用 with a reason, or 刻意不测 with a reason. Silence is not a state.

## Core dimensions — always

### 1. 正常 — the happy path

- One case per **distinct success outcome**, not per input. Two inputs that succeed the same way are one case; parameterize them.
- Assert the whole outcome: the return value, the persisted state, the emitted event — not merely "it succeeded".

### 2. 边界 — boundaries

For every ordered quantity the behavior depends on — numbers, lengths, sizes, counts, amounts, times:
- on the boundary, and one step off it on each side: `limit - 1`, `limit`, `limit + 1`. With inclusive or exclusive wording (满 100、不超过、以内、之前) the boundary value itself is the case that matters most;
- collections: empty, one, many; text: empty, blank, maximum length;
- zero, negative, and the type's extremes where they are reachable;
- money: the smallest unit, and rounding at the half (`0.005`);
- time: the exact expiry instant and one tick before it, month end, leap day, the time zone of the stored value.

A "boundary" case that does not sit on a boundary (quantity 5 when the limit is 10) is a normal case in disguise.

### 3. 异常 — invalid input and errors

- **Equivalence classes of invalid input**: missing or null, wrong type or format, out of range, an illegal combination. One case per class; parameterize the values inside a class.
- **Dependency failures**: the DB, a downstream HTTP service, MQ or the file system raising, timing out, answering 4xx / 5xx, or returning malformed data.
- Assert the error **and the side effects that must not happen**: nothing persisted, nothing sent, stock not decreased, the compensation performed. An error case that checks only the exception type misses half the behavior.
- The error contract: type and code; the message only when the message is the contract — shown to users or parsed by callers.

### 4. 状态 — state and ordering

- Every legal transition of the states the target moves through, and at least the illegal transitions a caller can actually trigger (cancel a shipped order, refund an unpaid one).
- The same operation repeated in sequence — a second submit, a second refund.
- Order dependence: B before A, A twice, re-entry after a failure.

### 5. 组合 — condition combinations

When two or more conditions jointly decide the outcome, build a decision table instead of enumerating 2^N combinations:
1. List the conditions and the possible outcomes.
2. Collapse the don't-care entries.
3. Cover every remaining rule (column) once.
4. For each condition, include a pair of cases that differ only in that condition and produce different outcomes — the evidence that the condition matters.

A validation chain with a documented order (先校验过期，再校验门槛) also needs a case where two conditions fail at once, asserting which one wins.

## Conditional dimensions — when triggered

### 6. 并发 — concurrency and idempotency

Triggers: shared mutable state (stock, balances, counters, caches), retries, message consumption, overlapping scheduled runs, locks.

Cases: the same request retried after a timeout; a duplicate message; an idempotency key reused; two concurrent updates of one record (lost update).

A unit test can prove idempotency logic; it cannot prove the absence of a race. A race that needs a real database or real threads gets a case only when integration infrastructure exists — otherwise 刻意不测, with that reason.

### 7. 权限 — permissions and security

Triggers: authentication or authorization checks, tenant or owner filters, user input reaching SQL / shell / HTML / file paths / templates, uploads, deserialization.

Cases: unauthenticated; authenticated but another user's resource (越权); a missing role; an injection or path-traversal payload handled safely; oversized input rejected.

### 8. 数据量 — volume

Triggers: pagination, batch operations, loops over caller-supplied collections, bulk import and export, configured limits.

Cases: page size 0 / 1 / max / max + 1; the last page and the empty page; a batch exactly at the limit and one over it; a collection of the maximum size processed correctly.

This is functional correctness at volume, not performance measurement — timing assertions do not belong here.

## Techniques behind the dimensions

| Technique | Serves | Use it to |
|---|---|---|
| 等价类划分 | 正常, 异常 | pick one representative per class of inputs that behave the same |
| 边界值分析 | 边界, 数据量 | put cases on and next to every boundary |
| 判定表 | 组合 | cover combinations without the explosion |
| 状态迁移 | 状态 | enumerate the legal and the illegal transitions |
| 场景法 | the Spec modes | basic flow, alternative flows, exception flows of each use case |
| 错误推测 | all | add cases where code of this shape usually breaks: off-by-one, `<` vs `<=`, null from a lookup, integer overflow, rounding, time zones, empty collections, a retry with no idempotency check |

An 错误推测 case names the suspected weakness in 场景, so the user can judge whether it is worth keeping.

## OpenAPI checklist, per operation

- Every documented response status has at least one case.
- Each required field missing once; each field's type, format, `enum`, `minimum` / `maximum`, `minLength` / `maxLength` / `pattern` violated once, and its boundaries hit.
- A security scheme is declared → an unauthenticated and a forbidden case; none declared → 权限 is 不适用 (规格未定义鉴权).
- The response body checked against the schema's required fields and enums, not merely "is JSON".
- Documented headers (`Location`, pagination headers) asserted.

## Granularity

- One case per behavior. Inputs that produce the same behavior are one parameterized case.
- Do not split one outcome into several cases, one per asserted field.
- Near-duplicate cases dilute the list the user has to confirm — merge them.
