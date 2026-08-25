# Agents 目录

## 用途

定义专用子代理，每个子代理拥有独立的上下文窗口、工具权限和提示。适用于并行工作、隔离任务或专门审查。

## 文件规范

- **格式**：`.md`（Markdown）
- **命名**：`<agent-name>.md`，文件名即为代理名称
- **编码**：UTF-8

## 文件结构

```markdown
---
description: "描述 Claude 何时应委派任务给此代理"
# tools: "Read,Glob,Grep,WebSearch"   # 可选：限制可用工具（逗号分隔）
# memory: project                      # 可选：启用持久记忆（project / local / user）
---

代理的系统提示和行为指令...
```

## memory 选项

| 值 | 记忆存储位置 | 适用场景 |
|----|-------------|---------|
| `project` | `.claude/agent-memory/<name>/` | 项目级共享知识 |
| `local` | 本地（不提交） | 个人偏好 |
| `user` | `~/.claude/agent-memory/<name>/` | 跨项目个人知识 |

## 示例

- `reviewer.md` — 代码审查专用代理
- `researcher.md` — 技术调研代理
- `documenter.md` — 文档生成代理
