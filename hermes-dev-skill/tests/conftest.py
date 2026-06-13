# hermes-dev-skill/tests/conftest.py
import os
import tempfile
from pathlib import Path
import pytest


@pytest.fixture
def tmp_home(monkeypatch):
    """Isolated $HOME for tests that touch ~/.hermes/."""
    with tempfile.TemporaryDirectory() as td:
        monkeypatch.setenv("HOME", td)
        (Path(td) / ".hermes").mkdir()
        yield Path(td)


@pytest.fixture
def tmp_runs_dir(tmp_path):
    """A scratch directory to act as a job's runs dir."""
    runs = tmp_path / "runs"
    runs.mkdir()
    return runs
