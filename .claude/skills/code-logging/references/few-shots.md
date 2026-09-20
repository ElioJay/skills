# Few-Shots

Anchors for how each tier is presented and rewritten. Read before the first edit.

---

## F — Format: one list, one gate, then batch

Present it compactly — these are mechanical and the user is confirming a class of change, not each line.

```
【F 格式类】6 处 · 确认后批量改

OrderService.java:48   F1  字符串拼接 → 占位符
OrderService.java:52   F2  "success" 无信息 → 订单支付成功 orderId=… amount=…
OrderService.java:71   F3  缺业务锚点 → 补 orderId
PayClient.java:33      F4  外部调用缺 costMs
PayClient.java:40      F9  两个占位符三个参数（输出已经是错的）
StockService.java:19   F2  "进入方法" → 库存扣减开始 skuId=… quantity=…
```

Rewrites:

```java
// F1
- log.info("order " + orderId + " paid, amount " + amount);
+ log.info("订单支付成功 orderId={} amount={}", orderId, amount);

// F2 + F3 — the two usually travel together
- log.info("success");
+ log.info("订单支付成功 orderId={} amount={} costMs={}", orderId, amount, costMs);

// F9 — output is silently wrong today
- log.info("处理完成 total={} success={}", total, success, failed);
+ log.info("处理完成 total={} success={} failed={}", total, success, failed);
```

---

## S — Semantic: one item, one gate

Each item states **what changes at runtime**, because that is what the user is actually deciding.

```
【S 语义类】第 1/4 项

OrderController.java:36   S1  参数校验失败打在 ERROR
  - log.error("参数不合法 orderId={}", orderId);
  + log.warn("参数不合法，请求被拒 orderId={} reason={}", orderId, reason);

  影响：这条目前进 ERROR 告警通道。降级后告警量下降，
        若有告警规则按 level=ERROR 匹配这条，规则需同步调整。
  改 / 跳过 / 全部同类一起改？
```

```
【S 语义类】第 2/4 项

OrderService.java:88   S3  catch 后记录并重新抛出
  - catch (PayException e) { log.error("支付失败 orderId={}", orderId, e); throw e; }
  + catch (PayException e) { throw e; }

  已确认最终处理者：GlobalExceptionHandler.java:24 会记录该异常。
  影响：同一次失败目前在三层各产生一条 ERROR，改后只剩最终一条。
```

The "已确认最终处理者" line is not optional. If no handler above logs it, say so and **recommend keeping the line** instead:

```
  未找到会记录该异常的上层处理者。删除这条会让失败彻底消失在日志里。
  建议：保留本条，改为在最外层补一个统一处理者（属 P4，另列）。
```

---

## P — Missing points: site, reason, proposed statement

```
【P 漏打类】4 处 · 每处单独确认

第 1/4  PayClient.java:57  P2 外部调用无日志
  第三方支付网关调用前后都没有日志，超时和失败时无从判断卡在哪一步。

  57  │  PayResponse resp = gateway.pay(req);
      ↓
  57  │  long start = System.currentTimeMillis();
  58  │  log.info("调用支付网关 orderId={} amount={}", orderId, amount);
  59  │  PayResponse resp = gateway.pay(req);
  60  │  log.info("支付网关返回 orderId={} code={} costMs={}",
      │          orderId, resp.getCode(), System.currentTimeMillis() - start);

  注：需引入计时变量（改动超出纯日志范围），确认后再加。
```

Sites deliberately **not** proposed are worth one line at the end of the section, so the user sees the judgment:

```
  未提议的点位：OrderService.calcDiscount（私有纯函数）、
  StockService 第 42 行循环体内（会随行数放大，违反 S6）。
```

---

## T — Trace continuity: full preview per site

```
【T 断链类】第 1/2 处

AsyncConfig.java:21   T2  线程池未传递 MDC，@Async 方法里 traceId 为空

  已探测：项目使用 Logback MDC，logback-spring.xml 的 pattern 含 %X{traceId}，
          traceId 由 TraceFilter.java:28 写入。机制存在，只是没跨线程。

  @Bean("orderExecutor")
  public ThreadPoolTaskExecutor orderExecutor() {
      ThreadPoolTaskExecutor executor = new ThreadPoolTaskExecutor();
      executor.setCorePoolSize(8);
+     executor.setTaskDecorator(runnable -> {
+         Map<String, String> ctx = MDC.getCopyOfContextMap();
+         return () -> {
+             if (ctx != null) MDC.setContextMap(ctx);
+             try { runnable.run(); } finally { MDC.clear(); }
+         };
+     });
      executor.initialize();
      return executor;
  }

  只加上下文传递，不动 logback 配置、不引新依赖。
  影响：@Async 任务的日志开始带上发起请求的 traceId。
```

When nothing exists to propagate, do not invent it:

```
【T 断链类】第 1/1 处 —— 仅报告，不改

  全仓未发现任何链路机制：logback pattern 无 %X，无 MDC 调用，
  无 Sleuth / OTel / SkyWalking 依赖。

  规范要求日志带 traceId，当前无来源，所有 traceId 相关检查失效。
  可选落地方式（需你决定，本次不做）：
    1. Micrometer Tracing —— Spring Boot 3 原生，改动最小
    2. OTel javaagent —— 零代码接入，但需要部署侧配合
    3. 自建 OncePerRequestFilter + MDC —— 最轻，跨服务需自行约定 header
```

---

## PII — report only

Never a diff. State the leak, the risk, and the rewrite the user can apply.

```
【PII】2 处 · 本 skill 不改，请你决定

UserService.java:44   PII1  整个 User 对象被打印
  log.info("用户信息 user={}", user);
  User.toString() 包含 mobile / idCard / address 三个字段，
  这三项会完整进入日志文件与采集端。

  建议改法（未执行）：
  log.info("用户查询成功 userId={} status={}", user.getId(), user.getStatus());

LoginController.java:29   PII4  token 明文入日志
  log.debug("登录成功 token={}", token);
  DEBUG 在生产通常关闭，但一旦为排障临时开启，凭据即落盘。

  建议改法（未执行）：删除该字段，或只打印后 6 位。

未脱敏的原因：脱敏可能遮蔽排障时真正需要的值，这个取舍归你。
```

---

## Report skeleton

```
日志规范审计 —— OrderService 模块（Path 模式）

扫描 7 个文件 · 日志语句 43 条 · 发现 18 项

  F 格式类    6   已批量修改
  S 语义类    4   3 改 1 跳过
  P 漏打类    4   2 补 2 跳过
  T 断链类    2   1 补 1 仅报告
  PII         2   仅报告

【已修改】…按 tier 列出 file:line + 检查号…
【已跳过】…含用户选择跳过的，与红线命中的…
【红线保留】OrderService.java:112  R1  该消息被 OrderServiceTest:88 断言
【仅报告】…PII 两项 + 链路缺口…
【附注，超出本 skill 职责】
  - OrderService.java:95 catch 后只记日志并返回成功，失败对调用方不可见
  - StockService.java:31 日志写"重试中"，但该路径没有重试逻辑
  - 项目无统一错误码体系，errorCode 一律降级为异常类型名
```

---

## New Code mode

No findings, no gates, no report. Write to the standard and close with one line:

```
已按日志规范打点：入口出口（含 costMs）、支付网关调用前后、状态流转到 PAID、
异常捕获一处（WARN，业务预期异常）。traceId 走项目现有 MDC，未新增机制。
```
