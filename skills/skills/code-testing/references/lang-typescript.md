# TypeScript / Node

## Detection

| Signal in `package.json` | Means |
|---|---|
| `vitest` | Vitest (`vi`) |
| `jest` with `ts-jest` / `@swc/jest` / `babel-jest` | Jest (`jest`) |
| `mocha` + `chai`, or `node --test` in `scripts` | follow the existing tests |
| `supertest` | in-process HTTP tests |
| `msw`, `nock` | HTTP faking |
| `@nestjs/testing` | the Nest testing module |
| `@testing-library/*` | component tests exist — follow them; browser E2E stays out of scope |

Also check `scripts.test`, `vitest.config.*` / `jest.config.*` (the test file patterns), and whether tests are colocated (`*.test.ts` beside the source), under `__tests__/`, or under `tests/`.

## No infrastructure — the proposal

- Vitest as a dev dependency (`npm i -D vitest`, or the project's package manager) and `"test": "vitest run"` in `scripts`; `supertest` and `@types/supertest` when an HTTP layer is in scope.
- Placement: `tests/`, mirroring `src/` — `src/points/redeem.ts` → `tests/points/redeem.test.ts`.

## Naming and shape

TypeScript tests have no method names: the method goes in `describe`, the Chinese scene and expected result go in `it`.

```ts
import { beforeEach, describe, expect, it } from 'vitest';
import { InsufficientPointsError, redeem } from '../../src/points/redeem';
import { FakePointsRepo } from '../fakes/fake-points-repo';

describe('redeem', () => {
  let repo: FakePointsRepo;

  beforeEach(() => {
    repo = new FakePointsRepo();
  });

  it('积分不足时抛出 InsufficientPointsError，余额不变且不生成兑换单', async () => {
    // given
    repo.setBalance('U1', 199);

    // when / then
    await expect(redeem(repo, 'U1', 200)).rejects.toThrow(InsufficientPointsError);
    expect(repo.balanceOf('U1')).toBe(199);
    expect(repo.redemptions).toEqual([]);
  });

  it.each([0, -1])('兑换数量为 %d 时抛出 RangeError', async (amount) => {
    await expect(redeem(repo, 'U1', amount)).rejects.toThrow(RangeError);
  });
});
```

- `// given` / `// when` / `// then`.
- Jest: the same shape; drop the import line when the project uses Jest globals, or import from `@jest/globals` when it does.

## Assertions

- `toBe` for primitives, `toEqual` for structures, `toStrictEqual` when `undefined` properties matter.
- Async: `await expect(promise).rejects.toThrow(...)` / `.resolves` — **without `await` the test finishes before the assertion runs, and passes.**
- Money and floats: `toBeCloseTo`, or integers in the smallest unit.

## Boundaries

| Boundary | Default |
|---|---|
| Injected dependencies | a fake class passed in |
| Imported modules (DB client, SDK) | `vi.mock('../src/db/client')` / `jest.mock(...)` — hoisted to the top of the file; `vi.restoreAllMocks()` / `jest.restoreAllMocks()` in `afterEach` |
| HTTP | `msw` / `nock` when present; otherwise mock the client module |
| Time | `vi.useFakeTimers()` then `vi.setSystemTime(new Date('2026-09-23T02:00:00Z'))`, and `vi.useRealTimers()` in `afterEach`; Jest: `jest.useFakeTimers()` then `jest.setSystemTime(...)` |
| Randomness, ids | mock the id module, or inject the generator |

## In-process API

```ts
import request from 'supertest';
import { createApp } from '../src/app';

it('兑换成功返回 201 和 Location 头', async () => {
  const app = createApp(new FakePointsRepo());
  const res = await request(app).post('/points/redemptions').send({ userId: 'U1', amount: 200 });
  expect(res.status).toBe(201);
  expect(res.headers.location).toMatch(/^\/points\/redemptions\//);
});
```

Pass the app object to `request()`; never `listen()` on a port. Nest: build the module with `Test.createTestingModule(...)`, `await app.init()`, then `request(app.getHttpServer())`.

## Test-first stub

```ts
export async function redeem(repo: PointsRepository, userId: string, amount: number): Promise<Redemption> {
  throw new Error('not implemented');
}
```

Right-reason failure: `Error: not implemented`, or an `expected … to …` assertion message.

## Running

- Vitest: `npx vitest run tests/points/redeem.test.ts`; one case: `-t '积分不足'`.
- Jest: `npx jest tests/points/redeem.test.ts -t '积分不足'`.
- Vitest, `@swc/jest` and `babel-jest` strip types without checking them — run `npx tsc --noEmit` first when the tsconfig covers the test files. `ts-jest` type-checks on its own.

| Output | Meaning |
|---|---|
| `Cannot find module`, `SyntaxError`, `error TS…` from tsc, `No test files found` / `No tests found` | the test's own fault, or a missing stub |
| `AssertionError: expected … to …`, `Expected: … Received: …` | an assertion failed |
| `Error: not implemented` | Test-first, the right reason |
