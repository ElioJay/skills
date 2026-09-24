# Quality Floor

These rules hold for every test and every documented case, in every mode, whatever the project's existing tests do. Project conventions decide style; they never lower this floor. An existing test that breaks a rule is left alone and mentioned in the report — rewriting it is out of scope unless it was confirmed as 需更新.

## The seven rules

1. **A behavioral assertion.** Every case asserts a specific outcome: a return value, a persisted or emitted state, an error with its type or code, a side effect that must not happen. None of these counts on its own: `assertNotNull`, `assertDoesNotThrow`, `toBeTruthy`, a bare `assert result`, a bare `toMatchSnapshot()`, "the response is JSON".
2. **One behavior per case.** Several assertions are fine when they describe the same outcome — status and body; the error and the absence of a write. Inputs with the same behavior form one parameterized case.
3. **Mock the boundaries, nothing else.** Boundaries are the database, HTTP, MQ, the file system, the clock, randomness, third-party SDKs. Collaborators inside the module under test are real objects. Interaction checks (`verify`, `toHaveBeenCalled`) only when the interaction is the behavior — "one notification sent", "payment not called when validation fails", "nothing written". A fake or stub returns every field the code reads; an incomplete one lets the test pass for the wrong reason.
4. **Deterministic.** The clock is fixed or injected; randomness is seeded or injected; generated ids are fixed, or the test asserts their relation rather than their value; no `sleep` — fake timers, latches or awaitable signals instead; no real network.
5. **Independent.** Each test builds its own state and passes alone or in any order. Shared fixtures are immutable or reset per test; temp files and rows are cleaned up.
6. **Assertions are never bent to the implementation.** A red test is fixed by fixing the test's own mistake — never by changing the expected value to what the code returns, unless the user ruled 按实现写 or the mode is Lock. Skipping (`@Disabled`, `.skip`, `xfail`) to get green is bending too.
7. **Production code is not edited.** Two exceptions, both confirmed first: Test-first minimal stubs, and the build-file change of an accepted infra proposal. A testability gap is solved with test-side tools — static mocking, monkeypatching, fake timers, an injection point that already exists — or reported as 不可测 with the suggested seam.

## Smells that fail the floor

| Smell | Why it fails | Rule |
|---|---|---|
| The test recomputes the implementation's formula and compares | cannot fail for the right reason | 1, 6 |
| The asserted object is the mock itself | tests the test | 1 |
| A snapshot with no semantic assertion | any change becomes "expected" once re-recorded | 1 |
| An async assertion without `await` | the test finishes before the assertion runs | 1 |
| An error case that checks only the exception type | misses the side effects that must not happen | 1 |
| Every dependency mocked; the test checks only wiring | nothing real is exercised | 3 |
| Mock setup longer than the behavior under test, or more than three mocks | a missing seam — report it rather than piling on mocks | 3 |
| The side effect the test is about has been mocked away | passes for the wrong reason | 3 |
| `LocalDateTime.now()` / `time.time()` / `Date.now()` read for real | flaky at midnight, at month end, in CI time zones | 4 |
| `sleep` to wait for async work | slow and flaky | 4 |
| Tests that pass only in file order | hidden shared state | 5 |

These match the test checks of `code-slimming` (M33, M35–M38, J30–J34) and the test-quality section of `code-review-deep`, so tests written here pass those reviews.
