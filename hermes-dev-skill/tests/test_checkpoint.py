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
