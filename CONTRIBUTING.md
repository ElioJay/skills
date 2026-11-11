# 贡献指南：新增与修改技能

本仓库的技能库按 `.docs/软件研发生命周期.md` 的能力缺口建设，不是技能堆积场。**新增一个技能前，先说明它填的是哪个阶段的哪个缺口**；补不出来的，说明它还不该进来。

## 一、仓库结构

```text
skills/
├── registry/skills.json     技能登记表（权威来源：谁存在、落在哪个阶段、成熟度、eval 与测试在哪）
└── skills/<name>/           全部技能的单一真源，Claude Code 与 Codex 共用
.claude/skills/              空目录，只留 .gitkeep，不放技能
.codex/skills/               空目录，只留 .gitkeep，不放技能
scripts/                     校验脚本
tests/                       技能契约测试
```

### 一份技能，两个宿主

- 所有技能只维护在 `skills/skills/<name>/`，没有镜像，也不需要同步。`.claude/skills` 与 `.codex/skills` 只保留空目录，往里放技能会被 `check-skills-repo.ps1` 拦下。
- 同一份 SKILL.md 同时给 Claude Code 和 Codex 用，宿主差异写进正文：
  - 提问工具写成「Claude Code 用 AskUserQuestion，Codex 用 request_user_input」。
  - 手动调用写成「/name（Claude Code）或 $name（Codex）」。不要写 `$ARGUMENTS`：Codex 不替换它；正文里没有 `$ARGUMENTS` 时，Claude Code 会把参数附在末尾的 `ARGUMENTS:` 之后。
  - 仅手动调用的技能两处都要设：frontmatter 的 `disable-model-invocation: true`（Claude Code）和 `agents/openai.yaml` 的 `policy.allow_implicit_invocation: false`（Codex）。校验脚本会检查两处是否一致。
  - 脚本要读宿主自己的数据时，在脚本里按宿主分支，参考 chat-sync 的 `-SyncHost`。
- 本机使用：用 `npx skills add -g` 从 GitHub 装到用户目录，命令见 README。

## 二、新增技能：六件套齐备才算完成

在 `skills/skills/<name>/` 下必须同时具备：

| 件 | 路径 | 要求 |
|---|---|---|
| 1. 入口 | `SKILL.md` | frontmatter 含 `name`（kebab-case，与目录名一致）与 `description`，仅手动调用的技能另加 `argument-hint`、`disable-model-invocation`；正文写清流程、交付物、与相邻技能的边界 |
| 2. 参考 | `references/*.md` | 领域细节：协议差异、语言差异、命令片段、判定标准。SKILL.md 超过约 120 行就该往外拆 |
| 3. 资产 | `assets/*` | 输出模板、清单、报告骨架。有固定交付格式的技能必须有 |
| 4. 质量用例 | `evals/evals.json` | 至少 3 条，每条含 prompt 与 expected_output，覆盖正常、边界、信息不足三类 |
| 5. 触发用例 | `evals/trigger-eval.json` | `should_trigger` 与 `should_not_trigger` 各至少 5 条，负例要写清该路由到哪个技能 |
| 6. 契约测试 | `tests/check-<name>-skill.ps1` | 断言 frontmatter、支撑文件、关键安全约束、登记一致性 |

外加两项登记：

- `skills/registry/skills.json`：在 `skills` 数组加条目（`name`、`summary`、`lifecycle`、`maturity`、`evals`，需要时 `tests`、`notes`）。
- `README.md`：加入对应分类表格，并给出 SKILL.md 链接。

> 如果某件确实不适用（例如纯对话型技能没有 assets），在登记表的 `notes` 里写明理由，不要静默省略。

## 三、description 的写法

`description` 是唯一的路由信号，也是本仓库最容易退化的字段。硬性要求：

- **长度 40–1200 字符**，由 `scripts/check-skills-repo.ps1` 校验。
- **必须写清何时用、何时不用**。不适用边界用 `not for` / `不要用于` / `Do not use for` 起头，并**点名该改用哪个技能**——只写"不适用"而不给替代，用户还是会被卡住。
- 触发词要具体。把用户真实会说的说法（中英混合、口语、报错原文）写进去，不要只写抽象名词。
- 改 description 后，同步更新登记表的 `summary`：这一项由 PR 评审负责，脚本不做字面判等（跨语言与不同粒度会导致误报）。

## 四、语言与脚本文体

- 技能正文与文档用中文；skill `name`、文件名、命令、代码标识符用英文。
- 脚本统一 PowerShell（`.ps1`），仓库不使用 `.sh`。脚本头部写清用途、输入、退出码约定。
- 不在任何文件里写密钥、令牌、私有 URL。敏感值走环境变量或被 gitignore 的本机配置。

## 五、提交前必跑

```powershell
# 全仓校验：frontmatter 契约、手动调用两宿主一致、宿主目录为空、登记表覆盖、生命周期锚点、技能引用、脚本与 JSON 语法
pwsh -NoProfile -File scripts/check-skills-repo.ps1

# 你新增技能的契约测试
pwsh -NoProfile -File tests/check-<name>-skill.ps1
```

`check-skills-repo.ps1` 以非零码退出即视为不通过，必须先修好再提交。

## 六、评审门

PR 评审按以下顺序过：

1. **缺口成立**：这个技能填的是 `.docs` 里哪个阶段的哪个缺口？说不出来的直接退回。
2. **边界清楚**：与相邻技能的边界是否写进了 description，且互不重叠。
3. **六件套齐备**：缺项要么补齐，要么在 `notes` 里说明不适用理由。
4. **不夸大能力**：技能里不得声称未运行的检查已通过、不得虚构消费者或验证结果。
5. **只有一份正文**：改动只落 `skills/skills/<name>/`；宿主差异写进同一份正文，不另开第二份。

## 七、修改已有技能

- 只改必要部分，保持该技能既有风格。
- 改 SKILL.md 后重跑对应契约测试与 `check-skills-repo.ps1`。
- 改 `description` 属于路由行为变更：同步更新 `trigger-eval.json`，并跑一次触发用例记录结果。
- 技能升级或降级（stub / beta / stable）时更新登记表的 `maturity`。

## 八、评测记录

评测结果归档到 `.docs/00-AI开发/04-评测记录`，命名 `<对象>-评测集.md` 与 `YYYYMMDD-<对象>-评测结果.md`，至少记录：用例集、实际触发情况、产出质量结论、与上一轮的对比。只写"效果不错"不算记录。
