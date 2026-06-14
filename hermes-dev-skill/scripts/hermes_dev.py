# hermes-dev-skill/scripts/hermes_dev.py
"""hermes-dev CLI entry point.

Subcommands:
  new          Create a new job (implemented)
  status       Show job state (stub)
  list         List all known jobs (stub)
  tail         Stream events.jsonl (stub)
  continue     Resume a job from checkpoint (stub)
  cancel       Mark a job halted (stub)
  register     Add a project to the registry (stub)
  unregister   Remove a project from the registry (stub)
  reconcile    Scan for orphaned jobs (stub)
"""
from __future__ import annotations

import argparse
import os
import sys
import time
import uuid
from pathlib import Path
from typing import Sequence

# Allow `from scripts.lib import ...` when this file is executed directly
# (e.g. `python scripts/hermes_dev.py` from the test harness).
_PROJECT_ROOT = Path(__file__).resolve().parent.parent
if str(_PROJECT_ROOT) not in sys.path:
    sys.path.insert(0, str(_PROJECT_ROOT))

from scripts.lib import state as state_lib
from scripts.lib import project_registry


def _generate_job_id() -> str:
    ts = time.strftime("%Y%m%d-%H%M")
    suffix = uuid.uuid4().hex[:6]
    return f"{ts}-{suffix}"


def _job_already_exists(runs_root: Path, job_id: str) -> bool:
    return (runs_root / job_id).exists()


def cmd_new(args: argparse.Namespace) -> int:
    runs_root = Path(os.path.expanduser("~/.hermes/runs"))
    runs_root.mkdir(parents=True, exist_ok=True)

    # Generate a unique job_id (with microsecond fallback on collision)
    for _ in range(5):
        job_id = _generate_job_id()
        if not _job_already_exists(runs_root, job_id):
            break
        time.sleep(0.001)
    else:
        # 5 collisions in a row is extremely unlikely; use a full uuid
        job_id = f"{time.strftime('%Y%m%d-%H%M')}-{uuid.uuid4().hex[:12]}"

    job_dir = runs_root / job_id
    job_dir.mkdir(parents=False)

    initial_state = {
        "job_id": job_id,
        "version": "1.0",
        "created_at": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
        "updated_at": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
        "status": "running",
        "phase": "clarify",
        "phase_round": 1,
        "intent": args.intent,
        "project": {},
        "artifacts": {},
        "feishu_message_ids": [],
        "errors": [],
        "user_overrides": {
            "codex_model": None,
            "max_review_rounds": 5,
            "extra_review_rounds_added": 0,
        },
    }
    state_lib.write(job_dir, initial_state)
    print(job_id)
    return 0


def _runs_dir() -> Path:
    return Path(os.path.expanduser("~/.hermes/runs"))


def _find_job(job_id: str) -> Path:
    p = _runs_dir() / job_id
    if not p.is_dir():
        raise FileNotFoundError(f"job {job_id} not found")
    return p


def cmd_status(args: argparse.Namespace) -> int:
    try:
        job_dir = _find_job(args.job_id) if args.job_id else None
    except FileNotFoundError as e:
        print(str(e), file=sys.stderr)
        return 1
    if job_dir is None:
        # No job_id given; pick the most recent
        runs = _runs_dir()
        if not runs.exists():
            print("no jobs", file=sys.stderr)
            return 1
        jobs = sorted(runs.iterdir(), key=lambda p: p.stat().st_mtime, reverse=True)
        if not jobs:
            print("no jobs", file=sys.stderr)
            return 1
        job_dir = jobs[0]
    s = state_lib.read(job_dir)
    # Pretty print key fields
    for key in ("job_id", "status", "phase", "phase_round", "intent"):
        if key in s:
            print(f"{key}: {s[key]}")
    if "project" in s and s["project"]:
        print(f"project: {s['project'].get('path', '<unset>')}")
    return 0


def cmd_list(args: argparse.Namespace) -> int:
    runs = _runs_dir()
    if not runs.exists():
        print("0 jobs")
        return 0
    jobs = sorted(runs.iterdir(), key=lambda p: p.stat().st_mtime, reverse=True)
    print(f"{len(jobs)} job(s):")
    for j in jobs:
        try:
            s = state_lib.read(j)
        except state_lib.StateError:
            print(f"  {j.name}  <corrupt>")
            continue
        print(f"  {j.name}  {s.get('status','?')}  phase={s.get('phase','?')}")
    return 0


def cmd_tail(args: argparse.Namespace) -> int:
    try:
        job_dir = _find_job(args.job_id)
    except FileNotFoundError as e:
        print(str(e), file=sys.stderr)
        return 1
    log = job_dir / "events.jsonl"
    if not log.exists():
        # Just print a friendly message and exit 0
        print("(no events)")
        return 0
    sys.stdout.write(log.read_text(encoding="utf-8"))
    return 0


def cmd_continue(args: argparse.Namespace) -> int:
    try:
        job_dir = _find_job(args.job_id)
    except FileNotFoundError as e:
        print(str(e), file=sys.stderr)
        return 1
    s = state_lib.read(job_dir)
    if s["status"] == "done":
        print(f"job {args.job_id} is done; nothing to continue", file=sys.stderr)
        return 1
    if s["status"] == "halted" and not args.force:
        print(
            f"job {args.job_id} is halted; pass --force to resume anyway",
            file=sys.stderr,
        )
        return 1

    # Mark as running and re-invoke the appropriate phase script.
    # For v1, the phase scripts are stubs that just exit 0; the actual
    # orchestrator will be implemented in later tasks. Here we just
    # re-set the status.
    state_lib.atomic_update(job_dir, '{"status": "running"}')
    print(f"resuming job {args.job_id} from phase {s['phase']}")
    return 0


def cmd_cancel(args: argparse.Namespace) -> int:
    try:
        job_dir = _find_job(args.job_id)
    except FileNotFoundError as e:
        print(str(e), file=sys.stderr)
        return 1
    state_lib.atomic_update(
        job_dir, '{"status": "halted", "phase": "halted"}'
    )
    print(f"job {args.job_id} marked halted")
    return 0


def cmd_register(args: argparse.Namespace) -> int:
    project_registry.register(args.name, args.path, default_branch=args.default_branch)
    print(f"registered '{args.name}' -> {args.path}")
    return 0


def cmd_unregister(args: argparse.Namespace) -> int:
    try:
        project_registry.unregister(args.name)
    except KeyError as e:
        print(str(e), file=sys.stderr)
        return 1
    print(f"unregistered '{args.name}'")
    return 0


def cmd_reconcile(args: argparse.Namespace) -> int:
    print(f"[stub] reconcile age={args.age}", file=sys.stderr)
    return 0


def build_parser() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(prog="hermes-dev", description=__doc__)
    sub = p.add_subparsers(dest="subcommand", required=True)

    sp = sub.add_parser("new", help="Create a new job")
    sp.add_argument("intent", help="The user's dev intent (free text)")
    sp.set_defaults(func=cmd_new)

    sp = sub.add_parser("status", help="Show job state")
    sp.add_argument("job_id", nargs="?", help="Job ID; defaults to most recent")
    sp.set_defaults(func=cmd_status)

    sp = sub.add_parser("list", help="List all known jobs")
    sp.set_defaults(func=cmd_list)

    sp = sub.add_parser("tail", help="Stream events.jsonl")
    sp.add_argument("job_id")
    sp.set_defaults(func=cmd_tail)

    sp = sub.add_parser("continue", help="Resume a job from checkpoint")
    sp.add_argument("job_id")
    sp.add_argument("--force", action="store_true", help="Force resume even if halted")
    sp.set_defaults(func=cmd_continue)

    sp = sub.add_parser("cancel", help="Mark a job halted")
    sp.add_argument("job_id")
    sp.set_defaults(func=cmd_cancel)

    sp = sub.add_parser("register", help="Register a project")
    sp.add_argument("name")
    sp.add_argument("path")
    sp.add_argument("--default-branch", default="main")
    sp.set_defaults(func=cmd_register)

    sp = sub.add_parser("unregister", help="Remove a project")
    sp.add_argument("name")
    sp.set_defaults(func=cmd_unregister)

    sp = sub.add_parser("reconcile", help="Scan for orphaned jobs")
    sp.add_argument("--age", default="5m", help="Threshold (e.g. 5m, 1h)")
    sp.add_argument("--auto-resume", action="store_true")
    sp.set_defaults(func=cmd_reconcile)

    return p


def main(argv: Sequence[str] | None = None) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)
    return args.func(args)


if __name__ == "__main__":
    sys.exit(main())
