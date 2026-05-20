#!/usr/bin/env python3
"""
Smoke test for OpenCodeAutoLoop v2 git path functions.

Validates that get_dirty_files(), get_changed_files(), get_untracked_files()
all return project_root-relative paths (i.e. normalized via _rel_path).

Usage:
  python opencode-autoloop/test_smoke.py
  python opencode-autoloop/test_smoke.py --project-root /path/to/project
"""

import argparse
import sys
from pathlib import Path

# Add tool directory to path so we can import autoloop
TOOL_ROOT = Path(__file__).resolve().parent
sys.path.insert(0, str(TOOL_ROOT))

import autoloop  # noqa: E402


def test_path_normalization():
    """Verify all paths from git functions are project_root-relative."""
    project_root = autoloop.get_project_root()
    print(f"Project root: {project_root}")
    print(f"Git repo:     {'inside' if autoloop.is_git_repo() else 'NOT A GIT REPO'}")

    if not autoloop.is_git_repo():
        print("SKIP: not inside a git repository")
        return

    # 1. get_dirty_files
    print("\n--- get_dirty_files() ---")
    dirty = autoloop.get_dirty_files()
    print(f"Count: {len(dirty)}")
    for path in dirty:
        ok = "OK" if not path.startswith(str(project_root)) and "/" not in path[0:2] else ""
        full = project_root / path
        exists = full.exists()
        print(f"  [{ok}] {path}  (exists={exists})")

    # 2. get_changed_files
    print("\n--- get_changed_files() ---")
    changed = autoloop.get_changed_files()
    print(changed if changed != "(none)" else "(none)")

    # 3. get_untracked_files
    print("\n--- get_untracked_files() ---")
    untracked = autoloop.get_untracked_files()
    print(f"Count: {len(untracked)}")
    for path in untracked:
        full = project_root / path
        exists = full.exists()
        print(f"  [{'OK' if exists else 'MISSING'}] {path}")

    # 4. _rel_path normalization
    print("\n--- _rel_path() normalization ---")
    test_cases = [
        ("file.py", "file.py"),
        ("opencode-autoloop/autoloop.py", None),  # depends on project_root
    ]
    for input_path, _expected in test_cases:
        result = autoloop._rel_path(input_path)
        is_abs = result.startswith("/")
        print(f"  _rel_path({input_path!r}) = {result!r}  {'[ABSOLUTE!]' if is_abs else 'OK'}")

    # 5. is_working_tree_clean_except_tool
    print("\n--- is_working_tree_clean_except_tool() ---")
    clean = autoloop.is_working_tree_clean_except_tool()
    print(f"Clean (except tool): {clean}")

    print("\n[DONE]")


def main():
    parser = argparse.ArgumentParser(description="Smoke test for OpenCodeAutoLoop v2")
    parser.add_argument("--project-root", help="Target project directory")
    args = parser.parse_args()

    if args.project_root:
        autoloop.set_project_root(Path(args.project_root))

    try:
        test_path_normalization()
    except Exception as e:
        print(f"\nFAIL: {e}")
        import traceback
        traceback.print_exc()
        sys.exit(1)


if __name__ == "__main__":
    main()
