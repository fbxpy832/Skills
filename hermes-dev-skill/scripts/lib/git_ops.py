# hermes-dev-skill/scripts/lib/git_ops.py
"""Thin wrappers around `git` for hermes-dev operations.

All operations run with `git -C <path>` so the caller never needs to chdir.
"""
from __future__ import annotations

import shlex
import subprocess
from pathlib import Path


class GitError(Exception):
    """Raised when a git command fails."""


def _run(path: Path, args: list[str], check: bool = True) -> str:
    result = subprocess.run(
        ["git", "-C", str(path), *args],
        capture_output=True, text=True,
    )
    if check and result.returncode != 0:
        raise GitError(
            f"git {shlex.join(args)} in {path} failed (exit {result.returncode}): "
            f"{result.stderr.strip()}"
        )
    return result.stdout


def is_git_repo(path: Path) -> bool:
    result = subprocess.run(
        ["git", "-C", str(path), "rev-parse", "--git-dir"],
        capture_output=True, text=True,
    )
    return result.returncode == 0


def current_branch(path: Path) -> str:
    return _run(path, ["rev-parse", "--abbrev-ref", "HEAD"]).strip()


def create_branch(path: Path, job_id: str, base: str = "main") -> None:
    """Create and checkout hermes-dev/<job_id> from base. Idempotent."""
    branch = f"hermes-dev/{job_id}"
    # Ensure base is checked out
    _run(path, ["checkout", base], check=False)
    # If branch already exists, just switch to it; else create it
    result = subprocess.run(
        ["git", "-C", str(path), "rev-parse", "--verify", branch],
        capture_output=True, text=True,
    )
    if result.returncode == 0:
        _run(path, ["checkout", branch])
    else:
        _run(path, ["checkout", "-b", branch])


def commit_iteration(path: Path, message: str) -> None:
    """Stage all changes and commit with the given message. No-op if no changes."""
    status = _run(path, ["status", "--porcelain"])
    if not status.strip():
        return
    _run(path, ["add", "-A"])
    _run(path, ["commit", "-m", message])


def diff_against_baseline(path: Path, base: str = "main") -> str:
    """Return the diff of the current branch against base. Empty if no diff."""
    return _run(path, ["diff", f"{base}..HEAD"], check=False)


def last_commit_message(path: Path) -> str:
    return _run(path, ["log", "-1", "--pretty=format:%s"]).strip()
