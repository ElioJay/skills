# Output Styles 目录

## 用途

自定义 Claude 的输出风格，改变回复的格式、语气和结构。

## 文件规范

- **格式**：`.md`（Markdown）
- **命名**：`<style-name>.md`，如 `concise.md`、`teaching.md`
- **编码**：UTF-8

## 文件结构

```markdown
---
# keep-coding-instructions: true   # 可选：保留默认的编程任务指令
---

输出风格指令...
```

## 配置方式

在 `settings.json` 中指定当前使用的风格：

```json
{
  "outputStyle": "concise"
}
```

或通过 `/config` 命令切换。

## 优先级

项目级风格 > 个人级风格（`~/.claude/output-styles/`）

## 内置风格

| 风格 | 说明 |
|------|------|
| `Explanatory` | 详细解释型，适合学习理解 |
| `Learning` | 教学型，引导式回答 |

## 示例

- `concise.md` — 简洁模式，最少文字完成任务
- `teaching.md` — 教学模式，解释每一步的原因
- `formal.md` — 正式模式，适合生成文档
