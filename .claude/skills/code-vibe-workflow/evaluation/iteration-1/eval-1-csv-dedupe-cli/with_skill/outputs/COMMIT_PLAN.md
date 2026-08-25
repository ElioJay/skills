# Commit Plan

## Files to commit

- `dedupe.py`            — CLI main program (argparse + csv-based dedupe)
- `test_dedupe.py`       — Unit tests covering happy path and 4 edge cases
- `README.md`            — Usage and error-handling documentation

## Commit message (English, per CLAUDE.md rule)

```
feat(dedupe): add CSV column-based deduplication CLI

Implement dedupe.py, a zero-dependency CLI that removes duplicate rows
from a CSV file based on a user-specified column, keeping the first
occurrence. Provide friendly error messages for missing args, missing
input file, missing column, and empty/headerless CSVs, all with a
non-zero exit code. Include unittest coverage for the happy path and
edge cases.
```

## Git commands that would be run (not executed in this simulation)

```bash
git add dedupe.py test_dedupe.py README.md
git commit -m "feat(dedupe): add CSV column-based deduplication CLI

Implement dedupe.py, a zero-dependency CLI that removes duplicate rows
from a CSV file based on a user-specified column, keeping the first
occurrence. Provide friendly error messages for missing args, missing
input file, missing column, and empty/headerless CSVs, all with a
non-zero exit code. Include unittest coverage for the happy path and
edge cases."
git status
```

Per CLAUDE.md: stay on current branch, do not create a new branch, do not push.
