# 敏感信息泄露审计报告模板

按以下结构输出。报告可以中文撰写，但保留英文锚点标题，便于自动化检查和跨团队引用。

# Git 敏感信息泄露审计报告

## Audit summary

- **总体风险等级**：High / Medium / Low / None
- **是否发现已推送远程泄露**：是 / 否
- **是否发现未推送本地风险**：是 / 否
- **最高风险类型**：例如 Private key、API Key、Password、PII、Internal address
- **建议优先动作**：例如立即轮换凭据、清理本地待推送内容、改写历史前先备份

## Scope and method

- **仓库根目录**：
- **远程仓库**：
- **审计远程引用**：
- **Remote tag scope**：纳入 / 未纳入；是否能确认 tag 来自远程：
- **提交范围**：
- **工作区范围**：staged / unstaged / untracked / ignored / stash / local-only commits
- **Git LFS 覆盖**：已扫描 / 未扫描 / 不适用；限制说明：
- **Submodule 覆盖**：已扫描 / 未扫描 / 不适用；限制说明：
- **远程引用刷新**：成功 / 失败 / 未执行
- **扫描工具**：
- **手工检查命令**：
- **限制说明**：

## Sanitized evidence policy

- 报告不展示完整 secret、password、token、private key、cookie 或 PII。
- 扫描器原始输出如果包含完整敏感值，只保留 sanitized scanner output。
- 不主动验证真实凭据是否有效，除非用户明确要求并确认外部调用风险。

## Remote history findings

| ID | 风险 | 类型 | 置信度 | 远程引用 / tag | 首次提交 | 最近提交 | 文件位置 | 脱敏证据 | 建议动作 |
|----|------|------|--------|----------------|----------|----------|----------|----------|----------|
| RH-001 | High | API Key | High | origin/main, v1.0.0 | `<sha>` | `<sha>` | `path/file:line` | `ghp_****(len=40)` | 立即撤销并轮换 |

如果没有发现：

> 未在本次审计范围内发现已推送远程历史中的敏感信息命中。此结论受限于扫描规则、远程引用新鲜度和可访问范围。

## Unpushed content statistics

| 来源 | 文件数 | 命中数 | High | Medium | Low | 说明 |
|------|--------|--------|------|--------|-----|------|
| staged | 0 | 0 | 0 | 0 | 0 | 已暂存差异 |
| unstaged | 0 | 0 | 0 | 0 | 0 | 未暂存差异 |
| untracked | 0 | 0 | 0 | 0 | 0 | 未跟踪文件 |
| ignored | 0 | 0 | 0 | 0 | 0 | ignored 本地文件 |
| stash | 0 | 0 | 0 | 0 | 0 | stash patch |
| local-only commits | 0 | 0 | 0 | 0 | 0 | 本地领先远程提交 |

## Local stash and ignored files

- **stash 数量**：
- **已检查 stash**：
- **ignored 文件数量**：
- **ignored 高风险路径**：
- **限制说明**：

### Unpushed findings

| ID | 来源 | 风险 | 类型 | 文件位置 | 脱敏证据 | 推送风险 | 建议动作 |
|----|------|------|------|----------|----------|----------|----------|
| UP-001 | staged | High | Private key | `path/file:line` | `BEGIN OPENSSH PRIVATE KEY` | 下一次提交/推送可能泄露 | 从暂存区移除并轮换 |

## Impact assessment

- **暴露面**：
- **可能影响的系统**：
- **是否需要通知协作者或安全团队**：
- **是否需要平台缓存清理**：

## General remediation

### 已推送远程

1. 撤销或轮换所有真实凭据。
2. 删除当前代码中的敏感值，改用 secret manager、环境变量或安全配置注入。
3. 需要清理历史时，先备份并确认范围，再使用 `git filter-repo` 或 BFG。
4. 清理后使用 `git push --force-with-lease`，并通知协作者处理本地旧历史。
5. 检查 PR diff、fork、release、artifact、CI 日志和远程平台缓存。

### 未推送本地

1. 从 staged、unstaged、untracked 内容中移除敏感值。
2. 如果命中来自本地提交，使用 amend/rebase/reset 前先确认不会丢失用户工作。
3. 更新 `.gitignore` 和示例配置文件。
4. 推送前重新扫描。

### 预防

1. 增加 pre-commit secret scanning。
2. 在 CI 中加入 secret scanning。
3. 使用最小权限和短期凭据。
4. 建立团队敏感配置规范。

## Raw command log

只记录命令、范围和退出结果，不记录完整敏感值。
