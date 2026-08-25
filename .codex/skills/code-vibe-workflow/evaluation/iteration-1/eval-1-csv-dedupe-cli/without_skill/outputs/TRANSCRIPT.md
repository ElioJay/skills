# Transcript

Steps taken to implement the CSV dedupe CLI from scratch:

1. **Confirmed the working directory** was the empty `outputs/` folder and that
   no prior code existed.
2. **Designed the CLI surface** to match the required spec:
   `python dedupe.py <input.csv> <output.csv> --column <col_name>` using
   `argparse` (two positionals + one required `--column` option). Relied on
   argparse for missing-argument errors so messages stay consistent.
3. **Implemented `dedupe.py`**:
   - `parse_args()` builds the argparse parser with a friendly description.
   - `dedupe_csv()` validates that the input file exists, uses `csv.DictReader`
     to iterate rows, validates the chosen column is in the header, and writes
     unique rows via `csv.DictWriter`, tracking seen keys in a `set` so the
     first occurrence wins.
   - `main()` wraps the call and translates `FileNotFoundError`, `ValueError`,
     `PermissionError`, `UnicodeDecodeError`, and other `OSError`s into clear
     stderr messages with `sys.exit(1)`.
   - Added module/function docstrings and inline comments per project rules.
4. **Wrote `test_dedupe.py`** (stdlib `unittest` + `subprocess`) to invoke the
   script as a real CLI and cover:
   - Keep-first deduplication behavior and header preservation.
   - Missing input file.
   - Missing `--column` option.
   - Missing positional arguments.
   - Unknown column name.
   - Empty input file.
5. **Wrote `README.md`** documenting usage, an example, error behavior, and
   how to run the tests.
6. **Wrote `COMMIT_PLAN.md`** listing files and a proposed commit message
   (no git commands were executed, per instructions).

## Notes / assumptions

- Assumed UTF-8 encoded CSVs (common default); surface a clear error otherwise.
- Assumed the deduplication key is the raw string value of the column as read
  by `csv.DictReader` (no trimming / case-folding). This matches the literal
  spec and avoids silent behavior changes.
- Preserved input column order in the output by mirroring `reader.fieldnames`.
