# 项目说明（本仓库特有约定）

> 通用编码与协作规则见全局 `~/.claude/CLAUDE.md`，此处不重复，仅记录本仓库特有内容。

## 仓库定位

个人 Claude Code 配置与 skills 集合。`.claude/` 即一套可复用的 Claude Code 工作区模板，
包含子代理、斜杠命令、规则、输出风格、hooks 与 skills。

## 目录速查

| 目录 | 用途 | 详细规范 |
|------|------|---------|
| `agents/` | 专用子代理（独立上下文/工具/提示） | @agents/README.md |
| `commands/` | 单文件斜杠命令 `/name` | @commands/README.md |
| `rules/` | 按主题/路径作用域的规则 | @rules/README.md |
| `output-styles/` | 自定义输出风格 | @output-styles/README.md |
| `hooks/` | hooks 调用的 PowerShell 脚本 | — |
| `skills/` | 复杂能力（SKILL.md + 支持文件） | — |
| `settings.json` | 权限 / hooks / env（提交） | — |
| `settings.local.json` | 个人覆盖（已 gitignore，不提交） | — |
| `.mcp.json` | 项目级 MCP 服务器定义 | — |

## skill 开发约定

一个 skill 是一个目录，结构如下：

- `SKILL.md`：必需。YAML frontmatter 含 `name`（kebab-case）、`description`（触发描述，写清何时用/何时不用）
- `references/`：参考文档，按需加载
- `scripts/`：可执行脚本（本仓库统一用 PowerShell `.ps1`）
- `evals/`：触发与质量评估（`evals.json`、`trigger-eval.json`）
- `assets/`：模板、图片等静态资源

## 环境约定

- 平台：Windows 11 + PowerShell（`pwsh`）。所有脚本写成 `.ps1`，不用 `.sh`。
- 本地敏感配置走 `local-config.json`（已被根 `.gitignore` 忽略），并提供 `local-config.template.json` 作为模板提交。

## "测试"含义

本仓库无 build / 编译步骤。这里的"测试"主要指 **skill 触发评估**：
- `evals/trigger-eval.json` —— 验证 description 能否在目标语句下被正确触发
- `evals/evals.json` —— 验证 skill 输出质量

新增/修改 skill 后，核对其 `evals/` 是否仍然覆盖。
