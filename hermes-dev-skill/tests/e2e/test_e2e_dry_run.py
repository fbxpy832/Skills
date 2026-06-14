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
