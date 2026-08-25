// __tests__/health.test.js
// WHY: Cover the contract of GET /health — the three fields the caller
// will rely on. We deliberately test the app via supertest (no real
// listen()) to keep the tests hermetic and fast.

const request = require('supertest');
const { createApp } = require('../app');

describe('GET /health', () => {
  const app = createApp();

  test('responds 200 with status "ok"', async () => {
    const res = await request(app).get('/health');

    expect(res.status).toBe(200);
    expect(res.body.status).toBe('ok');
  });

  test('uptime is a non-negative number', async () => {
    const res = await request(app).get('/health');

    // process.uptime() is fractional seconds; just assert it is a
    // sensible number rather than pinning an exact value (flaky).
    expect(typeof res.body.uptime).toBe('number');
    expect(Number.isFinite(res.body.uptime)).toBe(true);
    expect(res.body.uptime).toBeGreaterThanOrEqual(0);
  });

  test('timestamp is a valid ISO 8601 string', async () => {
    const res = await request(app).get('/health');

    expect(typeof res.body.timestamp).toBe('string');

    // Round-tripping through Date proves it parses and re-serializes
    // to the same canonical ISO form — the strongest cheap check we
    // can do without pulling in a date library.
    const parsed = new Date(res.body.timestamp);
    expect(Number.isNaN(parsed.getTime())).toBe(false);
    expect(parsed.toISOString()).toBe(res.body.timestamp);
  });

  test('response contains exactly the three documented fields', async () => {
    // Edge case: guard against accidental field leakage (e.g. someone
    // adds debug info later). Callers may rely on the shape.
    const res = await request(app).get('/health');

    expect(Object.keys(res.body).sort()).toEqual(
      ['status', 'timestamp', 'uptime'].sort()
    );
  });
});
