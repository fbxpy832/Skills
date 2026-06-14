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
import sys
from pathlib import Path
from typing import Sequence


def cmd_new(args: argparse.Namespace) -> int:
    print(f"[stub] new: {args.intent}", file=sys.stderr)
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
