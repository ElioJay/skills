#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""CSV 去重 CLI 工具.

按指定列对 CSV 去重，保留每个去重 key 第一次出现的行。
用法：
    python dedupe.py <input.csv> <output.csv> --column <col_name>

设计取舍（WHY）：
- 用标准库 csv，不引入 pandas：需求体量小，零依赖部署更轻。
- 全量加载 + set 判重：实现简单、保留行顺序、对中小 CSV 足够；
  超大文件场景不在本次需求范围内。
- 错误统一走 stderr + 非零退出码：方便 shell pipeline 判定失败。
"""

import argparse
import csv
import os
import sys
from typing import List, Optional


# 退出码：约定区分用户错误与系统错误，方便脚本上层判断
EXIT_OK = 0
EXIT_USER_ERROR = 2  # 参数错误、文件缺失、列缺失 —— argparse 默认也用 2


def _build_parser() -> argparse.ArgumentParser:
    """构建 argparse 解析器.

    单独抽出便于测试时复用，并保证 --help 行为统一。
    """
    parser = argparse.ArgumentParser(
        prog="dedupe.py",
        description="按指定列对 CSV 文件去重，保留首次出现的行。",
    )
    # 位置参数：input/output 必填，缺失时 argparse 会自动报友好错误
    parser.add_argument("input", help="输入 CSV 文件路径")
    parser.add_argument("output", help="输出 CSV 文件路径")
    parser.add_argument(
        "--column",
        required=True,
        help="作为去重依据的列名（必须存在于输入 CSV 的表头中）",
    )
    return parser


def dedupe_csv(input_path: str, output_path: str, column: str) -> int:
    """执行去重核心逻辑.

    返回写入到输出文件的去重后行数（不含表头）。

    Raises:
        FileNotFoundError: 输入文件不存在时抛出，由 main 转成友好错误。
        ValueError: 输入 CSV 无表头或指定列不存在时抛出。
    """
    # 提前校验输入存在，避免后续 open 抛出原始堆栈给用户
    if not os.path.isfile(input_path):
        raise FileNotFoundError(f"输入文件不存在：{input_path}")

    # newline="" 是 csv 模块官方推荐，避免在 Windows 上出现空行
    with open(input_path, "r", newline="", encoding="utf-8") as fin:
        reader = csv.DictReader(fin)

        # fieldnames 为空说明文件没有表头或为空文件，按用户错误处理
        if not reader.fieldnames:
            raise ValueError("输入 CSV 缺少表头或为空文件")

        # 指定列必须存在，否则没法去重，按用户错误处理
        if column not in reader.fieldnames:
            raise ValueError(
                f"列 '{column}' 不在表头中。可用列：{list(reader.fieldnames)}"
            )

        seen = set()  # 仅存键值字符串，O(1) 判重
        kept_rows: List[dict] = []
        for row in reader:
            # row[column] 取去重 key；None 转为空串以保证可哈希一致性
            key = row.get(column) or ""
            if key in seen:
                continue
            seen.add(key)
            kept_rows.append(row)

        fieldnames = list(reader.fieldnames)

    # 全部写入完成后再打开输出文件，避免输入读取失败时残留半成品
    with open(output_path, "w", newline="", encoding="utf-8") as fout:
        writer = csv.DictWriter(fout, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(kept_rows)

    return len(kept_rows)


def main(argv: Optional[List[str]] = None) -> int:
    """CLI 入口，返回进程退出码（便于测试直接断言）."""
    parser = _build_parser()
    # 参数缺失时 argparse 会自己打印用法并 sys.exit(2)，已经是友好错误
    args = parser.parse_args(argv)

    try:
        kept = dedupe_csv(args.input, args.output, args.column)
    except FileNotFoundError as e:
        # 用户层错误：只打印消息，不带 traceback
        print(f"错误：{e}", file=sys.stderr)
        return EXIT_USER_ERROR
    except ValueError as e:
        print(f"错误：{e}", file=sys.stderr)
        return EXIT_USER_ERROR

    print(f"完成：已写入 {kept} 行去重结果到 {args.output}")
    return EXIT_OK


if __name__ == "__main__":
    # 直接把 main 的返回值作为进程退出码
    sys.exit(main())
