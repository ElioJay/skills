---
paths:
  - "skills/**"
---

# Skills 编码风格规则

仅在编辑 `skills/**` 下的文件时生效。

- **脚本语言**：统一使用 PowerShell（`.ps1`），不要新增 `.sh`（本仓库为 Windows 环境）。
- **注释**：脚本头部用注释块说明「用途 / 输入 / 退出码或返回值约定」；关键分支处加行内注释。
- **SKILL.md frontmatter**：必须含 `name`（kebab-case）与 `description`；`description` 要写清"何时用 / 何时不用"，以提高触发准确率。
- **敏感配置**：不要把密钥写进脚本或 `SKILL.md`；走 `local-config.json`（已 gitignore），并提供 `local-config.template.json` 模板。
- **最小改动**：修改现有 skill 时只动必要部分，保持与该 skill 既有风格一致。
