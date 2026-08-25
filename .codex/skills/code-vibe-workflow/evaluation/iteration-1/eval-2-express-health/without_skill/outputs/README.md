# express-health-demo

A minimal Express 4.x service that exposes a `GET /health` endpoint for liveness checks.

## Requirements

- Node.js 18+ (uses `process.uptime()` and built-in `Date`)
- npm

## Install

```bash
npm install
```

## Run

```bash
npm start
```

The server listens on `http://localhost:3000` by default. Override with the `PORT` environment variable:

```bash
PORT=8080 npm start
```

## Endpoint

`GET /health` returns JSON:

```json
{
  "status": "ok",
  "uptime": 12.345,
  "timestamp": "2026-05-19T10:00:00.000Z"
}
```

- `status`: literal string `"ok"`
- `uptime`: process uptime in seconds (number)
- `timestamp`: current server time as an ISO 8601 string

## Test

```bash
npm test
```

Jest + supertest drive the Express app in-process, covering each response field.

## Project layout

```
src/
  app.js      # Express app factory (no listen)
  server.js   # Entry point that binds to a port
tests/
  health.test.js
package.json
README.md
```
