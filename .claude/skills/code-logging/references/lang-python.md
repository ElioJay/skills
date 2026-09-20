# Python

Standard library `logging`, or `structlog` when the project already uses it. Context rides on `contextvars`.

## Logger and call form

```python
logger = logging.getLogger(__name__)
```

- **`%s` placeholders, not f-strings.** `logger.info("订单支付成功 order_id=%s cost_ms=%s", order_id, cost_ms)`. An f-string is evaluated before the call, even at a disabled level, and the structured form is lost. This is F1 and it is the single most common Python violation, because f-strings are otherwise the right default everywhere else in the language.
- **Exceptions: `logger.exception(...)` inside an `except` block**, which attaches the traceback automatically. Outside an except block, `logger.error(..., exc_info=True)`.
  `logger.error(str(e))` and `logger.error(f"failed: {e}")` are S4 — the traceback is gone.
- Extra context goes in `extra={...}` when the project has a formatter that emits it; otherwise inline it in the message as `key=%s`. Do not use `extra` with keys that collide with `LogRecord` attributes (`message`, `args`, `exc_info`, `module`, `name`) — it raises at runtime.
- Never `print()` for diagnostics in library or service code.

With `structlog` the shape is `logger.info("订单支付成功", order_id=order_id, cost_ms=cost_ms)` — keys are kwargs, the message stays the human-readable part. The self-containment rule (F2) still applies to the message.

## traceId via contextvars

```python
trace_id_var: ContextVar[str] = ContextVar("trace_id", default="-")

class TraceFilter(logging.Filter):
    def filter(self, record):
        record.trace_id = trace_id_var.get()
        return True
```

The filter is attached to the handler and the formatter references `%(trace_id)s`. Reading the formatter string tells you whether the traceId reaches the output; **read it, do not edit it**.

**Detecting an existing mechanism:** OpenTelemetry (`opentelemetry-instrumentation`, which injects `otelTraceID` into records), a framework middleware already setting a contextvar, `structlog.contextvars.bind_contextvars`, or a home-grown `ContextVar`. Adopt what is there.

A `threading.local()` used for this is a bug waiting to happen under async — note it, and let the user decide whether to migrate.

## The four break points

**T1 — Entry.** ASGI/WSGI middleware (FastAPI `@app.middleware("http")`, Starlette `BaseHTTPMiddleware`, Django middleware, Flask `before_request`) that adopts an inbound header or generates a new id, sets the contextvar, and **resets the token** afterwards:

```python
token = trace_id_var.set(trace_id)
try:
    ...
finally:
    trace_id_var.reset(token)
```

**T2 — Thread pools and async.** The Python asymmetry matters here:

| Construct | Context propagates? |
|---|---|
| `asyncio.create_task` / `gather` / `await` | **yes** — contextvars are copied into the task automatically |
| `loop.run_in_executor` | **no** — a plain thread handoff |
| `ThreadPoolExecutor.submit` | **no** |
| `ProcessPoolExecutor`, `multiprocessing` | **no**, and not fixable by copying a var — the id must be passed as an argument |
| `threading.Thread` | **no** |

For the thread cases, capture and restore explicitly:

```python
ctx = contextvars.copy_context()
executor.submit(ctx.run, fn, *args)
```

Celery is its own case: the id goes in `task.apply_async(headers={...})` (or a `before_task_publish` / `task_prerun` signal pair), never through a contextvar.

**T3 — Message queue.** Producer writes the id into the message headers/properties; consumer reads it into the contextvar at the top of the handler. `kombu`, `aio-pika`, `confluent-kafka` all expose headers.

**T4 — Outbound.** An `httpx` event hook, a `requests` session with a prepared-request hook, or an `aiohttp` `TraceConfig` that writes the header outbound.

## Python-specific log points

- **P1** — route handlers / view functions; a middleware can cover entry+exit+`cost_ms` for all of them at once, which is usually the right call.
- **P2** — `httpx` / `requests` / `aiohttp` calls, ORM bulk operations, cache clients.
- **P4** — `except` blocks. `logger.exception` at the handler; nothing at intermediate layers that reraise (S3).
- **P5** — Celery tasks, APScheduler jobs, `asyncio` background tasks, management commands.

## Typical defects in Python codebases

```python
logger.info(f"order {order_id} paid")             # F1 + F2 (f-string, no keys)
logger.info("done")                                # F2
logger.error("参数不合法: %s", msg)                 # S1: validation at ERROR
except Exception as e:
    logger.error(f"failed: {e}")                   # S4: traceback gone → logger.exception
except Exception:
    pass                                           # S5
except Exception as e:
    logger.exception("处理失败"); raise             # S3 if a handler above also logs
logger.info("user=%s", user)                       # PII1: the dataclass repr dumps everything
for row in rows: logger.info("处理 %s", row.id)     # S6
logger.debug("payload=%s", json.dumps(big))        # S7: dumps() runs even when DEBUG is off
```
