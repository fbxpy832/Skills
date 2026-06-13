# hermes-dev-skill/tests/test_state.py
import json
from pathlib import Path
import pytest

from scripts.lib.state import read, write, StateError, atomic_update, get


def _write_state(runs_dir: Path, **overrides) -> None:
    """Helper: write a valid state with sensible defaults + overrides."""
    state = {
        "job_id": "a",
        "status": "running",
        "phase": "review",
        "phase_round": 1,
    }
    state.update(overrides)
    write(runs_dir, state)


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
    state = {
        "job_id": "test-001",
        "status": "running",
        "phase": "clarify",
        "phase_round": 1,
    }
    write(tmp_runs_dir, state)

    def boom(*args, **kwargs):
        raise OSError("disk full mid-rename")
    monkeypatch.setattr(os, "replace", boom)

    with pytest.raises(OSError):
        write(tmp_runs_dir, {"job_id": "test-002", "status": "running", "phase": "clarify", "phase_round": 1})

    # Original must still be readable
    assert read(tmp_runs_dir)["job_id"] == "test-001"
    # Temp file must be cleaned up
    leftovers = list(tmp_runs_dir.glob(".state.*.tmp"))
    assert leftovers == [], f"temp files not cleaned up: {leftovers}"


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


def test_atomic_update_increments_field(tmp_runs_dir):
    _write_state(
        tmp_runs_dir,
        user_overrides={"max_review_rounds": 5, "extra_review_rounds_added": 0},
    )
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
    _write_state(
        tmp_runs_dir,
        phase="clarify",
        project={"path": "/x", "branch": "hermes-dev/a"},
    )
    atomic_update(tmp_runs_dir, '''
    { "phase": "spec_plan" }
    ''')
    after = read(tmp_runs_dir)
    assert after["phase"] == "spec_plan"
    assert after["project"]["path"] == "/x"


def test_atomic_update_uses_lock(tmp_runs_dir):
    """Concurrent updates must not lose data (file lock around read+write)."""
    import threading
    _write_state(tmp_runs_dir, counter=0)

    def bump():
        for _ in range(20):
            atomic_update(tmp_runs_dir, '''
            { "counter": current["counter"] + 1 }
            ''')
    threads = [threading.Thread(target=bump) for _ in range(5)]
    for t in threads:
        t.start()
    for t in threads:
        t.join()
    assert read(tmp_runs_dir)["counter"] == 100


def test_get_dotted_path(tmp_runs_dir):
    _write_state(
        tmp_runs_dir,
        user_overrides={"max_review_rounds": 7},
    )
    assert get(tmp_runs_dir, "user_overrides.max_review_rounds") == 7
    assert get(tmp_runs_dir, "status") == "running"
