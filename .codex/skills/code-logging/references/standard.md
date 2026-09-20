# The Standard

What a log statement in code should look like. This is the "should" side; `checks.md` is the "how to spot a violation" side.

**The one assumption about output channels.** This standard governs what the code hands the logger. Whether that lands as JSON, as a text line, in a file or in a collector is the project's appender/encoder configuration, which this skill never touches. Everything below is written so it reads correctly either way — which is exactly why the message must be self-contained.

---

## 1. Message shape

```
动作 + 结果  key=value key=value ...
```

- **Chinese message, English keys.** The prose part is Chinese so a human reads it at a glance; keys stay English so they survive search, grep and log platforms.
- **Self-contained.** One log line, read alone with no surrounding context and no field schema, must say what happened. This is the single highest-value rule in this document: it is what lets an AI reason from a log excerpt instead of needing the source.
- **Parameterized, never concatenated.** Use the framework's lazy placeholder form. Concatenation evaluates even when the level is disabled, and destroys the structured form.

```java
// good
log.info("订单支付成功 orderId={} amount={} costMs={}", orderId, amount, costMs);
log.warn("库存不足，下单被拒 orderId={} skuId={} required={} available={}", orderId, skuId, need, available);

// bad — not self-contained; needs the surrounding code to mean anything
log.info("success");
log.info("进入方法");
log.info("result: {}", result);

// bad — concatenated, and the exception is reduced to a string
log.error("支付失败: " + e.getMessage());
```

**Wording.** State the business event, not the code mechanics. `订单支付成功` beats `payService.pay returned true`. Avoid mood without content (`异常!!!`, `这里不应该发生`).

**Do not log the same fact twice** on adjacent lines ("即将调用 X" followed immediately by "调用 X 完成" with no failure path between them is one line, not two).

---

## 2. Context keys

| Key | Mandatory where | Notes |
|---|---|---|
| **Business anchor** — `orderId` / `userId` / `tradeNo` / any queryable primary key | all five mandatory log points | The key that lets someone pull the whole business history out of the logs. Without it a reader can only walk one traceId at a time. |
| **Cost** — `costMs` | outbound calls; entry/exit | The only handle on latency and timeout problems. Measure the call, not the whole method, unless the point *is* the whole method. |
| **Error code** — `errorCode` | ERROR / WARN, **only if the project already has an error-code system** | No system in place → degrade to the exception type name. Never propose building an error-code system; that is an architecture decision, out of scope. |

`traceId` is **not** in this table: it belongs to the logging context, not to the call site. See §6.

Pick the anchor the project already uses — if the codebase says `orderNo`, use `orderNo`, do not normalize it to `orderId`. Consistency inside one repo beats consistency with this document.

**Never put an entire entity in as one value.** `log.info("用户信息 user={}", user)` is both unreadable and a PII leak; name the two or three fields that matter.

---

## 3. The five mandatory log points

A log point missing here is a finding (tier P). Each one has a shape:

| # | Point | What it logs |
|---|---|---|
| **P1** | **Request entry / exit** — controller, RPC handler, message consumer, CLI command | entry: the action and its key inputs (not the whole payload). exit: outcome + `costMs`. |
| **P2** | **Outbound call, both sides** — HTTP, RPC, DB batch, cache, third party | before: target + key params. after: outcome + `costMs`. On failure, the failure line replaces the success line. |
| **P3** | **Key state transition** — order paid, account frozen, task scheduled, retry exhausted | the from-state, the to-state, and what drove it. This is the backbone of any after-the-fact reconstruction. |
| **P4** | **Exception catch** | every `catch` either logs or rethrows — see §5. A `catch` that does neither is a violation. |
| **P5** | **Scheduled / async task start and end** | start: trigger + parameters. end: outcome + counts + `costMs`. These run unattended; if they do not log, nobody ever finds out they stopped. |

**What is deliberately not a mandatory point:** ordinary private helpers, getters, pure functions, and anything inside a loop body or a hot path. Adding a log point to satisfy this list, when it fires thousands of times per request, is itself a violation.

---

## 4. Levels

| Level | Meaning | Hard rules |
|---|---|---|
| **ERROR** | A failure that needs a human. | Must carry a stack trace **or** an error code. Must not fire for anything the system routinely recovers from. |
| **WARN** | Degraded, retried, fell back, or an *expected* business rejection. | Parameter validation failures, business-rule rejections, and expected exceptions live here, not at ERROR. |
| **INFO** | Business milestone. The five mandatory points default to INFO. | Never inside a loop body. Never a per-iteration counter. |
| **DEBUG** | Detail for diagnosis. | Must be lazily evaluated — placeholder form, or guarded by the language's `isDebugEnabled` equivalent when the argument itself is expensive to build. |
| **TRACE** | Rarely justified. | If the project does not already use it, do not introduce it. |

The most common real-world defect this catches: **parameter validation failures logged at ERROR.** They are neither rare nor actionable, and they drown the ERROR channel until nobody reads it.

---

## 5. Exceptions — the four rules

**E1 — Pass the exception object, never its message.**
The stack trace is the single most valuable thing in a failure log, and `getMessage()` discards it along with the cause chain.

```java
log.error("订单支付失败 orderId={} errorCode={}", orderId, code, e);   // good — e is the last arg
log.error("订单支付失败: " + e.getMessage());                            // bad
```

**E2 — Log where it is handled, not where it is caught and rethrown.**
A `catch` that rethrows (or wraps and rethrows) must not log at ERROR; the final handler logs it once. Otherwise one failure appears as three ERRORs at three layers and reads like three separate incidents.

If the intermediate layer genuinely adds context, add it to the rethrown exception, or log it at DEBUG — not ERROR.

**E3 — Expected exceptions are WARN, unexpected ones are ERROR.**
A declared business exception (`InsufficientBalanceException`) is control flow: WARN with an error code, no stack trace needed. An unexpected one (NPE, timeout, connection refused) is ERROR with the stack.

**E4 — No `printStackTrace`, no silent swallow.**
`e.printStackTrace()` bypasses the logging system entirely — no level, no traceId, no collection. An empty `catch` block is worse; if swallowing is genuinely correct, it needs a DEBUG line and a comment saying why.

---

## 6. traceId in the context

The code should not be threading a `traceId` parameter through business methods. It belongs to the ambient logging context, and the mechanism differs per language — see the matching `lang-*.md`:

| Language | Mechanism |
|---|---|
| Java | MDC — the value is injected by the encoder, call sites stay clean |
| Python | `contextvars` + a logging filter |
| Go | `ctx` carried explicitly, `slog.InfoContext` / a ctx-scoped logger |
| TypeScript / Node | `AsyncLocalStorage` |

What the **code** is responsible for is that the context survives the boundaries where it is silently dropped: thread pools, async submission, message queues, outbound calls. Those four break points are enumerated in `checks.md` (T1–T4).

If the project has no trace context at all, that is a gap to report, not something to invent mid-audit.

---

## 7. What not to log

- Anything in §PII of `checks.md` — phone numbers, ID numbers, card numbers, passwords, tokens, addresses, real names.
- Whole request/response bodies "just in case". Name the fields that matter.
- Inside loops, per-item, per-row, per-poll-tick.
- Values already on the same line in a different form.
- Entry/exit of trivial private helpers.
- Anything at ERROR that fires on normal user behavior.
