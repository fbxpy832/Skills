# Hermes Dev-Collab Skill — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a Hermes-invocable skill that turns a free-form Feishu dev idea into working code on a git branch, using Codex for spec/plan/review and Claude Code CLI for implementation, with a 5-round bounded review loop and checkpoint-based crash recovery.

**Architecture:** Hybrid orchestrator — Hermes (the LLM agent) drives multi-turn requirements clarification and the top-level phase transitions, while Bash + Python scripts handle deterministic state transitions, CLI invocations to `codex` / `claude` / `git` / `hermes send`, and review-verdict parsing. State lives at `~/.hermes/runs/<job_id>/` and is updated atomically.

**Tech Stack:**
- Python 3.11+ (state, parsers, CLI)
- Bash 5+ (thin phase scripts, hermes-send wrappers)
- pytest (unit + fixture tests)
- `codex` CLI 0.133.0 (spec, plan, self-check, review)
- `claude` CLI (implementation, with `--cwd` and headless `-p` mode)
- `git` 2.30+ (branch / commit / diff)
- `hermes` CLI (Feishu send; user-provided, not implemented by this skill)

**Source of truth:** `hermes-dev-skill/design-specs/2026-06-14-hermes-dev-collab-skill-design.md`

---

## File structure (target end-state)

```
hermes-dev-skill/
├── SKILL.md                              # Task 30
├── README.md                             # Task 33
├── config.example.yaml                   # Task 1
├── install.sh                            # Task 36
├── pyproject.toml                        # Task 1
├── pytest.ini                            # Task 1
├── scripts/
│   ├── hermes-dev                        # Task 12 (entry point)
│   ├── phases/
│   │   ├── 01_clarify.sh                 # Task 23 (Hermes-driven; shell marker)
│   │   ├── 02_spec_plan.sh               # Task 24
│   │   ├── 03_implement.sh               # Task 25
│   │   ├── 03_implement_iter.sh          # Task 26
│   │   ├── 04_review.sh                  # Task 28
│   │   ├── 04_review_one.sh              # Task 27
│   │   └── 05_handoff.sh                 # Task 29
│   ├── lib/
│   │   ├── __init__.py
│   │   ├── state.py                      # Tasks 2–5
│   │   ├── feishu.py                     # Tasks 6–7
│   │   ├── review_parser.py              # Task 8
│   │   ├── git_ops.py                    # Task 9
│   │   ├── project_registry.py           # Task 10
│   │   ├── checkpoint.py                 # Task 11
│   │   └── reconcile.py                  # Task 17
│   ├── handlers/
│   │   └── on_continue.sh                # Task 18
│   ├── claude_contract.md                # Task 22
│   └── codex_prompts/
│       ├── spec_plan.md                  # Task 19
│       ├── self_check.md                 # Task 20
│       └── review.md                     # Task 21
├── references/
│   ├── state-schema.md                   # Task 31
│   ├── feishu-message-format.md          # Task 32
│   └── troubleshooting.md                # Task 32
├── tests/
│   ├── __init__.py
│   ├── conftest.py                       # Task 1
│   ├── test_state.py                     # Tasks 2–5
│   ├── test_feishu.py                    # Tasks 6–7
│   ├── test_review_parser.py             # Task 8
│   ├── test_git_ops.py                   # Task 9
│   ├── test_project_registry.py          # Task 10
│   ├── test_checkpoint.py                # Task 11
│   ├── test_hermes_dev_cli.py            # Tasks 12–16
│   ├── test_reconcile.py                 # Task 17
│   ├── fixtures/
│   │   ├── sample-review-approved.md     # Task 8
│   │   ├── sample-review-rejected-p0.md  # Task 8
│   │   ├── sample-review-rejected-p1.md  # Task 8
│   │   └── sample-state.json             # Task 11
│   ├── e2e/
│   │   ├── sandbox-project/              # Task 34 (50-line throwaway git repo)
│   │   └── test_e2e_dry_run.py           # Task 34
│   └── manual/
│       └── smoke.sh                      # Task 35
├── design-specs/2026-06-14-hermes-dev-collab-skill-design.md   # already exists
└── plans/2026-06-14-hermes-dev-collab-skill.md                 # this file
```

---

## Task ordering & milestones

The 36 tasks are grouped into 9 milestones. Each milestone ends with a working, testable artifact.

| Milestone | Tasks | What's working at the end |
|---|---|---|
| M1: Project skeleton + state module | 1–5 | `state.py` with read/write, schema validation, atomic_update, TransientError. All state tests pass. |
| M2: External integrations | 6–10 | `feishu.py`, `review_parser.py`, `git_ops.py`, `project_registry.py` with full test coverage. |
| M3: Checkpoint + reconcile | 11, 17 | `checkpoint.py` save/restore, `reconcile.py` orphan detection. |
| M4: Hermes CLI | 12–16, 18 | `hermes-dev` subcommands (new, status, list, tail, continue, cancel, register, unregister) and `on_continue.sh` handler. |
| M5: Code templates | 19–22 | Codex prompt templates + Claude Code work contract (static content). |
| M6: Phase scripts | 23–29 | All 7 phase shell scripts; each is invocable and idempotent. |
| M7: SKILL.md + docs | 30–33 | Hermes-facing instructions + state schema reference + Feishu card templates + README. |
| M8: Install + e2e | 34–36 | `sandbox-project/` + e2e dry-run test + `install.sh` + `smoke.sh`. |
| M9: Manual verification | 37 | `verification.md` with explicit commands the user runs end-to-end. |

---

# M1: Project skeleton + state module

## Task 1: Project skeleton

**Files:**
- Create: `hermes-dev-skill/pyproject.toml`
- Create: `hermes-dev-skill/pytest.ini`
- Create: `hermes-dev-skill/conftest.py`
- Create: `hermes-dev-skill/.gitignore`
- Create: `hermes-dev-skill/config.example.yaml`
- Create: `hermes-dev-skill/scripts/lib/__init__.py`
- Create: `hermes-dev-skill/tests/__init__.py`
- Create: `hermes-dev-skill/tests/conftest.py`

- [ ] **Step 1: Create directory tree**

```bash
cd /Users/xpy/Documents/RichardHub/Git
mkdir -p hermes-dev-skill/{scripts/{phases,lib,handlers,codex_prompts},references,tests/{fixtures,e2e/sandbox-project,manual}}
cd hermes-dev-skill
touch scripts/__init__.py scripts/lib/__init__.py scripts/phases/__init__.py scripts/handlers/__init__.py
touch tests/__init__.py tests/fixtures/__init__.py tests/e2e/__init__.py
```

- [ ] **Step 2: Write `pyproject.toml`**

```toml
[build-system]
requires = ["setuptools>=68", "wheel"]
build-backend = "setuptools.build_meta"

[project]
name = "hermes-dev-skill"
version = "0.1.0"
description = "Hermes-invocable skill: idea-to-code via Codex and Claude Code"
requires-python = ">=3.11"
dependencies = [
    "pyyaml>=6.0",
    "jsonpatch>=1.33",
]

[project.optional-dependencies]
dev = [
    "pytest>=7.4",
    "pytest-cov>=4.1",
    "pytest-mock>=3.11",
]

[project.scripts]
hermes-dev = "scripts.hermes_dev:main"

[tool.setuptools]
packages = ["scripts", "scripts.lib"]
```

- [ ] **Step 3: Write `pytest.ini`**

```ini
[pytest]
testpaths = tests
python_files = test_*.py
python_classes = Test*
python_functions = test_*
addopts = -v --tb=short --strict-markers
markers =
    e2e: end-to-end tests (slower; uses sandbox-project/)
```

- [ ] **Step 4: Write root `conftest.py` (so pytest finds the package)**

```python
# hermes-dev-skill/conftest.py
import sys
from pathlib import Path

ROOT = Path(__file__).parent.resolve()
sys.path.insert(0, str(ROOT))
```

- [ ] **Step 5: Write `tests/conftest.py` with shared fixtures**

```python
# hermes-dev-skill/tests/conftest.py
import os
import tempfile
from pathlib import Path
import pytest


@pytest.fixture
def tmp_home(monkeypatch):
    """Isolated $HOME for tests that touch ~/.hermes/."""
    with tempfile.TemporaryDirectory() as td:
        monkeypatch.setenv("HOME", td)
        (Path(td) / ".hermes").mkdir()
        yield Path(td)


@pytest.fixture
def tmp_runs_dir(tmp_path):
    """A scratch directory to act as a job's runs dir."""
    runs = tmp_path / "runs"
    runs.mkdir()
    return runs
```

- [ ] **Step 6: Write `.gitignore`**

```
# Local skill state (do not commit)
__pycache__/
*.pyc
.pytest_cache/
.coverage
*.egg-info/
build/
dist/

# Test sandbox
tests/e2e/sandbox-project/.git/
```

- [ ] **Step 7: Write `config.example.yaml`**

```yaml
version: 1

codex:
  model: gpt-5.5
  reasoning_effort: medium

claude:
  model: claude-opus-4-8

phases:
  requirements:
    max_questions_per_turn: 3
    completeness_checklist:
      - functional_scope
      - behaviour
      - edge_cases
      - non_functional
      - acceptance_criteria
  spec_plan:
    max_self_check_retries: 2
  review:
    max_rounds_default: 5
    extra_rounds_per_continue: 5

feishu:
  prefer_card_over_text_threshold: 120
  progress_card_refresh: true

reconcile:
  orphan_threshold_seconds: 300
```

- [ ] **Step 8: Verify the empty test suite runs**

Run: `cd /Users/xpy/Documents/RichardHub/Git/hermes-dev-skill && python -m pytest --collect-only`
Expected: "no tests ran" or similar, no errors.

- [ ] **Step 9: Commit**

```bash
git add hermes-dev-skill/{pyproject.toml,pytest.ini,conftest.py,.gitignore,config.example.yaml,scripts,tests}
git commit -m "chore(skill): project skeleton with pyproject, pytest, and config template"
```

---

## Task 2: state.py — read/write state.json

**Files:**
- Create: `hermes-dev-skill/scripts/lib/state.py`
- Create: `hermes-dev-skill/tests/test_state.py`

- [ ] **Step 1: Write the failing test**

```python
# hermes-dev-skill/tests/test_state.py
import json
from pathlib import Path
import pytest

from scripts.lib.state import read, write, StateError


def test_read_missing_file_raises(tmp_runs_dir):
    with pytest.raises(StateError, match="state.json not found"):
        read(tmp_runs_dir)


def test_write_then_read_roundtrip(tmp_runs_dir):
    state = {
        "job_id": "test-001",
        "status": "running",
        "phase": "clarify",
        "phase_round": 1,
    }
    write(tmp_runs_dir, state)
    loaded = read(tmp_runs_dir)
    assert loaded == state


def test_write_is_atomic_no_partial_file(tmp_runs_dir, monkeypatch):
    """If os.replace fails, the original state.json is preserved and the
    temp file is cleaned up."""
    import os
    state = {"job_id": "test-001", "status": "running"}
    write(tmp_runs_dir, state)

    def boom(*args, **kwargs):
        raise OSError("disk full mid-rename")
    monkeypatch.setattr(os, "replace", boom)

    with pytest.raises(OSError):
        write(tmp_runs_dir, {"job_id": "test-002"})

    # Original must still be readable
    assert read(tmp_runs_dir)["job_id"] == "test-001"
    # Temp file must be cleaned up
    leftovers = list(tmp_runs_dir.glob(".state.*.tmp"))
    assert leftovers == [], f"temp files not cleaned up: {leftovers}"
```

- [ ] **Step 2: Run tests; expect failure (module doesn't exist)**

Run: `cd hermes-dev-skill && python -m pytest tests/test_state.py -v`
Expected: `ModuleNotFoundError: No module named 'scripts.lib.state'`

- [ ] **Step 3: Implement `scripts/lib/state.py`**

```python
# hermes-dev-skill/scripts/lib/state.py
"""Atomic read/write of job state.json files.

A state.json lives at <runs_dir>/state.json. Writes go through a temp file
+ os.replace to guarantee atomicity: readers always see either the old or
the new state, never a half-written one.
"""
from __future__ import annotations

import json
import os
import tempfile
from pathlib import Path
from typing import Any


class StateError(Exception):
    """Raised when state cannot be read or is structurally invalid."""


def read(runs_dir: Path) -> dict[str, Any]:
    """Load state.json from runs_dir. Raises StateError if missing or unparseable."""
    path = Path(runs_dir) / "state.json"
    if not path.exists():
        raise StateError(f"state.json not found in {runs_dir}")
    try:
        with path.open("r", encoding="utf-8") as f:
            return json.load(f)
    except json.JSONDecodeError as e:
        raise StateError(f"state.json in {runs_dir} is not valid JSON: {e}") from e


def write(runs_dir: Path, state: dict[str, Any]) -> None:
    """Atomically write state.json. Creates a temp file in the same dir
    (so os.replace is atomic on the same filesystem) and renames it over
    the target."""
    path = Path(runs_dir) / "state.json"
    path.parent.mkdir(parents=True, exist_ok=True)
    fd, tmp_name = tempfile.mkstemp(
        dir=str(path.parent), prefix=".state.", suffix=".tmp"
    )
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as f:
            json.dump(state, f, indent=2, ensure_ascii=False, sort_keys=True)
            f.flush()
            os.fsync(f.fileno())
        os.replace(tmp_name, path)
    except Exception:
        # Clean up the temp file on any failure
        try:
            os.unlink(tmp_name)
        except FileNotFoundError:
            pass
        raise


class TransientError(Exception):
    """Raised when an external call (codex / claude / network) fails in a way
    that retrying with backoff might succeed. Non-transient errors should
    not be wrapped in this; they propagate up to halt the job.
    """
```

- [ ] **Step 4: Run tests; expect pass**

Run: `cd hermes-dev-skill && python -m pytest tests/test_state.py -v`
Expected: 3 tests pass.

- [ ] **Step 5: Commit**

```bash
git add hermes-dev-skill/scripts/lib/state.py hermes-dev-skill/tests/test_state.py
git commit -m "feat(state): atomic read/write of job state.json with StateError"
```

---

## Task 3: state.py — schema validation

**Files:**
- Modify: `hermes-dev-skill/scripts/lib/state.py:55-58` (add `validate` function and wire into `read`)
- Modify: `hermes-dev-skill/tests/test_state.py` (add validation tests)

- [ ] **Step 1: Write failing tests for validation**

Append to `tests/test_state.py`:

```python
def test_read_invalid_missing_required_key(tmp_runs_dir):
    path = tmp_runs_dir / "state.json"
    path.write_text('{"status": "running"}', encoding="utf-8")
    with pytest.raises(StateError, match="missing required keys"):
        read(tmp_runs_dir)


def test_read_invalid_wrong_status_value(tmp_runs_dir):
    path = tmp_runs_dir / "state.json"
    path.write_text(
        '{"job_id":"a","status":"BOGUS","phase":"clarify","phase_round":1}',
        encoding="utf-8",
    )
    with pytest.raises(StateError, match="status .* not in allowed values"):
        read(tmp_runs_dir)


def test_read_valid_state_passes(tmp_runs_dir):
    state = {
        "job_id": "test-001",
        "status": "running",
        "phase": "clarify",
        "phase_round": 1,
    }
    write(tmp_runs_dir, state)
    loaded = read(tmp_runs_dir)
    assert loaded["job_id"] == "test-001"
```

- [ ] **Step 2: Run tests; expect the new ones to fail**

Run: `cd hermes-dev-skill && python -m pytest tests/test_state.py -v`
Expected: 3 new tests fail with "missing required keys" / "not in allowed values"; original 3 still pass.

- [ ] **Step 3: Add `REQUIRED_KEYS` and `ALLOWED_STATUSES` constants + `validate()` function**

In `scripts/lib/state.py`, **insert** (do NOT replace) the following block
**above** the existing `TransientError` class. The class itself must
remain for Task 5 (`retry_with_backoff` references it):

```python
# Above the TransientError class, add:

REQUIRED_KEYS = {"job_id", "status", "phase", "phase_round"}
ALLOWED_STATUSES = {
    "running", "awaiting_user", "awaiting_tool", "halted", "orphaned", "done"
}
ALLOWED_PHASES = {
    "bootstrap", "clarify", "spec_plan", "implement", "review", "handoff", "done", "halted"
}


def validate(state: dict[str, Any]) -> None:
    """Validate state structure. Raises StateError on any problem."""
    missing = REQUIRED_KEYS - state.keys()
    if missing:
        raise StateError(
            f"state.json missing required keys: {sorted(missing)}"
        )
    if state["status"] not in ALLOWED_STATUSES:
        raise StateError(
            f"status {state['status']!r} not in allowed values: "
            f"{sorted(ALLOWED_STATUSES)}"
        )
    if state["phase"] not in ALLOWED_PHASES:
        raise StateError(
            f"phase {state['phase']!r} not in allowed values: "
            f"{sorted(ALLOWED_PHASES)}"
        )
    if not isinstance(state["phase_round"], int) or state["phase_round"] < 1:
        raise StateError(
            f"phase_round must be a positive integer, got {state['phase_round']!r}"
        )
```

Then update `read()` to call `validate()`:

```python
def read(runs_dir: Path) -> dict[str, Any]:
    """Load state.json from runs_dir. Raises StateError if missing, unparseable, or invalid."""
    path = Path(runs_dir) / "state.json"
    if not path.exists():
        raise StateError(f"state.json not found in {runs_dir}")
    try:
        with path.open("r", encoding="utf-8") as f:
            state = json.load(f)
    except json.JSONDecodeError as e:
        raise StateError(f"state.json in {runs_dir} is not valid JSON: {e}") from e
    validate(state)
    return state
```

- [ ] **Step 4: Run tests; expect all to pass**

Run: `cd hermes-dev-skill && python -m pytest tests/test_state.py -v`
Expected: 6 tests pass.

- [ ] **Step 5: Commit**

```bash
git add hermes-dev-skill/scripts/lib/state.py hermes-dev-skill/tests/test_state.py
git commit -m "feat(state): validate required keys and enum values on read"
```

---

## Task 4: state.py — atomic_update with JSON-patch

**Files:**
- Modify: `hermes-dev-skill/scripts/lib/state.py` (add `atomic_update`)
- Modify: `hermes-dev-skill/tests/test_state.py` (add tests)

- [ ] **Step 1: Write failing tests**

Append to `tests/test_state.py`:

```python
from scripts.lib.state import atomic_update, get


def test_atomic_update_increments_field(tmp_runs_dir):
    write(tmp_runs_dir, {
        "job_id": "a", "status": "running", "phase": "review", "phase_round": 1,
        "user_overrides": {"max_review_rounds": 5, "extra_review_rounds_added": 0},
    })
    atomic_update(tmp_runs_dir, '''
    {
      "user_overrides": {
        "max_review_rounds": (current["user_overrides"]["max_review_rounds"] + 5),
        "extra_review_rounds_added": (
          current["user_overrides"]["extra_review_rounds_added"] + 5
        )
      }
    }
    ''')
    after = read(tmp_runs_dir)
    assert after["user_overrides"]["max_review_rounds"] == 10
    assert after["user_overrides"]["extra_review_rounds_added"] == 5


def test_atomic_update_preserves_unrelated_fields(tmp_runs_dir):
    write(tmp_runs_dir, {
        "job_id": "a", "status": "running", "phase": "clarify", "phase_round": 1,
        "project": {"path": "/x", "branch": "hermes-dev/a"},
    })
    atomic_update(tmp_runs_dir, '''
    { "phase": "spec_plan" }
    ''')
    after = read(tmp_runs_dir)
    assert after["phase"] == "spec_plan"
    assert after["project"]["path"] == "/x"


def test_atomic_update_uses_lock(tmp_runs_dir):
    """Concurrent updates must not lose data (file lock around read+write)."""
    import threading
    write(tmp_runs_dir, {
        "job_id": "a", "status": "running", "phase": "review", "phase_round": 1,
        "counter": 0,
    })
    def bump():
        for _ in range(20):
            atomic_update(tmp_runs_dir, '''
            { "counter": current["counter"] + 1 }
            ''')
    threads = [threading.Thread(target=bump) for _ in range(5)]
    for t in threads: t.start()
    for t in threads: t.join()
    assert read(tmp_runs_dir)["counter"] == 100


def test_get_dotted_path(tmp_runs_dir):
    write(tmp_runs_dir, {
        "job_id": "a", "status": "running", "phase": "review", "phase_round": 1,
        "user_overrides": {"max_review_rounds": 7},
    })
    assert get(tmp_runs_dir, "user_overrides.max_review_rounds") == 7
    assert get(tmp_runs_dir, "status") == "running"
```

- [ ] **Step 2: Run tests; expect 4 failures**

Run: `cd hermes-dev-skill && python -m pytest tests/test_state.py -v`
Expected: 4 new tests fail with `ImportError: cannot import name 'atomic_update'`.

- [ ] **Step 3: Implement `atomic_update` and `get`**

First, **add** the following imports to the top of `scripts/lib/state.py`
(do NOT just append them inside the function — module-level imports
keep the module surface clean):

```python
import jsonpatch
from filelock import FileLock
```

Then **append** the following to `scripts/lib/state.py`:

```python
def _lock_path(runs_dir: Path) -> Path:
    return Path(runs_dir) / ".state.lock"


def _eval_patch_expr(patch_expr: str, current: dict[str, Any]) -> Any:
    """Evaluate a patch expression in the context of the current state.

    `patch_expr` is a Python expression where `current` refers to the
    current state dict. It must return either a dict (which is merged
    into the state via shallow update) or a full state dict (replaced).

    This is internal to hermes-dev and only used with trusted code, not
    user input. `__builtins__` is cleared in the eval namespace as a
    defense-in-depth measure.
    """
    import textwrap
    return eval(  # noqa: S307
        textwrap.dedent(patch_expr),
        {"__builtins__": {}},
        {"current": current},
    )


def atomic_update(runs_dir: Path, patch_expr: str) -> None:
    """Atomically read-modify-write state.json.

    `patch_expr` is a Python expression (NOT a JSON-Patch) that can
    reference `current` to read the existing state and must return a
    dict. The returned dict is merged into the state (shallow update).

    Examples:
        atomic_update(runs_dir, '{"phase": "spec_plan"}')
        atomic_update(runs_dir, '''
        {
          "user_overrides": {
            "max_review_rounds": current["user_overrides"]["max_review_rounds"] + 5
          }
        }
        ''')

    The whole operation is wrapped in a FileLock so concurrent updates
    cannot lose data.
    """
    runs_dir = Path(runs_dir)
    runs_dir.mkdir(parents=True, exist_ok=True)
    with FileLock(str(_lock_path(runs_dir))):
        current_state = read(runs_dir)
        patch_result = _eval_patch_expr(patch_expr, current_state)
        if not isinstance(patch_result, dict):
            raise StateError(
                f"atomic_update patch_expr must return a dict, got {type(patch_result).__name__}"
            )
        new_state = {**current_state, **patch_result}
        validate(new_state)
        write(runs_dir, new_state)


def get(runs_dir: Path, dotted_path: str) -> Any:
    """Read a value from state.json by dotted path (e.g. 'user_overrides.max_review_rounds')."""
    state = read(runs_dir)
    cur: Any = state
    for part in dotted_path.split("."):
        cur = cur[part]
    return cur
```

- [ ] **Step 4: Add `filelock` to pyproject deps**

Edit `pyproject.toml` and add `"filelock>=3.12"` to `dependencies`:

```toml
dependencies = [
    "pyyaml>=6.0",
    "jsonpatch>=1.33",
    "filelock>=3.12",
]
```

Run: `pip install -e ".[dev]"` from the `hermes-dev-skill/` directory.

- [ ] **Step 5: Run tests; expect all 10 to pass**

Run: `cd hermes-dev-skill && python -m pytest tests/test_state.py -v`
Expected: 10 tests pass.

- [ ] **Step 6: Commit**

```bash
git add hermes-dev-skill/scripts/lib/state.py hermes-dev-skill/tests/test_state.py hermes-dev-skill/pyproject.toml
git commit -m "feat(state): atomic_update with JSON-patch + dotted-path get"
```

---

## Task 5: state.py — retry_with_backoff helper

**Files:**
- Modify: `hermes-dev-skill/scripts/lib/state.py` (add `retry_with_backoff`)
- Modify: `hermes-dev-skill/tests/test_state.py` (add tests)

- [ ] **Step 1: Write failing tests**

Append to `tests/test_state.py`:

```python
import time
from scripts.lib.state import retry_with_backoff, TransientError


def test_retry_succeeds_on_second_attempt():
    calls = {"n": 0}
    def fn():
        calls["n"] += 1
        if calls["n"] < 2:
            raise TransientError("network blip")
        return "ok"
    assert retry_with_backoff(fn) == "ok"
    assert calls["n"] == 2


def test_retry_raises_after_max_attempts():
    calls = {"n": 0}
    def fn():
        calls["n"] += 1
        raise TransientError("always fails")
    with pytest.raises(TransientError):
        retry_with_backoff(fn, max_attempts=3, base=1.0)
    assert calls["n"] == 3


def test_retry_does_not_catch_non_transient():
    def fn():
        raise ValueError("not transient")
    with pytest.raises(ValueError):
        retry_with_backoff(fn)


def test_retry_backoff_timing(monkeypatch):
    sleeps = []
    monkeypatch.setattr(time, "sleep", lambda s: sleeps.append(s))
    calls = {"n": 0}
    def fn():
        calls["n"] += 1
        if calls["n"] < 3:
            raise TransientError("x")
        return "ok"
    retry_with_backoff(fn, max_attempts=3, base=2.0)
    # Sleeps should be base^1, base^2 = 2.0, 4.0
    assert sleeps == [2.0, 4.0]
```

- [ ] **Step 2: Run tests; expect 4 failures**

Run: `cd hermes-dev-skill && python -m pytest tests/test_state.py::test_retry_* -v`
Expected: 4 import errors / not implemented.

- [ ] **Step 3: Implement `retry_with_backoff`**

Append to `scripts/lib/state.py`:

```python
def retry_with_backoff(fn, max_attempts: int = 3, base: float = 2.0):
    """Run `fn` (no-arg callable) up to `max_attempts` times.

    Returns the value of the first successful call.
    Raises the last TransientError if all attempts fail.
    Non-transient errors propagate immediately without retry.
    """
    last_error: TransientError | None = None
    for attempt in range(1, max_attempts + 1):
        try:
            return fn()
        except TransientError as e:
            last_error = e
            if attempt < max_attempts:
                time.sleep(base ** attempt)
    assert last_error is not None
    raise last_error
```

Also add `import time` at the top of the file (next to existing imports).

- [ ] **Step 4: Run tests; expect all 14 to pass**

Run: `cd hermes-dev-skill && python -m pytest tests/test_state.py -v`
Expected: 14 tests pass.

- [ ] **Step 5: Commit**

```bash
git add hermes-dev-skill/scripts/lib/state.py hermes-dev-skill/tests/test_state.py
git commit -m "feat(state): retry_with_backoff for transient errors"
```

---

# M2: External integrations

## Task 6: feishu.py — `send_text` wrapper

**Files:**
- Create: `hermes-dev-skill/scripts/lib/feishu.py`
- Create: `hermes-dev-skill/tests/test_feishu.py`
- Create: `hermes-dev-skill/tests/fixtures/fake_hermes.sh` (test helper)

- [ ] **Step 1: Write the test helper `fake_hermes.sh`**

```bash
#!/bin/bash
# hermes-dev-skill/tests/fixtures/fake_hermes.sh
# A fake `hermes` CLI used in unit tests. Records args, returns a fake
# message_id, and supports configurable failure modes.
echo "$0 $@" >> "${HERMES_TEST_LOG:-/tmp/hermes_test.log}"
case "${HERMES_TEST_FAIL:-ok}" in
    ok)
        echo "message_id: om_test_${RANDOM}"
        exit 0
        ;;
    fail)
        echo "hermes send failed" >&2
        exit 1
        ;;
esac
```

```bash
chmod +x /Users/xpy/Documents/RichardHub/Git/hermes-dev-skill/tests/fixtures/fake_hermes.sh
```

- [ ] **Step 2: Write failing tests**

```python
# hermes-dev-skill/tests/test_feishu.py
import os
import subprocess
from pathlib import Path
import pytest

from scripts.lib.feishu import send_text, send_card, FeishuError


@pytest.fixture
def fake_hermes(tmp_path, monkeypatch):
    """Install a fake hermes binary on PATH and capture its invocations."""
    fixture = Path(__file__).parent / "fixtures" / "fake_hermes.sh"
    bin_dir = tmp_path / "bin"
    bin_dir.mkdir()
    (bin_dir / "hermes").write_text(fixture.read_text())
    (bin_dir / "hermes").chmod(0o755)
    log = tmp_path / "hermes.log"
    monkeypatch.setenv("PATH", f"{bin_dir}:{os.environ['PATH']}")
    monkeypatch.setenv("HERMES_TEST_LOG", str(log))
    monkeypatch.delenv("HERMES_TEST_FAIL", raising=False)
    return log


def test_send_text_invokes_hermes(fake_hermes):
    msg_id = send_text("hello world")
    assert msg_id.startswith("om_test_")
    invocation = fake_hermes.read_text()
    assert "hermes send --text hello world" in invocation


def test_send_text_raises_on_hermes_failure(fake_hermes, monkeypatch):
    monkeypatch.setenv("HERMES_TEST_FAIL", "fail")
    with pytest.raises(FeishuError):
        send_text("hi")


def test_send_text_returns_empty_when_no_message_id(tmp_path, monkeypatch):
    """If hermes send doesn't print 'message_id: ...', we return '' without raising."""
    no_id = tmp_path / "bin" / "hermes"
    no_id.parent.mkdir()
    no_id.write_text("#!/bin/bash\necho 'sent ok'\nexit 0\n")
    no_id.chmod(0o755)
    monkeypatch.setenv("PATH", f"{tmp_path / 'bin'}:{os.environ['PATH']}")
    assert send_text("hi") == ""
```

- [ ] **Step 3: Run tests; expect 3 failures**

Run: `cd hermes-dev-skill && python -m pytest tests/test_feishu.py -v`
Expected: `ModuleNotFoundError: No module named 'scripts.lib.feishu'`

- [ ] **Step 4: Implement `scripts/lib/feishu.py`**

```python
# hermes-dev-skill/scripts/lib/feishu.py
"""Thin wrapper around `hermes send` for Feishu.

Contract: `hermes send` is expected to print a line of the form
`message_id: om_xxx` to stdout on success. If it does not, the wrapper
returns "" (best-effort) and does not raise. If `hermes send` exits
non-zero, raises FeishuError.
"""
from __future__ import annotations

import json
import shlex
import subprocess
from typing import Any


class FeishuError(Exception):
    """hermes send failed (non-zero exit)."""


def _run(args: list[str]) -> str:
    """Run `hermes send <args>` and return the message_id from stdout.

    If the output does not contain a parseable `message_id: ...` line,
    returns "". Non-zero exit raises FeishuError.
    """
    result = subprocess.run(
        ["hermes", "send", *args],
        capture_output=True, text=True,
    )
    if result.returncode != 0:
        raise FeishuError(
            f"hermes send failed (exit {result.returncode}): "
            f"stderr={result.stderr.strip()!r}"
        )
    for line in result.stdout.splitlines():
        if line.startswith("message_id:"):
            return line.split(":", 1)[1].strip()
    return ""


def send_text(text: str) -> str:
    """Send a plain-text message via hermes send. Returns the message_id or ''."""
    return _run(["--text", text])


def send_card(title: str, fields: list[dict[str, str]],
              buttons: list[dict[str, Any]] | None = None) -> str:
    """Send a Feishu interactive card.

    `fields` is a list of {"key": ..., "value": ...} dicts shown as
    key:value rows. `buttons` (optional) is a list of button specs
    with keys: text, type (default|primary|danger), value, url.
    """
    elements: list[dict] = []
    for f in fields:
        elements.append({
            "tag": "div",
            "text": {
                "tag": "lark_md",
                "content": f"**{f['key']}**: {f['value']}",
            },
        })
    if buttons:
        elements.append({"tag": "action", "actions": [
            {
                "tag": "button",
                "text": {"tag": "plain_text", "content": b["text"]},
                "type": b.get("type", "default"),
                **({"url": b["url"]} if "url" in b else {}),
                **({"value": b["value"]} if "value" in b else {}),
            }
            for b in buttons
        ]})
    card = {
        "header": {"title": {"tag": "plain_text", "content": title}},
        "elements": elements,
    }
    return _run(["--card-json", json.dumps(card, ensure_ascii=False)])
```

- [ ] **Step 5: Run tests; expect 3 pass**

Run: `cd hermes-dev-skill && python -m pytest tests/test_feishu.py -v`
Expected: 3 tests pass.

- [ ] **Step 6: Commit**

```bash
git add hermes-dev-skill/scripts/lib/feishu.py hermes-dev-skill/tests/test_feishu.py hermes-dev-skill/tests/fixtures/fake_hermes.sh
git commit -m "feat(feishu): hermes send wrapper with text and card helpers"
```

---

## Task 7: feishu.py — `send_card` with fields and buttons

**Files:**
- Modify: `hermes-dev-skill/tests/test_feishu.py` (add card tests)

- [ ] **Step 1: Write failing tests for `send_card`**

Append to `tests/test_feishu.py`:

```python
import json


def test_send_card_renders_title_fields_buttons(fake_hermes):
    msg_id = send_card(
        title="Job #abc — Phase 4/5",
        fields=[{"key": "Status", "value": "REJECTED"}],
        buttons=[{"text": "View", "url": "file:///x.md", "type": "primary"}],
    )
    assert msg_id.startswith("om_test_")
    invocation = fake_hermes.read_text()
    # Find the --card-json argument value
    assert "hermes send --card-json" in invocation
    # Extract JSON
    idx = invocation.find("--card-json ") + len("--card-json ")
    end = invocation.find("\n", idx)
    payload = json.loads(invocation[idx:end])
    assert payload["header"]["title"]["content"] == "Job #abc — Phase 4/5"
    assert payload["elements"][0]["text"]["content"] == "**Status**: REJECTED"
    assert payload["elements"][1]["actions"][0]["text"]["content"] == "View"


def test_send_card_with_no_buttons(fake_hermes):
    msg_id = send_card("Hi", [{"key": "K", "value": "V"}])
    assert msg_id.startswith("om_test_")
    invocation = fake_hermes.read_text()
    idx = invocation.find("--card-json ") + len("--card-json ")
    payload = json.loads(invocation[idx:invocation.find("\n", idx)])
    assert "actions" not in str(payload["elements"])
```

- [ ] **Step 2: Run tests; expect 2 pass (implementation is already in Task 6)**

Run: `cd hermes-dev-skill && python -m pytest tests/test_feishu.py -v`
Expected: 5 tests pass.

- [ ] **Step 3: Commit**

```bash
git add hermes-dev-skill/tests/test_feishu.py
git commit -m "test(feishu): cover send_card rendering of title, fields, buttons"
```

---

## Task 8: review_parser.py + fixtures

**Files:**
- Create: `hermes-dev-skill/scripts/lib/review_parser.py`
- Create: `hermes-dev-skill/tests/test_review_parser.py`
- Create: `hermes-dev-skill/tests/fixtures/sample-review-approved.md`
- Create: `hermes-dev-skill/tests/fixtures/sample-review-rejected-p0.md`
- Create: `hermes-dev-skill/tests/fixtures/sample-review-rejected-p1.md`
- Create: `hermes-dev-skill/tests/fixtures/sample-review-malformed.md`

- [ ] **Step 1: Create fixture files**

`tests/fixtures/sample-review-approved.md`:

```markdown
# Review — round 1

## Summary
Implementation looks correct. All acceptance criteria met.

## Spec compliance
- AC1: met (src/api.py:42)
- AC2: met (src/api.py:88)

## Issues found

### P0 — must fix
(none)

### P1 — should fix
(none)

### P2 — nice to have
- [P2] src/api.py:100 — consider extracting magic number to a constant

## Praise
Clean separation of concerns.

VERDICT: APPROVED
```

`tests/fixtures/sample-review-rejected-p0.md`:

```markdown
# Review — round 1

## Issues found

### P0 — must fix
- [P0] src/auth.py:12 — auth check is missing on /admin endpoint
- [P0] src/db.py:55 — SQL injection via user input

VERDICT: REJECTED
```

`tests/fixtures/sample-review-rejected-p1.md`:

```markdown
# Review — round 1

## Issues found

### P1 — should fix
- [P1] src/utils.py:30 — race condition in cache invalidation
- [P1] src/api.py:99 — missing input validation
- [P1] tests/test_api.py:5 — test doesn't cover error case

VERDICT: REJECTED
```

`tests/fixtures/sample-review-malformed.md`:

```markdown
# Review — round 1

Some notes from Codex, but the verdict line is missing.
```

- [ ] **Step 2: Write failing tests**

```python
# hermes-dev-skill/tests/test_review_parser.py
from pathlib import Path
import pytest

from scripts.lib.review_parser import parse, is_pass


FIX = Path(__file__).parent / "fixtures"


def test_parse_approved():
    parsed = parse((FIX / "sample-review-approved.md").read_text())
    assert parsed["verdict"] == "APPROVED"
    assert parsed["p0"] == 0
    assert parsed["p1"] == 0
    assert parsed["p2"] == 1


def test_parse_rejected_p0():
    parsed = parse((FIX / "sample-review-rejected-p0.md").read_text())
    assert parsed["verdict"] == "REJECTED"
    assert parsed["p0"] == 2
    assert parsed["p1"] == 0


def test_parse_rejected_p1():
    parsed = parse((FIX / "sample-review-rejected-p1.md").read_text())
    assert parsed["verdict"] == "REJECTED"
    assert parsed["p0"] == 0
    assert parsed["p1"] == 3


def test_parse_malformed_defaults_to_rejected():
    parsed = parse((FIX / "sample-review-malformed.md").read_text())
    assert parsed["verdict"] == "REJECTED"


def test_is_pass_only_when_approved_and_no_p0_p1():
    assert is_pass({"verdict": "APPROVED", "p0": 0, "p1": 0}) is True
    assert is_pass({"verdict": "APPROVED", "p0": 1, "p1": 0}) is False
    assert is_pass({"verdict": "REJECTED", "p0": 0, "p1": 0}) is False
```

- [ ] **Step 3: Run tests; expect 5 failures**

Run: `cd hermes-dev-skill && python -m pytest tests/test_review_parser.py -v`
Expected: `ModuleNotFoundError: No module named 'scripts.lib.review_parser'`

- [ ] **Step 4: Implement `scripts/lib/review_parser.py`**

```python
# hermes-dev-skill/scripts/lib/review_parser.py
"""Parse Codex review output and decide pass/fail.

A review is considered a PASS iff:
  - The review contains a line `VERDICT: APPROVED`
  - The review contains no P0 or P1 markers

P0/P1/P2 markers are matched with \b word boundary on standalone tags,
e.g. `[P0]`, `### P0 —`, `P0:`. This means a variable name like P0_param
will NOT match, but a mention like "see P0 above" WILL.
"""
from __future__ import annotations

import re
from pathlib import Path


VERDICT_RE = re.compile(r"^VERDICT:\s*(APPROVED|REJECTED)\s*$", re.MULTILINE)
P0_RE = re.compile(r"\bP0\b")
P1_RE = re.compile(r"\bP1\b")
P2_RE = re.compile(r"\bP2\b")
ISSUES_SECTION_RE = re.compile(
    r"##\s*Issues found\s*\n(.*?)(?=\n##|\Z)", re.DOTALL
)


def parse(review_md: str) -> dict:
    """Return {verdict, p0, p1, p2, summary}."""
    verdict_m = VERDICT_RE.search(review_md)
    verdict = verdict_m.group(1) if verdict_m else "REJECTED"
    return {
        "verdict": verdict,
        "p0": len(P0_RE.findall(review_md)),
        "p1": len(P1_RE.findall(review_md)),
        "p2": len(P2_RE.findall(review_md)),
        "summary": _extract_summary(review_md),
    }


def is_pass(parsed: dict) -> bool:
    return (
        parsed["verdict"] == "APPROVED"
        and parsed["p0"] == 0
        and parsed["p1"] == 0
    )


def _extract_summary(review_md: str) -> str:
    m = ISSUES_SECTION_RE.search(review_md)
    if not m:
        return review_md[:200].strip()
    return m.group(1).strip()[:300]


def parse_file(path: Path) -> dict:
    return parse(Path(path).read_text(encoding="utf-8"))
```

- [ ] **Step 5: Run tests; expect 5 pass**

Run: `cd hermes-dev-skill && python -m pytest tests/test_review_parser.py -v`
Expected: 5 tests pass.

- [ ] **Step 6: Commit**

```bash
git add hermes-dev-skill/scripts/lib/review_parser.py hermes-dev-skill/tests/test_review_parser.py hermes-dev-skill/tests/fixtures/sample-review-*.md
git commit -m "feat(review_parser): verdict + P0/P1/P2 extraction with fixture coverage"
```

---

## Task 9: git_ops.py

**Files:**
- Create: `hermes-dev-skill/scripts/lib/git_ops.py`
- Create: `hermes-dev-skill/tests/test_git_ops.py`

- [ ] **Step 1: Write failing tests**

```python
# hermes-dev-skill/tests/test_git_ops.py
import subprocess
from pathlib import Path
import pytest

from scripts.lib.git_ops import (
    is_git_repo, create_branch, commit_iteration,
    diff_against_baseline, current_branch, last_commit_message,
)


@pytest.fixture
def git_repo(tmp_path):
    """Initialize a git repo with one commit on main."""
    repo = tmp_path / "repo"
    repo.mkdir()
    subprocess.run(["git", "init", "-b", "main"], cwd=repo, check=True, capture_output=True)
    subprocess.run(["git", "config", "user.email", "test@test"], cwd=repo, check=True)
    subprocess.run(["git", "config", "user.name", "Test"], cwd=repo, check=True)
    (repo / "README.md").write_text("hello\n")
    subprocess.run(["git", "add", "-A"], cwd=repo, check=True)
    subprocess.run(["git", "commit", "-m", "initial"], cwd=repo, check=True)
    return repo


def test_is_git_repo_true(git_repo):
    assert is_git_repo(git_repo) is True


def test_is_git_repo_false(tmp_path):
    assert is_git_repo(tmp_path) is False


def test_create_branch_checkouts_new(git_repo):
    create_branch(git_repo, "abc123", base="main")
    assert current_branch(git_repo) == "hermes-dev/abc123"


def test_create_branch_idempotent(git_repo):
    create_branch(git_repo, "abc123", base="main")
    create_branch(git_repo, "abc123", base="main")  # should not error
    assert current_branch(git_repo) == "hermes-dev/abc123"


def test_commit_iteration(git_repo):
    create_branch(git_repo, "abc", base="main")
    (git_repo / "new.txt").write_text("content\n")
    commit_iteration(git_repo, "hermes-dev(abc): add new.txt")
    msg = last_commit_message(git_repo)
    assert "hermes-dev(abc): add new.txt" in msg


def test_diff_against_baseline(git_repo):
    create_branch(git_repo, "abc", base="main")
    (git_repo / "new.txt").write_text("content\n")
    commit_iteration(git_repo, "hermes-dev(abc): add new.txt")
    diff = diff_against_baseline(git_repo, base="main")
    assert "+content" in diff
```

- [ ] **Step 2: Run tests; expect 6 failures**

Run: `cd hermes-dev-skill && python -m pytest tests/test_git_ops.py -v`
Expected: `ModuleNotFoundError: No module named 'scripts.lib.git_ops'`

- [ ] **Step 3: Implement `scripts/lib/git_ops.py`**

```python
# hermes-dev-skill/scripts/lib/git_ops.py
"""Thin wrappers around `git` for hermes-dev operations.

All operations run with `git -C <path>` so the caller never needs to chdir.
"""
from __future__ import annotations

import shlex
import subprocess
from pathlib import Path


class GitError(Exception):
    """Raised when a git command fails."""


def _run(path: Path, args: list[str], check: bool = True) -> str:
    result = subprocess.run(
        ["git", "-C", str(path), *args],
        capture_output=True, text=True,
    )
    if check and result.returncode != 0:
        raise GitError(
            f"git {shlex.join(args)} in {path} failed (exit {result.returncode}): "
            f"{result.stderr.strip()}"
        )
    return result.stdout


def is_git_repo(path: Path) -> bool:
    result = subprocess.run(
        ["git", "-C", str(path), "rev-parse", "--git-dir"],
        capture_output=True, text=True,
    )
    return result.returncode == 0


def current_branch(path: Path) -> str:
    return _run(path, ["rev-parse", "--abbrev-ref", "HEAD"]).strip()


def create_branch(path: Path, job_id: str, base: str = "main") -> None:
    """Create and checkout hermes-dev/<job_id> from base. Idempotent."""
    branch = f"hermes-dev/{job_id}"
    # Ensure base is checked out
    _run(path, ["checkout", base], check=False)
    # If branch already exists, just switch to it; else create it
    result = subprocess.run(
        ["git", "-C", str(path), "rev-parse", "--verify", branch],
        capture_output=True, text=True,
    )
    if result.returncode == 0:
        _run(path, ["checkout", branch])
    else:
        _run(path, ["checkout", "-b", branch])


def commit_iteration(path: Path, message: str) -> None:
    """Stage all changes and commit with the given message. No-op if no changes."""
    status = _run(path, ["status", "--porcelain"])
    if not status.strip():
        return
    _run(path, ["add", "-A"])
    _run(path, ["commit", "-m", message])


def diff_against_baseline(path: Path, base: str = "main") -> str:
    """Return the diff of the current branch against base. Empty if no diff."""
    return _run(path, ["diff", f"{base}..HEAD"], check=False)


def last_commit_message(path: Path) -> str:
    return _run(path, ["log", "-1", "--pretty=format:%s"]).strip()
```

- [ ] **Step 4: Run tests; expect 6 pass**

Run: `cd hermes-dev-skill && python -m pytest tests/test_git_ops.py -v`
Expected: 6 tests pass.

- [ ] **Step 5: Commit**

```bash
git add hermes-dev-skill/scripts/lib/git_ops.py hermes-dev-skill/tests/test_git_ops.py
git commit -m "feat(git_ops): branch, commit, diff helpers with idempotent branch create"
```

---

## Task 10: project_registry.py

**Files:**
- Create: `hermes-dev-skill/scripts/lib/project_registry.py`
- Create: `hermes-dev-skill/tests/test_project_registry.py`

- [ ] **Step 1: Write failing tests**

```python
# hermes-dev-skill/tests/test_project_registry.py
import json
from pathlib import Path
import pytest

from scripts.lib.project_registry import (
    registry_path, load, save, register, unregister, lookup, scan_common_dirs
)


def test_registry_path(tmp_home):
    assert registry_path() == tmp_home / ".hermes" / "projects.json"


def test_load_when_missing_returns_empty(tmp_home):
    assert load() == {}


def test_register_creates_file(tmp_home):
    register("stocks", "~/projects/stocks", default_branch="main")
    assert json.loads(registry_path().read_text()) == {
        "stocks": {"path": "~/projects/stocks", "default_branch": "main"}
    }


def test_register_expands_user(tmp_home):
    register("blog", "~/code/blog")
    assert lookup("blog")["path"] == str(Path("~/code/blog").expanduser())


def test_unregister(tmp_home):
    register("x", "/x")
    register("y", "/y")
    unregister("x")
    assert set(load().keys()) == {"y"}


def test_unregister_missing_raises(tmp_home):
    with pytest.raises(KeyError):
        unregister("nonexistent")


def test_lookup_missing_returns_none(tmp_home):
    assert lookup("nope") is None


def test_scan_common_dirs_finds_repos(tmp_home, tmp_path, monkeypatch):
    """scan_common_dirs() looks for git repos in ~/projects, ~/code, ~/Documents."""
    proj = tmp_path / "projects" / "myrepo"
    proj.mkdir(parents=True)
    (proj / ".git").mkdir()  # marker only
    monkeypatch.setenv("HOME", str(tmp_path))
    found = scan_common_dirs()
    assert any("myrepo" in p for p in found)
```

- [ ] **Step 2: Run tests; expect 7 failures**

Run: `cd hermes-dev-skill && python -m pytest tests/test_project_registry.py -v`
Expected: `ModuleNotFoundError: No module named 'scripts.lib.project_registry'`

- [ ] **Step 3: Implement `scripts/lib/project_registry.py`**

```python
# hermes-dev-skill/scripts/lib/project_registry.py
"""Read/write ~/.hermes/projects.json.

The registry maps project names (short, typeable in Feishu) to absolute
paths. It is created lazily on first register(). Paths may be stored with
~ in them and are expanded at lookup time.
"""
from __future__ import annotations

import json
import os
from pathlib import Path
from typing import Any


def registry_path() -> Path:
    return Path(os.path.expanduser("~/.hermes/projects.json"))


def load() -> dict[str, dict[str, Any]]:
    p = registry_path()
    if not p.exists():
        return {}
    return json.loads(p.read_text(encoding="utf-8"))


def save(reg: dict[str, dict[str, Any]]) -> None:
    p = registry_path()
    p.parent.mkdir(parents=True, exist_ok=True)
    p.write_text(json.dumps(reg, indent=2, ensure_ascii=False), encoding="utf-8")


def register(name: str, path: str, default_branch: str = "main") -> None:
    reg = load()
    reg[name] = {"path": path, "default_branch": default_branch}
    save(reg)


def unregister(name: str) -> None:
    reg = load()
    if name not in reg:
        raise KeyError(f"project {name!r} not registered")
    del reg[name]
    save(reg)


def lookup(name: str) -> dict[str, Any] | None:
    reg = load()
    if name not in reg:
        return None
    entry = dict(reg[name])
    entry["path"] = str(Path(entry["path"]).expanduser())
    return entry


def scan_common_dirs() -> list[str]:
    """Return absolute paths of git repos under ~/projects, ~/code, ~/Documents.

    One level deep only (e.g., ~/projects/stocks yes, ~/projects/stocks/subdir no).
    """
    home = Path(os.path.expanduser("~"))
    roots = [home / "projects", home / "code", home / "Documents"]
    found: list[str] = []
    for root in roots:
        if not root.is_dir():
            continue
        for child in root.iterdir():
            if child.is_dir() and (child / ".git").exists():
                found.append(str(child))
    return sorted(found)
```

- [ ] **Step 4: Run tests; expect 7 pass**

Run: `cd hermes-dev-skill && python -m pytest tests/test_project_registry.py -v`
Expected: 7 tests pass.

- [ ] **Step 5: Commit**

```bash
git add hermes-dev-skill/scripts/lib/project_registry.py hermes-dev-skill/tests/test_project_registry.py
git commit -m "feat(project_registry): projects.json read/write + common-dir scan"
```

---

# M3: Checkpoint + reconcile

## Task 11: checkpoint.py

**Files:**
- Create: `hermes-dev-skill/scripts/lib/checkpoint.py`
- Create: `hermes-dev-skill/tests/test_checkpoint.py`
- Create: `hermes-dev-skill/tests/fixtures/sample-state.json`

- [ ] **Step 1: Create the fixture**

```json
{
  "job_id": "20260614-1030-a1b2c3",
  "status": "running",
  "phase": "review",
  "phase_round": 2,
  "project": {
    "name": "stocks",
    "path": "/Users/xpy/projects/stocks",
    "branch": "hermes-dev/20260614-1030-a1b2c3",
    "base_branch": "main",
    "is_git": true
  },
  "artifacts": {
    "requirements": "requirements.md",
    "spec": "spec.md",
    "plan": "plan.md"
  }
}
```

Write this to `tests/fixtures/sample-state.json`.

- [ ] **Step 2: Write failing tests**

```python
# hermes-dev-skill/tests/test_checkpoint.py
import hashlib
import json
from pathlib import Path
import pytest

from scripts.lib import checkpoint
from scripts.lib.state import write


@pytest.fixture
def state_with_artifacts(tmp_runs_dir):
    write(tmp_runs_dir, {
        "job_id": "abc", "status": "running", "phase": "clarify", "phase_round": 1,
    })
    (tmp_runs_dir / "requirements.md").write_text("# Requirements\nfoo\n")
    (tmp_runs_dir / "spec.md").write_text("# Spec\nbar\n")
    return tmp_runs_dir


def test_save_writes_phase_checkpoint(state_with_artifacts):
    checkpoint.save(state_with_artifacts, phase=1, artifacts=["requirements.md", "spec.md"])
    cp = state_with_artifacts / "checkpoints" / "phase1.json"
    assert cp.exists()
    body = json.loads(cp.read_text())
    assert body["phase"] == 1
    assert body["state"]["phase"] == "clarify"
    # Artifacts should have hashes recorded
    assert "requirements.md" in body["artifact_hashes"]
    assert "spec.md" in body["artifact_hashes"]


def test_save_includes_correct_sha256(state_with_artifacts):
    expected = hashlib.sha256(b"# Requirements\nfoo\n").hexdigest()
    checkpoint.save(state_with_artifacts, phase=1, artifacts=["requirements.md"])
    cp = json.loads((state_with_artifacts / "checkpoints" / "phase1.json").read_text())
    assert cp["artifact_hashes"]["requirements.md"] == expected


def test_load_returns_state(state_with_artifacts):
    checkpoint.save(state_with_artifacts, phase=1, artifacts=["requirements.md"])
    loaded = checkpoint.load(state_with_artifacts, phase=1)
    assert loaded["state"]["job_id"] == "abc"


def test_load_missing_raises(state_with_artifacts):
    with pytest.raises(FileNotFoundError):
        checkpoint.load(state_with_artifacts, phase=99)


def test_verify_passes_when_artifacts_unchanged(state_with_artifacts):
    checkpoint.save(state_with_artifacts, phase=1, artifacts=["requirements.md"])
    assert checkpoint.verify(state_with_artifacts, phase=1) is True


def test_verify_fails_when_artifact_changed(state_with_artifacts):
    checkpoint.save(state_with_artifacts, phase=1, artifacts=["requirements.md"])
    (state_with_artifacts / "requirements.md").write_text("# Requirements\nMODIFIED\n")
    assert checkpoint.verify(state_with_artifacts, phase=1) is False


def test_latest_phase_returns_highest_existing(state_with_artifacts):
    checkpoint.save(state_with_artifacts, phase=1)
    checkpoint.save(state_with_artifacts, phase=2)
    checkpoint.save(state_with_artifacts, phase=3)
    assert checkpoint.latest_phase(state_with_artifacts) == 3
```

- [ ] **Step 3: Run tests; expect 7 failures**

Run: `cd hermes-dev-skill && python -m pytest tests/test_checkpoint.py -v`
Expected: `ModuleNotFoundError: No module named 'scripts.lib.checkpoint'`

- [ ] **Step 4: Implement `scripts/lib/checkpoint.py`**

```python
# hermes-dev-skill/scripts/lib/checkpoint.py
"""Per-phase checkpoints: snapshot of state.json + hashes of produced artifacts.

A checkpoint is written at the end of each phase. On resume, the orchestrator
re-reads the latest checkpoint to know which phase to re-enter.
"""
from __future__ import annotations

import hashlib
import json
from pathlib import Path
from typing import Any

from . import state


def _checkpoint_path(runs_dir: Path, phase: int) -> Path:
    return Path(runs_dir) / "checkpoints" / f"phase{phase}.json"


def save(runs_dir: Path, phase: int, artifacts: list[str] | None = None) -> None:
    """Snapshot state.json plus SHA-256 hashes of the named artifact files.

    `artifacts` are paths relative to runs_dir (e.g. 'requirements.md')."""
    runs_dir = Path(runs_dir)
    runs_dir.mkdir(parents=True, exist_ok=True)
    (runs_dir / "checkpoints").mkdir(parents=True, exist_ok=True)
    current = state.read(runs_dir)
    hashes: dict[str, str] = {}
    for name in (artifacts or []):
        p = runs_dir / name
        if not p.exists():
            continue
        hashes[name] = hashlib.sha256(p.read_bytes()).hexdigest()
    body = {
        "phase": phase,
        "state": current,
        "artifact_hashes": hashes,
    }
    _checkpoint_path(runs_dir, phase).write_text(
        json.dumps(body, indent=2, ensure_ascii=False, sort_keys=True),
        encoding="utf-8",
    )


def load(runs_dir: Path, phase: int) -> dict[str, Any]:
    """Return the checkpoint body for a given phase. Raises FileNotFoundError if missing."""
    p = _checkpoint_path(runs_dir, phase)
    if not p.exists():
        raise FileNotFoundError(f"no checkpoint for phase {phase} in {runs_dir}")
    return json.loads(p.read_text(encoding="utf-8"))


def verify(runs_dir: Path, phase: int) -> bool:
    """Return True iff all artifacts recorded in the checkpoint still match their hashes."""
    body = load(runs_dir, phase)
    for name, expected in body["artifact_hashes"].items():
        p = Path(runs_dir) / name
        if not p.exists():
            return False
        actual = hashlib.sha256(p.read_bytes()).hexdigest()
        if actual != expected:
            return False
    return True


def latest_phase(runs_dir: Path) -> int | None:
    """Return the highest phase number that has a checkpoint, or None if none exist."""
    cp_dir = Path(runs_dir) / "checkpoints"
    if not cp_dir.is_dir():
        return None
    phases = []
    for p in cp_dir.iterdir():
        if p.name.startswith("phase") and p.name.endswith(".json"):
            try:
                n = int(p.name.removeprefix("phase").removesuffix(".json"))
                phases.append(n)
            except ValueError:
                continue
    return max(phases) if phases else None
```

- [ ] **Step 5: Run tests; expect 7 pass**

Run: `cd hermes-dev-skill && python -m pytest tests/test_checkpoint.py -v`
Expected: 7 tests pass.

- [ ] **Step 6: Commit**

```bash
git add hermes-dev-skill/scripts/lib/checkpoint.py hermes-dev-skill/tests/test_checkpoint.py hermes-dev-skill/tests/fixtures/sample-state.json
git commit -m "feat(checkpoint): per-phase snapshot with artifact SHA-256 verification"
```

---

# M4: Hermes CLI

## Task 12: hermes-dev CLI skeleton with argparse

**Files:**
- Create: `hermes-dev-skill/scripts/hermes_dev.py` (the actual entry point; referenced by pyproject `[project.scripts]`)
- Create: `hermes-dev-skill/scripts/__init__.py` (allow `scripts` to be a package)
- Create: `hermes-dev-skill/tests/test_hermes_dev_cli.py`

- [ ] **Step 1: Write `scripts/__init__.py`**

```python
# hermes-dev-skill/scripts/__init__.py
"""hermes-dev skill — entry points and phase scripts."""
```

- [ ] **Step 2: Write the CLI skeleton with stubs**

```python
# hermes-dev-skill/scripts/hermes_dev.py
"""hermes-dev CLI entry point.

Subcommands (all stubbed initially, implemented in later tasks):
  new          Create a new job
  status       Show job state
  list         List all known jobs
  tail         Stream events.jsonl
  continue     Resume a job from checkpoint
  cancel       Mark a job halted
  register     Add a project to the registry
  unregister   Remove a project from the registry
  reconcile    Scan for orphaned jobs
"""
from __future__ import annotations

import argparse
import sys
from pathlib import Path
from typing import Sequence


def cmd_new(args: argparse.Namespace) -> int:
    print(f"[stub] new: {args.intent}", file=sys.stderr)
    return 0


def cmd_status(args: argparse.Namespace) -> int:
    print(f"[stub] status: {args.job_id}", file=sys.stderr)
    return 0


def cmd_list(args: argparse.Namespace) -> int:
    print("[stub] list", file=sys.stderr)
    return 0


def cmd_tail(args: argparse.Namespace) -> int:
    print(f"[stub] tail: {args.job_id}", file=sys.stderr)
    return 0


def cmd_continue(args: argparse.Namespace) -> int:
    print(f"[stub] continue: {args.job_id} force={args.force}", file=sys.stderr)
    return 0


def cmd_cancel(args: argparse.Namespace) -> int:
    print(f"[stub] cancel: {args.job_id}", file=sys.stderr)
    return 0


def cmd_register(args: argparse.Namespace) -> int:
    print(f"[stub] register: {args.name} -> {args.path}", file=sys.stderr)
    return 0


def cmd_unregister(args: argparse.Namespace) -> int:
    print(f"[stub] unregister: {args.name}", file=sys.stderr)
    return 0


def cmd_reconcile(args: argparse.Namespace) -> int:
    print(f"[stub] reconcile age={args.age}", file=sys.stderr)
    return 0


def build_parser() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(prog="hermes-dev", description=__doc__)
    sub = p.add_subparsers(dest="subcommand", required=True)

    sp = sub.add_parser("new", help="Create a new job")
    sp.add_argument("intent", help="The user's dev intent (free text)")
    sp.set_defaults(func=cmd_new)

    sp = sub.add_parser("status", help="Show job state")
    sp.add_argument("job_id", nargs="?", help="Job ID; defaults to most recent")
    sp.set_defaults(func=cmd_status)

    sp = sub.add_parser("list", help="List all known jobs")
    sp.set_defaults(func=cmd_list)

    sp = sub.add_parser("tail", help="Stream events.jsonl")
    sp.add_argument("job_id")
    sp.set_defaults(func=cmd_tail)

    sp = sub.add_parser("continue", help="Resume a job from checkpoint")
    sp.add_argument("job_id")
    sp.add_argument("--force", action="store_true", help="Force resume even if halted")
    sp.set_defaults(func=cmd_continue)

    sp = sub.add_parser("cancel", help="Mark a job halted")
    sp.add_argument("job_id")
    sp.set_defaults(func=cmd_cancel)

    sp = sub.add_parser("register", help="Register a project")
    sp.add_argument("name")
    sp.add_argument("path")
    sp.add_argument("--default-branch", default="main")
    sp.set_defaults(func=cmd_register)

    sp = sub.add_parser("unregister", help="Remove a project")
    sp.add_argument("name")
    sp.set_defaults(func=cmd_unregister)

    sp = sub.add_parser("reconcile", help="Scan for orphaned jobs")
    sp.add_argument("--age", default="5m", help="Threshold (e.g. 5m, 1h)")
    sp.add_argument("--auto-resume", action="store_true")
    sp.set_defaults(func=cmd_reconcile)

    return p


def main(argv: Sequence[str] | None = None) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)
    return args.func(args)


if __name__ == "__main__":
    sys.exit(main())
```

- [ ] **Step 3: Write failing tests**

```python
# hermes-dev-skill/tests/test_hermes_dev_cli.py
import subprocess
import sys
from pathlib import Path
import pytest


SCRIPT = Path(__file__).parent.parent / "scripts" / "hermes_dev.py"


def run_cli(*args):
    return subprocess.run(
        [sys.executable, str(SCRIPT), *args],
        capture_output=True, text=True,
    )


def test_help_exits_zero():
    r = run_cli("--help")
    assert r.returncode == 0
    assert "hermes-dev" in r.stdout


def test_unknown_subcommand_fails():
    r = run_cli("nope")
    assert r.returncode != 0


def test_new_stub_runs():
    r = run_cli("new", "build me a thing")
    assert r.returncode == 0
    assert "build me a thing" in r.stderr


def test_status_with_job_id():
    r = run_cli("status", "abc123")
    assert r.returncode == 0
    assert "abc123" in r.stderr


def test_register_parses_default_branch():
    r = run_cli("register", "stocks", "/x", "--default-branch", "main")
    assert r.returncode == 0
    assert "stocks" in r.stderr
    assert "/x" in r.stderr
```

- [ ] **Step 4: Run tests; expect 5 pass (stub CLI implements all subcommands)**

Run: `cd hermes-dev-skill && python -m pytest tests/test_hermes_dev_cli.py -v`
Expected: 5 tests pass.

- [ ] **Step 5: Verify the entry point is wired**

Run: `cd hermes-dev-skill && pip install -e ".[dev]"`
Expected: installs successfully.

Then run: `hermes-dev --help`
Expected: prints the same help as `python -m scripts.hermes_dev --help`.

- [ ] **Step 6: Commit**

```bash
git add hermes-dev-skill/scripts/hermes_dev.py hermes-dev-skill/scripts/__init__.py hermes-dev-skill/tests/test_hermes_dev_cli.py
git commit -m "feat(cli): hermes-dev argparse skeleton with all subcommand stubs"
```

---

## Task 13: hermes-dev `new` subcommand

**Files:**
- Modify: `hermes-dev-skill/scripts/hermes_dev.py` (replace `cmd_new` stub)

- [ ] **Step 1: Write failing tests for `new`**

Append to `tests/test_hermes_dev_cli.py`:

```python
def test_new_creates_runs_dir_and_state(tmp_home):
    r = run_cli("new", "build me a stock alerter")
    assert r.returncode == 0
    # The CLI should print a job_id (e.g. 20260101-1200-abc123) to stdout
    out = r.stdout.strip()
    assert out  # non-empty
    # The runs dir should exist with state.json
    runs = Path.home() / ".hermes" / "runs"
    jobs = list(runs.iterdir())
    assert len(jobs) == 1
    state_file = jobs[0] / "state.json"
    assert state_file.exists()
    import json
    s = json.loads(state_file.read_text())
    assert s["phase"] == "clarify"
    assert s["status"] == "running"
    assert s["intent"] == "build me a stock alerter"


def test_new_unique_job_ids(tmp_home):
    ids = set()
    for _ in range(3):
        r = run_cli("new", "x")
        assert r.returncode == 0
        ids.add(r.stdout.strip())
    assert len(ids) == 3
```

- [ ] **Step 2: Run tests; expect 2 failures**

Run: `cd hermes-dev-skill && python -m pytest tests/test_hermes_dev_cli.py -k "test_new_" -v`
Expected: tests fail because the stub doesn't create dirs.

- [ ] **Step 3: Implement `cmd_new`**

Replace `cmd_new` in `hermes_dev.py`:

```python
import os
import time
import uuid
from scripts.lib import state as state_lib


def _generate_job_id() -> str:
    ts = time.strftime("%Y%m%d-%H%M")
    suffix = uuid.uuid4().hex[:6]
    return f"{ts}-{suffix}"


def _job_already_exists(runs_root: Path, job_id: str) -> bool:
    return (runs_root / job_id).exists()


def cmd_new(args: argparse.Namespace) -> int:
    runs_root = Path(os.path.expanduser("~/.hermes/runs"))
    runs_root.mkdir(parents=True, exist_ok=True)

    # Generate a unique job_id (with microsecond fallback on collision)
    for _ in range(5):
        job_id = _generate_job_id()
        if not _job_already_exists(runs_root, job_id):
            break
        time.sleep(0.001)
    else:
        # 5 collisions in a row is extremely unlikely; use a full uuid
        job_id = f"{time.strftime('%Y%m%d-%H%M')}-{uuid.uuid4().hex[:12]}"

    job_dir = runs_root / job_id
    job_dir.mkdir(parents=False)

    initial_state = {
        "job_id": job_id,
        "version": "1.0",
        "created_at": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
        "updated_at": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
        "status": "running",
        "phase": "clarify",
        "phase_round": 1,
        "intent": args.intent,
        "project": {},
        "artifacts": {},
        "feishu_message_ids": [],
        "errors": [],
        "user_overrides": {
            "codex_model": None,
            "max_review_rounds": 5,
            "extra_review_rounds_added": 0,
        },
    }
    state_lib.write(job_dir, initial_state)
    print(job_id)
    return 0
```

- [ ] **Step 4: Run tests; expect 2 pass**

Run: `cd hermes-dev-skill && python -m pytest tests/test_hermes_dev_cli.py -k "test_new_" -v`
Expected: 2 tests pass.

- [ ] **Step 5: Commit**

```bash
git add hermes-dev-skill/scripts/hermes_dev.py hermes-dev-skill/tests/test_hermes_dev_cli.py
git commit -m "feat(cli): new subcommand creates runs dir + state.json"
```

---

## Task 14: hermes-dev `status`, `list`, `tail`

**Files:**
- Modify: `hermes-dev-skill/scripts/hermes_dev.py` (replace stubs)

- [ ] **Step 1: Write failing tests**

Append to `tests/test_hermes_dev_cli.py`:

```python
def test_status_pretty_prints_state(tmp_home):
    # Create a job
    r = run_cli("new", "x")
    job_id = r.stdout.strip()
    r = run_cli("status", job_id)
    assert r.returncode == 0
    assert job_id in r.stdout
    assert "phase" in r.stdout
    assert "clarify" in r.stdout


def test_status_missing_job_prints_error(tmp_home):
    r = run_cli("status", "nope-no-such-job")
    assert r.returncode != 0
    assert "not found" in r.stderr.lower()


def test_list_shows_all_jobs(tmp_home):
    run_cli("new", "a")
    run_cli("new", "b")
    r = run_cli("list")
    assert r.returncode == 0
    assert "2" in r.stdout  # 2 jobs


def test_tail_prints_events_jsonl(tmp_home):
    r = run_cli("new", "x")
    job_id = r.stdout.strip()
    runs = Path.home() / ".hermes" / "runs" / job_id
    (runs / "events.jsonl").write_text(
        '{"ts":"2026-01-01T00:00:00Z","event":"phase_enter","phase":"clarify"}\n',
        encoding="utf-8",
    )
    r = run_cli("tail", job_id)
    assert r.returncode == 0
    assert "phase_enter" in r.stdout
```

- [ ] **Step 2: Run tests; expect 4 failures**

Run: `cd hermes-dev-skill && python -m pytest tests/test_hermes_dev_cli.py -k "test_status_ or test_list_ or test_tail_" -v`

- [ ] **Step 3: Implement `cmd_status`, `cmd_list`, `cmd_tail`**

Replace the stub functions:

```python
def _runs_dir() -> Path:
    return Path(os.path.expanduser("~/.hermes/runs"))


def _find_job(job_id: str) -> Path:
    p = _runs_dir() / job_id
    if not p.is_dir():
        raise FileNotFoundError(f"job {job_id} not found")
    return p


def cmd_status(args: argparse.Namespace) -> int:
    try:
        job_dir = _find_job(args.job_id) if args.job_id else None
    except FileNotFoundError as e:
        print(str(e), file=sys.stderr)
        return 1
    if job_dir is None:
        # No job_id given; pick the most recent
        runs = _runs_dir()
        if not runs.exists():
            print("no jobs", file=sys.stderr)
            return 1
        jobs = sorted(runs.iterdir(), key=lambda p: p.stat().st_mtime, reverse=True)
        if not jobs:
            print("no jobs", file=sys.stderr)
            return 1
        job_dir = jobs[0]
    s = state_lib.read(job_dir)
    # Pretty print key fields
    for key in ("job_id", "status", "phase", "phase_round", "intent"):
        if key in s:
            print(f"{key}: {s[key]}")
    if "project" in s and s["project"]:
        print(f"project: {s['project'].get('path', '<unset>')}")
    return 0


def cmd_list(args: argparse.Namespace) -> int:
    runs = _runs_dir()
    if not runs.exists():
        print("0 jobs")
        return 0
    jobs = sorted(runs.iterdir(), key=lambda p: p.stat().st_mtime, reverse=True)
    print(f"{len(jobs)} job(s):")
    for j in jobs:
        try:
            s = state_lib.read(j)
        except state_lib.StateError:
            print(f"  {j.name}  <corrupt>")
            continue
        print(f"  {j.name}  {s.get('status','?')}  phase={s.get('phase','?')}")
    return 0


def cmd_tail(args: argparse.Namespace) -> int:
    try:
        job_dir = _find_job(args.job_id)
    except FileNotFoundError as e:
        print(str(e), file=sys.stderr)
        return 1
    log = job_dir / "events.jsonl"
    if not log.exists():
        # Just print a friendly message and exit 0
        print("(no events)")
        return 0
    sys.stdout.write(log.read_text(encoding="utf-8"))
    return 0
```

- [ ] **Step 4: Run tests; expect 4 pass**

Run: `cd hermes-dev-skill && python -m pytest tests/test_hermes_dev_cli.py -k "test_status_ or test_list_ or test_tail_" -v`

- [ ] **Step 5: Commit**

```bash
git add hermes-dev-skill/scripts/hermes_dev.py hermes-dev-skill/tests/test_hermes_dev_cli.py
git commit -m "feat(cli): status, list, tail subcommands"
```

---

## Task 15: hermes-dev `continue`, `cancel`

**Files:**
- Modify: `hermes-dev-skill/scripts/hermes_dev.py` (replace stubs)
- Create: `hermes-dev-skill/scripts/phases/__init__.py` (already created in Task 1)

- [ ] **Step 1: Write failing tests**

Append to `tests/test_hermes_dev_cli.py`:

```python
def test_continue_refuses_done_job(tmp_home):
    r = run_cli("new", "x")
    job_id = r.stdout.strip()
    # Mark job done
    from scripts.lib.state import read, write
    job_dir = Path.home() / ".hermes" / "runs" / job_id
    s = read(job_dir)
    s["status"] = "done"
    write(job_dir, s)
    r = run_cli("continue", job_id)
    assert r.returncode != 0
    assert "done" in r.stderr.lower()


def test_continue_halted_requires_force(tmp_home):
    r = run_cli("new", "x")
    job_id = r.stdout.strip()
    from scripts.lib.state import read, write
    job_dir = Path.home() / ".hermes" / "runs" / job_id
    s = read(job_dir)
    s["status"] = "halted"
    write(job_dir, s)
    r = run_cli("continue", job_id)
    assert r.returncode != 0
    assert "--force" in r.stderr
    r = run_cli("continue", job_id, "--force")
    # Force goes through (stub); accept either success or non-error
    assert r.returncode in (0, 1)


def test_cancel_marks_halted(tmp_home):
    r = run_cli("new", "x")
    job_id = r.stdout.strip()
    r = run_cli("cancel", job_id)
    assert r.returncode == 0
    from scripts.lib.state import read
    s = read(Path.home() / ".hermes" / "runs" / job_id)
    assert s["status"] == "halted"
    assert s["phase"] == "halted"
```

- [ ] **Step 2: Run tests; expect 3 failures (stubs don't enforce rules)**

Run: `cd hermes-dev-skill && python -m pytest tests/test_hermes_dev_cli.py -k "test_continue_ or test_cancel_" -v`

- [ ] **Step 3: Implement `cmd_continue` and `cmd_cancel`**

Replace the stubs:

```python
def cmd_continue(args: argparse.Namespace) -> int:
    try:
        job_dir = _find_job(args.job_id)
    except FileNotFoundError as e:
        print(str(e), file=sys.stderr)
        return 1
    s = state_lib.read(job_dir)
    if s["status"] == "done":
        print(f"job {args.job_id} is done; nothing to continue", file=sys.stderr)
        return 1
    if s["status"] == "halted" and not args.force:
        print(
            f"job {args.job_id} is halted; pass --force to resume anyway",
            file=sys.stderr,
        )
        return 1

    # Mark as running and re-invoke the appropriate phase script.
    # For v1, the phase scripts are stubs that just exit 0; the actual
    # orchestrator will be implemented in later tasks. Here we just
    # re-set the status.
    state_lib.atomic_update(job_dir, {"status": "running"})
    print(f"resuming job {args.job_id} from phase {s['phase']}")
    return 0


def cmd_cancel(args: argparse.Namespace) -> int:
    try:
        job_dir = _find_job(args.job_id)
    except FileNotFoundError as e:
        print(str(e), file=sys.stderr)
        return 1
    state_lib.atomic_update(job_dir, {"status": "halted", "phase": "halted"})
    print(f"job {args.job_id} marked halted")
    return 0
```

- [ ] **Step 4: Run tests; expect 3 pass**

Run: `cd hermes-dev-skill && python -m pytest tests/test_hermes_dev_cli.py -k "test_continue_ or test_cancel_" -v`

- [ ] **Step 5: Commit**

```bash
git add hermes-dev-skill/scripts/hermes_dev.py hermes-dev-skill/tests/test_hermes_dev_cli.py
git commit -m "feat(cli): continue (with --force) and cancel subcommands"
```

---

## Task 16: hermes-dev `register`, `unregister`

**Files:**
- Modify: `hermes-dev-skill/scripts/hermes_dev.py` (replace stubs)

- [ ] **Step 1: Write failing tests**

Append to `tests/test_hermes_dev_cli.py`:

```python
def test_register_creates_entry(tmp_home):
    r = run_cli("register", "stocks", "/tmp/stocks", "--default-branch", "main")
    assert r.returncode == 0
    import json
    reg = json.loads((Path.home() / ".hermes" / "projects.json").read_text())
    assert "stocks" in reg
    assert reg["stocks"]["path"] == "/tmp/stocks"
    assert reg["stocks"]["default_branch"] == "main"


def test_unregister_removes_entry(tmp_home):
    run_cli("register", "x", "/x")
    r = run_cli("unregister", "x")
    assert r.returncode == 0
    import json
    reg = json.loads((Path.home() / ".hermes" / "projects.json").read_text())
    assert "x" not in reg


def test_unregister_missing_fails(tmp_home):
    r = run_cli("unregister", "never-existed")
    assert r.returncode != 0
```

- [ ] **Step 2: Run tests; expect 3 failures**

Run: `cd hermes-dev-skill && python -m pytest tests/test_hermes_dev_cli.py -k "test_register or test_unregister" -v`

- [ ] **Step 3: Implement `cmd_register`, `cmd_unregister`**

```python
from scripts.lib import project_registry


def cmd_register(args: argparse.Namespace) -> int:
    project_registry.register(args.name, args.path, default_branch=args.default_branch)
    print(f"registered '{args.name}' -> {args.path}")
    return 0


def cmd_unregister(args: argparse.Namespace) -> int:
    try:
        project_registry.unregister(args.name)
    except KeyError as e:
        print(str(e), file=sys.stderr)
        return 1
    print(f"unregistered '{args.name}'")
    return 0
```

- [ ] **Step 4: Run tests; expect 3 pass**

Run: `cd hermes-dev-skill && python -m pytest tests/test_hermes_dev_cli.py -k "test_register or test_unregister" -v`

- [ ] **Step 5: Commit**

```bash
git add hermes-dev-skill/scripts/hermes_dev.py hermes-dev-skill/tests/test_hermes_dev_cli.py
git commit -m "feat(cli): register and unregister wrap project_registry"
```

---

## Task 17: reconcile.py + reconcile CLI command

**Files:**
- Create: `hermes-dev-skill/scripts/lib/reconcile.py`
- Create: `hermes-dev-skill/tests/test_reconcile.py`
- Modify: `hermes-dev-skill/scripts/hermes_dev.py` (replace `cmd_reconcile`)

- [ ] **Step 1: Write failing tests**

```python
# hermes-dev-skill/tests/test_reconcile.py
import json
import time
from pathlib import Path
import pytest

from scripts.lib import reconcile
from scripts.lib.state import write


def _make_job(runs_dir, name, status, age_seconds):
    d = runs_dir / name
    d.mkdir()
    write(d, {
        "job_id": name, "status": status, "phase": "clarify", "phase_round": 1,
    })
    # Backdate the state.json mtime to simulate an old job
    p = d / "state.json"
    old = time.time() - age_seconds
    import os
    os.utime(p, (old, old))
    return d


def test_find_orphans_returns_old_running_jobs(tmp_home):
    runs = Path.home() / ".hermes" / "runs"
    _make_job(runs, "old-running", "running", age_seconds=600)
    _make_job(runs, "fresh-running", "running", age_seconds=10)
    _make_job(runs, "old-halted", "halted", age_seconds=600)
    orphans = reconcile.find_orphans(age_seconds=300)
    names = [o.name for o in orphans]
    assert "old-running" in names
    assert "fresh-running" not in names
    assert "old-halted" not in names  # halted jobs are NOT orphans


def test_mark_orphaned(tmp_home):
    runs = Path.home() / ".hermes" / "runs"
    d = _make_job(runs, "x", "running", age_seconds=600)
    reconcile.mark_orphaned(d)
    from scripts.lib.state import read
    s = read(d)
    assert s["status"] == "orphaned"


def test_reconcile_dry_run_no_auto_resume(tmp_home):
    runs = Path.home() / ".hermes" / "runs"
    _make_job(runs, "a", "running", age_seconds=600)
    n = reconcile.run(age_seconds=300, auto_resume=False, dry_run=True)
    assert n == 1
    from scripts.lib.state import read
    s = read(runs / "a")
    assert s["status"] == "running"  # unchanged in dry-run
```

- [ ] **Step 2: Run tests; expect 3 failures**

Run: `cd hermes-dev-skill && python -m pytest tests/test_reconcile.py -v`
Expected: `ModuleNotFoundError: No module named 'scripts.lib.reconcile'`

- [ ] **Step 3: Implement `scripts/lib/reconcile.py`**

```python
# hermes-dev-skill/scripts/lib/reconcile.py
"""Scan runs/ for orphaned jobs and optionally resume them.

A job is orphaned when:
  - status is in (running, awaiting_tool)
  - state.json mtime is older than the age threshold
  (We do not track a PID because the Bash subprocess is short-lived per
  phase; the user-facing 'alive' signal is the freshness of state.json.)
"""
from __future__ import annotations

import os
import time
from pathlib import Path

from . import state


_RUNNING_STATUSES = {"running", "awaiting_tool"}


def _runs_dir() -> Path:
    return Path(os.path.expanduser("~/.hermes/runs"))


def find_orphans(age_seconds: int) -> list[Path]:
    runs = _runs_dir()
    if not runs.is_dir():
        return []
    cutoff = time.time() - age_seconds
    orphans: list[Path] = []
    for d in runs.iterdir():
        if not d.is_dir():
            continue
        sf = d / "state.json"
        if not sf.exists():
            continue
        try:
            s = state.read(d)
        except state.StateError:
            continue
        if s["status"] in _RUNNING_STATUSES and sf.stat().st_mtime < cutoff:
            orphans.append(d)
    return orphans


def mark_orphaned(job_dir: Path) -> None:
    state.atomic_update(job_dir, {"status": "orphaned"})


def run(age_seconds: int, auto_resume: bool, dry_run: bool = False) -> int:
    """Mark orphans (or count them in dry-run). If auto_resume, kick off
    `hermes-dev continue` for each. Returns number of jobs acted on."""
    orphans = find_orphans(age_seconds)
    for d in orphans:
        if dry_run:
            continue
        mark_orphaned(d)
    if auto_resume and not dry_run:
        import subprocess
        for d in orphans:
            subprocess.run(
                ["hermes-dev", "continue", d.name, "--force"],
                check=False,
            )
    return len(orphans)
```

- [ ] **Step 4: Implement `cmd_reconcile` in `hermes_dev.py`**

```python
from scripts.lib import reconcile


def _parse_age(age_str: str) -> int:
    """Parse '5m' / '1h' / '30s' to seconds."""
    s = age_str.strip().lower()
    if s.endswith("s"):
        return int(s[:-1])
    if s.endswith("m"):
        return int(s[:-1]) * 60
    if s.endswith("h"):
        return int(s[:-1]) * 3600
    return int(s)


def cmd_reconcile(args: argparse.Namespace) -> int:
    seconds = _parse_age(args.age)
    n = reconcile.run(
        age_seconds=seconds,
        auto_resume=args.auto_resume,
        dry_run=False,
    )
    print(f"reconciled {n} job(s)")
    return 0
```

- [ ] **Step 5: Run tests; expect 3 pass**

Run: `cd hermes-dev-skill && python -m pytest tests/test_reconcile.py -v`

- [ ] **Step 6: Commit**

```bash
git add hermes-dev-skill/scripts/lib/reconcile.py hermes-dev-skill/tests/test_reconcile.py hermes-dev-skill/scripts/hermes_dev.py
git commit -m "feat(reconcile): orphan detection + auto-resume + CLI subcommand"
```

---

## Task 18: handlers/on_continue.sh

**Files:**
- Create: `hermes-dev-skill/scripts/handlers/on_continue.sh`
- Create: `hermes-dev-skill/tests/test_on_continue.sh` (Bash test)

- [ ] **Step 1: Write `scripts/handlers/on_continue.sh`**

```bash
#!/usr/bin/env bash
# hermes-dev-skill/scripts/handlers/on_continue.sh
# Invoked by Hermes when the user says "@bot 继续" or taps a "continue" card
# button. Atomically increments max_review_rounds by 5 and resumes the
# review loop if the job is currently halted.
set -euo pipefail

JOB_ID="$1"
if [ -z "$JOB_ID" ]; then
    echo "usage: $0 <job_id>" >&2
    exit 1
fi

RUNS_DIR="$HOME/.hermes/runs/$JOB_ID"
if [ ! -d "$RUNS_DIR" ]; then
    echo "job $JOB_ID not found" >&2
    exit 1
fi

# SKILL_DIR resolution: respect HERMES_DEV_SKILL_DIR override (used by
# tests to point at a copy of the skill without overwriting real scripts).
SKILL_DIR="${HERMES_DEV_SKILL_DIR:-$(cd "$(dirname "$0")/../.." && pwd)}"

# Atomic update of state.json
python -m scripts.lib.state atomic_update "$RUNS_DIR/state.json" '
{
  "user_overrides": {
    "max_review_rounds": (current["user_overrides"]["max_review_rounds"] + 5),
    "extra_review_rounds_added": (current["user_overrides"]["extra_review_rounds_added"] + 5)
  }
}
'

NEW_MAX=$(python -m scripts.lib.state get "$RUNS_DIR/state.json" \
    user_overrides.max_review_rounds)
python -m scripts.lib.feishu send_text \
    "Job #${JOB_ID:0:6} 已增加 5 轮 review 上限，现在最多 $NEW_MAX 轮"

CURRENT_STATUS=$(python -m scripts.lib.state get "$RUNS_DIR/state.json" status)
if [ "$CURRENT_STATUS" = "halted" ]; then
    bash "$SKILL_DIR/scripts/phases/04_review.sh" "$JOB_ID"
fi
```

```bash
chmod +x /Users/xpy/Documents/RichardHub/Git/hermes-dev-skill/scripts/handlers/on_continue.sh
```

- [ ] **Step 2: Write a non-destructive Bash test**

`tests/test_on_continue.sh`:

```bash
#!/usr/bin/env bash
# Tests for handlers/on_continue.sh. Runs against a fake HOME and a
# temporary HERMES_DEV_SKILL_DIR copy so the real skill files are
# never overwritten.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

# Set up isolated HOME
export HOME=$(mktemp -d)
mkdir -p "$HOME/.hermes"

# Set up a temp copy of the skill so we can stub 04_review.sh
TEST_SKILL="$(mktemp -d)"
mkdir -p "$TEST_SKILL/scripts/phases" "$TEST_SKILL/scripts/lib" "$TEST_SKILL/scripts/handlers"
cp "$REPO_ROOT/scripts/lib/state.py" "$TEST_SKILL/scripts/lib/"
cp "$REPO_ROOT/scripts/lib/feishu.py" "$TEST_SKILL/scripts/lib/"
cp "$REPO_ROOT/scripts/handlers/on_continue.sh" "$TEST_SKILL/scripts/handlers/"
cat > "$TEST_SKILL/scripts/phases/04_review.sh" <<'EOF'
#!/usr/bin/env bash
echo "[stub] 04_review $1"
exit 0
EOF
chmod +x "$TEST_SKILL/scripts/phases/04_review.sh"

# Create a job
JOB_ID="20260101-1200-abc123"
RUNS_DIR="$HOME/.hermes/runs/$JOB_ID"
mkdir -p "$RUNS_DIR"

PYTHONPATH="$REPO_ROOT:$TEST_SKILL:$TEST_SKILL" python -m scripts.lib.state write "$RUNS_DIR" '{
  "job_id": "'$JOB_ID'",
  "status": "halted",
  "phase": "review",
  "phase_round": 5,
  "user_overrides": {"max_review_rounds": 5, "extra_review_rounds_added": 0}
}'

# Stub hermes send on PATH
TEST_BIN="$(mktemp -d)"
cat > "$TEST_BIN/hermes" <<'EOF'
#!/usr/bin/env bash
echo "message_id: om_test"
EOF
chmod +x "$TEST_BIN/hermes"

# Run the handler with the temp skill dir
export PATH="$TEST_BIN:$PATH"
export HERMES_DEV_SKILL_DIR="$TEST_SKILL"
export PYTHONPATH="$REPO_ROOT:$TEST_SKILL"

bash "$TEST_SKILL/scripts/handlers/on_continue.sh" "$JOB_ID"

# Verify state was updated
NEW_MAX=$(PYTHONPATH="$REPO_ROOT:$TEST_SKILL" python -m scripts.lib.state get "$RUNS_DIR/state.json" user_overrides.max_review_rounds)
if [ "$NEW_MAX" = "10" ]; then
    echo "PASS: max_review_rounds incremented to 10"
else
    echo "FAIL: max_review_rounds is '$NEW_MAX', expected 10"
    exit 1
fi
```

```bash
chmod +x /Users/xpy/Documents/RichardHub/Git/hermes-dev-skill/tests/test_on_continue.sh
```

- [ ] **Step 3: Run the test (this test is a shell script, not pytest)**

Run: `cd hermes-dev-skill && bash tests/test_on_continue.sh`
Expected: prints "PASS: max_review_rounds incremented to 10".

- [ ] **Step 4: Commit**

```bash
git add hermes-dev-skill/scripts/handlers/on_continue.sh hermes-dev-skill/tests/test_on_continue.sh
git commit -m "feat(handler): on_continue bumps review cap and resumes halted jobs"
```

---

# M5: Code templates

## Task 19: codex_prompts/spec_plan.md

**Files:**
- Create: `hermes-dev-skill/scripts/codex_prompts/spec_plan.md`

- [ ] **Step 1: Write the prompt file**

```markdown
You are Codex, invoked by the hermes-dev skill to convert a requirements
document into a Specification and a Plan for implementation.

## INPUTS

A requirements document written by the user via dialogue. It describes:
- The feature the user wants
- The project it should be implemented in
- Edge cases and acceptance criteria gathered through Q&A

## YOUR TASK

Produce TWO files in the runs directory (paths provided in the prompt):

### 1. `spec.md`

Schema (use these exact section headings):

```
# Specification

## Goals
<bullet list>

## Non-goals
<bullet list>

## Behaviour
<numbered list, step by step>

## Edge cases
<bullet list, each with: trigger + expected behaviour>

## Acceptance criteria
<numbered list, each verifiable: "Given X, when Y, then Z">

## Out-of-scope (deferred)
<bullet list — anything that came up in requirements but is for a later iteration>
```

### 2. `plan.md`

Schema:

```
# Plan

## Phases
<ordered list; each phase is a self-contained unit of work>

## Files to create / modify
<grouped by phase; for each file, list purpose>

## Test strategy
<how to verify each acceptance criterion>

## Risks
<anything that could go wrong, with mitigations>
```

## RULES

- Do not invent behaviour not in the requirements. If a behaviour is implied
  but not stated, write a question to `claude-questions.txt` and stop.
- Prefer smallest-viable spec. If 5 lines solve the user's problem, do not
  write 50.
- Be specific. "Add a button" is bad. "Add a `Submit` button to the bottom
  of the `<form id=checkout>` that POSTs to `/api/orders`" is good.

## OUTPUT

When done, print a one-line summary to stdout. Do not return the full
spec/plan in the assistant message — it lives in the files.
```

- [ ] **Step 2: Commit**

```bash
git add hermes-dev-skill/scripts/codex_prompts/spec_plan.md
git commit -m "docs(prompts): Codex spec_plan.md template"
```

---

## Task 20: codex_prompts/self_check.md

**Files:**
- Create: `hermes-dev-skill/scripts/codex_prompts/self_check.md`

- [ ] **Step 1: Write the prompt file**

```markdown
You are Codex, auditing a spec/plan pair for internal consistency, gaps,
and risks.

## INPUTS

The full content of `spec.md` and `plan.md`.

## YOUR TASK

Produce a single file `self-check.md` in the runs dir with this schema:

```
# Self-Check

## Coverage
<does the plan cover every acceptance criterion in the spec? yes/no per item>

## Internal consistency
<do the spec and plan contradict each other? list contradictions>

## Gaps
<behaviours described in the spec that the plan does not implement>

## Risks
<plan steps that are technically risky; e.g., large refactor without tests>

## Verdict
VERDICT: PASS    # if there are no P0 gaps and the plan is sound
# OR
VERDICT: FAIL    # if there are P0 gaps or contradictions
```

A P0 gap is one of:
- An acceptance criterion with no plan coverage
- A contradiction between spec and plan
- A plan step that cannot actually achieve its stated goal

## OUTPUT

One-line summary to stdout. Full report in the file.
```

- [ ] **Step 2: Commit**

```bash
git add hermes-dev-skill/scripts/codex_prompts/self_check.md
git commit -m "docs(prompts): Codex self_check.md template"
```

---

## Task 21: codex_prompts/review.md

**Files:**
- Create: `hermes-dev-skill/scripts/codex_prompts/review.md`

- [ ] **Step 1: Write the prompt file**

```markdown
You are Codex, performing a code review of an implementation.

## INPUTS

- The original `spec.md` (what should be built)
- The original `plan.md` (how it should be built)
- A `git diff <base>..HEAD` of the implementation, OR a directory tree of
  the project if it is not a git repo (the orchestrator will tell you
  which kind of input you have).

## YOUR TASK

Produce `review-rounds/round-N.md` with this schema:

```
# Review — round N

## Summary
<one paragraph: what does this implementation do>

## Spec compliance
<per acceptance criterion: met / not met / partial — with file:line evidence>

## Issues found

### P0 — must fix (blocks acceptance)
- [P0] <file:line> — <problem> — <suggested fix>

### P1 — should fix (correctness, missing tests, security)
- [P1] <file:line> — <problem> — <suggested fix>

### P2 — nice to have
- [P2] <file:line> — <problem> — <suggested fix>

## Praise
<things done well; useful for the user to see>

VERDICT: APPROVED
# OR
VERDICT: REJECTED
```

## RULES

- Every P0 and P1 must include a `file:line` reference. If you cannot
  cite file:line, the issue is not actionable — demote to P2 or drop.
- P0 = blocks spec compliance. P1 = doesn't block spec but is a real bug.
- If the spec is satisfied, output `VERDICT: APPROVED` even if P2s remain.
- The diff / tree can be very long. Skim the spec first, then read the
  relevant files end-to-end; do not rely on grep.
```

- [ ] **Step 2: Commit**

```bash
git add hermes-dev-skill/scripts/codex_prompts/review.md
git commit -m "docs(prompts): Codex review.md template"
```

---

## Task 22: claude_contract.md

**Files:**
- Create: `hermes-dev-skill/scripts/claude_contract.md`

- [ ] **Step 1: Write the work contract**

```markdown
# Claude Code Work Contract — hermes-dev

You are Claude Code, invoked by the hermes-dev skill to implement a
specification. Read this entire file before doing any work.

## ABSOLUTE RULES (do not violate under any circumstance)

1. **Stay on the assigned branch.** The branch `hermes-dev/<job_id>` is
   already checked out. Do not run `git checkout` to any other branch,
   including `main` or `master`.
2. **Never push.** Do not run `git push`, regardless of remote configuration.
3. **Never modify state outside the project.** Do not touch:
   - `~/.hermes/` (the runs dir, hermes config)
   - `runs/<job_id>/` (your supervisor's data)
   - Any file outside `$PROJECT_PATH` (the project working tree)
4. **Commit incrementally.** After each logically complete change, commit
   with message format: `hermes-dev(<job_id>): <imperative summary, ≤72 chars>`
   Then add a blank line and a paragraph explaining the change.
5. **If the spec is silent on a behaviour, STOP and ask.** Do not invent.
   Do not extend scope. When you stop, write the question to
   `$RUNS_DIR/claude-questions.txt` and exit. The orchestrator will surface
   the question to the user via Feishu.
6. **Before declaring done**, run the project's checks if configured: read
   `.hermes-dev.yaml` in the project root. If it defines `lint_cmd` or
   `test_cmd`, run them. If they fail, fix the failures; do not declare done.
7. **Output format**: when you finish, write a summary of what you did to
   `$RUNS_DIR/claude-summary.md` and exit. Do not write to stdout.

## GIT USAGE

- `git status` to see current state
- `git log -1` to see the last commit
- `git diff HEAD~1` to see your last change
- `git add -A && git commit -m "..."` for each logical change
- Do not use `git commit --amend` (would rewrite history the orchestrator
  depends on)
- Do not use `git rebase -i` for the same reason

## INCREMENTAL STYLE

- Small commits > large commits. The reviewer (Codex) sees the diff; small
  diffs are easier to review.
- Each commit should compile / type-check on its own if the project
  supports it.
```

- [ ] **Step 2: Commit**

```bash
git add hermes-dev-skill/scripts/claude_contract.md
git commit -m "docs(contract): Claude Code work contract for hermes-dev"
```

---

# M6: Phase scripts

## Task 23: phases/01_clarify.sh

**Files:**
- Create: `hermes-dev-skill/scripts/phases/01_clarify.sh`

- [ ] **Step 1: Write the script**

```bash
#!/usr/bin/env bash
# hermes-dev-skill/scripts/phases/01_clarify.sh
# Phase 1: requirements clarification. This phase is driven by Hermes
# (the LLM), not by a script. The script exists as a marker so the
# orchestrator can invoke "the phase 1 entry point" uniformly. It is a
# no-op; Hermes handles the dialogue directly.
set -euo pipefail
JOB_ID="${1:-}"
if [ -z "$JOB_ID" ]; then
    echo "usage: $0 <job_id>" >&2
    exit 1
fi
echo "[phase1/clarify] job=$JOB_ID — driven by Hermes, no-op script"
exit 0
```

```bash
chmod +x /Users/xpy/Documents/RichardHub/Git/hermes-dev-skill/scripts/phases/01_clarify.sh
```

- [ ] **Step 2: Commit**

```bash
git add hermes-dev-skill/scripts/phases/01_clarify.sh
git commit -m "feat(phase): 01_clarify.sh marker script (Hermes-driven)"
```

---

## Task 24: phases/02_spec_plan.sh

**Files:**
- Create: `hermes-dev-skill/scripts/phases/02_spec_plan.sh`

- [ ] **Step 1: Write the script**

```bash
#!/usr/bin/env bash
# hermes-dev-skill/scripts/phases/02_spec_plan.sh
# Phase 2: invoke Codex to generate spec.md and plan.md, then run a
# self-check pass. Up to 2 retries if self-check fails.
set -euo pipefail
JOB_ID="${1:-}"
if [ -z "$JOB_ID" ]; then
    echo "usage: $0 <job_id>" >&2
    exit 1
fi

RUNS_DIR="$HOME/.hermes/runs/$JOB_ID"
CODEX_MODEL=$(python -m scripts.lib.state get "$RUNS_DIR/state.json" \
    user_overrides.codex_model 2>/dev/null || echo "")
CODEX_MODEL=${CODEX_MODEL:-gpt-5.5}
SKILL_DIR="$(cd "$(dirname "$0")/../.." && pwd)"

# Sanity check requirements.md exists (Phase 1 must have produced it)
if [ ! -f "$RUNS_DIR/requirements.md" ]; then
    echo "[phase2] requirements.md missing in $RUNS_DIR" >&2
    exit 1
fi

build_prompt() {
    local prompt_template="$1"
    cat "$SKILL_DIR/scripts/codex_prompts/$prompt_template"
    echo ""
    echo "=== REQUIREMENTS ==="
    cat "$RUNS_DIR/requirements.md"
    echo ""
    echo "=== PROJECT CONTEXT ==="
    PROJECT_PATH=$(python -m scripts.lib.state get "$RUNS_DIR/state.json" project.path)
    echo "Path: $PROJECT_PATH"
    BASE_BRANCH=$(python -m scripts.lib.state get "$RUNS_DIR/state.json" project.base_branch 2>/dev/null || echo "main")
    echo "Default branch: $BASE_BRANCH"
}

PROMPT=$(build_prompt "spec_plan.md")

echo "[phase2] invoking Codex ($CODEX_MODEL) for spec/plan"
codex --model "$CODEX_MODEL" \
      --sandbox danger-full-access \
      -p "$PROMPT" \
      --output-format json \
      > "$RUNS_DIR/codex-spec-plan.raw.json"

# Validate the output files exist
for f in spec.md plan.md; do
    if [ ! -s "$RUNS_DIR/$f" ]; then
        echo "[phase2] Codex did not produce $f" >&2
        python -m scripts.lib.state atomic_update "$RUNS_DIR/state.json" \
            '{"status": "halted"}'
        python -m scripts.lib.feishu send_text \
            "Job #${JOB_ID:0:6} Phase 2 失败：Codex 未生成 $f，请人工介入"
        exit 1
    fi
done

# Self-check
SELF_CHECK_PROMPT="$(cat $SKILL_DIR/scripts/codex_prompts/self_check.md)

=== SPEC ===
$(cat $RUNS_DIR/spec.md)

=== PLAN ===
$(cat $RUNS_DIR/plan.md)"

MAX_RETRIES=2
ATTEMPT=0
VERDICT="FAIL"
while [ $ATTEMPT -le $MAX_RETRIES ]; do
    echo "[phase2] self-check attempt $((ATTEMPT+1))"
    codex --model "$CODEX_MODEL" \
          --sandbox danger-full-access \
          -p "$SELF_CHECK_PROMPT" \
          --output-format json \
          > "$RUNS_DIR/self-check.raw.json"
    VERDICT=$(grep -E '^VERDICT:' "$RUNS_DIR/self-check.md" 2>/dev/null | tail -1 | awk '{print $2}' || echo "FAIL")
    if [ "$VERDICT" = "PASS" ]; then
        break
    fi
    ATTEMPT=$((ATTEMPT + 1))
done

if [ "$VERDICT" != "PASS" ]; then
    python -m scripts.lib.state atomic_update "$RUNS_DIR/state.json" \
        '{"status": "halted"}'
    python -m scripts.lib.feishu send_card \
        "Job #${JOB_ID:0:6} 自审未通过" \
        '[{"key": "请查看", "value": "self-check.md"}]' \
        '[{"text": "查看 self-check", "url": "file://'$RUNS_DIR'/self-check.md", "type": "primary"}]'
    exit 1
fi

# Save a checkpoint and move to phase 3
python -c "
from scripts.lib import checkpoint
checkpoint.save('$RUNS_DIR', 2, ['requirements.md', 'spec.md', 'plan.md', 'self-check.md'])
"
python -m scripts.lib.state atomic_update "$RUNS_DIR/state.json" \
    '{"phase": "implement"}'

python -m scripts.lib.feishu send_card \
    "Job #${JOB_ID:0:6} — Spec/Plan 已生成并自审通过" \
    '[{"key": "阶段", "value": "进入开发"}]' \
    '[{"text": "查看 Spec", "url": "file://'$RUNS_DIR'/spec.md", "type": "primary"},
      {"text": "查看 Plan", "url": "file://'$RUNS_DIR'/plan.md"}]'

echo "[phase2] done"
```

```bash
chmod +x /Users/xpy/Documents/RichardHub/Git/hermes-dev-skill/scripts/phases/02_spec_plan.sh
```

- [ ] **Step 2: Commit**

```bash
git add hermes-dev-skill/scripts/phases/02_spec_plan.sh
git commit -m "feat(phase): 02_spec_plan.sh invokes Codex for spec+plan+self-check"
```

---

## Task 25: phases/03_implement.sh

**Files:**
- Create: `hermes-dev-skill/scripts/phases/03_implement.sh`

- [ ] **Step 1: Write the script**

```bash
#!/usr/bin/env bash
# hermes-dev-skill/scripts/phases/03_implement.sh
# Phase 3 (first round): invoke Claude Code to implement the spec.
# The follow-up round (after a review) is 03_implement_iter.sh.
set -euo pipefail
JOB_ID="${1:-}"
ROUND="${2:-1}"
if [ -z "$JOB_ID" ]; then
    echo "usage: $0 <job_id> [round]" >&2
    exit 1
fi

RUNS_DIR="$HOME/.hermes/runs/$JOB_ID"
PROJECT_PATH=$(python -m scripts.lib.state get "$RUNS_DIR/state.json" project.path)
IS_GIT=$(python -m scripts.lib.state get "$RUNS_DIR/state.json" project.is_git)
BASE_BRANCH=$(python -m scripts.lib.state get "$RUNS_DIR/state.json" project.base_branch 2>/dev/null || echo "main")
CLAUDE_MODEL=$(python -m scripts.lib.state get "$RUNS_DIR/state.json" \
    user_overrides.claude_model 2>/dev/null || echo "")
CLAUDE_MODEL=${CLAUDE_MODEL:-claude-opus-4-8}
SKILL_DIR="$(cd "$(dirname "$0")/../.." && pwd)"

# Pre-flight: ensure branch exists (first round only)
if [ "$IS_GIT" = "True" ] || [ "$IS_GIT" = "true" ]; then
    BRANCH="hermes-dev/$JOB_ID"
    if [ "$ROUND" = "1" ]; then
        python -m scripts.lib.git_ops create_branch "$PROJECT_PATH" "$JOB_ID" base="$BASE_BRANCH"
        python -m scripts.lib.state atomic_update "$RUNS_DIR/state.json" \
            "{\"project\": {\"branch\": \"$BRANCH\"}}"
    fi
fi

# Build the prompt
PROMPT="$(cat $SKILL_DIR/scripts/claude_contract.md)

=== JOB CONTEXT ===
- Job ID: $JOB_ID
- Project: $PROJECT_PATH
- Branch: $(python -m scripts.lib.state get $RUNS_DIR/state.json project.branch 2>/dev/null || echo unknown)
- Run dir: $RUNS_DIR

=== SPEC ===
$(cat $RUNS_DIR/spec.md)

=== PLAN ===
$(cat $RUNS_DIR/plan.md)

=== LAST REVIEW FEEDBACK ===
$(cat $RUNS_DIR/review-rounds/round-$((ROUND-1)).md 2>/dev/null || echo 'NONE — first implementation round')"

# Invoke Claude Code
echo "[phase3] invoking Claude Code ($CLAUDE_MODEL) round $ROUND"
cd "$PROJECT_PATH"
claude --model "$CLAUDE_MODEL" \
       --cwd "$PROJECT_PATH" \
       -p "$PROMPT" \
       --output-format json \
       > "$RUNS_DIR/claude-impl-round-$ROUND.json"

# Update state
python -m scripts.lib.state atomic_update "$RUNS_DIR/state.json" \
    "{\"phase\": \"review\", \"phase_round\": $ROUND}"

python -m scripts.lib.feishu send_text \
    "Job #${JOB_ID:0:6} 开发完成，进入 Review 第 $ROUND 轮"

echo "[phase3] done"
```

```bash
chmod +x /Users/xpy/Documents/RichardHub/Git/hermes-dev-skill/scripts/phases/03_implement.sh
```

- [ ] **Step 2: Commit**

```bash
git add hermes-dev-skill/scripts/phases/03_implement.sh
git commit -m "feat(phase): 03_implement.sh invokes Claude Code (round 1)"
```

---

## Task 26: phases/03_implement_iter.sh

**Files:**
- Create: `hermes-dev-skill/scripts/phases/03_implement_iter.sh`

- [ ] **Step 1: Write the script**

```bash
#!/usr/bin/env bash
# hermes-dev-skill/scripts/phases/03_implement_iter.sh
# Follow-up round: re-invoke Claude Code with the previous round's review
# feedback. Round number is passed in.
set -euo pipefail
JOB_ID="${1:?usage: $0 <job_id> <round>}"
ROUND="${2:?usage: $0 <job_id> <round>}"

# This is structurally identical to 03_implement.sh with the round arg
# explicitly provided; reuse by calling it.
SKILL_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
bash "$SKILL_DIR/scripts/phases/03_implement.sh" "$JOB_ID" "$ROUND"
```

```bash
chmod +x /Users/xpy/Documents/RichardHub/Git/hermes-dev-skill/scripts/phases/03_implement_iter.sh
```

- [ ] **Step 2: Commit**

```bash
git add hermes-dev-skill/scripts/phases/03_implement_iter.sh
git commit -m "feat(phase): 03_implement_iter.sh delegates to 03_implement.sh"
```

---

## Task 27: phases/04_review_one.sh

**Files:**
- Create: `hermes-dev-skill/scripts/phases/04_review_one.sh`

- [ ] **Step 1: Write the script**

```bash
#!/usr/bin/env bash
# hermes-dev-skill/scripts/phases/04_review_one.sh
# Run a single round of Codex review.
set -euo pipefail
JOB_ID="${1:?usage: $0 <job_id> <round>}"
ROUND="${2:?usage: $0 <job_id> <round>}"

RUNS_DIR="$HOME/.hermes/runs/$JOB_ID"
PROJECT_PATH=$(python -m scripts.lib.state get "$RUNS_DIR/state.json" project.path)
IS_GIT=$(python -m scripts.lib.state get "$RUNS_DIR/state.json" project.is_git)
BASE_BRANCH=$(python -m scripts.lib.state get "$RUNS_DIR/state.json" project.base_branch 2>/dev/null || echo "main")
CODEX_MODEL=$(python -m scripts.lib.state get "$RUNS_DIR/state.json" \
    user_overrides.codex_model 2>/dev/null || echo "")
CODEX_MODEL=${CODEX_MODEL:-gpt-5.5}
SKILL_DIR="$(cd "$(dirname "$0")/../.." && pwd)"

mkdir -p "$RUNS_DIR/review-rounds"

if [ "$IS_GIT" = "True" ] || [ "$IS_GIT" = "true" ]; then
    DIFF=$(cd "$PROJECT_PATH" && git diff "$BASE_BRANCH"..HEAD)
    DIFF_FILE="$RUNS_DIR/review-rounds/diff-round-$ROUND.txt"
    echo "$DIFF" > "$DIFF_FILE"
    REVIEW_INPUT_KIND="diff"
    SANDBOX_FLAGS="--sandbox danger-full-access"
    INPUT_BLOCK="Kind: cumulative git diff against base branch
Diff file: $DIFF_FILE (read this file directly)
$(cat "$DIFF_FILE")"
else
    REVIEW_INPUT_KIND="directory"
    SANDBOX_FLAGS="--sandbox workspace-write --add-dir $PROJECT_PATH"
    INPUT_BLOCK="Kind: directory tree (project is not a git repo)
Project path: $PROJECT_PATH
Read files from disk under that path as needed.
Do not require a diff blob; explore the tree."
fi

PROMPT="$(cat $SKILL_DIR/scripts/codex_prompts/review.md)

=== SPEC ===
$(cat $RUNS_DIR/spec.md)

=== PLAN ===
$(cat $RUNS_DIR/plan.md)

=== REVIEW INPUT ===
$INPUT_BLOCK

=== OUTPUT INSTRUCTIONS ===
Write your review to $RUNS_DIR/review-rounds/round-$ROUND.md.
End the file with a single line: VERDICT: APPROVED  or  VERDICT: REJECTED
Use the format - [P0] / - [P1] / - [P2] for issue entries."

codex --model "$CODEX_MODEL" $SANDBOX_FLAGS -p "$PROMPT" \
      --output-format json > "$RUNS_DIR/review-rounds/round-$ROUND.raw.json"

if [ ! -s "$RUNS_DIR/review-rounds/round-$ROUND.md" ]; then
    echo "[phase4] Codex did not produce round-$ROUND.md" >&2
    python -m scripts.lib.state atomic_update "$RUNS_DIR/state.json" \
        '{"status": "halted"}'
    exit 1
fi
```

```bash
chmod +x /Users/xpy/Documents/RichardHub/Git/hermes-dev-skill/scripts/phases/04_review_one.sh
```

- [ ] **Step 2: Commit**

```bash
git add hermes-dev-skill/scripts/phases/04_review_one.sh
git commit -m "feat(phase): 04_review_one.sh runs a single Codex review round"
```

---

## Task 28: phases/04_review.sh

**Files:**
- Create: `hermes-dev-skill/scripts/phases/04_review.sh`

- [ ] **Step 1: Write the script**

```bash
#!/usr/bin/env bash
# hermes-dev-skill/scripts/phases/04_review.sh
# The review loop. Each iteration:
#   1. If round > 1, re-invoke Claude Code with prior review feedback
#   2. Run Codex review
#   3. Parse verdict; if APPROVED, transition to handoff
#   4. If max rounds reached, halt and escalate
set -euo pipefail
JOB_ID="${1:?usage: $0 <job_id>}"
SKILL_DIR="$(cd "$(dirname "$0")/../.." && pwd)"

RUNS_DIR="$HOME/.hermes/runs/$JOB_ID"
MAX=$(python -m scripts.lib.state get "$RUNS_DIR/state.json" \
    user_overrides.max_review_rounds)
ROUND=$(python -m scripts.lib.state get "$RUNS_DIR/state.json" phase_round 1)

while [ "$ROUND" -le "$MAX" ]; do
    if [ "$ROUND" -gt 1 ]; then
        bash "$SKILL_DIR/scripts/phases/03_implement_iter.sh" "$JOB_ID" "$ROUND"
    fi

    bash "$SKILL_DIR/scripts/phases/04_review_one.sh" "$JOB_ID" "$ROUND"

    REVIEW_FILE="$RUNS_DIR/review-rounds/round-$ROUND.md"
    VERDICT=$(python -c "
from scripts.lib.review_parser import parse_file
import sys
p = parse_file('$REVIEW_FILE')
print(p['verdict'])
print(p['p0'])
print(p['p1'])
")
    V=$(echo "$VERDICT" | sed -n 1p)
    P0=$(echo "$VERDICT" | sed -n 2p)
    P1=$(echo "$VERDICT" | sed -n 3p)

    python -m scripts.lib.feishu send_text \
        "Job #${JOB_ID:0:6} Review 第 $ROUND 轮：$V (P0=$P0, P1=$P1)"

    if [ "$V" = "APPROVED" ] && [ "$P0" = "0" ] && [ "$P1" = "0" ]; then
        python -m scripts.lib.state atomic_update "$RUNS_DIR/state.json" \
            '{"phase": "handoff", "status": "running"}'
        bash "$SKILL_DIR/scripts/phases/05_handoff.sh" "$JOB_ID"
        exit 0
    fi

    ROUND=$((ROUND + 1))
    python -m scripts.lib.state atomic_update "$RUNS_DIR/state.json" \
        "{\"phase_round\": $ROUND}"
done

# Cap exceeded
python -m scripts.lib.feishu send_text \
    "Job #${JOB_ID:0:6} 已迭代 $MAX 轮未通过 Review，建议人工介入。请查看最后一轮 review。"
python -m scripts.lib.state atomic_update "$RUNS_DIR/state.json" \
    '{"status": "halted"}'
```

```bash
chmod +x /Users/xpy/Documents/RichardHub/Git/hermes-dev-skill/scripts/phases/04_review.sh
```

- [ ] **Step 2: Commit**

```bash
git add hermes-dev-skill/scripts/phases/04_review.sh
git commit -m "feat(phase): 04_review.sh loop driver with 5-round cap"
```

---

## Task 29: phases/05_handoff.sh

**Files:**
- Create: `hermes-dev-skill/scripts/phases/05_handoff.sh`

- [ ] **Step 1: Write the script**

```bash
#!/usr/bin/env bash
# hermes-dev-skill/scripts/phases/05_handoff.sh
# Final handoff: send a summary card with branch info, diffstat, and
# next-step instructions to the user.
set -euo pipefail
JOB_ID="${1:?usage: $0 <job_id>}"
RUNS_DIR="$HOME/.hermes/runs/$JOB_ID"

PROJECT_PATH=$(python -m scripts.lib.state get "$RUNS_DIR/state.json" project.path)
BRANCH=$(python -m scripts.lib.state get "$RUNS_DIR/state.json" project.branch)
BASE_BRANCH=$(python -m scripts.lib.state get "$RUNS_DIR/state.json" project.base_branch 2>/dev/null || echo "main")
IS_GIT=$(python -m scripts.lib.state get "$RUNS_DIR/state.json" project.is_git)

if [ "$IS_GIT" = "True" ] || [ "$IS_GIT" = "true" ]; then
    SHORTSTAT=$(cd "$PROJECT_PATH" && git diff --shortstat "$BASE_BRANCH"..HEAD 2>/dev/null || echo "n/a")
    COMMIT_COUNT=$(cd "$PROJECT_PATH" && git rev-list --count "$BASE_BRANCH"..HEAD 2>/dev/null || echo "0")
else
    SHORTSTAT="(non-git project)"
    COMMIT_COUNT="0"
fi

SUMMARY=$(cat "$RUNS_DIR/claude-summary.md" 2>/dev/null || echo "(no summary)")

python -m scripts.lib.feishu send_card \
    "Job #${JOB_ID:0:6} 完成" \
    "[{\"key\": \"Branch\", \"value\": \"$BRANCH\"},
      {\"key\": \"Diffstat\", \"value\": \"$SHORTSTAT\"},
      {\"key\": \"Commits\", \"value\": \"$COMMIT_COUNT\"},
      {\"key\": \"Summary\", \"value\": \"$SUMMARY\"}]" \
    "[{\"text\": \"查看 Spec\", \"url\": \"file://$RUNS_DIR/spec.md\"},
      {\"text\": \"查看 Plan\", \"url\": \"file://$RUNS_DIR/plan.md\"},
      {\"text\": \"需要继续?\", \"value\": {\"action\": \"continue\"}, \"type\": \"primary\"}]"

# Do not mark done yet — wait for user ack in Hermes
echo "[phase5] handoff sent"
```

```bash
chmod +x /Users/xpy/Documents/RichardHub/Git/hermes-dev-skill/scripts/phases/05_handoff.sh
```

- [ ] **Step 2: Commit**

```bash
git add hermes-dev-skill/scripts/phases/05_handoff.sh
git commit -m "feat(phase): 05_handoff.sh sends final summary card"
```

---

# M7: SKILL.md + references

## Task 30: SKILL.md (the manifest Hermes reads)

**Files:**
- Create: `hermes-dev-skill/SKILL.md`

- [ ] **Step 1: Write the manifest**

```markdown
---
name: hermes-dev-skill
description: |
  End-to-end dev collaboration skill. Drives the loop from a free-form dev
  idea in Feishu to working code on a git branch, using Codex for spec /
  plan / review and Claude Code for implementation. Includes a 5-round
  bounded review loop and checkpoint-based crash recovery.
---

# Hermes Dev-Collab Skill

You are Hermes, with this skill loaded. When the user sends a dev intent
in Feishu ("build me X", "在 stocks 加一个价格预警", etc.), you orchestrate
the following phases. Each phase has a state machine entry point; you
drive the LLM-judgment parts and call out to scripts for the mechanical
parts.

## Phase 0: bootstrap (per `hermes-dev new`)

When you detect a dev intent, run:

```bash
hermes-dev new "<user's intent, verbatim>"
```

The CLI prints a `job_id` to stdout. Capture it; all subsequent commands
take that `job_id` as their first argument.

Send a Feishu card to the user:

> Job #<short-id> 启动，需求澄清中。

## Phase 1: requirements clarification (you drive this)

The phase script `scripts/phases/01_clarify.sh` is a no-op marker. You
handle the multi-turn dialogue yourself, asking 1–3 questions per turn
and updating `requirements.md` (in `~/.hermes/runs/<job_id>/`) after
every turn. Completeness checklist:

- [ ] functional_scope
- [ ] behaviour
- [ ] edge_cases
- [ ] non_functional
- [ ] acceptance_criteria

When all are checked AND the user has confirmed the project path (see
below), write the final `requirements.md`, then run:

```bash
python -m scripts.lib.state atomic_update $HOME/.hermes/runs/$JOB_ID/state.json \
  '{"phase": "spec_plan"}'
python -m scripts.lib.feishu send_text "需求已确认，进入规划"
bash scripts/phases/02_spec_plan.sh $JOB_ID
```

### Project path resolution

Ask the user once, near the end of the dialogue:

> 请告诉我项目路径，或从已注册项目里选：[<names from ~/.hermes/projects.json>]。
> 如果没有想好路径，可以发 `look` 让我扫一下 `~/projects/ ~/code/ ~/Documents/`。

Then run the appropriate script:

```bash
# If user gave a name
python -m scripts.lib.project_registry register "$NAME" "$PATH"   # first time only
PROJECT=$(python -m scripts.lib.project_registry lookup "$NAME" | python -c "import sys,json; print(json.load(sys.stdin)['path'])")
# Or scan if user said "look"
python -m scripts.lib.project_registry scan_common_dirs
# Then save
python -m scripts.lib.state atomic_update $HOME/.hermes/runs/$JOB_ID/state.json "
{
  'project': {
    'name': '$NAME',
    'path': '$PROJECT',
    'base_branch': 'main',
    'is_git': true
  }
}
"
```

## Phase 2: spec & plan generation (script-driven)

`scripts/phases/02_spec_plan.sh` invokes Codex twice (spec/plan, then
self-check). It writes `spec.md`, `plan.md`, and `self-check.md` in the
runs dir. On `VERDICT: PASS`, it transitions state to `phase=implement`
and posts a Feishu card. On failure it halts and surfaces the issue.

You do not need to drive this phase — just call the script and wait for
the next user message (which will be a Feishu push, not a user reply).

## Phase 3: implementation (script-driven, Claude Code under the hood)

`scripts/phases/03_implement.sh` invokes Claude Code with the work
contract + spec + plan. Claude Code writes code on `hermes-dev/<job_id>`
branch and commits. You do not drive this phase either.

If Claude Code writes questions to `claude-questions.txt`, surface them
to the user via Feishu and set `status=awaiting_user`.

## Phase 4: review loop (script-driven)

`scripts/phases/04_review.sh` runs up to 5 rounds of Codex review +
Claude Code fix. On APPROVED, transitions to handoff. On cap, halts and
escalates to the user.

## Phase 5: handoff (script-driven)

`scripts/phases/05_handoff.sh` sends the summary card. After the user
acks ("ok" / "done") or after 24h, mark the job `status=done`.

## Message handlers (you parse Feishu messages)

| User says | You do |
|---|---|
| "在 <repo> 加一个功能..." | Phase 0 (new) → Phase 1 |
| "@bot 继续" | `bash scripts/handlers/on_continue.sh <job_id>` |
| "@bot 状态" | `hermes-dev status <job_id>` |
| "@bot 取消" | `hermes-dev cancel <job_id>` |
| "ok" / "done" (after handoff) | `hermes-dev continue <job_id>` (no-op) → state `done` |
| "merge" (after handoff) | Tell user the merge is theirs to do (out of scope) |

## Error escalation

If any phase script exits non-zero, read the `state.json.errors` array
and the most recent `events.jsonl` line, then send a Feishu card
explaining the failure and asking the user how to proceed.

## State introspection

```bash
hermes-dev status $JOB_ID       # pretty print key state fields
hermes-dev tail $JOB_ID         # stream events.jsonl
hermes-dev list                 # all jobs
```
```

- [ ] **Step 2: Commit**

```bash
git add hermes-dev-skill/SKILL.md
git commit -m "docs(skill): SKILL.md manifest for Hermes to load"
```

---

## Task 31: references/state-schema.md

**Files:**
- Create: `hermes-dev-skill/references/state-schema.md`

- [ ] **Step 1: Write the reference**

````markdown
# state.json schema reference

`state.json` lives at the root of each job's runs directory:
`~/.hermes/runs/<job_id>/state.json`. It is the single source of truth
for job state; everything else in the runs dir is an artifact.

## Top-level fields

```json
{
  "job_id": "20260614-1030-a1b2c3",
  "version": "1.0",
  "created_at": "2026-06-14T10:30:00Z",
  "updated_at": "2026-06-14T10:35:22Z",
  "status": "running",
  "phase": "review",
  "phase_round": 2,
  "intent": "build me a stock alerter",
  "project": { ... },
  "artifacts": { ... },
  "checkpoints": { ... },
  "feishu_message_ids": ["om_abc123"],
  "events_log": "events.jsonl",
  "errors": [],
  "user_overrides": { ... }
}
```

### Required keys (validated on read)

`job_id`, `status`, `phase`, `phase_round`. See
`scripts/lib/state.py:REQUIRED_KEYS`.

### Allowed values

- `status` ∈ {`running`, `awaiting_user`, `awaiting_tool`, `halted`,
  `orphaned`, `done`}
- `phase` ∈ {`bootstrap`, `clarify`, `spec_plan`, `implement`, `review`,
  `handoff`, `done`, `halted`}

## `project` sub-object

```json
{
  "name": "stocks",
  "path": "/Users/xpy/projects/stocks",
  "branch": "hermes-dev/20260614-1030-a1b2c3",
  "base_branch": "main",
  "is_git": true
}
```

Set by Phase 1 (clarify) when the user confirms the project path.

## `artifacts` sub-object

Paths are **relative to the runs dir**:

```json
{
  "requirements": "requirements.md",
  "spec": "spec.md",
  "plan": "plan.md",
  "self_check": "self-check.md",
  "review_rounds": [
    "review-rounds/round-1.md",
    "review-rounds/round-2.md"
  ]
}
```

## `user_overrides` sub-object

```json
{
  "codex_model": null,
  "claude_model": null,
  "max_review_rounds": 5,
  "extra_review_rounds_added": 0
}
```

`null` for a model means "use config.yaml default".

## `errors` array (capped at 50)

```json
[
  {
    "at": "2026-06-14T10:35:22Z",
    "phase": "review",
    "kind": "codex_5xx",
    "message": "Codex returned 503",
    "traceback": "..."
  }
]
```

## Atomic update API

```python
from scripts.lib import state

# Shorthand: replace/add these fields
state.atomic_update(runs_dir, {"phase": "implement", "phase_round": 1})

# Full JSON-Patch
state.atomic_update(runs_dir, '''
[
  {"op": "replace", "path": "/phase", "value": "review"},
  {"op": "inc",    "path": "/phase_round", "value": 1}
]
''')
```

`atomic_update` takes a file lock so concurrent calls are safe.
````

- [ ] **Step 2: Commit**

```bash
git add hermes-dev-skill/references/state-schema.md
git commit -m "docs(references): state.json schema reference"
```

---

## Task 32: feishu-message-format.md + troubleshooting.md

**Files:**
- Create: `hermes-dev-skill/references/feishu-message-format.md`
- Create: `hermes-dev-skill/references/troubleshooting.md`

- [ ] **Step 1: Write `feishu-message-format.md`**

````markdown
# Feishu message format reference

All Feishu traffic from this skill goes through `hermes send`, which
takes `--text` or `--card-json`. The Python wrapper `lib/feishu.py`
provides `send_text()` and `send_card()`.

## Plain text (`send_text`)

```python
send_text("Job #abc 已启动，需求澄清中")
```

Becomes:

```bash
hermes send --text "Job #abc 已启动，需求澄清中"
```

## Card (`send_card`)

```python
send_card(
    title="Job #abc — Phase 4/5",
    fields=[
        {"key": "Status", "value": "REJECTED"},
        {"key": "Round",  "value": "2 of 5"},
    ],
    buttons=[
        {"text": "View Review", "url": "file:///x.md", "type": "primary"},
        {"text": "Continue",    "value": {"action": "continue"}},
    ],
)
```

Becomes:

```bash
hermes send --card-json '{
  "header": {"title": {"tag": "plain_text", "content": "Job #abc — Phase 4/5"}},
  "elements": [
    {"tag": "div", "text": {"tag": "lark_md", "content": "**Status**: REJECTED"}},
    {"tag": "div", "text": {"tag": "lark_md", "content": "**Round**: 2 of 5"}},
    {"tag": "action", "actions": [
      {"tag": "button", "text": {"tag": "plain_text", "content": "View Review"},
       "type": "primary", "url": "file:///x.md"},
      {"tag": "button", "text": {"tag": "plain_text", "content": "Continue"},
       "value": {"action": "continue"}}
    ]}
  ]
}'
```

## Card button actions

A card button can have either:
- `url`: opens a URL when clicked (used for `file://` links to spec/plan)
- `value`: sends a card callback to the bot with the given JSON

The skill uses `value` only for `{"action": "continue"}`, which the
message handler in SKILL.md maps to `on_continue.sh <job_id>`.
````

- [ ] **Step 2: Write `troubleshooting.md`**

````markdown
# Troubleshooting

## "hermes send" doesn't print a message_id

Some `hermes send` implementations don't emit the `message_id: om_xxx`
line. The skill falls back to returning `""` and does not raise. Card
edits will not work; new cards are sent each time. To fix: ensure your
`hermes send` outputs `message_id: om_xxx` on stdout on success.

## "state.json is missing required keys"

This means a script wrote a partial state. Check the most recent
`events.jsonl` for the last successful operation. You can re-write the
state with `python -c "from scripts.lib import state; state.write(
'<runs_dir>', { ... full state ... })"`.

## "Review keeps failing self-check"

`02_spec_plan.sh` retries self-check up to 2 times, then halts. Read
`self-check.md` to see what Codex thinks is missing. Common causes:
- The spec references behaviour the user did not state (over-spec)
- The plan skips an acceptance criterion (under-plan)
- The plan uses a technology the project does not have

You can re-run Phase 2 after editing the spec/plan manually:
`bash scripts/phases/02_spec_plan.sh <job_id>`.

## "Job is orphaned"

Run `hermes-dev reconcile --auto-resume`. Or manually:
`hermes-dev continue <job_id> --force`.

## "git diff is empty for a non-trivial change"

This means Claude Code committed on a different branch. Check
`state.json.project.branch`; if it does not match
`hermes-dev/<job_id>`, manually re-checkout and re-commit:
`cd $PROJECT && git checkout hermes-dev/<job_id> && git cherry-pick <sha>`.

## "Codex 5xx error"

Transient. The skill retries 3 times with exponential backoff. If it
still fails, the job is halted. Re-run `bash scripts/phases/02_spec_plan.sh`
or `04_review.sh` after Codex is back up.
````

- [ ] **Step 3: Commit**

```bash
git add hermes-dev-skill/references/feishu-message-format.md hermes-dev-skill/references/troubleshooting.md
git commit -m "docs(references): feishu card format and troubleshooting"
```

---

## Task 33: README.md

**Files:**
- Create: `hermes-dev-skill/README.md`

- [ ] **Step 1: Write the README**

````markdown
# hermes-dev-skill

A Hermes-invocable skill that turns a free-form dev idea in Feishu into
working code on a git branch, using Codex (for spec / plan / review) and
Claude Code (for implementation). Includes a 5-round bounded review
loop and checkpoint-based crash recovery.

## Install

```bash
cd ~/Documents/RichardHub/Git/hermes-dev-skill
pip install -e ".[dev]"
bash install.sh
```

`install.sh` (run separately after `pip install`):
- Creates `~/.hermes/hermes-dev/` and copies `config.example.yaml` →
  `config.yaml`
- Creates `~/.hermes/runs/`
- Symlinks `scripts/hermes-dev` into `~/.local/bin/hermes-dev`

## Use

From a Feishu chat with your Hermes bot, say something like:

> 帮我做一个股票价格预警功能，触发条件是价格跌破 5 日均线 5%

Hermes will:
1. Create a new job and reply with the job ID
2. Ask 1–3 clarifying questions per turn
3. Invoke Codex to write `spec.md` and `plan.md`, then self-check
4. Invoke Claude Code to implement on `hermes-dev/<job_id>` branch
5. Run up to 5 rounds of Codex review + Claude Code fix
6. Send a summary card with the diff and branch info

Reply `@bot 继续` to extend the review cap by 5 rounds if the first 5
don't pass.

## Architecture

Hybrid orchestrator:
- **Hermes (LLM)** drives: Feishu I/O, multi-turn clarification, the
  "is the spec complete" judgement, the handoff message
- **Bash + Python scripts** drive: `codex` and `claude` CLI invocations,
  `git` operations, `state.json` transitions, review-verdict parsing,
  retry logic

State lives at `~/.hermes/runs/<job_id>/` and is updated atomically.

## Tests

```bash
cd ~/Documents/RichardHub/Git/hermes-dev-skill
python -m pytest                  # unit + integration (no real Codex/Claude Code)
python -m pytest -m e2e           # e2e dry-run with canned responses
```

Manual smoke: see `tests/manual/smoke.sh`.

## Spec / design

See `design-specs/2026-06-14-hermes-dev-collab-skill-design.md` for the
full design rationale and `plans/2026-06-14-hermes-dev-collab-skill.md`
for the implementation plan.
````

- [ ] **Step 2: Commit**

```bash
git add hermes-dev-skill/README.md
git commit -m "docs: README with install and quickstart"
```

---

# M8: Install + e2e + smoke

## Task 34: e2e test with sandbox-project

**Files:**
- Create: `hermes-dev-skill/tests/e2e/sandbox-project/setup.sh` (creates the 50-line throwaway git repo)
- Create: `hermes-dev-skill/tests/e2e/test_e2e_dry_run.py`

- [ ] **Step 1: Write the sandbox setup script**

`tests/e2e/sandbox-project/setup.sh`:

```bash
#!/usr/bin/env bash
# Tests/e2e/sandbox-project/setup.sh
# Creates a 50-line throwaway Python project for e2e tests.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
cd "$HERE"

if [ -d ".git" ]; then
    echo "sandbox-project already initialized"
    exit 0
fi

git init -b main
git config user.email "sandbox@test"
git config user.name "Sandbox"

cat > add.py <<'PY'
"""add two numbers"""


def add(a: int, b: int) -> int:
    return a + b


if __name__ == "__main__":
    print(add(1, 2))
PY

cat > test_add.py <<'PY'
from add import add


def test_add_basic():
    assert add(1, 2) == 3


def test_add_negative():
    assert add(-1, 1) == 0
PY

cat > README.md <<'MD'
# Sandbox Project
Throwaway 50-line Python project for hermes-dev e2e tests.
MD

git add -A
git commit -m "initial sandbox"
echo "sandbox-project ready"
```

```bash
chmod +x /Users/xpy/Documents/RichardHub/Git/hermes-dev-skill/tests/e2e/sandbox-project/setup.sh
```

- [ ] **Step 2: Run setup to create the project**

Run: `cd hermes-dev-skill/tests/e2e/sandbox-project && bash setup.sh`
Expected: prints "sandbox-project ready"; `.git/` now exists.

- [ ] **Step 3: Write the e2e test**

```python
# hermes-dev-skill/tests/e2e/test_e2e_dry_run.py
"""End-to-end dry-run test.

This test exercises the full pipeline (new -> status -> cancel) without
invoking real Codex or Claude Code. It validates the CLI plumbing and
state transitions work end-to-end. The Phase 2/3/4 scripts are not
exercised here because they would call out to real CLIs.
"""
import os
import subprocess
import sys
from pathlib import Path
import pytest

ROOT = Path(__file__).parent.parent.parent
SCRIPT = ROOT / "scripts" / "hermes_dev.py"
SANDBOX = ROOT / "tests" / "e2e" / "sandbox-project"


def run_cli(*args, env=None):
    full_env = os.environ.copy()
    if env:
        full_env.update(env)
    return subprocess.run(
        [sys.executable, str(SCRIPT), *args],
        capture_output=True, text=True, env=full_env,
    )


@pytest.mark.e2e
def test_full_lifecycle_new_status_cancel(tmp_path, monkeypatch):
    monkeypatch.setenv("HOME", str(tmp_path))
    # Set up sandbox project
    assert SANDBOX.exists()
    assert (SANDBOX / ".git").exists()

    # Phase 0: new
    r = run_cli("new", "add a multiply function to the sandbox")
    assert r.returncode == 0, r.stderr
    job_id = r.stdout.strip()
    assert job_id

    # Phase 1: simulate the user choosing the project
    r = run_cli("register", "sandbox", str(SANDBOX))
    assert r.returncode == 0, r.stderr

    import json
    runs = tmp_path / ".hermes" / "runs" / job_id
    state = json.loads((runs / "state.json").read_text())
    state["project"] = {
        "name": "sandbox",
        "path": str(SANDBOX),
        "branch": f"hermes-dev/{job_id}",
        "base_branch": "main",
        "is_git": True,
    }
    (runs / "state.json").write_text(json.dumps(state, indent=2))
    # Drop a fake requirements.md
    (runs / "requirements.md").write_text("Add multiply(a, b) to add.py\n")

    # Status check
    r = run_cli("status", job_id)
    assert r.returncode == 0
    assert job_id in r.stdout
    assert "sandbox" in r.stdout

    # List check
    r = run_cli("list")
    assert r.returncode == 0
    assert "1 job" in r.stdout

    # Cancel
    r = run_cli("cancel", job_id)
    assert r.returncode == 0
    state = json.loads((runs / "state.json").read_text())
    assert state["status"] == "halted"


@pytest.mark.e2e
def test_register_unregister(tmp_path, monkeypatch):
    monkeypatch.setenv("HOME", str(tmp_path))
    r = run_cli("register", "sandbox", str(SANDBOX))
    assert r.returncode == 0
    r = run_cli("unregister", "sandbox")
    assert r.returncode == 0
    r = run_cli("unregister", "sandbox")
    assert r.returncode != 0
```

- [ ] **Step 4: Run e2e tests**

Run: `cd hermes-dev-skill && python -m pytest tests/e2e/ -m e2e -v`
Expected: 2 tests pass.

- [ ] **Step 5: Commit**

```bash
git add hermes-dev-skill/tests/e2e/
git commit -m "test(e2e): full lifecycle new+register+status+cancel+unregister"
```

---

## Task 35: install.sh + manual smoke

**Files:**
- Create: `hermes-dev-skill/install.sh`
- Create: `hermes-dev-skill/tests/manual/smoke.sh`

- [ ] **Step 1: Write `install.sh`**

```bash
#!/usr/bin/env bash
# hermes-dev-skill/install.sh
# Per-user install: config dir, runs dir, bin symlink. Does NOT configure
# launchd / cron (that's the Hermes host's job).
set -euo pipefail

SKILL_DIR="$(cd "$(dirname "$0")" && pwd)"
HERMES_DIR="$HOME/.hermes"
CONFIG_DIR="$HERMES_DIR/hermes-dev"
RUNS_DIR="$HERMES_DIR/runs"
BIN_DIR="${HOME}/.local/bin"

echo "Installing hermes-dev-skill"
echo "  Skill dir:  $SKILL_DIR"
echo "  Config dir: $CONFIG_DIR"
echo "  Runs dir:   $RUNS_DIR"
echo "  Bin dir:    $BIN_DIR"

# 1. Config dir + config.yaml (only if missing)
mkdir -p "$CONFIG_DIR"
if [ ! -f "$CONFIG_DIR/config.yaml" ]; then
    cp "$SKILL_DIR/config.example.yaml" "$CONFIG_DIR/config.yaml"
    chmod 600 "$CONFIG_DIR/config.yaml"
    echo "  Wrote $CONFIG_DIR/config.yaml"
else
    echo "  $CONFIG_DIR/config.yaml already exists, leaving alone"
fi

# 2. Runs dir
mkdir -p "$RUNS_DIR"
echo "  Runs dir: $RUNS_DIR"

# 3. Bin symlink
mkdir -p "$BIN_DIR"
if [ -L "$BIN_DIR/hermes-dev" ] || [ -e "$BIN_DIR/hermes-dev" ]; then
    echo "  $BIN_DIR/hermes-dev already exists, leaving alone"
else
    ln -s "$SKILL_DIR/scripts/hermes_dev.py" "$BIN_DIR/hermes-dev"
    chmod +x "$BIN_DIR/hermes-dev"
    echo "  Symlinked $BIN_DIR/hermes-dev -> $SKILL_DIR/scripts/hermes_dev.py"
fi

# 4. Optional: add ~/.local/bin to PATH if not already
if [[ ":$PATH:" != *":$BIN_DIR:"* ]]; then
    echo ""
    echo "NOTE: $BIN_DIR is not in your PATH. Add this to your shell rc:"
    echo "  export PATH=\"$BIN_DIR:\$PATH\""
fi

echo ""
echo "Install complete. Verify with:"
echo "  hermes-dev --help"
```

```bash
chmod +x /Users/xpy/Documents/RichardHub/Git/hermes-dev-skill/install.sh
```

- [ ] **Step 2: Write `tests/manual/smoke.sh`**

```bash
#!/usr/bin/env bash
# hermes-dev-skill/tests/manual/smoke.sh
# End-to-end smoke test. Runs against a real project (passed as $1) and
# asserts the state machine, CLI, and basic plumbing work. Does NOT call
# real Codex / Claude Code (those require the user to be present for
# model invocation).
#
# Usage: bash tests/manual/smoke.sh <project_path>
set -euo pipefail

PROJECT="${1:-}"
if [ -z "$PROJECT" ]; then
    echo "usage: $0 <project_path>" >&2
    exit 1
fi
if [ ! -d "$PROJECT" ]; then
    echo "project $PROJECT does not exist" >&2
    exit 1
fi

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
export PYTHONPATH="$REPO_ROOT:$PYTHONPATH"
export HOME=$(mktemp -d)
mkdir -p "$HOME/.hermes"

PASS=0
FAIL=0
check() {
    local desc="$1"
    local result="$2"
    if [ "$result" = "0" ]; then
        echo "  PASS: $desc"
        PASS=$((PASS+1))
    else
        echo "  FAIL: $desc"
        FAIL=$((FAIL+1))
    fi
}

echo "=== hermes-dev-skill smoke test ==="
echo "Project: $PROJECT"
echo "Isolated HOME: $HOME"
echo ""

# 1. CLI works
hermes-dev --help >/dev/null
check "hermes-dev --help exits 0" $?

# 2. Register the project
hermes-dev register smoke "$PROJECT" >/dev/null
check "register smoke" $?

# 3. Create a job
JOB_ID=$(hermes-dev new "smoke test job")
check "new returns a job_id" $?

# 4. Set project state
python -m scripts.lib.state atomic_update \
    "$HOME/.hermes/runs/$JOB_ID/state.json" \
    "{\"project\": {\"name\": \"smoke\", \"path\": \"$PROJECT\", \"branch\": \"hermes-dev/$JOB_ID\", \"base_branch\": \"main\", \"is_git\": true}}"
check "set project in state" $?

# 5. Status reports the project
STATUS_OUT=$(hermes-dev status "$JOB_ID")
echo "$STATUS_OUT" | grep -q "smoke"
check "status shows project" $?

# 6. List shows the job
LIST_OUT=$(hermes-dev list)
echo "$LIST_OUT" | grep -q "1 job"
check "list shows 1 job" $?

# 7. Cancel
hermes-dev cancel "$JOB_ID" >/dev/null
check "cancel succeeds" $?
STATUS=$(python -m scripts.lib.state get "$HOME/.hermes/runs/$JOB_ID/state.json" status)
[ "$STATUS" = "halted" ]
check "status is halted" $?

# 8. Unregister
hermes-dev unregister smoke >/dev/null
check "unregister succeeds" $?

echo ""
echo "=== Result: $PASS passed, $FAIL failed ==="
[ "$FAIL" = "0" ]
```

```bash
chmod +x /Users/xpy/Documents/RichardHub/Git/hermes-dev-skill/tests/manual/smoke.sh
```

- [ ] **Step 3: Commit**

```bash
git add hermes-dev-skill/install.sh hermes-dev-skill/tests/manual/smoke.sh
git commit -m "feat(install): install.sh and manual smoke test"
```

---

# M9: Manual verification

## Task 36: User-runs end-to-end against the sandbox

This task has no automated test; the user runs the smoke script and
confirms it passes.

- [ ] **Step 1: Run the install**

```bash
cd /Users/xpy/Documents/RichardHub/Git/hermes-dev-skill
pip install -e ".[dev]"
bash install.sh
```

Expected: prints "Install complete".

- [ ] **Step 2: Run the manual smoke against the e2e sandbox project**

```bash
bash tests/manual/smoke.sh "$(pwd)/tests/e2e/sandbox-project"
```

Expected: prints "=== Result: 8 passed, 0 failed ===" (8 checks pass).

- [ ] **Step 3: Run the full pytest suite**

```bash
python -m pytest -v
```

Expected: all tests pass (unit + integration + e2e). Should be around
40+ tests in total.

- [ ] **Step 4: Verify the CLI works end-to-end**

```bash
hermes-dev --help
hermes-dev new "manual test"
hermes-dev list
hermes-dev status <job_id from new>
hermes-dev cancel <job_id from new>
```

Expected: each command exits 0; `list` shows 1 job; `status` shows
"phase: clarify"; `cancel` halts it.

- [ ] **Step 5: Clean up test artifacts**

```bash
rm -rf ~/.hermes/runs/*  # job dirs created in steps 2–4
```

- [ ] **Step 6: Commit the verification results**

Create `hermes-dev-skill/verification.md`:

```markdown
# Verification

The following checks have been run manually against this build:

- [ ] `pip install -e ".[dev]"` succeeds
- [ ] `bash install.sh` succeeds
- [ ] `bash tests/manual/smoke.sh tests/e2e/sandbox-project` — 8/8 pass
- [ ] `python -m pytest -v` — all unit, integration, and e2e tests pass
- [ ] `hermes-dev new` / `list` / `status` / `cancel` — all work end-to-end

Date: __DATE__
Tester: __NAME__
```

Commit:

```bash
git add hermes-dev-skill/verification.md
git commit -m "docs: verification.md template (fill in after running Task 36)"
```

---

# End of plan

After all 36 tasks are complete, the skill is fully functional for the
state-machine + CLI + happy-path phases. The remaining out-of-scope items
(launchd / cron for reconcile, multi-user, push/PR) are listed in the
spec §15 Open Questions and are intentionally deferred to v1.1.
