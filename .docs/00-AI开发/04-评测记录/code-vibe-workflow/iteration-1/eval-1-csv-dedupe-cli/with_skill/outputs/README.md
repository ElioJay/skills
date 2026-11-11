# dedupe.py

按指定列对 CSV 文件去重的 Python CLI 小工具。保留每个去重 key 第一次出现的行，输出到新 CSV 文件。

## 特性

- 零第三方依赖（仅使用 Python 标准库 `csv` + `argparse`）
- 保留原列顺序与原表头
- 保留**每个 key 首次出现**的整行
- 友好错误处理：参数缺失、文件不存在、列名不存在均给出清晰提示，并以非零退出码退出

## 环境要求

- Python 3.7+

## 用法

```bash
python dedupe.py <input.csv> <output.csv> --column <col_name>
```

### 示例

输入 `users.csv`：

```csv
id,name,age
1,alice,20
2,bob,30
1,alice-dup,99
3,carol,40
```

命令：

```bash
python dedupe.py users.csv users_unique.csv --column id
```

输出 `users_unique.csv`（重复的 id=1 行被丢弃，保留首次出现）：

```csv
id,name,age
1,alice,20
2,bob,30
3,carol,40
```

## 错误处理

| 场景 | 行为 |
|------|------|
| 缺少位置参数或 `--column` | argparse 打印用法并以退出码 2 退出 |
| 输入文件不存在 | stderr 输出 `错误：输入文件不存在：...`，退出码 2 |
| 指定列不在表头 | stderr 输出 `错误：列 'xxx' 不在表头中。可用列：[...]`，退出码 2 |
| 输入 CSV 为空 / 无表头 | stderr 输出 `错误：输入 CSV 缺少表头或为空文件`，退出码 2 |

## 运行测试

```bash
python -m unittest test_dedupe -v
```

## 文件结构

```
dedupe.py        # CLI 主程序
test_dedupe.py   # 单元测试
README.md        # 本文件
```
