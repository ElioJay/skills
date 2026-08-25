// app.js
// WHY: Export the Express app without calling listen() so unit tests can
// drive it via supertest without binding a TCP port. The actual HTTP
// server bootstrap lives in server.js.

const express = require('express');

// Factory keeps construction explicit and avoids hidden shared state
// between tests that may require fresh instances in the future.
function createApp() {
  const app = express();

  // GET /health
  // WHY: Returns a simple liveness payload that is cheap to compute, so
  // load balancers / orchestrators can probe at high frequency.
  // - status:    fixed string 'ok' (this endpoint never reports failure;
  //              if the process is down, the probe will fail to connect)
  // - uptime:    process.uptime() returns fractional seconds since the
  //              Node process started — exactly what callers asked for
  // - timestamp: ISO 8601 string for log/timeseries correlation
  app.get('/health', (req, res) => {
    res.json({
      status: 'ok',
      uptime: process.uptime(),
      timestamp: new Date().toISOString(),
    });
  });

  return app;
}

module.exports = { createApp };
