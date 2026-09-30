# Go

`log/slog` (stdlib, Go 1.21+) or `zap` / `zerolog` when the project already uses one. Context is carried by `ctx`, explicitly — this is the language's idiom and this standard does not fight it.

## Logger and call form

```go
slog.InfoContext(ctx, "订单支付成功", "order_id", orderID, "cost_ms", costMs)
```

- **Always the `...Context` variant** when a `ctx` is in scope. `slog.Info` without ctx cannot pick up the trace id, and that is the most common Go break.
- Keys are `snake_case` string literals paired with values, or typed attrs (`slog.String("order_id", id)`) — pick whichever the repo already uses and stay consistent.
- Errors: `slog.ErrorContext(ctx, "订单支付失败", "order_id", orderID, "err", err)`. Go has no stack trace on a plain error; if the project uses `pkg/errors` or `cockroachdb/errors`, log `%+v` to get one.
- `fmt.Sprintf` inside a log call is F1. So is `log.Printf` from the old stdlib logger in a codebase that has moved to slog.
- `panic` / `log.Fatal` in library code is not logging — flag it as an observation.

zap equivalent: `logger.Info("订单支付成功", zap.String("order_id", id), zap.Int64("cost_ms", ms))`, and `zap.Error(err)` for the error field. Avoid `SugaredLogger`'s `Infof` — it is F1 by construction.

## traceId via ctx

There is no ambient context in Go. Two workable shapes:

```go
// A: a ctx-scoped logger — preferred when the codebase already passes a logger
ctx = context.WithValue(ctx, loggerKey{}, slog.With("trace_id", traceID))

// B: a slog.Handler that reads the id out of ctx on every record
func (h traceHandler) Handle(ctx context.Context, r slog.Record) error {
    if id, ok := ctx.Value(traceKey{}).(string); ok {
        r.AddAttrs(slog.String("trace_id", id))
    }
    return h.Handler.Handle(ctx, r)
}
```

B is usually the lighter change on an existing codebase: the id goes into ctx once and every `...Context` call picks it up without touching call sites. It makes "did you use `InfoContext`?" the only rule call sites must follow.

**Detecting an existing mechanism:** OpenTelemetry (`go.opentelemetry.io/otel`, `trace.SpanFromContext(ctx).SpanContext().TraceID()`), a middleware already putting an id in ctx, or a request-id package (`chi/middleware`, `gin-contrib/requestid`). Adopt it.

## The four break points

**T1 — Entry.** `net/http` middleware, a gin/echo/chi middleware, or a gRPC `UnaryInterceptor`: adopt the inbound header or generate an id, put it in ctx, pass the derived ctx down. Handlers that ignore `r.Context()` and build their own `context.Background()` defeat this — scan for that.

**T2 — Goroutines.** Go's specific failure: a goroutine does not inherit anything, and `context.Background()` inside one is the break.

```go
go func() {
    // BAD: fresh ctx, trace lost
    doWork(context.Background())
}()

go func(ctx context.Context) {
    doWork(ctx)     // pass the parent ctx in explicitly
}(ctx)
```

Watch for: bare `go func()` closures that call `context.Background()` or `context.TODO()`, `errgroup.Group` (its `WithContext` ctx is the right one to pass), worker pools reading off a channel where the job struct does not carry the ctx or the id, and `time.AfterFunc`.

A caveat worth reporting rather than fixing: passing the request ctx into a goroutine that outlives the request means the goroutine is cancelled when the request ends. The correct shape is `context.WithoutCancel(ctx)` (Go 1.21+) — it keeps the values, drops the cancellation. Propose it, do not apply it silently; it changes lifecycle.

**T3 — Message queue.** Producer writes the id into the message headers (Kafka `Headers`, NATS headers, an envelope field); consumer reads it back into a fresh ctx at the top of the handler. Two findings, not one.

**T4 — Outbound.** An `http.RoundTripper` wrapper that injects the header, or a gRPC `UnaryClientInterceptor` adding it to the outgoing metadata. A hand-rolled `http.Client` per call site is a sign this will be missed in several places — report all of them.

## Go-specific log points

- **P1** — HTTP handlers and gRPC methods; middleware covers entry+exit+`cost_ms` uniformly.
- **P2** — outbound `http.Client` calls, database `QueryContext` batches, cache clients.
- **P4** — Go has no exceptions, so the analogue is `if err != nil`. **Not every one of them logs** — that produces the same error at five layers. Log where the error stops (the handler), wrap with context (`fmt.Errorf("fetch order: %w", err)`) everywhere else. A logged-and-returned error is S3.
- **P5** — goroutine-based background workers, cron jobs, and any `for { select {} }` loop: log start, log exit, and log the reason for exit.

## Typical defects in Go codebases

```go
slog.Info("订单支付成功", "order_id", id)          // T2-adjacent: no ctx → no trace_id
slog.Info(fmt.Sprintf("order %s paid", id))        // F1 + F2
slog.Info("done")                                  // F2
if err != nil {
    slog.ErrorContext(ctx, "查询失败", "err", err)
    return err                                     // S3: logged and returned — logged again above
}
if err != nil { return fmt.Errorf("%w", err) }     // observation: wrap adds nothing
go func() { doWork(context.Background()) }()       // T2
slog.InfoContext(ctx, "用户", "user", user)        // PII1: the whole struct
for _, r := range rows { slog.InfoContext(ctx, "处理", "id", r.ID) }  // S6
```
