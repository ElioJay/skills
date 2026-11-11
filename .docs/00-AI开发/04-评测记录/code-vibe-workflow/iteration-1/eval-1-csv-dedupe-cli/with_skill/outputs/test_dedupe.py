# -*- coding: utf-8 -*-
"""dedupe.py 的单元测试.

覆盖：
- 正常去重 + 保留首次出现
- 输入文件不存在 -> 友好错误，非零退出码
- 列名不存在 -> 友好错误，非零退出码
- 缺少必填参数 --column -> argparse 报错并退出
- 空 CSV / 无表头 -> 友好错误
- 输出文件内容正确（行顺序、列顺序）
"""

import csv
import io
import os
import tempfile
import unittest
from contextlib import redirect_stderr, redirect_stdout

import dedupe


def _write_csv(path: str, rows: list, fieldnames: list) -> None:
    """测试辅助：把 list[dict] 写到指定 CSV 路径."""
    with open(path, "w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(rows)


def _read_csv(path: str) -> list:
    """测试辅助：读出 CSV 为 list[dict]."""
    with open(path, "r", newline="", encoding="utf-8") as f:
        return list(csv.DictReader(f))


class DedupeCsvCoreTests(unittest.TestCase):
    """直接测试 dedupe_csv 核心函数."""

    def setUp(self):
        # 每个用例独立临时目录，避免相互污染
        self.tmpdir = tempfile.mkdtemp()
        self.input_path = os.path.join(self.tmpdir, "in.csv")
        self.output_path = os.path.join(self.tmpdir, "out.csv")

    def test_dedupe_keeps_first_occurrence(self):
        """去重后应保留每个 key 第一次出现的整行."""
        _write_csv(
            self.input_path,
            rows=[
                {"id": "1", "name": "alice", "age": "20"},
                {"id": "2", "name": "bob", "age": "30"},
                {"id": "1", "name": "alice-dup", "age": "99"},  # 重复 id=1
                {"id": "3", "name": "carol", "age": "40"},
            ],
            fieldnames=["id", "name", "age"],
        )

        kept = dedupe.dedupe_csv(self.input_path, self.output_path, column="id")

        self.assertEqual(kept, 3)
        result = _read_csv(self.output_path)
        # 顺序必须按首次出现：1, 2, 3
        self.assertEqual([r["id"] for r in result], ["1", "2", "3"])
        # 重复行的"非 key 列"应来自首次出现的那一行（alice，不是 alice-dup）
        self.assertEqual(result[0]["name"], "alice")

    def test_missing_input_file_raises(self):
        """输入文件不存在应抛 FileNotFoundError，由 main 层翻译成友好错误."""
        with self.assertRaises(FileNotFoundError):
            dedupe.dedupe_csv(
                os.path.join(self.tmpdir, "nope.csv"),
                self.output_path,
                column="id",
            )

    def test_missing_column_raises(self):
        """指定列不在表头中应抛 ValueError."""
        _write_csv(
            self.input_path,
            rows=[{"id": "1", "name": "a"}],
            fieldnames=["id", "name"],
        )
        with self.assertRaises(ValueError):
            dedupe.dedupe_csv(self.input_path, self.output_path, column="email")

    def test_empty_csv_raises(self):
        """完全空文件应抛 ValueError（无表头）."""
        # 写一个真正的空文件
        open(self.input_path, "w", encoding="utf-8").close()
        with self.assertRaises(ValueError):
            dedupe.dedupe_csv(self.input_path, self.output_path, column="id")


class DedupeCliTests(unittest.TestCase):
    """测试 main() CLI 入口的退出码与错误输出."""

    def setUp(self):
        self.tmpdir = tempfile.mkdtemp()
        self.input_path = os.path.join(self.tmpdir, "in.csv")
        self.output_path = os.path.join(self.tmpdir, "out.csv")

    def test_main_happy_path_returns_zero(self):
        """正常调用应返回 0 退出码并生成输出文件."""
        _write_csv(
            self.input_path,
            rows=[
                {"id": "1", "v": "a"},
                {"id": "1", "v": "b"},
                {"id": "2", "v": "c"},
            ],
            fieldnames=["id", "v"],
        )
        # 捕获 stdout 避免污染测试输出
        with redirect_stdout(io.StringIO()):
            code = dedupe.main(
                [self.input_path, self.output_path, "--column", "id"]
            )
        self.assertEqual(code, 0)
        self.assertEqual(len(_read_csv(self.output_path)), 2)

    def test_main_missing_file_returns_user_error(self):
        """文件不存在时返回 EXIT_USER_ERROR 且 stderr 有友好消息."""
        err = io.StringIO()
        with redirect_stderr(err):
            code = dedupe.main(
                [
                    os.path.join(self.tmpdir, "no.csv"),
                    self.output_path,
                    "--column",
                    "id",
                ]
            )
        self.assertEqual(code, dedupe.EXIT_USER_ERROR)
        self.assertIn("错误", err.getvalue())

    def test_main_missing_column_returns_user_error(self):
        """列不存在时返回 EXIT_USER_ERROR 且消息包含列名提示."""
        _write_csv(
            self.input_path,
            rows=[{"id": "1"}],
            fieldnames=["id"],
        )
        err = io.StringIO()
        with redirect_stderr(err):
            code = dedupe.main(
                [self.input_path, self.output_path, "--column", "nope"]
            )
        self.assertEqual(code, dedupe.EXIT_USER_ERROR)
        self.assertIn("nope", err.getvalue())

    def test_main_missing_required_arg_exits(self):
        """没传 --column argparse 应自己 sys.exit(2)."""
        _write_csv(
            self.input_path,
            rows=[{"id": "1"}],
            fieldnames=["id"],
        )
        # argparse 错误会直接 SystemExit，捕获之
        with self.assertRaises(SystemExit) as ctx:
            with redirect_stderr(io.StringIO()):
                dedupe.main([self.input_path, self.output_path])
        # argparse 用 code=2 表示用法错误
        self.assertEqual(ctx.exception.code, 2)


if __name__ == "__main__":
    unittest.main()
