# 可植入 CLAUDE.md 的日志条款

skill 是按需加载的 —— 写新功能时它不会被触发。要让「每次写代码都按规范打日志」真正生效，把下面的条款复制进**项目的 `CLAUDE.md`**（或 `~/.claude/CLAUDE.md`，如果你希望全局生效）。

复制时请把 `<业务主键>` 换成项目实际用的锚点字段名（`orderId` / `orderNo` / `tradeNo` …），把语种一行调成项目现状。

---

```markdown
## 日志规范

1. 消息形如「动作+结果 + key=value」，中文消息、英文 key；单行自包含 —— 脱离上下文也能读懂。
2. 一律用框架占位符传参（SLF4J `{}` / Python `%s` / slog kv / pino 对象），禁止字符串拼接和 f-string。
3. 必打五类点位：请求入口出口、外部调用前后、关键状态流转、异常捕获、定时与异步任务起止。
4. 这五类必须带业务锚点 `<业务主键>`；外部调用和入口出口还要带 `costMs`。
5. ERROR 只给需要人介入的失败，且必须带堆栈或错误码；参数校验失败、业务规则拒绝一律 WARN。
6. 异常对象作为最后一个参数传入（`log.error("...", args, e)` / `logger.exception` / `zap.Error`），
   禁止只打 `e.getMessage()`；禁止 `printStackTrace` 和空 catch。
7. catch 后重新抛出的不要打 ERROR，由最终处理者记录一次，避免一个故障刷出三条 ERROR。
8. 循环体和热路径内不打 INFO；改为循环结束后打一条汇总（`total/success/failed`）。
9. traceId 走项目现有上下文机制（Java MDC / Python contextvars / Go ctx / Node AsyncLocalStorage），
   不要在业务方法签名里传 traceId；跨线程池、异步、MQ、出站调用时必须把上下文带过去。
10. 禁止打印整个实体对象，禁止打印手机号、身份证、银行卡、密码、token、地址、真实姓名。
```
