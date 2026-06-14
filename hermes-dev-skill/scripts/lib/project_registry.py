# hermes-dev-skill/scripts/lib/project_registry.py
"""Read/write ~/.hermes/projects.json.

The registry maps project names (short, typeable in Feishu) to absolute
paths. It is created lazily on first register(). Paths may be stored with
~ in them and are expanded at lookup time.
"""
from __future__ import annotations

import json
import os
from pathlib import Path
from typing import Any


def registry_path() -> Path:
    return Path(os.path.expanduser("~/.hermes/projects.json"))


def load() -> dict[str, dict[str, Any]]:
    p = registry_path()
    if not p.exists():
        return {}
    return json.loads(p.read_text(encoding="utf-8"))


def save(reg: dict[str, dict[str, Any]]) -> None:
    p = registry_path()
    p.parent.mkdir(parents=True, exist_ok=True)
    p.write_text(json.dumps(reg, indent=2, ensure_ascii=False), encoding="utf-8")


def register(name: str, path: str, default_branch: str = "main") -> None:
    reg = load()
    reg[name] = {"path": path, "default_branch": default_branch}
    save(reg)


def unregister(name: str) -> None:
    reg = load()
    if name not in reg:
        raise KeyError(f"project {name!r} not registered")
    del reg[name]
    save(reg)


def lookup(name: str) -> dict[str, Any] | None:
    reg = load()
    if name not in reg:
        return None
    entry = dict(reg[name])
    entry["path"] = str(Path(entry["path"]).expanduser())
    return entry


def scan_common_dirs() -> list[str]:
    """Return absolute paths of git repos under ~/projects, ~/code, ~/Documents.

    One level deep only (e.g., ~/projects/stocks yes, ~/projects/stocks/subdir no).
    """
    home = Path(os.path.expanduser("~"))
    roots = [home / "projects", home / "code", home / "Documents"]
    found: list[str] = []
    for root in roots:
        if not root.is_dir():
            continue
        for child in root.iterdir():
            if child.is_dir() and (child / ".git").exists():
                found.append(str(child))
    return sorted(found)
