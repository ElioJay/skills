# Commands 目录

## 用途

存放单文件命令提示，通过 `/command-name` 在会话中调用。

## 文件规范

- **格式**：`.md`（Markdown）
- **命名**：`<command-name>.md`，文件名即为调用名称
- **编码**：UTF-8

## 文件结构

```markdown
---
description: "命令的简要描述，显示在 /help 列表中"
# allowed-tools: "Read,Glob,Grep"    # 可选：限制可用工具
# context: fork                       # 可选：在子代理中运行
---

命令提示内容...

可用变量：
- $ARGUMENTS — 用户传入的全部参数
- $0, $1, $2 — 按空格分割的参数
```

## 与 Skills 的区别

| 特性 | Commands | Skills |
|------|----------|--------|
| 文件结构 | 单个 `.md` 文件 | 目录（含 SKILL.md + 支持文件） |
| 适用场景 | 简单提示 | 复杂流程，需引用脚本/参考文档 |
| 优先级 | 同名 skill 存在时，skill 优先 | 高于 command |

## 示例

- `summarize.md` — 总结当前文件或目录
- `review.md` — 快速代码审查
- `translate.md` — 翻译选中内容
