# 推送策略与安全强推

本文件说明推送形态怎么选、强推什么时候可以接受、以及对应的命令。命令按 Git 通用语法书写，与宿主 shell 无关。

## 1. 先看清要推什么

```bash
git status -sb                          # 当前分支、upstream、领先/落后
git remote -v                           # 远程名与地址
git log --oneline @{upstream}..HEAD     # 这次真正会推上去的提交
git diff --stat @{upstream}..HEAD       # 会推上去的改动规模
```

判断要点：

- `status -sb` 显示 `[ahead N]`：本地领先 N 个提交，常规快进推送。
- 显示 `[behind N]` 或 `[ahead N, behind M]`：**本地与远程分叉**。默认先同步再推，不要强推。
- 没有 upstream（`status -sb` 不显示跟踪信息）：推送新分支是需确认的动作。

### 被 `non-fast-forward` 拒绝时怎么办

这是最常见的推送拒绝：远程分支上有本地没有的提交，Git 拒绝覆盖。**它不是需要绕过的小故障，而是"有东西不该被覆盖"的信号。**

```bash
git fetch origin
git log --oneline --left-right HEAD...origin/<branch>   # 左=本地独有，右=远程独有
```

- 远程那些提交应当保留：`git pull --rebase`（或按仓库约定 merge）后再 `git push`。出现冲突就如实报告冲突文件，让用户决定取舍。
- 确认远程提交应被自己的历史取代（刚做过 rebase 或回滚）：属于强推场景，按下文第 3 节先确认远程 SHA，再用 `--force-with-lease`。
- **任何情况下都不要用 `--force` 绕过这个拒绝。** 那等于静默删除别人的提交。

`--force-with-lease` 自身报 `stale info` 也是同一回事：说明远程 ref 已被更新，lease 正在正常工作。此时 `git fetch` 后重新判断，而不是改用 `--force`。

## 2. 四种推送形态

| 形态 | 何时用 | 命令 | 风险 |
|---|---|---|---|
| 快进推送 | 本地领先、远程未变 | `git push` | 低 |
| 首次推送分支 | 分支尚未存在于远程 | `git push -u origin <branch>` | 中：会占用远程分支名，需确认 |
| 同步后推送 | 远程有新提交 | `git pull --rebase` 后 `git push` | 中：rebase 会改写本地提交哈希 |
| 安全强推 | 已 rebase / 改写消息 / 回滚，且远程仍是自己上次推送的 SHA | `git push --force-with-lease` | 高：需单独授权 |

`git pull --rebase` 与 `git pull --no-rebase` 的选择应遵循仓库既有约定；不确定时先看 `git config pull.rebase` 与最近的历史形态，或直接问用户。

## 3. 强推的红线

- **默认禁止 `--force`**。它会无条件覆盖远程 ref，会静默丢掉别人的提交。
- 允许 `--force-with-lease`：它在远程 ref 与本地记录不一致时拒绝推送，是唯一可接受的强推形态。
- 更严格的做法是指定预期 SHA：

  ```bash
  git push --force-with-lease=<branch>:<expected-sha> origin <branch>
  ```

  推送前用 `git ls-remote origin refs/heads/<branch>` 取当前远程 SHA 填入，避免本地过期的远程跟踪信息骗过 lease 检查。
- 以下情况**一律不推**，先回到用户：共享主干分支（`main` / `master` / `release/*`）、有分支保护规则、远程 SHA 已被他人更新、无法确认远程当前状态。

## 4. 推送 tags 与删除分支

两者都不属于"帮我把改动推上去"的默认范围，必须单独确认：

```bash
git push origin <tag>                    # 单个 tag
git push --tags                          # 全部本地 tag（范围大，慎用）
git push origin --delete <branch>        # 删除远程分支（不可逆）
```

推送 tag 前确认 tag 指向的提交是否已推送、命名是否符合仓库约定。删除远程分支前确认没有其他人基于它工作。

## 5. 推送前的自查清单

- [ ] 目标 remote 与分支就是用户要推的那个
- [ ] `git log @{upstream}..HEAD` 里的每个提交都是有意提交的
- [ ] 工作区未提交的改动已被明确排除在本次推送之外
- [ ] 待推送内容中没有密钥、令牌、`.env`、`local-config.json` 等敏感文件
- [ ] 没有误入的大文件、构建产物或本地配置
- [ ] 若使用强推：远程 ref 当前 SHA 已确认，且是本人上次推送的结果
- [ ] 若推送 tag / 删除分支：范围已获用户明确确认
