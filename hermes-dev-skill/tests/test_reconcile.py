# hermes-dev-skill/tests/test_reconcile.py
import json
import time
from pathlib import Path
import pytest

from scripts.lib import reconcile
from scripts.lib.state import write


def _make_job(runs_dir, name, status, age_seconds):
    d = runs_dir / name
    d.mkdir(parents=True)
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
