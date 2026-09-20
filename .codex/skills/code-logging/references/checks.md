# Checks

How to spot a violation, and which tier it lands in. Every finding reported to the user carries its id from this file.

Tiers, and what each one is allowed to do: **F** batch-edit after one confirmation · **S** per-item confirmation · **P** per-item confirmation, inserts new statements · **T** per-site preview and confirmation, adds context propagation only · **PII** report only, never edited.

Read `standard.md` first — these checks are the negative image of it.

---

## Redlines — never rewritten, in any tier

Check these **before** proposing any edit to an existing log line. A hit means the line is recorded in the "left alone" section of the report with its reason, and nothing else.

- **R1 — The message text is asserted by a test.** Search the test sources for the literal prefix of the message before rewording it. Log assertions are rare but real, and rewording silently breaks the suite.
- **R2 — The line feeds an alert rule or a log-based metric.** Signals: a comment saying so, a marker like `DO NOT CHANGE` / `监控依赖`, a message that is an odd fixed token, or a grep hit in any `*alert*` / `*monitor*` / `*.rules.yml` in the repo. Changing the wording silently disables a production alarm.
- **R3 — Audit / compliance logs.** Anything routed to an audit logger, an operation-trail table, or named `audit` / `操作日志` / `留痕`. These carry legally-mandated formats and are not this skill's subject.
- **R4 — The line carries an explicit intent marker about itself**: `TODO` / `FIXME` / `XXX` / `WORKAROUND` referring to the logging. Report it; do not "resolve" it.
- **R5 — Generated code** (`DO NOT EDIT`, `@Generated`, protobuf/openapi output).
- **R6 — Test files.** This standard governs production code. Tests may log however they like.

A redline blocks *rewriting* a line. It never blocks *reporting* a PII leak on that line.

---

## F — Format (batch after one confirmation)

Mechanical, low-risk, no behavior change.

**F1 — Concatenation instead of a placeholder.**
`log.info("order " + id + " paid")`, f-strings in Python `logging`, template literals in a pino call. The argument is built even when the level is off, and the structured form is lost.
→ Rewrite to the language's lazy placeholder form.

**F2 — Message is not self-contained.**
`"success"`, `"进入方法"`, `"result: {}"`, `"=== start ==="`, a bare method name. The test: read the line with no file, no schema, no neighbouring lines — does it say what happened?
→ Rewrite as `动作 + 结果` plus the keys that make it concrete.

**F3 — Missing business anchor** at one of the five mandatory points. Use the key the repo already uses; do not normalize `orderNo` to `orderId`.

**F4 — Missing `costMs`** on an outbound call or an entry/exit pair.
→ If no timer exists, adding one is an S-tier change (it touches control flow), not F. Report it as F but land it under S confirmation.

**F5 — ERROR/WARN with neither an error code nor an exception type.** Degrade to the exception's class name when the project has no error-code system.

**F6 — A whole entity passed as one value.** `user={}`, `req={}`, `dto={}`. Name the two or three fields that matter.
→ If the entity plausibly carries personal data, this is **PII1**, not F6. PII wins; report, do not edit.

**F7 — Message shape or language inconsistent with the repo.** Chinese message + English keys is the standard, but a repo that is uniformly English stays English — consistency inside the repo wins. Flag the outliers, not the majority.

**F8 — Adjacent duplicate.** "即将调用 X" immediately followed by "调用 X 完成" with no branch between them is one line.

**F9 — Placeholder / argument count mismatch.** `"{} {}"` with three args, or two placeholders and one arg. This is a live defect, not a style issue — the output is silently wrong. Fix it and call it out in the report.

---

## S — Semantic (per-item confirmation)

Each of these changes runtime behavior, alerting volume, or what a failure looks like. Never batch them.

**S1 — Level too high.** ERROR on something the system routinely handles: parameter validation failure, business-rule rejection, "record not found", an expected declared exception. → WARN (or INFO for pure control flow).
This is the highest-volume real finding in most codebases, and the reason the ERROR channel stops being read.

**S2 — Level too low.** A genuine unrecoverable failure at INFO or DEBUG, or a swallowed error logged at DEBUG so it never surfaces. → ERROR.

**S3 — Duplicate recording (`standard.md` E2).** `catch { log.error(...); throw ...; }` — the exception is logged here and again by the caller and again by the global handler. One incident, three ERRORs.
→ Remove the ERROR at the intermediate layer, or demote it to DEBUG if it genuinely adds context the final handler lacks. **Verify a final handler actually exists** (global exception handler, top-level catch) before removing — if nothing above logs it, deleting this line loses the failure entirely.

**S4 — Exception object not passed (E1).** `log.error("failed: " + e.getMessage())`, `log.error(str(e))`, `logger.error({err: e.message})`. The stack and cause chain are gone.
→ Pass the exception itself in the language's designated position.

**S5 — `printStackTrace` or silent swallow (E4).** The former bypasses the logging system (no level, no traceId, no collection); the latter erases the event. An empty `catch` that is genuinely correct needs a DEBUG line plus a comment stating why.

**S6 — INFO inside a loop body or a hot path.** Per-item, per-row, per-poll-tick.
→ Collapse to one summary line after the loop (`处理完成 total={} success={} failed={}`), or demote to DEBUG.

**S7 — Eagerly-built DEBUG argument.** A concatenation, a serialization, or an expensive call evaluated to produce a DEBUG argument.
→ Placeholder form, or the language's level guard when the argument itself is costly.

---

## P — Missing log points (per-item confirmation, inserts code)

For each of P1–P5 in `standard.md`, walk the scope and find the sites that qualify but have no log line. Report each as: the site, which point it is, and the exact statement proposed.

**P1** request entry / exit · **P2** outbound call, both sides · **P3** key state transition · **P4** exception catch · **P5** scheduled or async task start / end.

Two judgment rules that keep this tier from exploding:

- **Do not propose a point that would fire inside a loop or a hot path.** A missing log is better than a log that fires 10,000 times per request.
- **In Git Uncommitted mode, only qualifying sites inside the changed hunks count.** Do not report every missing log point in a file the user touched two lines of.

---

## T — Trace continuity (per-site preview and confirmation)

Where the logging context silently disappears. Only context propagation is ever added — never an appender, an encoder, collection config, or a tracing dependency the project does not already have.

**T1 — No trace context at the entry.** Requests arrive and nothing establishes a trace id, or an inbound one (`traceparent`, `X-Trace-Id`, or whatever the project's upstream sends) is dropped instead of adopted.
→ If the project has no trace mechanism at all, this is a **gap to report**, not a fix to apply. Name the language-appropriate mechanism and stop.

**T2 — Thread pool / async submission.** A task submitted to an executor runs on a thread with no context. The most common break, and the one that makes people believe "traceId doesn't work".

**T3 — Message queue.** Producer does not put the trace id on the message; consumer does not read it back into the context. Two separate sites; report them separately.

**T4 — Outbound call.** HTTP client, RPC stub, or feign-style interface that does not inject the trace header, so the downstream service starts a fresh trace.

For each, the per-language idiom is in the matching `lang-*.md`. Show the exact diff before asking.

---

## PII — Report only, never edited

Highest report priority. These are **never** rewritten by this skill: masking can hide the very value someone needs during an incident, so the decision is the user's. Give the finding, the risk, and a suggested rewrite they can apply.

**PII1 — Whole entity or DTO logged as one value**, where the type plausibly carries personal data: `user`, `customer`, `account`, `member`, `profile`, `address`, `card`, `payment`, `identity`. The `toString` dumps every field including the ones nobody meant to log.

**PII2 — A sensitive field logged directly.** Names to scan for, in both English and Chinese: phone / mobile / 手机号, idCard / idNo / 身份证, bankCard / cardNo / 银行卡, password / pwd / 密码, token / accessToken / secret / apiKey, email / 邮箱, address / addr / 地址, realName / 姓名, birthday, salary.

**PII3 — Whole request or response body dumped**, typically in an interceptor or filter "for debugging".

**PII4 — Credentials in the log.** A token, key, or password value reaching a log call — including inside a URL or a header map.

**Boundary:** credentials *committed into the repository or pushed to a remote* are not this skill's subject; that is `audit-remote-secret-leaks`. This skill only looks at what a running program writes to its logs.

---

## Observations — report only, never acted on

Things worth telling the user that are outside this skill's mandate:

- **A `catch` that logs and then returns a normal success value**, hiding the failure from the caller. A logging change cannot fix it; it needs a control-flow decision.
- **A log message that contradicts the code** (says "重试中" on a path that does not retry). Often a real bug; record it, do not "fix" the message.
- **Log points that would need a new timer, counter, or return value** to carry the standard's context keys.
- **A missing error-code system**, when `errorCode` degraded to exception type names across the board.
