# Skills

面向 Claude Code 与 Codex 的可复用开发技能集合，涵盖代码阅读、代码审查、浏览器自动化、安全审计、开发工作流和辅助写作。

## 目录

- `.claude/skills/`：Claude Code 技能。
- `.codex/skills/`：Codex 技能。
- `.claude/agents/`：Claude Code 子代理定义。
- `.claude/commands/`：Claude Code 命令。
- `.claude/rules/`：项目规则示例。
- `.claude/output-styles/`：输出风格示例。

## Skills

### security

| Skill | 说明 |
|-------|------|
| `audit-remote-secret-leaks` | 审计 Git 远程历史与本地待推送内容中的敏感信息泄露风险。 |

### development

| Skill | 说明 |
|-------|------|
| `automation-playwright` | 通过 Playwright CLI 自动化真实浏览器。 |
| `code-annotating` | 为代码补充聚焦于意图、约束和取舍的注释。 |
| `code-read-deep-change` | 阅读一次 diff、commit 或 PR 的变更与影响半径。 |
| `code-read-deep-file` | 通读单个源文件并生成结构与依赖报告。 |
| `code-read-deep-function` | 从单个方法入口梳理调用链和数据流。 |
| `code-read-deep-module` | 阅读单个模块、包或目录的结构与依赖。 |
| `code-read-deep-project` | 阅读整个项目并生成系统与模块架构图。 |
| `code-read-deep-trace` | 跨文件、跨模块追踪业务能力或数据项。 |
| `code-review-deep-zh` | 从十个维度执行中文深度代码审查。 |
| `code-vibe-workflow` | 按需求、计划、编码、测试、审查和提交推进功能开发。 |
| `codebase-diagrams` | 为代码库生成 Mermaid 架构图集（Claude Code）。 |
| `design-pattern-advisor` | 评估设计模式是否必要，并给出最小可行建议。 |
| `naturalize-zh` | 去除中文文本中的机器化表达（Claude Code）。 |
| `skill-creator-guide` | 通过对话引导创建新的技能草稿。 |

部分技能同时提供 `.claude` 与 `.codex` 版本；仅适用于单一宿主的技能只保留对应目录。

## 使用

克隆仓库后，将需要的技能目录复制或链接到对应宿主的技能目录。每个技能的 `SKILL.md` 是入口，配套的 `references`、`scripts`、`assets`、`evals` 等目录应一并保留。

本地配置文件（例如 `local-config.json` 与 `.claude/settings.local.json`）已由 `.gitignore` 排除，不应提交到仓库。

## 许可证

本仓库采用 [Apache License 2.0](LICENSE) 开源。子目录中附带的第三方 `LICENSE` 或 `NOTICE` 文件继续适用于对应组件。
