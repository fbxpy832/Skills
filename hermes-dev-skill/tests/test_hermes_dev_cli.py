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


def test_status_with_job_id():
    r = run_cli("status", "abc123")
    assert r.returncode == 0
    assert "abc123" in r.stderr


def test_register_parses_default_branch():
    r = run_cli("register", "stocks", "/x", "--default-branch", "main")
    assert r.returncode == 0
    assert "stocks" in r.stderr
    assert "/x" in r.stderr


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
