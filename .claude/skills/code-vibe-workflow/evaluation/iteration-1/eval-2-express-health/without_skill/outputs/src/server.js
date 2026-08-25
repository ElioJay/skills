// Server entry point.
// Creates the Express app and starts listening on the configured port.
const createApp = require('./app');

const PORT = process.env.PORT || 3000;
const app = createApp();

app.listen(PORT, () => {
  // eslint-disable-next-line no-console
  console.log(`Health service listening on http://localhost:${PORT}`);
});
