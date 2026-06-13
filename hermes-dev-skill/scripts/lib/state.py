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

from filelock import FileLock


class StateError(Exception):
    """Raised when state cannot be read or is structurally invalid."""


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


class TransientError(Exception):
    """Raised when an external call (codex / claude / network) fails in a way
    that retrying with backoff might succeed. Non-transient errors should
    not be wrapped in this; they propagate up to halt the job.
    """


def _lock_path(runs_dir: Path) -> Path:
    return Path(runs_dir) / ".state.lock"


def _eval_patch_expr(patch_expr: str, current: dict[str, Any]) -> Any:
    """Evaluate a patch expression string with `current` bound to the
    existing state. Valid JSON is also valid Python (modulo null/true/false
    which the current callers don't use), so callers that pass a pure-JSON
    string still work. We dedent first so multi-line patches written
    with Python indentation work too. `__builtins__` is cleared as a
    defense-in-depth measure since `eval` is otherwise a code-execution
    sink — callers are internal trusted code.

    Returns whatever the expression evaluates to (must be a dict for
    `atomic_update`).
    """
    import textwrap
    return eval(  # noqa: S307 — callers are internal trusted code
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
