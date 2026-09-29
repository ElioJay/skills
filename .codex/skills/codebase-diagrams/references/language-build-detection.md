# 多语言识别 · 第 ①② 层：语言层 与 构建层

阶段 3 侦察开始时读这份文件。第 ③ 层（框架层）与跨语言连边见 `framework-lenses.md`。

**三层的分工**：

| 层 | 解决什么 | 不做的后果 |
|---|---|---|
| ① 语言层 | 认得出文件是什么语言、提取类 / 函数 / import | 读不了代码 |
| ② 构建层 | 从构建文件定模块边界与依赖 | **模块依赖图（#5）画不出来** |
| ③ 框架层 | 依赖不在 import 里时去哪读 | **依赖图是错的** |

---

## 一、第 1 步：先看构建文件，再看源码

**不要一上来就 `find *.java`。** 构建文件同时告诉你四件事：语言、模块边界、外部依赖、入口。

```bash
# 一次扫出全部构建文件，这是整个侦察的起点
find . -maxdepth 4 \( -name "pom.xml" -o -name "build.gradle*" -o -name "settings.gradle*" \
  -o -name "package.json" -o -name "go.mod" -o -name "Cargo.toml" -o -name "*.csproj" \
  -o -name "*.sln" -o -name "pyproject.toml" -o -name "setup.py" -o -name "requirements*.txt" \
  -o -name "composer.json" -o -name "Gemfile" -o -name "CMakeLists.txt" \) \
  -not -path "*/node_modules/*" -not -path "*/vendor/*" -not -path "*/target/*"
```

**构建文件出现在几个不同目录 = 多模块**；**出现不同生态的构建文件 = polyglot**。这两条判定直接决定后面画不画 #8 技术栈全景图、要不要做跨语言连边。

---

## 二、语言与构建生态速查

| 语言 | 源码扩展名 | 构建/清单文件 | 模块边界怎么定 | 外部依赖从哪读 | 入口在哪 |
|---|---|---|---|---|---|
| **Java** | `.java` | `pom.xml`、`build.gradle`、`settings.gradle` | `settings.gradle` 的 `include` / `pom.xml` 的 `<modules>`；单模块时按顶层包 | `<dependency>` / `dependencies {}` | `public static void main`、`@SpringBootApplication` |
| **Kotlin** | `.kt`、`.kts` | 同 Java（Gradle 为主） | 同 Java | 同 Java | `fun main`、`@SpringBootApplication` |
| **Python** | `.py`、`.pyi` | `pyproject.toml`、`setup.py`、`setup.cfg`、`requirements*.txt` | 有 `__init__.py` 的目录 = 包；`pyproject.toml` 的 `[tool.poetry.packages]` / `packages=` | `[project.dependencies]` / `install_requires` / `requirements.txt` | `if __name__ == "__main__"`、`app = FastAPI()`、`manage.py` |
| **JavaScript** | `.js`、`.mjs`、`.cjs`、`.jsx` | `package.json`、`pnpm-workspace.yaml`、`lerna.json`、`turbo.json` | **monorepo 看 `workspaces` / `pnpm-workspace.yaml`**；否则按 `src/` 下顶层目录 | `dependencies` / `devDependencies` / `peerDependencies` | `main` / `bin` / `scripts.start` 字段 |
| **TypeScript** | `.ts`、`.tsx` | 同 JS + `tsconfig.json` | 同 JS；**`tsconfig.json` 的 `references` 是项目引用边界** | 同 JS + `@types/*` | 同 JS |
| **Go** | `.go` | `go.mod`、`go.work` | 一个目录 = 一个 package；`go.work` 的 `use` 列出多模块 | `require` 块 | `package main` 里的 `func main` |
| **C#** | `.cs` | `*.csproj`、`*.sln`、`Directory.Build.props` | 一个 `.csproj` = 一个项目 = 一个模块 | `<PackageReference>`、`<ProjectReference>` | `Program.cs`、`Main`、`WebApplication.CreateBuilder` |
| **Rust** | `.rs` | `Cargo.toml`、`Cargo.lock` | `[workspace].members` 列出 crate；单 crate 看 `src/` 下模块树 | `[dependencies]` | `src/main.rs` 的 `fn main`、`[[bin]]` |
| **PHP** | `.php` | `composer.json` | `autoload.psr-4` 的命名空间 → 目录映射 | `require` 块 | `public/index.php`、框架路由文件 |
| **Ruby** | `.rb` | `Gemfile`、`*.gemspec` | `lib/` 下顶层目录；Rails 看 `app/` 下分层 | `Gemfile` 的 `gem` | `config.ru`、`bin/rails` |

---

## 三、模块边界判定的优先级

模块边界弄错，#5 依赖图和 #2 容器图全错。按这个优先级判，**高优先级的证据压低优先级的**：

1. **构建文件显式声明**（`settings.gradle` 的 `include`、`workspaces`、`go.work` 的 `use`、`.sln` 的项目列表）—— 最强证据，直接用。
2. **独立的可部署单元**（自带 `Dockerfile` / `main` 入口 / 独立端口）—— 即使构建文件没分模块，它也是独立容器。
3. **目录约定**（`src/<模块>/`、`internal/<模块>/`、`apps/<应用>/`、`packages/<包>/`）。
4. **命名空间 / 包名前缀**（`com.example.order.*`、`myapp.payment.*`）。
5. **实在分不清** → **列候选让用户确认，不擅自划**。模块边界是用户比你更清楚的事。

### 三个常见误判

| 误判 | 症状 | 正确做法 |
|---|---|---|
| 把分层目录当模块 | 画出「controller 模块 → service 模块 → dao 模块」 | 这是**分层**（#4），不是模块（#5）。分层图和依赖图别混 |
| 把 monorepo 当单模块 | 20 个 package 画成一个盒子 | 读 `workspaces` / `pnpm-workspace.yaml` |
| 把 vendor 目录当自己的模块 | 依赖图里出现一堆三方库文件 | 排除 `node_modules` `vendor` `target` `dist` `build` `.venv` `__pycache__` |

---

## 四、依赖边的提取（第 ② 层能拿到的部分）

第 ② 层能可靠拿到的只有**静态依赖**。列进事实档案时**必须标边类型**，因为不同边类型在图里的线型不同（见 `mermaid-conventions.md`）。

| 边类型 | 怎么提取 | 确定性 |
|---|---|---|
| **构建依赖** | 构建文件里的模块间引用（`<ProjectReference>`、`implementation project(':order')`、workspace 内部包） | 确定 |
| **import 依赖** | 源码 import / require / use 语句，过滤掉指向外部的 | 确定 |
| **三方依赖** | 构建文件的外部依赖坐标 | 确定 |
| **DI 注入依赖** | **第 ② 层拿不到** | 交给第 ③ 层 |
| **HTTP / MQ / DB 跨语言依赖** | **第 ② 层拿不到** | 交给第 ③ 层 |

各语言的 import 语法：

```
Java/Kotlin   import com.example.order.OrderService;
Python        from myapp.order import service   /   import myapp.order.service
JS/TS         import { x } from './order'      /   require('../order')
Go            import "github.com/me/app/internal/order"
C#            using MyApp.Order;                （也看 <ProjectReference>）
Rust          use crate::order::service;        /   mod order;
PHP           use App\Order\OrderService;
Ruby          require_relative 'order/service'  /   require 'order'
```

**过滤规则**：只保留指向**本仓库内**的 import 作为内部依赖边；指向三方包的归入「外部依赖」，在 #1 上下文图和 #43 供应链图里体现，不进 #5 模块依赖图（否则依赖图会被三方库淹没）。

---

## 五、polyglot 项目的分区

一个仓库里多种语言时，事实档案里要建**语言分区表**：

| 分区 | 语言 | 根目录 | 构建文件 | 角色 |
|---|---|---|---|---|
| web | TypeScript | `web/` | `package.json` | 前端 SPA |
| order | Java | `order/` | `build.gradle` | 订单服务 |
| payment | Java | `payment/` | `build.gradle` | 支付服务 |
| shared | Java | `shared/` | `build.gradle` | 共享库 |
| scripts | Python | `tools/` | `requirements.txt` | 运维脚本 |

这张表直接驱动三件事：

1. **#8 技术栈全景图**恒画（polyglot 触发判据）。
2. **#2 容器图**里每个容器要标语言与技术栈。
3. **跨语言连边**：不同分区之间**没有 import 边**，它们之间的连接必须靠第 ③ 层的三种匹配去找（见 `framework-lenses.md`）。**不做这一步，前后端在架构图上就是两座孤岛。**

### 语言占比要数出来

```bash
# 各语言文件数，用于 #8 技术栈全景图；排除依赖目录
for ext in java kt py ts tsx js go cs rs php rb; do
  n=$(find . -name "*.$ext" -not -path "*/node_modules/*" -not -path "*/vendor/*" \
      -not -path "*/target/*" -not -path "*/.venv/*" | wc -l)
  [ "$n" -gt 0 ] && echo "$ext: $n"
done
```

数字进图之前**必须是这样数出来的**，不能凭目录印象。

---

## 六、大项目的并行测绘

模块数 ≥ 6 或文件数 ≥ 500 时，派并行子代理分模块测绘。**子代理只读不画**，每个回传固定结构的事实片段：

```
模块名 / 根目录 / 语言与构建
组件清单：组件 → 文件路径 → 一句话职责
对外暴露：门面类 / 端点 / 导出函数（含 HTTP 路径、MQ topic、表名——跨语言连边要用）
依赖：内部模块依赖 / 三方依赖 / 外部系统（DB/HTTP/MQ/缓存）
项目类型标记：有无 MQ / 状态机 / 缓存 / 事务 / 定时任务 / 鉴权
关键数字：数值 + 出处命令
```

主上下文负责：**合并 + 消歧 + 建统一命名表**。同一个组件被两个子代理用不同名字报上来时，主上下文定唯一显示名——这是跨图一致性的源头，**不能下放给子代理**。

---

## 七、读多少算够

能回答这四个问题就够了：

1. 一次典型请求经过哪些模块、哪些类、哪些分支？
2. 它依赖哪些外部系统？
3. 失败时怎么走？
4. 这个仓库里有几种语言，它们之间怎么连？

读不完全部代码是正常的。**画不准的部分宁可不画，也不要编**——不画的写进索引第九节的「未画的图」，画不准的边标 `⚠推断`。
