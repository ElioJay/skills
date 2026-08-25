# Rules 目录

## 用途

存放按主题组织的规则文件，Claude 会根据配置自动加载。

## 文件规范

- **格式**：`.md`（Markdown）
- **命名**：`<主题>.md`，如 `testing.md`、`api-design.md`、`code-style.md`
- **编码**：UTF-8

## 文件结构

每个规则文件可包含可选的 YAML frontmatter：

```markdown
---
paths:
  - "src/api/**"       # 可选：限定规则仅在匹配路径的文件上下文中生效
  - "src/routes/**"
---

规则内容...
```

## 加载机制

| 类型 | 加载时机 |
|------|---------|
| 无 `paths` 字段 | 会话开始时自动加载（同 CLAUDE.md） |
| 有 `paths` 字段 | 仅当 Claude 读取匹配路径的文件时加载 |

## 示例

- `testing.md` — 测试相关约定（框架选择、覆盖率要求）
- `api-design.md` — API 设计规范（命名、错误码、版本控制）
- `code-style.md` — 编码风格规则
- `security.md` — 安全相关约束
