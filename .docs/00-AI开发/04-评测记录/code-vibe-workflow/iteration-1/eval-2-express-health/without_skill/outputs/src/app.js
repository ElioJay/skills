// Express application factory.
// Keeping the app definition separate from the listener makes the app testable
// with supertest without needing to bind to a network port.
const express = require('express');

function createApp() {
  const app = express();

  // GET /health: lightweight liveness probe.
  // Returns the service status, process uptime in seconds, and current ISO timestamp.
  app.get('/health', (req, res) => {
    res.json({
      status: 'ok',
      uptime: process.uptime(), // seconds the Node.js process has been running
      timestamp: new Date().toISOString(), // current time in ISO 8601 format
    });
  });

  return app;
}

module.exports = createApp;
