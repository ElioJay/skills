# Commit Plan

Per CLAUDE.md: use the current branch, do not create a new one, do not
push, and use an English commit message. The user should review this
plan and confirm before running the git commands.

## Files to stage

- `package.json`
- `app.js`
- `server.js`
- `__tests__/health.test.js`
- `README.md`

(TRANSCRIPT.md and COMMIT_PLAN.md are workflow artifacts and should
NOT be part of the project commit.)

## Proposed git commands

```bash
git add package.json app.js server.js __tests__/health.test.js README.md
git commit -m "feat(health): add minimal Express service with GET /health endpoint

- Add app.js exposing GET /health returning {status, uptime, timestamp}
- Add server.js bootstrap listening on PORT (default 3000)
- Add jest + supertest tests covering all three response fields
- Add README with install, start, and test instructions"
git status
```

## Commit message (single-line variant, if preferred)

```
feat(health): add minimal Express service with GET /health endpoint
```
