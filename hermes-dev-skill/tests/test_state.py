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
    """If the write is interrupted, the original file (or no file) is preserved."""
    state = {"job_id": "test-001", "status": "running"}
    write(tmp_runs_dir, state)

    # Simulate crash mid-write by raising after rename begins
    real_rename = Path.rename
    def boom(self, target):
        real_rename(self, target)
        raise OSError("disk full")
    monkeypatch.setattr(Path, "rename", boom)

    with pytest.raises(OSError):
        write(tmp_runs_dir, {"job_id": "test-002"})

    # Original must still be readable
    assert read(tmp_runs_dir)["job_id"] == "test-001"
