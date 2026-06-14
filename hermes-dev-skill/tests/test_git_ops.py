# hermes-dev-skill/tests/test_git_ops.py
import subprocess
from pathlib import Path
import pytest

from scripts.lib.git_ops import (
    is_git_repo, create_branch, commit_iteration,
    diff_against_baseline, current_branch, last_commit_message,
)


@pytest.fixture
def git_repo(tmp_path):
    """Initialize a git repo with one commit on main."""
    repo = tmp_path / "repo"
    repo.mkdir()
    subprocess.run(["git", "init", "-b", "main"], cwd=repo, check=True, capture_output=True)
    subprocess.run(["git", "config", "user.email", "test@test"], cwd=repo, check=True)
    subprocess.run(["git", "config", "user.name", "Test"], cwd=repo, check=True)
    (repo / "README.md").write_text("hello\n")
    subprocess.run(["git", "add", "-A"], cwd=repo, check=True)
    subprocess.run(["git", "commit", "-m", "initial"], cwd=repo, check=True)
    return repo


def test_is_git_repo_true(git_repo):
    assert is_git_repo(git_repo) is True


def test_is_git_repo_false(tmp_path):
    assert is_git_repo(tmp_path) is False


def test_create_branch_checkouts_new(git_repo):
    create_branch(git_repo, "abc123", base="main")
    assert current_branch(git_repo) == "hermes-dev/abc123"


def test_create_branch_idempotent(git_repo):
    create_branch(git_repo, "abc123", base="main")
    create_branch(git_repo, "abc123", base="main")  # should not error
    assert current_branch(git_repo) == "hermes-dev/abc123"


def test_commit_iteration(git_repo):
    create_branch(git_repo, "abc", base="main")
    (git_repo / "new.txt").write_text("content\n")
    commit_iteration(git_repo, "hermes-dev(abc): add new.txt")
    msg = last_commit_message(git_repo)
    assert "hermes-dev(abc): add new.txt" in msg


def test_diff_against_baseline(git_repo):
    create_branch(git_repo, "abc", base="main")
    (git_repo / "new.txt").write_text("content\n")
    commit_iteration(git_repo, "hermes-dev(abc): add new.txt")
    diff = diff_against_baseline(git_repo, base="main")
    assert "+content" in diff
