# hermes-dev-skill/tests/test_project_registry.py
import json
from pathlib import Path
import pytest

from scripts.lib.project_registry import (
    registry_path, load, save, register, unregister, lookup, scan_common_dirs
)


def test_registry_path(tmp_home):
    assert registry_path() == tmp_home / ".hermes" / "projects.json"


def test_load_when_missing_returns_empty(tmp_home):
    assert load() == {}


def test_register_creates_file(tmp_home):
    register("stocks", "~/projects/stocks", default_branch="main")
    assert json.loads(registry_path().read_text()) == {
        "stocks": {"path": "~/projects/stocks", "default_branch": "main"}
    }


def test_register_expands_user(tmp_home):
    register("blog", "~/code/blog")
    assert lookup("blog")["path"] == str(Path("~/code/blog").expanduser())


def test_unregister(tmp_home):
    register("x", "/x")
    register("y", "/y")
    unregister("x")
    assert set(load().keys()) == {"y"}


def test_unregister_missing_raises(tmp_home):
    with pytest.raises(KeyError):
        unregister("nonexistent")


def test_lookup_missing_returns_none(tmp_home):
    assert lookup("nope") is None


def test_scan_common_dirs_finds_repos(tmp_home, tmp_path, monkeypatch):
    """scan_common_dirs() looks for git repos in ~/projects, ~/code, ~/Documents."""
    proj = tmp_path / "projects" / "myrepo"
    proj.mkdir(parents=True)
    (proj / ".git").mkdir()  # marker only
    monkeypatch.setenv("HOME", str(tmp_path))
    found = scan_common_dirs()
    assert any("myrepo" in p for p in found)
