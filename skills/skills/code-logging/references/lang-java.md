# Java / Spring Boot

The reference stack: SLF4J API + Logback, MDC for context, Spring for the boundaries. Log4j2 differs only in configuration, which is out of scope anyway.

## Logger and call form

```java
private static final Logger log = LoggerFactory.getLogger(OrderService.class);   // or @Slf4j
```

- Placeholders are `{}`, and the exception goes **last, without a placeholder**:
  `log.error("订单支付失败 orderId={} errorCode={}", orderId, code, e);`
  Adding a `{}` for `e` is a common mistake — it prints `e.toString()` and drops the stack.
- `log.debug("...", expensive())` still evaluates `expensive()`. Guard with `if (log.isDebugEnabled())` only when the *argument* is costly to build; the placeholder alone handles the formatting cost.
- Never `System.out.println`, never `e.printStackTrace()`.
- `@Slf4j` is fine when Lombok is already in the project; do not introduce Lombok to get it.

## traceId via MDC

Call sites stay clean — `MDC.put` happens at the boundary, the encoder emits it:

```java
MDC.put("traceId", traceId);
try {
    // ... the request
} finally {
    MDC.clear();     // mandatory: pooled threads are reused, a stale traceId is worse than none
}
```

Reading the pattern in `logback-spring.xml` tells you the key name in use (`%X{traceId}`) — **read it, never edit it.** If the pattern has no `%X`, the traceId is not reaching the output and that is a T1 gap to report.

**Detecting an existing mechanism, in priority order.** Adopt whatever is already there; do not layer a second one:

| Present | Signal | traceId source |
|---|---|---|
| Micrometer Tracing / Sleuth | `io.micrometer:micrometer-tracing`, `spring-cloud-sleuth` | already in MDC as `traceId`; nothing to add |
| OpenTelemetry agent | `-javaagent:opentelemetry-javaagent.jar`, `otel.*` properties | MDC keys `trace_id` / `span_id` via log appender autoconfig |
| SkyWalking agent | `skywalking-agent.jar`, `apm-toolkit-logback` | `%tid` in the pattern, or `TraceContext.traceId()` |
| Home-grown | a `TraceContext` / `ThreadLocal<String>` / a filter doing `MDC.put` | that key |
| None | no `%X` in the pattern, no MDC anywhere | T1 gap — report, do not invent |

## The four break points

**T1 — Entry.** A `OncePerRequestFilter` (or a `HandlerInterceptor`) that adopts an inbound `traceparent` / `X-Trace-Id` when present and generates one otherwise, `MDC.put` before `chain.doFilter`, `MDC.clear()` in `finally`. Register it early in the filter chain.

**T2 — Thread pools and async.** This is the one that bites.

```java
// ThreadPoolTaskExecutor: a TaskDecorator copies the context across the handoff
executor.setTaskDecorator(runnable -> {
    Map<String, String> ctx = MDC.getCopyOfContextMap();
    return () -> {
        if (ctx != null) MDC.setContextMap(ctx);
        try { runnable.run(); } finally { MDC.clear(); }
    };
});
```

Sites to scan: `@Async` methods, `ThreadPoolTaskExecutor` / `ThreadPoolExecutor` beans, raw `executor.submit(...)`, `CompletableFuture.supplyAsync(...)` **without** an executor (it runs on the common ForkJoinPool — context is gone), `parallelStream()`, `new Thread(...)`, `@Scheduled` (a scheduled run has no inbound request, so it needs its own traceId generated at the start).

**T3 — Message queue.** Producer puts the traceId on the message headers; consumer reads it into MDC at the top of the handler and clears it in `finally`. Kafka `ProducerInterceptor` / `ConsumerInterceptor`, RabbitMQ `MessagePostProcessor`, RocketMQ `SendMessageHook`. Producer and consumer are two separate findings.

**T4 — Outbound.** Feign `RequestInterceptor`, `RestTemplate` `ClientHttpRequestInterceptor`, `WebClient` filter, or an OkHttp `Interceptor` that writes the traceId into the outbound header. Without it the downstream service opens a fresh trace and the chain ends at your boundary.

## Spring-specific log points

- **P1** — `@RestController` / `@Controller` methods; `@RabbitListener` / `@KafkaListener`; `@GrpcService`. A global `@RestControllerAdvice` is the natural home for the exit-on-failure line, and the natural final handler for S3.
- **P2** — Feign clients, `RestTemplate` / `WebClient` calls, and batch DB operations. A single-row `findById` is not a P2 point.
- **P4** — `@ExceptionHandler` methods are the final handler: they log at ERROR. Intermediate `catch` blocks that rethrow do not (S3).
- **P5** — `@Scheduled` and `@Async` methods.
- Avoid an around-`@Aspect` that logs entry/exit of every service method. It produces volume, not information, and buries the five points that matter.

## Alibaba Java guideline clauses that apply

The manual's logging section, restated where it overlaps this standard:

- **Mandatory** — Use the SLF4J API, not a concrete implementation directly.
- **Mandatory** — Log file naming and rolling policy: configuration, out of scope here.
- **Mandatory** — `log.debug`/`log.trace` calls must use the placeholder form or a level guard; string concatenation in a disabled level is forbidden. (= F1 / S7)
- **Mandatory** — When catching and rethrowing, do not log at the catch site; log once where it is handled. (= S3 / E2)
- **Mandatory** — Exception logs must include the context parameters **and** the stack: `log.error("xx异常 param={}", param, e)`. (= S4 / E1)
- **Mandatory** — Never use `System.out` / `System.err` / `e.printStackTrace()` in production code. (= S5 / E4)
- **Recommended** — Log messages should be informative enough to reconstruct what happened without reading the code. (= F2)
- **Recommended** — Avoid unnecessary logging at INFO in loops and hot paths. (= S6)

Where the manual and this standard disagree, the manual wins for Java — but note the disagreement in the report rather than silently picking one.

## Typical defects in Java codebases

```java
log.error("系统异常", e);                          // F2: which system? which operation? no anchor
log.info("orderId:" + orderId);                    // F1 + F2
log.error("参数错误: {}", msg);                     // S1: validation failure at ERROR
catch (Exception e) { log.error("失败", e); throw e; }   // S3: logged here and again upstream
catch (Exception e) { log.error(e.getMessage()); } // S4: stack gone
catch (Exception e) { }                            // S5
log.info("用户信息 user={}", user);                 // PII1
for (Item i : items) log.info("处理 {}", i.getId()); // S6
log.info("处理完成 {} {}", total, success, failed); // F9: three args, two placeholders
```
