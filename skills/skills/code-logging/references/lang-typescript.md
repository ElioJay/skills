# TypeScript / Node

`pino` or `winston` for services, whatever the framework ships (`@nestjs/common` `Logger`) when the project is on one. Context rides on `AsyncLocalStorage`.

## Logger and call form

```ts
logger.info({ orderId, costMs }, "订单支付成功");
```

- **pino's argument order is object-first, message-second.** `logger.info("订单支付成功", { orderId })` puts the object in the wrong slot and it is dropped or stringified. This is the most common mechanical defect in pino codebases.
- winston is the other way round: `logger.info("订单支付成功", { orderId, costMs })`. Follow whichever the project uses; do not mix.
- **Template literals in the message are F1.** `` logger.info(`order ${id} paid`) `` bakes the value into the string and loses the field. Put values in the object.
- Errors: `logger.error({ err, orderId }, "订单支付失败")`. The key must be `err` for pino's standard serializer to expand the stack — `{ error: e }` prints `{}` because `Error` has no enumerable own properties. That silent-empty-object behaviour is S4 in disguise and worth calling out explicitly.
- Never `console.log` / `console.error` for diagnostics in service code: no level, no trace id, no serializer, and it bypasses collection.

## traceId via AsyncLocalStorage

```ts
const als = new AsyncLocalStorage<{ traceId: string }>();

// at the entry
als.run({ traceId }, () => next());

// in the logger config — every line picks it up, call sites stay clean
pino({ mixin: () => ({ traceId: als.getStore()?.traceId }) });
```

The `mixin` (pino) or a custom `format` (winston) is what makes this invisible at the call site. Reading it tells you whether the trace id reaches the output; **read it, do not edit it.**

**Detecting an existing mechanism:** OpenTelemetry (`@opentelemetry/api`, `trace.getActiveSpan()`), NestJS `ClsModule` (`nestjs-cls`), `cls-hooked` in older codebases, or a home-grown ALS. Adopt it.

## The four break points

**T1 — Entry.** Express/Koa/Fastify middleware or a NestJS interceptor that adopts the inbound `traceparent` / `x-trace-id` or generates one, then wraps the rest of the request in `als.run(...)`. The wrap must enclose the *whole* downstream chain — an `als.run` that returns before the handler's promise settles loses the context for everything after the first `await`.

**T2 — Async boundaries.** The good news: `AsyncLocalStorage` survives most of them.

| Construct | Context survives? |
|---|---|
| `await`, promise chains, `Promise.all` | **yes** |
| `setTimeout` / `setInterval` / `setImmediate` | **yes** |
| `EventEmitter` listener registered *inside* the context | yes — bound at registration |
| `EventEmitter` listener registered at module load, fired later | **no** — it runs in the registration context, not the emitter's |
| `worker_threads` | **no** — separate isolate; pass the id in `workerData` or a message |
| child process, a job enqueued to Redis/BullMQ | **no** — the id must travel in the payload |
| A callback stored in a module-level queue and drained later | **no** |

So T2 in Node is narrower than in Java or Go, and the real finds are the bottom four rows. A job queue (BullMQ, Bee, Agenda) is the usual one: the id goes into the job data on enqueue and back into `als.run` on process.

**T3 — Message queue.** Producer puts the id on the message headers; consumer reads it and wraps the handler in `als.run`. `amqplib` properties, `kafkajs` headers, SQS message attributes.

**T4 — Outbound.** An axios request interceptor, an `undici` / `fetch` wrapper, or a `got` hook that writes the header from `als.getStore()`.

## Node-specific log points

- **P1** — route handlers, NestJS controllers, GraphQL resolvers at the top level. One middleware covers entry+exit+`costMs` for all of them.
- **P2** — axios/fetch calls, ORM transactions and bulk operations (Prisma, TypeORM), cache clients.
- **P4** — `catch` blocks and `.catch()` handlers. Also: an `async` function whose rejection nobody handles, and a missing `process.on('unhandledRejection')` — both are observations worth reporting, since a silent unhandled rejection is the hardest thing in Node to diagnose from logs.
- **P5** — cron jobs (`node-cron`, BullMQ repeatable), queue consumers, startup and graceful-shutdown hooks.

## Typical defects in Node codebases

```ts
console.log("order paid", orderId);                    // bypasses the logger entirely
logger.info(`order ${orderId} paid`);                  // F1 + F2
logger.info("ok");                                     // F2
logger.info("订单支付成功", { orderId });               // pino: object in the wrong slot, dropped
logger.error({ error: e }, "失败");                     // S4: prints {} — the key must be `err`
logger.error("失败: " + e.message);                     // S4: stack gone
catch (e) { logger.error({ err: e }, "失败"); throw e; } // S3 if an upper handler also logs
catch (e) { /* ignore */ }                              // S5
logger.info({ user }, "用户信息");                      // PII1: whole object serialized
rows.forEach(r => logger.info({ id: r.id }, "处理"));   // S6
```
