# Python

## Detection

| Signal | Means |
|---|---|
| `pytest` in `pyproject.toml` (`[tool.pytest.ini_options]`, dev dependencies), `pytest.ini`, `setup.cfg`, `tox.ini`, `requirements-dev.txt`; a `conftest.py` | pytest |
| `unittest.TestCase` subclasses in the existing tests and no pytest | unittest — follow it |
| `pytest-mock` | the `mocker` fixture |
| `freezegun`, `time-machine` | time freezing |
| `responses`, `respx`, `pytest-httpx` | HTTP faking for `requests` / `httpx` |
| `pytest-asyncio`, `anyio` | async tests |
| `pytest-django`, or `manage.py` with tests | Django |
| `fastapi` with `TestClient` / `httpx.AsyncClient` in the tests | FastAPI in-process API tests |

## No infrastructure — the proposal

- pytest as a dev dependency, through the tool the project uses: `uv add --dev pytest` (writes `[dependency-groups] dev`), `poetry add --group dev pytest`, or a line in `requirements-dev.txt`. Show the exact file change.
- `[tool.pytest.ini_options]` with `testpaths = ["tests"]` and `pythonpath = ["."]` (`["src"]` for a src layout), so the tests import the package without installing it.
- Placement: `tests/`, mirroring the package — `app/points.py` → `tests/test_points.py`.

## Naming and shape

```python
import pytest

from app.points import InsufficientPoints, redeem


def test_redeem_points_insufficient_raises(fake_repo):
    """积分不足时抛出 InsufficientPoints，余额不变且不生成兑换单"""
    # given
    fake_repo.balances["U1"] = 199

    # when / then
    with pytest.raises(InsufficientPoints):
        redeem(fake_repo, "U1", 200)
    assert fake_repo.balances["U1"] == 199
    assert fake_repo.redemptions == []


@pytest.mark.parametrize("amount", [pytest.param(0, id="zero"), pytest.param(-1, id="negative")])
def test_redeem_non_positive_amount_raises_value_error(fake_repo, amount):
    """兑换数量不是正数时抛出 ValueError"""
    with pytest.raises(ValueError):
        redeem(fake_repo, "U1", amount)
```

- `test_` + `method_scene_expected` in snake_case; the docstring's first line carries the Chinese description.
- Parametrize ids stay short ASCII: pytest escapes non-ASCII ids in its output (`数…`) unless the project enables `disable_test_id_escaping_and_forfeit_all_rights_to_community_support`.
- `# given` / `# when` / `# then`.
- Shared fixtures go in `conftest.py`, function-scoped unless they are immutable.

## Assertions

- A plain `assert` against the exact expected value; pytest prints the diff.
- `pytest.raises(Exc, match=...)` — `match` is a regex, and only for messages that are the contract.
- Floats: `pytest.approx`. Money: `Decimal` against `Decimal`, never against a float.

## Boundaries

| Boundary | Default |
|---|---|
| Repositories | an in-memory fake passed in, when the code takes the dependency as a parameter |
| Module-level clients | `monkeypatch.setattr("app.points.client", fake)` or `mocker.patch(...)` — patch where the name is **looked up**, not where it is defined |
| HTTP | `respx` / `responses` / `pytest-httpx` when present; otherwise patch the client call |
| Time | `freezegun.freeze_time("2026-09-23 10:00:00")` or `time_machine.travel(...)` when present; otherwise `monkeypatch` the module's `datetime` reference; neither possible → 不可测 (seam: pass `now` in) |
| Randomness | a seeded `random.Random` passed in, or patch the module's `random` |

## In-process API

FastAPI `TestClient(app)`, Flask `app.test_client()`, Django `Client` — whichever the project uses. Replace boundaries through the framework's own hook, e.g. FastAPI `app.dependency_overrides`.

## Test-first stub

```python
def redeem(repo: PointsRepository, user_id: str, amount: int) -> Redemption:
    raise NotImplementedError
```

Right-reason failure: `NotImplementedError`, or an `AssertionError` with pytest's diff.

## Running

- `pytest tests/test_points.py -q`; one test: `pytest "tests/test_points.py::test_redeem_points_insufficient_raises"`.
- Through the project's runner when it has one: `uv run pytest …`, `poetry run pytest …`.
- Django without pytest-django: `python manage.py test app.tests.test_points`.

| Output | Meaning |
|---|---|
| `ImportError`, `ModuleNotFoundError`, `fixture '…' not found`, `SyntaxError`, `collected 0 items` | the test's own fault, or a missing stub |
| `AssertionError`, `assert … == …` | an assertion failed |
| `NotImplementedError` | Test-first, the right reason |
