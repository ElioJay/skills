# Scope creep — the feature nobody asked for

While implementing the A the user asked for, the model also shipped B: a cache layer, a retry
policy, timeout parameters, an Options struct, config keys, an abstract factory, a connection
pool, a circuit breaker, metrics, pagination, rate limiting.

**This is usually not bad code.** It is well-formed, commented, sometimes even tested. The problem
is that nobody wanted it.

**The test is authorization, not quality.** A beautifully written retry loop the user never asked
for is still out of scope.

Most of the damage lands on YAGNI's *cost of carry*: unused capability makes every later change
and every later debugging session more expensive, and it keeps charging for as long as it stays.

## Where the requirement comes from

Infer it from the current session: what the user actually asked for, in their words. If the
session does not contain it (a resumed session, a stale diff), say so and drop the scope-creep
pass rather than guessing. Never invent a requirement to justify a deletion.

## Signals, most reliable first

### S1 — Noun-set difference · high confidence

Diff the **nouns in the request** (task description, issue text, the user's prompt) against the
**nouns in the added identifiers** (class names, function names, field names, config keys).

High-risk difference terms:

```
cache / caching / cached
retry / retries / backoff / jitter
timeout / deadline / expire / ttl
pool / pooling / connection_pool
circuit / breaker / fallback / degrade
throttle / ratelimit / rate_limit / quota
metrics / telemetry / instrument
options / opts / config / settings / params
factory / builder / provider / registry
strategy / policy / handler_chain
async / queue / worker / scheduler
pagination / cursor / offset / page_size
```

For each term in the difference, ask directly: was this requested?

This is the only signal that maps "the model added it" onto "the user wanted it" without an
intermediate inference. Everything below is indirect.

### S2 — New dependency · high confidence

The diff modifies a dependency manifest — `go.mod`/`go.sum`, `package.json`/lockfile,
`pom.xml`/`build.gradle`, `requirements.txt`/`pyproject.toml`/`poetry.lock` — and the added
library is never mentioned in the request.

Typical: the task was "add a field to the order endpoint" and the diff pulls in `caffeine`,
`resilience4j`, or `p-retry`.

If the dependency exists only to serve out-of-scope code, it goes when that code goes.

### S3 — Config key never read, or only ever default · high confidence

Repo-wide read sites for a newly added env var or config key: zero means dead config; nonzero but
every caller passing the default means the configurability serves nobody.

### S4 — Options/Config struct, one call site, all defaults · high confidence

An `Options`/`Config` struct or a functional-options set (`WithXxx`) with exactly one construction
site, every field at its default. Internal API: delete the mechanism, pass fields directly.
Public library: configurability is the product — keep.

### S5 — Single-implementation abstraction with no second one described · high confidence

A new interface / abstract class / strategy registry with one implementation, **and no comment,
TODO, ADR, or issue link saying a second one is coming**.

The absence of a trace is the point. A developer who genuinely expects a second implementation
leaves evidence. No evidence means this was reflex, not design.

Same phenomenon as `JV1` / `GO3` / `TS2` / `PY8` in the language files, viewed from a different
angle: those ask "should it be deleted", this asks "who added it".

### S6 — Suspiciously round magic number · medium-high

A new timeout, retry count, capacity or batch size is `3`, `10`, `30`, `60`, `100`, `1000`, `5000`
— **and** has no constant name, no comment about its origin, no config key, no SLA or benchmark
behind it.

Values that came from real tuning tend to be unround (27s, 4 attempts). Round numbers are what
"looks reasonable" produces.

First ask whether the *feature* the parameter belongs to was requested. If yes, the missing
justification is a separate finding. If no, the whole block goes.

### S7 — New path, no test · medium-high

The diff adds cache-hit/miss, retry, degradation, or circuit-open branches, and the tests cover
only the happy path.

If the author believed the path mattered, they would have tested it. Adding it untested is an
admission that it is decorative.

Weakened when the model also generated tests — but a test that only asserts "does not throw"
still counts as a hit.

### S8 — Placeholder wording · medium-high

```
for future / future-proof / extensible / extensibility
in case we need / just in case / might need
将来 / 未来 / 后续 / 方便扩展 / 便于扩展 / 预留 / 可配置 / 灵活性
TODO: support ... later
```

The author is stating outright that this serves a speculative requirement.

### S9 — File count out of proportion to the task · medium

An "add a field" / "fix a condition" / "change a string" task produced three or more new files, or
a new directory.

Code volume correlates strongly with architectural drift in agent-generated work — as the agent
produces more files, its ability to hold a coherent architecture collapses, yielding surface-level
file separation without semantic cohesion. Use this to trigger review, never as grounds for
deletion.

### S10 — Docs describe capabilities nobody asked for · medium

README, docstrings, or API docs touched by this diff describe features outside the task. Also
watch for `PLAN.md` / `SCRATCH.md` / `ANALYSIS.md` / `NOTES.md` scratch files leaking into the diff.

### S11 — Abstraction-level jump · medium

The new code introduces a pattern that appears **nowhere else in this codebase**. The repo is all
direct calls and plain functions, and suddenly there is an `AbstractOrderProcessorFactory` plus an
`OrderProcessingStrategy` plus a `ProcessorRegistry`.

Count existing occurrences of the pattern outside this diff. Zero means a hit. A relative
criterion — not "is this pattern good" but "is it consistent with this codebase" — which is far
more robust than an absolute rule.

### S12 — Concurrency added on its own initiative · medium-high

Its own entry because concurrency is one of the model's favourite unrequested "optimizations",
and the complexity it brings — races, nondeterministic ordering, undebuggable failures — almost
always outweighs the time it saves.

- A goroutine / `Promise.all` / thread pool / `asyncio.gather` added over a collection whose size
  is known to be small (10 or fewer elements)
- A mutex or semaphore added around data only one goroutine or one request ever touches
- `errgroup` / `Promise.allSettled` whose error handling is exactly equivalent to the serial form

Reverting to serial **removes** code, so it is in scope — but confirm the upper bound on the
collection size first.

## Disposition

| Signals hit | What to do |
|---|---|
| S1 + (S3 or S4 or S5) | High confidence. List as a deletion candidate; user confirms |
| S2 alone | High confidence. Question the dependency; if it only serves out-of-scope code, both go |
| S12 with a confirmed small upper bound | Reverting to serial is subtraction — offer it as a deletion candidate |
| Only S6 / S7 / S8 | Report, do not delete. May be necessary robustness that merely lacks stated justification |
| Only S9 / S10 / S11 | Trigger human review. No automatic judgment |
| Out-of-scope code protected by a redline (metrics already wired, TODO marker present) | **Do not delete.** Report it as "outside the task's scope, worth a separate review" |

**Never delete a scope-creep finding automatically — not even under `--auto`.** The inferred
requirement can be wrong, and acting on it means cutting features on the user's behalf.

## Report format

```
[SCOPE CREEP] <file>:<line>
命中信号：S1（名词差："cache"）+ S4（Options 单调用点全默认）+ S7（无测试）
新增内容：CacheConfig 结构体 + WithCache option + 缓存读写分支，共 47 行
任务描述中的依据：无
carry cost：后续每次改 Fetch 都要考虑缓存一致性
建议：删除（需你确认）
```

Always cite the signal numbers. The user must be able to re-check the reasoning, not just receive
a verdict.
