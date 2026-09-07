# Python

**The signature redundancy: fake class namespaces, plus docstrings that restate the signature.**
The first comes from over-generalizing "OO means professional"; the second from the mass of
auto-generated documentation in training data.

## A. Mechanical

### PY1 — Docstring restating the signature *(highest value in this language)*

```python
def send_email(to: str, subject: str, body: str) -> bool:
    """Send an email.

    Args:
        to (str): The to.
        subject (str): The subject.
        body (str): The body.

    Returns:
        bool: The result.
    """
```

Hit: every `Args` entry repeats the parameter name and the type already in the annotation; no
constraint, no unit, no `Raises`, no example, no side-effect note.

Action: delete the docstring, or keep only the summary line.

**Keep the docstring** if it contains any of: a `Raises:` section naming concrete exceptions; a
unit, time zone, or precision; a value constraint ("must be positive", "UTC only"); example code;
a side-effect note ("writes to disk"); a link to external docs or an issue.

### PY2 — Fake class namespace

Hit, all of them: every method is a `@staticmethod`; no `__init__`, no instance attributes, no
class attributes beyond constants; no inheritance and not inherited from; no `cls`/`self` use.

Action: flatten to module-level functions **within the same file**; call sites go from
`Helper.do_x()` to `do_x()`. A Python module already is a namespace — the class is a Java/C#
transplant.

Exemption: the class is a constant container, or a framework config class (Django `class Meta`,
Pydantic `class Config`). Those are redlines.

### PY3 — Unused typing imports

Hit: `from typing import List, Dict, Tuple, Set` on Python 3.9+ where the code already uses
`list[str]` / `dict[str, int]`; or `Optional`/`Union` on 3.10+ where `X | None` is already in use.

### PY4 — Redundant emptiness checks

```python
if x is not None and x:      # → if x:
if len(x) > 0 and x:         # → if x:
if bool(x):                  # → if x:
```

**`if x is not None:` is not equivalent to `if x:`** — `0`, `""`, `[]` are falsy. Merge only when
the type rules those out; otherwise drop to J-tier.

### PY5 — `raise e` re-raise

```python
except SomeError as e:
    raise e          # redundant, and resets the traceback origin
```

Action: delete the whole try/except.

**A bare `raise` is legitimate and preferred** — it preserves the full traceback and is the normal
log-then-rethrow idiom. Only `raise e` is a hit.

### PY6 — Hand-written `__init__` on a dataclass

Hit: `@dataclass` or `@attrs.define` alongside a hand-written `__init__` that only assigns fields.
If the `__init__` validates or converts, the fix is `__post_init__` — that is addition, so report
only.

### PY7 — Identity wrappers

`list(already_a_list)`, `dict(already_a_dict)`, `str(already_a_str)`, `tuple(already_a_tuple)`,
`f"{x}"` where `x` is already a string.

**`list(x)` is sometimes a deliberate shallow copy.** If the result is mutated afterwards, keep it;
that boundary case drops to J-tier.

### PY8 — Single-implementation ABC / Protocol

Hit: `ABC` subclass count == 1, no mock implementation (no `create_autospec` against it, no test
fake), no `isinstance` polymorphism.

`Protocol` is structural, so it may be used purely for annotation with no explicit implements
relationship — treat Protocol conservatively and drop it to J-tier.

### PY9 — Redundant `else` and `return`

```python
if cond:
    return a
else:
    return b        # else is redundant after a return
```

Plus a trailing explicit `return None` that adds nothing.

### PY10 — f-string with no placeholder

`f"plain text"` containing no `{}`.

### PY11 — Redundant comprehension wrapper

```python
list([x for x in items])            # the comprehension is already a list
set({x for x in items})
sum([x for x in items])             # → sum(x for x in items), skips the intermediate list
list(x for x in items)              # → [x for x in items]
dict([(k, v) for k, v in pairs])    # → {k: v for k, v in pairs}
```

### PY12 — Pure-forwarding lambda

`map(lambda x: str(x), items)` → `map(str, items)`; `lambda x: f(x)` → `f`.

**Only pure forwarding.** `sorted(items, key=lambda x: x.name)` is not redundant — leave it.

## B. Judgment

### PY13 — `# type: ignore` sprawl

Two or more added with no stated reason. Distinguish a genuine typing gap (third-party stubs
missing — acceptable) from silencing a real problem (route to `[附注]`). Narrowing to
`# type: ignore[error-code]` with a reason is addition — suggest, do not apply.

### PY14 — Hand-rolled dict/list convenience wrappers

`def get_or_default(d, k, default): return d.get(k, default)` and similar zero-value wrappers.
One call site routes to the M-tier inline rule; many call sites means switching them all, which is
cross-file — report only.

### PY15 — `_private` helper with one call site

Low-risk inline, **except**: recursive functions, functions passed as callbacks, and
decorator-wrapped functions all defeat grep counting. Also skip when inlining would push the
caller past ~50 lines — readability beats line count.

### PY16 — `__init__.py` re-export nobody uses

`from .x import Y` in `__init__.py` with zero references outside the package. **Public-API redline,
report only** — consumers may live outside this repository. If `Y` is in `__all__`, that is an
explicit API promise; never delete.

### PY17 — Over-broad `try` block

A `try` spanning 20+ lines where the `except` targets an exception only one of those lines can
raise. A wide block masks unrelated failures. Narrowing is an in-place edit and in scope — confirm
`finally` and resource-cleanup semantics survive.

### PY18 — Mutable default argument

`def f(items=[])`, `def f(d={})`. The default is evaluated once at definition and shared across
calls. **This is a bug, not redundancy** — route to `[附注]`.

### PY19 — Hand-rolled dataclass boilerplate

Hit: a class whose only methods are `__init__`, `__repr__` and `__eq__`, all doing plain field
assignment and comparison. Switching to `@dataclass` is a **net line reduction**, so it is in scope.

Confirm first: do any fields have defaults whose ordering would break? Is `frozen=True` needed? Does
an inheritance chain interact badly with dataclass generation? And if the class is managed by
Pydantic, SQLAlchemy or Django, **leave it alone** — that is a redline.

## C. Framework boilerplate — never delete

| Category | Details |
|---|---|
| pytest | Fixtures in `conftest.py` — injected by name with zero explicit calls; `pytest_*` hooks; `@pytest.fixture`, `@pytest.mark.*` |
| Web routing | Views referenced from Django `urls.py`; functions decorated `@app.get` / `@router.post` in FastAPI/Flask — registered by decorator, never called explicitly |
| Pydantic | `class Config` / `model_config`; `@field_validator`, `@model_validator`, `@computed_field`; `Field(...)` arguments |
| ORM | `__tablename__`; attributes defined by `relationship()`; `@declared_attr`; Django `class Meta` |
| Task queues | `@app.task`, `@shared_task`, `@periodic_task` |
| Public API | Everything in `__all__`; `__init__.py` re-exports (report only) |
| Dunder protocol methods | `__enter__`, `__exit__`, `__iter__`, `__next__`, `__len__`, `__getitem__`, `__eq__`, `__hash__`, `__repr__`, `__call__` — called implicitly by the language |
| Serialization hooks | `__getstate__`, `__setstate__`, `__reduce__`; `to_dict`/`from_dict` when a framework calls them by name |
| Descriptors | `@property`, `@cached_property`, `@staticmethod`, `@classmethod`, `@functools.wraps` |
| Type-checking only | Imports inside `if TYPE_CHECKING:` — genuinely unused at runtime, but removing them breaks type checking; `@overload` declarations, whose bodies look empty by design |
| Linter directives | `# noqa`, `# noqa: E501`, `# pragma: no cover`, `# type: ignore` |
| Entry points | `if __name__ == "__main__":`; functions named by `entry_points` / `[project.scripts]` |
| Enums | `enum.Enum` members — may be referenced by name from config strings |
| Plugins / DI | Plugins loaded via `importlib.metadata.entry_points`; Django `AppConfig.ready()`; modules listed in `INSTALLED_APPS` |
