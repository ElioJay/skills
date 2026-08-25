# `.claude` 配置目录

该目录提供 Claude Code 的可复用配置与公共技能。

## 结构

- `skills/`：技能入口及配套资源。
- `agents/`：专用子代理定义。
- `commands/`：可调用命令。
- `rules/`：主题规则。
- `output-styles/`：输出风格。
- `hooks/`：本地自动化钩子。
- `settings.json`：项目级设置示例。

## 公共技能

公共技能清单见仓库根 [README](../README.md)。技能目录应整体复制，避免遗漏相对引用的脚本、参考资料、资产或评估夹具。

个人覆盖配置 `.claude/settings.local.json` 不应提交。敏感值应通过环境变量或被忽略的本地配置注入。
