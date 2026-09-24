# The Case List

One format for all three modes. It is what the user confirms, and in Spec → Doc it becomes the document's summary table.

## Columns

| Column | Content |
|---|---|
| `#` | `TC-01`, `TC-02` … stable within the list; Spec → Doc keeps the same ids in the document |
| 关联需求 | **only when a requirements document or spec is an input**: the item number (`3.2`), or `METHOD /path` for OpenAPI |
| 维度 | one of 正常 / 边界 / 异常 / 状态 / 组合 / 并发 / 权限 / 数据量 (`test-design.md`) |
| 场景 | the situation, in a few words |
| 输入/前置 | the inputs and the state that matter; leave out what does not |
| 预期 | the observable outcome, including the side effects that must or must not happen |
| 依据 | where the expected result comes from — see below |
| 优先级 | P0 / P1 / P2 — see below |

Title line: `用例清单 · <target>（待确认）`, plus the mode when it is not obvious.

## 依据 — the oracle source

| Value | Meaning |
|---|---|
| `需求 <编号>` | a requirement item, an acceptance criterion, an OpenAPI operation |
| `注释` | a doc comment, Javadoc or docstring on the target |
| `文档` | a README, design doc or API doc in the repo |
| `调用方` | how callers use the result or handle the error |
| `推断` | inferred from naming and context — the user must see it, and may correct it |
| `待确认` | no evidence either way — becomes a question in the confirmation round |
| `实现` | the implementation's current behavior — **Lock mode only** |

When sources disagree the higher one wins: 需求 > 注释 / 文档 > 调用方 / naming > 推断. A disagreement between the intent and the implementation is a ⚠ — never resolved silently.

## 优先级

| Level | Meaning |
|---|---|
| P0 | the core flow; money or data correctness; security |
| P1 | important branches and common errors |
| P2 | minor or rare situations |

## Sections under the table

Only the ones that apply, in this order:

1. **⚠ 疑似缺陷** — per item: the case id, what the intent source says (quoted), what the implementation does (`file:line`), and the ruling to make.
2. **需更新的现有测试** — per test: `file:line` · test name · why it is stale · the planned change.
3. **已有覆盖** — scenario · the existing test that covers it. These are not rewritten.
4. **刻意不测 / 不适用** — dimension · reason. Testability gaps go here too: 不可测 · the suggested seam.
5. **测试入口与最小桩** (Test-first) — the entry point each case calls; per stub: path · signature · body · whether it changes an existing type.
6. **测试基建方案** (no test infrastructure) — framework, placement, the exact build-file change.
7. **文档** (Spec → Doc) — the proposed path, with a flag when a file already exists there; whether to also export `.docx`.
8. **待确认** — the open question behind every `待确认` row.

## The confirmation round

Show the list and its sections in the terminal first. Then collect decisions with the interactive question tool — recommended option first, at most four questions per call, as many calls in a row as needed, nothing written in between.

| Decision | Options, recommended first |
|---|---|
| the list | 确认清单 / 只落地 P0、P1 / 我要增删改（Other 里写明编号） |
| each ⚠ | 按意图写（测试会失败）/ 按实现写 / 删除该用例 |
| stale tests | 按新行为改写 / 保持不动（本次运行会失败） |
| each 待确认 | the concrete readings of the requirement |
| stubs | 按清单建桩 / 不建桩（编译失败也算失败，报告列出待实现签名） |
| infra | 按方案建 / 只写测试不建（报告标未验证） |
| document path | 用建议路径 / 其他（Other） |
| document format | 只要 Markdown / 同时生成 docx |

Several ⚠ of the same shape may be ruled together; say so in the question.

## Example

**用例清单 · PointsService.redeem（待确认）**

| # | 维度 | 场景 | 输入/前置 | 预期 | 依据 | 优先级 |
|---|---|---|---|---|---|---|
| TC-01 | 正常 | 积分充足 | 余额 500，兑换 200 | 返回兑换单号；余额 300；兑换单已保存 | 注释 | P0 |
| TC-02 | 边界 | 刚好用完 | 余额 200，兑换 200 | 兑换成功；余额 0 | 注释 | P0 |
| TC-03 | 异常 | 积分不足 | 余额 199，兑换 200 | 抛 InsufficientPointsException；余额不变；不生成兑换单 | 注释 | P0 |
| TC-04 | 边界 | 兑换数量非法 | 0 / -1 | （建议）抛 IllegalArgumentException | 待确认 | P1 |
| TC-05 ⚠ | 状态 | 冻结账户兑换 | 账户 FROZEN，余额 500 | 拒绝兑换；余额不变 | 需求 2.3 | P1 |
| TC-06 | 异常 | 保存兑换单时数据库报错 | 仓储 save 抛异常 | 异常原样抛出，不被吞掉 | 调用方 | P1 |

**⚠ 疑似缺陷**
- TC-05：需求 2.3 写“冻结账户不能兑换”，实现只校验余额，没有检查账户状态（PointsService.java:37）→ 按意图写（测试会失败）/ 按实现写 / 删除该用例

**刻意不测 / 不适用**
- 并发：两次兑换同时扣减同一余额，要靠数据库行锁保证，单元层验证不了
- 权限：不适用，鉴权在网关层，本方法不做
- 数据量：不适用，没有批量或循环

**待确认**
- TC-04：数量为 0 时是抛异常还是当作无操作？代码里没有校验，注释也没写
