# express-health-service

Minimal Express 4.x service exposing a single `GET /health` endpoint, intended
as a starting point for liveness probes.

## Tech stack

- Node.js (>= 14 recommended)
- Express 4.x
- Jest + supertest (dev)

## Project layout

```
.
├── app.js                  # Express app factory (no listen)
├── server.js               # HTTP bootstrap (calls listen)
├── __tests__/
│   └── health.test.js      # Jest + supertest contract tests
├── package.json
└── README.md
```

## Install

```bash
npm install
```

## Run

```bash
npm start
# or with a custom port:
PORT=8080 npm start
```

The service then responds on `http://localhost:3000/health` (or your chosen
port).

## API

### `GET /health`

Returns the current process liveness snapshot.

**Response 200**

```json
{
  "status": "ok",
  "uptime": 12.345,
  "timestamp": "2026-05-19T10:00:00.000Z"
}
```

| Field      | Type   | Notes                                              |
|------------|--------|----------------------------------------------------|
| status     | string | Always `"ok"` while the process is serving traffic |
| uptime     | number | Seconds since the Node process started             |
| timestamp  | string | ISO 8601 timestamp at the moment of the response   |

## Test

```bash
npm test
```

The Jest suite drives the app via supertest, so no port is opened during
testing.
