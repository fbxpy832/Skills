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
    state.atomic_update(job_dir, '{"status": "orphaned"}')


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
