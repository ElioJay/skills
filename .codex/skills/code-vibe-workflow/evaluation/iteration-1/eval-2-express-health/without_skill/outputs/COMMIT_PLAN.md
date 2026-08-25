# Commit Plan

## Files to add

- `package.json`
- `.gitignore`
- `README.md`
- `src/app.js`
- `src/server.js`
- `tests/health.test.js`

## Commit message

```
feat: add minimal Express service with GET /health and jest tests

- Express 4.x app factory exposing GET /health
- Response includes status, process uptime (seconds), ISO timestamp
- Jest + supertest cover content type, field types, and uptime monotonicity
- README documents install / start / test workflow
```
