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
