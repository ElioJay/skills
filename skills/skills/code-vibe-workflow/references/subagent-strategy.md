# Subagent 委托策略

本文件是 code-vibe-workflow 的 subagent 使用配套。核心原则：**独立、可并行的任务才派；一旦派出，同一个 message 里多个并发，不要串行**。

---

## 决策树：要不要派 subagent？

```
任务是否独立（无共享状态、无顺序依赖）？
  ├─ 否 → 不派
  └─ 是 → 是否有 2+ 个？
            ├─ 否 → 是否需要保护主上下文（结果会很长）？
            │       ├─ 是 → 派 1 个
            │       └─ 否 → 不派，直接做
            └─ 是 → 派多个，同一 message 并发
```

---

## 6 个阶段的 subagent 使用矩阵

| 阶段 | 是否常用 subagent | 用什么类型 | 典型场景 |
|------|-------------------|-----------|----------|
| 1. 需求理解 | ❌ 极少 | - | 需要与用户对话，不能委托 |
| 2. Plan 设计 | ✅ 常用 | Explore / general-purpose | 大型项目的"代码现状探索" |
| 3. 编码实现 | ⚠️ 视情况 | general-purpose | 独立模块（如前/后端解耦）并行编码 |
| 4. 测试 | ⚠️ 视情况 | general-purpose | 实现与测试解耦时，可并行写测试 |
| 5. Code Review | ✅ 推荐 | code-improvement-scanner | 盲审降低自审盲区 |
| 6. 提交 | ❌ 不用 | - | 涉及用户决策与 git 状态，必须主线程做 |

---

## 场景 1：Plan 阶段的代码探索（最高 ROI）

**何时用**：大型项目（>50 文件）、对项目不熟、需要跨多目录理解架构。

**派单个 Explore subagent**：
```
Agent({
  subagent_type: "Explore",
  description: "探索登录相关模块",
  prompt: "在当前仓库中调查与用户登录相关的代码：
  1. 找到登录入口（Controller/Route）
  2. 追溯到 Service 和 Repository 层
  3. 找到 User 实体定义和数据库映射
  4. 列出已有的 JWT/Session 工具类
  5. 找到现有的单元测试样板

  返回：每个发现的文件路径 + 一句话作用 + 关键方法签名。
  搜索广度：medium。"
})
```

**派多个 Explore 并行**（同一 message 里）：
```
// 前后端分别派一个
Agent({ subagent_type: "Explore", description: "后端订单模块", prompt: "..." })
Agent({ subagent_type: "Explore", description: "前端订单页面", prompt: "..." })
```

---

## 场景 2：编码阶段的并行实现

**何时用**：方案明确拆出了**完全独立**的模块（接口契约已定）。

**典型例子**：前后端分离，后端 API 已定义清楚，前端可独立开发。

```
// 同一个 message 里
Agent({
  subagent_type: "general-purpose",
  description: "实现订单导出后端 API",
  prompt: "实现 GET /api/orders/export?format=xlsx 接口...
  完整契约：{...}
  约束：复用现有 OrderService、用 EasyExcel。
  完成后返回：新建/修改的文件清单 + 测试结果。"
})
Agent({
  subagent_type: "general-purpose",
  description: "实现订单导出前端按钮",
  prompt: "在 OrderListPage 加导出按钮...
  调用契约：GET /api/orders/export?format=xlsx
  返回 blob，触发下载。
  完成后返回：改动文件 + 截图（可选）。"
})
```

**反例（不要这样）**：
- ❌ 派一个 subagent 改 A，再派一个改依赖 A 的 B —— 有依赖就别拆
- ❌ 同一个文件被两个 subagent 同时改 —— 会冲突

---

## 场景 3：测试编写并行

**何时用**：多个独立模块的测试可以并行写。

```
Agent({ description: "为 OrderService 写测试", prompt: "..." })
Agent({ description: "为 TaxCalculator 写测试", prompt: "..." })
```

**注意**：测试跑通的最终验证还是要在主线程做一次 `mvn test` / `pytest`，确认所有测试 pass。

---

## 场景 4：盲审 Code Review（强烈推荐）

**为什么**：自己 review 自己有盲区，独立 subagent 不知道你的实现思路，更容易发现逻辑漏洞。

```
Agent({
  subagent_type: "code-improvement-scanner",
  description: "盲审登录次数统计功能",
  prompt: "请独立 review 以下文件，关注：
  - 正确性、安全（SQL 注入/权限）、性能（N+1）、异常处理、测试覆盖
  - 不要看我的实现说明，只看代码本身

  涉及文件：
  - src/.../LoginStatsService.java
  - src/.../LoginStatsController.java
  - test/.../LoginStatsServiceTest.java

  需求摘要（仅供判断"是否实现了需求"）：
  实现 GET /api/users/{id}/login-stats?days=7 返回最近 N 天登录次数。

  输出：维度评分 + Top 3 必须修复问题 + 是否建议合并。"
})
```

---

## 写好 subagent prompt 的 5 条规则

1. **自包含**：subagent 看不到你和用户的对话，把所需上下文（背景、约束、契约）都写进 prompt
2. **明确返回什么**：让 subagent 输出"结构化的结论"，不要让它写一大段散文
3. **限定搜索广度**（Explore 类）：quick / medium / very thorough，避免无限扩散
4. **限定字数**（研究类）：写 "report in under 200 words"，避免上下文爆炸
5. **不要让 subagent 决策**：决策点（方案选 A 还是 B）必须回主线程，让用户拍板

---

## 反模式（不要这样做）

| 反模式 | 问题 | 正确做法 |
|--------|------|----------|
| 派 subagent 做"读一个已知路径的文件" | 浪费，Read 一下就行 | 直接 Read |
| 派 subagent 后用 `sleep` 等结果 | 阻塞 + 浪费 | 用 run_in_background 或同步等待 |
| 串行派多个独立 subagent | 慢 | 同一 message 内并发派 |
| 把"和用户对话"委托给 subagent | subagent 不能与用户交互 | 主线程做 |
| Subagent 改了文件，主线程不验证 | 风险高 | 主线程 Read 关键文件确认 |
| 派 subagent 做 git commit | 状态分裂、不可控 | 主线程做 |

---

## subagent 委托后的"验证"清单

派出去 ≠ 完成。结果回来后，主线程要做：

- ☐ 读 subagent 报告，理解它做了什么
- ☐ 对它改/新建的关键文件用 Read 抽查
- ☐ 跑测试确认未破坏现有功能
- ☐ 如发现 subagent 跑偏，立刻修正（不要默认信任）

记住：**subagent 的报告描述的是它"打算做"的事，不一定是它"实际做"的事**。
