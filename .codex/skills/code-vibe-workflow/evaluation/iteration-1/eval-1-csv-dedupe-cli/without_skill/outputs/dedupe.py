#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
dedupe.py - A CLI tool to deduplicate rows in a CSV file by a specified column.

Usage:
    python dedupe.py <input.csv> <output.csv> --column <col_name>

Behavior:
    - Reads the input CSV file.
    - Removes duplicate rows based on the specified column.
    - Keeps the first occurrence of each unique value.
    - Writes the deduplicated rows to the output CSV file.
    - Provides friendly error messages for missing arguments, missing files,
      or missing columns.
"""

import argparse  # For parsing command-line arguments
import csv       # For reading and writing CSV files
import os        # For checking file existence
import sys       # For exiting with a non-zero status code on error


def parse_args():
    """
    Parse command-line arguments.

    Returns:
        argparse.Namespace: Parsed arguments containing input, output, and column.
    """
    # Create the argument parser with a friendly description and usage example
    parser = argparse.ArgumentParser(
        prog="dedupe.py",
        description="Deduplicate rows in a CSV file by a specified column, "
                    "keeping the first occurrence.",
        epilog="Example: python dedupe.py input.csv output.csv --column email",
    )

    # Positional argument: path to the input CSV file
    parser.add_argument(
        "input",
        help="Path to the input CSV file."
    )

    # Positional argument: path to the output CSV file
    parser.add_argument(
        "output",
        help="Path to the output CSV file."
    )

    # Required option: the column name used to detect duplicates
    parser.add_argument(
        "--column",
        required=True,
        help="Name of the column used to identify duplicate rows."
    )

    # argparse will automatically print a friendly error and exit(2) if
    # required arguments are missing.
    return parser.parse_args()


def dedupe_csv(input_path, output_path, column):
    """
    Deduplicate the input CSV by the specified column and write to output.

    Args:
        input_path (str): Path to the input CSV file.
        output_path (str): Path to the output CSV file.
        column (str): Column name used to detect duplicates.

    Raises:
        FileNotFoundError: If the input file does not exist.
        ValueError: If the column is not found in the CSV header.
    """
    # Friendly check for the input file's existence before opening it
    if not os.path.isfile(input_path):
        raise FileNotFoundError(
            f"Input file not found: '{input_path}'. "
            "Please check the path and try again."
        )

    # Track already-seen values of the dedupe column
    seen = set()

    # Open input for reading and output for writing using UTF-8 with newline=''
    # (the recommended way for the csv module to handle line endings correctly).
    with open(input_path, "r", newline="", encoding="utf-8") as infile, \
            open(output_path, "w", newline="", encoding="utf-8") as outfile:

        # Use DictReader so we can address columns by name
        reader = csv.DictReader(infile)

        # Validate that the file actually has a header row
        if reader.fieldnames is None:
            raise ValueError(
                f"Input file '{input_path}' appears to be empty or has no header row."
            )

        # Validate that the requested column exists in the header
        if column not in reader.fieldnames:
            raise ValueError(
                f"Column '{column}' not found in CSV header. "
                f"Available columns: {', '.join(reader.fieldnames)}"
            )

        # Use DictWriter mirroring the input header to preserve column order
        writer = csv.DictWriter(outfile, fieldnames=reader.fieldnames)
        writer.writeheader()

        # Iterate row by row; keep only the first occurrence per dedupe key
        kept = 0
        dropped = 0
        for row in reader:
            key = row.get(column)
            if key in seen:
                # Duplicate value -> skip this row
                dropped += 1
                continue
            seen.add(key)
            writer.writerow(row)
            kept += 1

    # Report a short, friendly summary to stdout
    print(
        f"Done. Kept {kept} unique row(s), dropped {dropped} duplicate(s). "
        f"Output written to: {output_path}"
    )


def main():
    """
    Entry point: parse arguments, run dedupe, and translate exceptions into
    friendly error messages with a non-zero exit code.
    """
    # Parse args first; argparse handles missing-argument errors for us.
    args = parse_args()

    try:
        dedupe_csv(args.input, args.output, args.column)
    except FileNotFoundError as e:
        # Friendly error for missing input file
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(1)
    except ValueError as e:
        # Friendly error for missing column or empty file
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(1)
    except PermissionError as e:
        # Friendly error if we cannot read input or write output
        print(f"Error: Permission denied: {e}", file=sys.stderr)
        sys.exit(1)
    except UnicodeDecodeError as e:
        # Friendly error if the file is not valid UTF-8
        print(
            f"Error: Could not decode '{args.input}' as UTF-8. Details: {e}",
            file=sys.stderr,
        )
        sys.exit(1)
    except OSError as e:
        # Catch-all for other I/O errors (disk full, invalid path, etc.)
        print(f"Error: I/O error: {e}", file=sys.stderr)
        sys.exit(1)


# Standard Python entry-point guard
if __name__ == "__main__":
    main()
