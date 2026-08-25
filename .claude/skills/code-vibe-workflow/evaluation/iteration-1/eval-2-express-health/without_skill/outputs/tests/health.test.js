// Unit tests for GET /health.
// Uses supertest to drive the Express app without binding to a real port.
const request = require('supertest');
const createApp = require('../src/app');

describe('GET /health', () => {
  const app = createApp();

  test('returns HTTP 200 with JSON content type', async () => {
    const res = await request(app).get('/health');
    expect(res.status).toBe(200);
    expect(res.headers['content-type']).toMatch(/application\/json/);
  });

  test('response body contains status, uptime, timestamp', async () => {
    const res = await request(app).get('/health');
    // status must be the literal string 'ok'
    expect(res.body.status).toBe('ok');
    // uptime must be a non-negative number (process.uptime() in seconds)
    expect(typeof res.body.uptime).toBe('number');
    expect(res.body.uptime).toBeGreaterThanOrEqual(0);
    // timestamp must be a valid ISO 8601 string parseable back to the same value
    expect(typeof res.body.timestamp).toBe('string');
    const parsed = new Date(res.body.timestamp);
    expect(Number.isNaN(parsed.getTime())).toBe(false);
    expect(parsed.toISOString()).toBe(res.body.timestamp);
  });

  test('uptime increases between two successive calls', async () => {
    const first = await request(app).get('/health');
    // small busy wait to guarantee uptime advances measurably
    await new Promise((resolve) => setTimeout(resolve, 20));
    const second = await request(app).get('/health');
    expect(second.body.uptime).toBeGreaterThanOrEqual(first.body.uptime);
  });
});
