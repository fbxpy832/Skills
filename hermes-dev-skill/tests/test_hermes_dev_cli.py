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


def test_status_with_job_id(tmp_home):
    r = run_cli("new", "x")
    job_id = r.stdout.strip()
    r = run_cli("status", job_id)
    assert r.returncode == 0
    assert job_id in r.stdout


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
