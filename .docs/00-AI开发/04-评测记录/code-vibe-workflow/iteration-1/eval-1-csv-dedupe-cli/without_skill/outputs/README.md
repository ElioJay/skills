# dedupe.py

A tiny Python CLI tool that removes duplicate rows from a CSV file based on a
specified column, keeping the first occurrence of each unique value.

## Requirements

- Python 3.7+ (uses only the standard library: `argparse`, `csv`, `os`, `sys`)

## Usage

```bash
python dedupe.py <input.csv> <output.csv> --column <col_name>
```

### Example

Given `input.csv`:

```csv
id,name
1,Alice
2,Bob
1,Alice-Duplicate
3,Carol
```

Run:

```bash
python dedupe.py input.csv output.csv --column id
```

You get `output.csv`:

```csv
id,name
1,Alice
2,Bob
3,Carol
```

## Error handling

The tool prints a friendly message and exits with a non-zero status when:

- Required arguments are missing (handled by `argparse`).
- The input file does not exist.
- The requested column is not present in the CSV header.
- The input file is empty or has no header row.
- The file cannot be decoded as UTF-8, or there is a permission/I/O error.

## Running the tests

```bash
python -m unittest test_dedupe.py -v
```
