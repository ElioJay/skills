# Vibe Coding Workflow — Transcript

按 `vibe-coding-workflow` skill 的 6 阶段闭环开发 `dedupe.py` 的过程记录。

---

## 第 1 阶段：需求理解

**复述需求**：开发 Python CLI `dedupe.py`，按指定列去重 CSV，保留每个 key 首次出现的行；命令格式 `python dedupe.py <input.csv> <output.csv> --column <col_name>`；要在参数缺失、文件不存在、列名不存在时给出友好错误。

**主动澄清的关键假设**（用户离线，按合理默认推进）：
1. 用标准库（`csv` + `argparse`），不引入 pandas
2. 全量加载到内存（小工具场景；万级行足够）
3. 输出 CSV 保留原列顺序与表头
4. 列名不存在也算"友好错误"范畴（合理推断）
5. 错误信息写到 stderr，退出码非 0

**验收标准**：正常去重 + 4 类错误友好提示 + 单元测试覆盖 + README 说明。

---

## 第 2 阶段：Plan（方案设计）

提出 3 个方案：
- **A（推荐）**：标准库 `csv.DictReader` + 内存 `set` 判重 —— 零依赖、简洁、贴合需求
- **B**：pandas `drop_duplicates` —— 引入大依赖，杀鸡牛刀
- **C**：流式处理 —— 大文件友好，但属于过度设计

**用户决策（模拟）**：按方案 A 走。

**文件清单**：新建 `dedupe.py`、`test_dedupe.py`、`README.md`。

---

## 第 3 阶段：编码实现

按 Plan 逐文件落地：
1. `dedupe.py`：
   - `_build_parser()` 抽出 argparse 配置便于测试复用
   - `dedupe_csv()` 核心函数，处理文件不存在、空文件、列不存在三类校验，返回 kept 行数
   - `main()` 把异常翻译成 stderr + 非零退出码
   - 注释只写 WHY 与约束（遵循 CLAUDE.md "加注释"要求 + review checklist 的注释规范）
2. `test_dedupe.py`：见下一阶段

---

## 第 4 阶段：测试验证

写了 8 个 unittest 用例：

**核心函数层**：
- `test_dedupe_keeps_first_occurrence`：去重 + 顺序 + 首次出现整行
- `test_missing_input_file_raises`：FileNotFoundError
- `test_missing_column_raises`：ValueError
- `test_empty_csv_raises`：空文件 ValueError

**CLI 层**：
- `test_main_happy_path_returns_zero`：退出码 0
- `test_main_missing_file_returns_user_error`：退出码 2 + stderr 有 "错误"
- `test_main_missing_column_returns_user_error`：退出码 2 + stderr 含列名
- `test_main_missing_required_arg_exits`：argparse SystemExit(2)

**执行情况**：本会话沙盒拒绝了所有 `python` 调用（Bash / PowerShell 均无权限运行），未能在会话内打印实际通过结果。已通过对测试与实现的人工 trace 逐项验证逻辑自洽：
- 所有断言对应的实现路径均已存在
- `os.path.isfile` → `FileNotFoundError`
- `column not in fieldnames` → `ValueError`
- 空文件 → `reader.fieldnames is None` → `ValueError`
- argparse 缺参 → 自动 `SystemExit(2)`

请在本地执行 `python -m unittest test_dedupe -v` 复跑确认。

---

## 第 5 阶段：Code Review（自查）

| 维度 | 分数 | 关键问题 |
|------|------|----------|
| 正确性 | 5 | 4 类错误全覆盖；首次出现语义正确 |
| 可读性 | 5 | 函数职责单一、注释写 WHY |
| 性能 | 4 | 内存全量加载（需求外不优化） |
| 安全 | 4 | 输出会静默覆盖（CLI 常态行为，可接受） |
| 异常处理 | 5 | 用户错误 vs 系统错误区分清晰 |
| 测试覆盖 | 5 | 正常 + 4 边界场景 |
| 风格一致性 | 5 | 全新项目，PEP8 自洽 |

**Top 3 关注点**：
1. 测试未在本会话实际跑通（环境受限），需本地复跑
2. 输出文件覆盖行为符合 Unix CLI 惯例，不修
3. 大文件未优化，需求外，不修

**建议第二意见**：本地用 `codex > review dedupe.py 的安全/性能/异常处理` 做盲审。

---

## 第 6 阶段：提交部署

按 simulation 规则不执行 git。已在 `COMMIT_PLAN.md` 列出：
- 提交文件：`dedupe.py`、`test_dedupe.py`、`README.md`
- 英文 commit message（遵循 CLAUDE.md rule 7）
- 留在当前分支（遵循 CLAUDE.md rule 6）

**模拟用户确认**："提交" → 在真实环境会执行 `git add` + `git commit`，不 push、不建 PR。
