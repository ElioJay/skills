// server.js
// WHY: Thin bootstrap that turns the pure Express app (app.js) into a
// running HTTP server. Kept separate so tests can import the app
// without a port being bound.

const { createApp } = require('./app');

// PORT is read from env to ease container deployment; default 3000
// matches the Express convention so README instructions stay short.
const PORT = process.env.PORT || 3000;

const app = createApp();

app.listen(PORT, () => {
  // Single startup log — intentionally minimal so it doesn't pollute
  // structured logging pipelines in production.
  console.log(`Health service listening on http://localhost:${PORT}`);
});
