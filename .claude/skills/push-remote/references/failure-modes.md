# 推送失败：现象、原因与恢复

推送被拒时先分类，再按对应路径恢复。**不要用 `--force` 绕过任何一类失败**——被拒通常意味着有东西不该被覆盖。

## 1. `! [rejected] ... (non-fast-forward)`

**现象**：远程分支存在本地没有的提交，Git 拒绝覆盖。

**原因**：别人推了新提交，或自己在别处推过、本地历史已过期。

**恢复**：

```bash
git fetch origin
git log --oneline --left-right HEAD...origin/<branch>   # 看清双方各有哪几个提交
```

- 如果远程那些提交应该保留：`git pull --rebase`（或按仓库约定 merge）后再 `git push`。出现冲突就**如实报告冲突文件**，让用户决定取舍，不要自行挑选一边。
- 如果确认远程提交应该被自己的历史取代（如刚做过 rebase）：这属于强推场景，回到 `push-strategies.md` 第 3 节，先确认远程 SHA，再用 `--force-with-lease`。

## 2. `! [rejected] ... (fetch first)` / `(stale info)`

**现象**：`--force-with-lease` 自己拒绝了推送。

**原因**：远程 ref 与本地记录的预期值不一致，说明期间有人推送过。

**恢复**：**这是 lease 在正常工作，不是故障。** 执行 `git fetch origin` 重新读取远程状态，向用户说明远程已被更新，由用户决定是并入对方提交还是确认后强推。绝不要改用 `--force` 绕过。

## 3. 认证失败

**现象**：`Authentication failed` / `Permission denied (publickey)` / `could not read Username` / `403`。

**原因**：凭据过期、SSH key 未加载、token 无权限、或对目标仓库没有写权限。

**恢复**：

- 先确认远程地址与协议：`git remote -v`。HTTPS 与 SSH 的凭据机制不同，改协议属于配置变更，需用户确认。
- 检查本机凭据是否存在与有效（凭据管理器、`~/.ssh` 下的 key、环境变量中的 token）。
- **不要把 token 写进 remote URL 或任何提交内容**。需要凭据时让用户在自己的凭据存储里配置。
- 无写权限时明确报告"当前账号对该仓库无 push 权限"，不要反复重试。

## 4. Hook 或服务端策略拒绝

**现象**：pre-push hook 失败、`protected branch`、`GH006`、提交信息或签名规则不通过、服务端 `pre-receive` 拒绝。

**原因**：本机 hook 校验未过、分支受保护、提交未按规范签名。

**恢复**：

- 读完整错误输出，按提示修正内容后**重新提交**，不要用 `--no-verify` 跳过 hook，除非用户明确要求且知道后果。
- 受保护分支：走常规流程（新分支 + PR），不要试图强推主干。
- 签名要求：按仓库说明配置签名后重新提交；未配置时向用户报告缺什么。

## 5. 推送"成功"但远程没变

**现象**：命令退出码为 0，但 `git log origin/<branch>` 仍是旧提交。

**原因**：推到了别的 remote 或别的分支名、本地与远程分支名不一致、或 remote 配置指向了镜像而非预期仓库。

**恢复**：

```bash
git remote -v
git ls-remote origin refs/heads/<branch>       # 直接看远程真实 SHA
git rev-parse HEAD                             # 本地 SHA
```

三者对照后向用户说明实际推到了哪里。**"以为推上去了"是本类问题最危险的形态**，因此推送后的验证是必做步骤，不能只看退出码。

## 6. 网络中断或推送中途失败

**现象**：`RPC failed` / `early EOF` / 连接超时 / 大体积推送中断。

**恢复**：

- 重新执行同一条 `git push`。Git 的推送是原子的：中途失败不会留下半成品 ref，重试是安全的。
- 若因体积过大反复失败，先确认是否误入了大文件或构建产物；调整传输参数属于环境变更，需用户确认。
