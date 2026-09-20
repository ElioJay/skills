# Skills for Practical Engineering

[![License](https://img.shields.io/github/license/ElioJay/skills)](./LICENSE)
[![Claude Code](https://img.shields.io/badge/Claude_Code-supported-7C3AED)](./.claude/skills)
[![Codex](https://img.shields.io/badge/Codex-supported-111827)](./.codex/skills)

一组用于真实软件工程工作的 Agent Skills：读代码、做审查、推进开发、自动化浏览器，并在发布前检查敏感信息。

这些技能不试图接管整个开发过程。每个技能只解决一个边界清楚的问题，可以单独使用，也可以按任务组合。你仍然掌握范围、技术决策和最终提交。

## 快速安装

需要先安装 Node.js（自带 npm）。推荐使用官方 [`skills`](https://github.com/vercel-labs/skills) CLI，它会识别仓库中的 `SKILL.md`，并将技能安装到所选 Agent 的目录。

### 方式一：使用 npx 安装（推荐）

先查看仓库中可安装的技能：

```bash
npx skills@latest add ElioJay/skills --list
```

交互式选择技能和 Agent：

```bash
npx skills@latest add ElioJay/skills
```

也可以直接指定一个或多个技能，并同时安装给 Claude Code 与 Codex：

```bash
npx skills@latest add ElioJay/skills \
  --skill code-read-deep-project \
  --skill audit-remote-secret-leaks \
  --agent claude-code \
  --agent codex
```

默认安装到当前项目；添加 `-g` 会安装到用户级目录，添加 `-y` 会跳过确认，适合自动化脚本：

```bash
npx skills@latest add ElioJay/skills \
  --skill code-read-deep-project \
  --agent codex \
  -g -y
```

更新已安装的技能：

```bash
npx skills update
```

### 方式二：克隆整个仓库

```bash
git clone https://github.com/ElioJay/skills.git
```

根据使用的 Agent，复制需要的技能目录：

- Claude Code：`.claude/skills/<skill-name>/`
- Codex：`.codex/skills/<skill-name>/`

技能目录应整体复制。`SKILL.md` 是入口，旁边的 `references`、`scripts`、`assets` 和 `evals` 可能是运行所需资源。

### 方式三：手动只取一个技能

```bash
git clone --depth 1 https://github.com/ElioJay/skills.git
```

然后仅复制目标技能在对应宿主目录下的完整子目录。不要只复制 `SKILL.md`。

## 为什么需要这些技能

### 1. 代码读过了，却没有真正建立系统地图

`code-read-deep-*` 家族按方法、文件、模块、项目、横切线索和单次变更六个视角组织阅读结果。它们强调入口、依赖、数据流和影响半径，而不是把源码换一种说法复述一遍。

### 2. 功能做出来了，但过程不可验证

`code-vibe-workflow` 把需求、计划、实现、测试、审查和提交连成可检查的闭环；`design-pattern-advisor` 则先通过 YAGNI 闸门，再判断设计模式是否真的必要。

### 3. Review 只看风格，漏掉真正的风险

`code-review-deep-zh` 从正确性、安全、性能、可靠性、架构、数据完整性、可维护性、一致性、可观测性和文档十个维度并行审查。

### 4. 发布之前，不确定仓库是否夹带隐私

`audit-remote-secret-leaks` 同时检查远程历史和本地待推送内容，区分真实泄露、占位示例和未推送风险，并要求证据脱敏。

### 5. Agent 需要看到真实页面，而不仅是猜 UI

`automation-playwright` 用 Playwright CLI 驱动真实浏览器，适合表单操作、截图、数据提取和 UI 流程排查。

### 6. 功能是做出来了，同时留下一堆没人要的代码

`code-slimming` 只做减法：删死代码、拆掉只有一个实现的接口、内联一次性 wrapper、清掉重述代码的注释，
并单独识别「AI 自作主张加的缓存、重试、配置项」。它先列清单再动手，红线（对外 API、日志埋点、TODO 标记、
框架样板）一律跳过并逐条记录原因；`--audit` 用来回头审计清理本身有没有删过头。

### 7. 线上出了问题，翻日志什么也看不出来

`code-logging` 治的是代码里的 log 语句本身：消息是否自包含、级别用得对不对、关键路径有没有打点、
异常有没有丢堆栈、traceId 在线程池和消息队列里断没断。按风险分档确认——格式问题批量改，
级别变更和新增日志逐项确认，日志泄露隐私只报不改。不碰 logback 配置和采集端。

## Skill 参考

标记说明：`Claude + Codex` 表示仓库同时提供两种宿主版本；`Claude` 表示当前仅提供 Claude Code 版本。

### security

| Skill | 宿主 | 用途 |
|---|---|---|
| [`audit-remote-secret-leaks`](./.claude/skills/audit-remote-secret-leaks/SKILL.md) | Claude + Codex | 审计 Git 历史、工作区、ignored 文件和 stash 中的敏感信息风险。 |

### 自动化

| Skill | 宿主 | 用途 |
|---|---|---|
| [`automation-playwright`](./.claude/skills/automation-playwright/SKILL.md) | Claude + Codex | 通过终端自动化真实浏览器。 |

### 代码阅读

| Skill | 宿主 | 用途 |
|---|---|---|
| [`code-read-deep-function`](./.claude/skills/code-read-deep-function/SKILL.md) | Claude + Codex | 从明确的方法入口追踪调用链与数据流。 |
| [`code-read-deep-file`](./.claude/skills/code-read-deep-file/SKILL.md) | Claude + Codex | 通读单个源文件，输出结构与依赖地图。 |
| [`code-read-deep-module`](./.claude/skills/code-read-deep-module/SKILL.md) | Claude + Codex | 阅读单个模块、包或目录并检查内部依赖。 |
| [`code-read-deep-project`](./.claude/skills/code-read-deep-project/SKILL.md) | Claude + Codex | 建立项目级技术栈、容器和模块依赖全景。 |
| [`code-read-deep-trace`](./.claude/skills/code-read-deep-trace/SKILL.md) | Claude + Codex | 沿业务能力、关注点或字段跨模块追踪。 |
| [`code-read-deep-change`](./.claude/skills/code-read-deep-change/SKILL.md) | Claude + Codex | 解释一次 diff、commit 或 PR 的意图与影响半径。 |

### 开发与审查

| Skill | 宿主 | 用途 |
|---|---|---|
| [`code-annotating`](./.claude/skills/code-annotating/SKILL.md) | Claude + Codex | 为非显而易见的意图、约束和取舍补充注释。 |
| [`code-slimming`](./.claude/skills/code-slimming/SKILL.md) | Claude + Codex | 删除新写代码中的冗余，只做减法与就地内联。 |
| [`code-logging`](./.claude/skills/code-logging/SKILL.md) | Claude + Codex | 规范代码中的日志语句，补齐打点与断掉的 traceId。 |
| [`code-review-deep-zh`](./.claude/skills/code-review-deep-zh/SKILL.md) | Claude + Codex | 执行十维度中文深度代码审查。 |
| [`code-vibe-workflow`](./.claude/skills/code-vibe-workflow/SKILL.md) | Claude + Codex | 推进需求到提交的完整开发闭环。 |
| [`design-pattern-advisor`](./.claude/skills/design-pattern-advisor/SKILL.md) | Claude + Codex | 判断是否需要设计模式，并给出最小实现。 |
| [`codebase-diagrams`](./.claude/skills/codebase-diagrams/SKILL.md) | Claude | 生成项目、模块和方法级 Mermaid 图集。 |

### 写作与扩展

| Skill | 宿主 | 用途 |
|---|---|---|
| [`naturalize-zh`](./.claude/skills/naturalize-zh/SKILL.md) | Claude | 去除中文文本中的机器化表达。 |
| [`skill-creator-guide`](./.claude/skills/skill-creator-guide/SKILL.md) | Claude + Codex | 通过对话生成结构清楚的 Skill 草稿。 |

## 仓库结构

```text
.
├── .claude/
│   ├── skills/          # Claude Code Skills
│   ├── agents/          # 子代理定义
│   ├── commands/        # 命令提示
│   ├── rules/           # 项目规则示例
│   └── output-styles/   # 输出风格
├── .codex/
│   └── skills/          # Codex Skills
├── tests/               # 仓库级检查
└── LICENSE              # Apache License 2.0
```

本地覆盖配置（如 `.claude/settings.local.json`）不应提交。敏感值应通过环境变量或被忽略的本地配置注入。

## 验证

仓库中的 JSON、PowerShell、Python、JavaScript 和 Shell 文件会在发布前做语法检查；Mermaid 图块和关键 Skill 契约也有对应校验。

## 许可证

本仓库采用 [Apache License 2.0](./LICENSE)。子目录自带的第三方 `LICENSE` 或 `NOTICE` 继续适用于对应组件。
