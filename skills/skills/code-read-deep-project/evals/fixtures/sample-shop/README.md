# sample-shop（多模块样例项目 · fixture）

> 仅用于 `code-read-deep-project` 的质量评估，不参与真实构建/运行。

电商下单样例，**多模块 + 多语言**：

- **后端（Java / Gradle 多模块）**
  - `shared/` —— 公共值对象（`Money`），被 order、payment 共用（构建拓扑的基础）。
  - `payment/` —— 支付模块，依赖 `shared`，对外提供 `charge`（扣款）。
  - `order/` —— 订单模块，依赖 `shared` 与 `payment`，对外暴露 HTTP 入口 `OrderController`（`POST /orders`）。
- **前端（TypeScript / npm）**
  - `web/` —— 前端订单客户端，通过 HTTP 调用后端 order 模块的 `/orders`。

**模块依赖（构建期）**：`order → {shared, payment}`，`payment → shared`，`shared →（无）`。无环。
**运行期调用**：`web →(HTTP)→ order → payment / shared`。
