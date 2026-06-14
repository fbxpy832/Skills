# hermes-dev-skill/scripts/hermes_dev.py
"""hermes-dev CLI entry point.

Subcommands (all stubbed initially, implemented in later tasks):
  new          Create a new job
  status       Show job state
  list         List all known jobs
  tail         Stream events.jsonl
  continue     Resume a job from checkpoint
  cancel       Mark a job halted
  register     Add a project to the registry
  unregister   Remove a project from the registry
  reconcile    Scan for orphaned jobs
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


def cmd_status(args: argparse.Namespace) -> int:
    print(f"[stub] status: {args.job_id}", file=sys.stderr)
    return 0


def cmd_list(args: argparse.Namespace) -> int:
    print("[stub] list", file=sys.stderr)
    return 0


def cmd_tail(args: argparse.Namespace) -> int:
    print(f"[stub] tail: {args.job_id}", file=sys.stderr)
    return 0


def cmd_continue(args: argparse.Namespace) -> int:
    print(f"[stub] continue: {args.job_id} force={args.force}", file=sys.stderr)
    return 0


def cmd_cancel(args: argparse.Namespace) -> int:
    print(f"[stub] cancel: {args.job_id}", file=sys.stderr)
    return 0


def cmd_register(args: argparse.Namespace) -> int:
    print(f"[stub] register: {args.name} -> {args.path}", file=sys.stderr)
    return 0


def cmd_unregister(args: argparse.Namespace) -> int:
    print(f"[stub] unregister: {args.name}", file=sys.stderr)
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
