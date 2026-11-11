# Commit Plan

## Files to commit

- `dedupe.py` - CLI tool that deduplicates a CSV by a specified column, keeping the first occurrence.
- `test_dedupe.py` - Unittest-based end-to-end tests covering happy path and error cases.
- `README.md` - Usage, example, error-handling notes, and test instructions.

## Suggested commit message

```
Add dedupe.py CLI for column-based CSV deduplication

- Implement dedupe.py: read input CSV, drop later duplicates by a chosen
  column via DictReader/DictWriter, preserve header order.
- Handle missing args, missing files, unknown columns, empty files, and
  decoding/permission errors with friendly messages and non-zero exits.
- Add test_dedupe.py covering keep-first behavior, missing input file,
  missing --column, missing positional args, unknown column, empty file.
- Add README.md with usage example, error behavior, and test instructions.
```
