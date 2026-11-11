#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
test_dedupe.py - Basic tests for dedupe.py.

Run with:
    python -m pytest test_dedupe.py -v
or simply:
    python test_dedupe.py
"""

import csv          # For building/reading CSV fixtures
import os           # For path operations
import subprocess   # For invoking dedupe.py as a CLI subprocess
import sys          # To use the same Python interpreter
import tempfile     # For isolated temporary directories
import unittest     # Standard library test framework


# Absolute path to the dedupe.py script under test (same folder as this file)
SCRIPT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "dedupe.py")


def run_cli(*args):
    """
    Helper: run `python dedupe.py <args...>` and return the CompletedProcess.
    """
    return subprocess.run(
        [sys.executable, SCRIPT, *args],
        capture_output=True,
        text=True,
    )


def write_csv(path, rows, fieldnames):
    """
    Helper: write `rows` (list of dicts) to `path` with the given `fieldnames`.
    """
    with open(path, "w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(rows)


def read_csv(path):
    """
    Helper: read a CSV file and return (fieldnames, list_of_row_dicts).
    """
    with open(path, "r", newline="", encoding="utf-8") as f:
        reader = csv.DictReader(f)
        return reader.fieldnames, list(reader)


class DedupeCliTests(unittest.TestCase):
    """End-to-end tests that invoke dedupe.py as a real CLI."""

    def setUp(self):
        # Create a fresh temp directory for each test for isolation
        self.tmp = tempfile.mkdtemp()
        self.input_path = os.path.join(self.tmp, "in.csv")
        self.output_path = os.path.join(self.tmp, "out.csv")

    def test_keeps_first_occurrence(self):
        """Duplicate rows by the chosen column should drop later occurrences."""
        write_csv(
            self.input_path,
            rows=[
                {"id": "1", "name": "Alice"},
                {"id": "2", "name": "Bob"},
                {"id": "1", "name": "Alice-Duplicate"},  # should be dropped
                {"id": "3", "name": "Carol"},
                {"id": "2", "name": "Bob-Duplicate"},    # should be dropped
            ],
            fieldnames=["id", "name"],
        )

        result = run_cli(self.input_path, self.output_path, "--column", "id")
        self.assertEqual(result.returncode, 0, msg=result.stderr)

        fieldnames, rows = read_csv(self.output_path)
        # Column order should be preserved
        self.assertEqual(fieldnames, ["id", "name"])
        # Only first occurrences should remain
        self.assertEqual(
            rows,
            [
                {"id": "1", "name": "Alice"},
                {"id": "2", "name": "Bob"},
                {"id": "3", "name": "Carol"},
            ],
        )

    def test_missing_input_file(self):
        """A missing input file should produce a friendly error and exit code 1."""
        missing = os.path.join(self.tmp, "does_not_exist.csv")
        result = run_cli(missing, self.output_path, "--column", "id")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("not found", result.stderr.lower())

    def test_missing_column_argument(self):
        """Missing --column should be caught by argparse with a non-zero exit."""
        write_csv(
            self.input_path,
            rows=[{"id": "1", "name": "Alice"}],
            fieldnames=["id", "name"],
        )
        # Call without --column at all
        result = run_cli(self.input_path, self.output_path)
        self.assertNotEqual(result.returncode, 0)
        # argparse writes its usage/error to stderr
        self.assertIn("--column", result.stderr)

    def test_missing_positional_arguments(self):
        """Missing positional args should be caught by argparse."""
        result = run_cli()  # no arguments at all
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("usage", result.stderr.lower())

    def test_unknown_column(self):
        """A column not present in the header should produce a friendly error."""
        write_csv(
            self.input_path,
            rows=[{"id": "1", "name": "Alice"}],
            fieldnames=["id", "name"],
        )
        result = run_cli(self.input_path, self.output_path, "--column", "email")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("not found", result.stderr.lower())

    def test_empty_file(self):
        """An empty input file should produce a friendly error."""
        # Create a completely empty file
        open(self.input_path, "w", encoding="utf-8").close()
        result = run_cli(self.input_path, self.output_path, "--column", "id")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("empty", result.stderr.lower())


if __name__ == "__main__":
    unittest.main()
