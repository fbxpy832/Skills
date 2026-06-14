# hermes-dev-skill/scripts/lib/checkpoint.py
"""Per-phase checkpoints: snapshot of state.json + hashes of produced artifacts.

A checkpoint is written at the end of each phase. On resume, the orchestrator
re-reads the latest checkpoint to know which phase to re-enter.
"""
from __future__ import annotations

import hashlib
import json
from pathlib import Path
from typing import Any

from . import state


def _checkpoint_path(runs_dir: Path, phase: int) -> Path:
    return Path(runs_dir) / "checkpoints" / f"phase{phase}.json"


def save(runs_dir: Path, phase: int, artifacts: list[str] | None = None) -> None:
    """Snapshot state.json plus SHA-256 hashes of the named artifact files.

    `artifacts` are paths relative to runs_dir (e.g. 'requirements.md')."""
    runs_dir = Path(runs_dir)
    runs_dir.mkdir(parents=True, exist_ok=True)
    (runs_dir / "checkpoints").mkdir(parents=True, exist_ok=True)
    current = state.read(runs_dir)
    hashes: dict[str, str] = {}
    for name in (artifacts or []):
        p = runs_dir / name
        if not p.exists():
            continue
        hashes[name] = hashlib.sha256(p.read_bytes()).hexdigest()
    body = {
        "phase": phase,
        "state": current,
        "artifact_hashes": hashes,
    }
    _checkpoint_path(runs_dir, phase).write_text(
        json.dumps(body, indent=2, ensure_ascii=False, sort_keys=True),
        encoding="utf-8",
    )


def load(runs_dir: Path, phase: int) -> dict[str, Any]:
    """Return the checkpoint body for a given phase. Raises FileNotFoundError if missing."""
    p = _checkpoint_path(runs_dir, phase)
    if not p.exists():
        raise FileNotFoundError(f"no checkpoint for phase {phase} in {runs_dir}")
    return json.loads(p.read_text(encoding="utf-8"))


def verify(runs_dir: Path, phase: int) -> bool:
    """Return True iff all artifacts recorded in the checkpoint still match their hashes."""
    body = load(runs_dir, phase)
    for name, expected in body["artifact_hashes"].items():
        p = Path(runs_dir) / name
        if not p.exists():
            return False
        actual = hashlib.sha256(p.read_bytes()).hexdigest()
        if actual != expected:
            return False
    return True


def latest_phase(runs_dir: Path) -> int | None:
    """Return the highest phase number that has a checkpoint, or None if none exist."""
    cp_dir = Path(runs_dir) / "checkpoints"
    if not cp_dir.is_dir():
        return None
    phases = []
    for p in cp_dir.iterdir():
        if p.name.startswith("phase") and p.name.endswith(".json"):
            try:
                n = int(p.name.removeprefix("phase").removesuffix(".json"))
                phases.append(n)
            except ValueError:
                continue
    return max(phases) if phases else None
