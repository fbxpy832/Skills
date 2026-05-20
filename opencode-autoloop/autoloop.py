#!/usr/bin/env python3
"""
OpenCodeAutoLoop v2 - Local automated development orchestrator.

Architecture:
  OpenCode (main developer) -> Orchestrator (flow control) -> Codex (diff review only)

Usage:
  python opencode-autoloop/autoloop.py --task "your requirement"
  python opencode-autoloop/autoloop.py --task-file docs/USER_REQUIREMENT.md
  python opencode-autoloop/autoloop.py --resume
  python opencode-autoloop/autoloop.py --review-only
  python opencode-autoloop/autoloop.py --fix-only
  python opencode-autoloop/autoloop.py --status
"""

import argparse
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
import time
from datetime import datetime, timedelta
from pathlib import Path
from typing import Optional, Tuple


# -- Color / Output -----------------------------------------------

class _Colors:
    GREEN  = '\033[32m'
    RED    = '\033[31m'
    YELLOW = '\033[33m'
    CYAN   = '\033[36m'
    BOLD   = '\033[1m'
    RESET  = '\033[0m'

_use_color = sys.stdout.isatty()
_quiet = False


def set_quiet(v: bool):
    global _quiet; _quiet = v


def set_no_color():
    global _use_color; _use_color = False


def _c(text: str, code: str) -> str:
    return f"{code}{text}{_Colors.RESET}" if _use_color else text


def info(msg: str):
    if not _quiet:
        print(f"[INFO] {msg}")


def warn(msg: str):
    print(_c(f"[WARN] {msg}", _Colors.YELLOW))


def success(msg: str):
    print(_c(f"[OK] {msg}", _Colors.GREEN))


def die(msg: str, code: int = 1):
    print(_c(f"[ERROR] {msg}", _Colors.RED), file=sys.stderr)
    sys.exit(code)


def phase_header(name: str):
    if not _quiet:
        print()
        print(_c("=" * 60, _Colors.CYAN))
        print(_c(name, _Colors.BOLD))
        print(_c("=" * 60, _Colors.CYAN))


# -- Constants --------------------------------------------------

TOOL_ROOT    = Path(__file__).resolve().parent       # opencode-autoloop/
CONFIG_FILE  = TOOL_ROOT / ".autoloop" / "config.json"
STATE_FILE   = TOOL_ROOT / ".autoloop" / "state.json"
LAST_REVIEW  = TOOL_ROOT / ".autoloop" / "last_review.md"
LAST_PROMPT  = TOOL_ROOT / ".autoloop" / "last_prompt.md"

ANSI_RE = re.compile(r'\x1B(?:[@-Z\\-_]|\[[0-?]*[ -/]*[@-~])')


# -- Helpers ----------------------------------------------------


def get_docs_dir() -> Path:
    """Project-relative docs output directory."""
    return get_project_root() / "docs"


def get_logs_dir() -> Path:
    """Project-relative logs output directory."""
    return get_project_root() / "logs"


# -- Helpers ----------------------------------------------------

def strip_ansi(text: str) -> str:
    return ANSI_RE.sub("", text)


def now_ts() -> str:
    return datetime.now().strftime("%Y%m%d-%H%M%S")


def now_iso() -> str:
    return datetime.now().strftime("%Y-%m-%d %H:%M:%S")


def ensure_dirs():
    for d in [TOOL_ROOT / ".autoloop", get_docs_dir(), get_logs_dir()]:
        d.mkdir(parents=True, exist_ok=True)


def short(text: str, max_len: int = 200) -> str:
    t = " ".join(text.split())
    return t if len(t) <= max_len else t[:max_len - 3] + "..."


def fmt_elapsed(seconds: float) -> str:
    if seconds < 60:
        return f"{seconds:.0f}s"
    elif seconds < 3600:
        return f"{seconds / 60:.1f}m"
    return f"{seconds / 3600:.1f}h"


# -- Project Root ------------------------------------------------

_project_root_override: Optional[Path] = None


def set_project_root(path: Path):
    global _project_root_override
    _project_root_override = path.resolve()


def get_project_root() -> Path:
    if _project_root_override is not None:
        return _project_root_override
    return Path.cwd()


# -- Config -----------------------------------------------------

def _detect_commands() -> dict:
    root = get_project_root()
    result = {"test_commands": [], "lint_commands": [], "build_commands": []}

    pkg_json = root / "package.json"
    if pkg_json.exists():
        try:
            scripts = json.loads(pkg_json.read_text()).get("scripts", {})
            for key, _ in scripts.items():
                full = f"npm run {key}"
                if key in ("test", "test:ci", "test:unit"):
                    if full not in result["test_commands"]:
                        result["test_commands"].append(full)
                if key in ("lint", "lint:check", "eslint", "prettier"):
                    if full not in result["lint_commands"]:
                        result["lint_commands"].append(full)
                if key in ("typecheck", "tsc", "type-check"):
                    if full not in result["lint_commands"]:
                        result["lint_commands"].append(full)
                if key in ("build", "compile"):
                    if full not in result["build_commands"]:
                        result["build_commands"].append(full)
        except Exception:
            pass

    pyproject = root / "pyproject.toml"
    if pyproject.exists():
        try:
            content = pyproject.read_text()
            for cmd in ["pytest", "python -m pytest"]:
                if cmd not in result["test_commands"]:
                    result["test_commands"].append(cmd)
            if "ruff" in content:
                result["lint_commands"].append("ruff check .")
            if "mypy" in content:
                result["lint_commands"].append("mypy .")
        except Exception:
            pass

    makefile = root / "Makefile"
    if makefile.exists():
        try:
            content = makefile.read_text()
            for target in ["test", "lint", "build"]:
                if re.search(rf"^{target}:", content, re.MULTILINE):
                    if target == "test" and "make test" not in result["test_commands"]:
                        result["test_commands"].append("make test")
                    elif target == "lint" and "make lint" not in result["lint_commands"]:
                        result["lint_commands"].append("make lint")
                    elif target == "build" and "make build" not in result["build_commands"]:
                        result["build_commands"].append("make build")
        except Exception:
            pass

    return result


DEFAULT_CONFIG = {
    "opencode_command": "opencode",
    "codex_command": "codex",
    "max_review_rounds": 2,
    "opencode_timeout_seconds": 1800,
    "codex_timeout_seconds": 900,
    "test_commands": [],
    "lint_commands": [],
    "build_commands": [],
    "review_mode": "diff-only",
    "auto_commit": False,
    "require_clean_git_before_start": True,
    "logs_dir": "logs",
    "log_retention_days": 30,
    "opencode_flags": ["--dangerously-skip-permissions"],
    "codex_flags": ["--dangerously-bypass-approvals-and-sandbox"],
    "diff_max_lines": 500,
    "ignore_patterns": [
        "node_modules/*", "dist/*", "build/*", ".next/*",
        "venv/*", ".git/*", "__pycache__/*",
        "*.lock", "package-lock.json", "yarn.lock", "pnpm-lock.yaml"
    ]
}


def load_config() -> dict:
    if CONFIG_FILE.exists():
        try:
            cfg = json.loads(CONFIG_FILE.read_text())
            _migrate_config(cfg)
            return cfg
        except Exception:
            pass
    return {}


def _migrate_config(cfg: dict):
    """Ensure config has all current defaults for missing keys."""
    updated = False
    for key, default_value in DEFAULT_CONFIG.items():
        if key not in cfg:
            cfg[key] = default_value
            updated = True
    if updated:
        CONFIG_FILE.write_text(json.dumps(cfg, indent=2, ensure_ascii=False) + "\n")
        info(f"Migrated config: added missing keys to {CONFIG_FILE}")


def init_config() -> dict:
    config = load_config()
    if config:
        return config

    detected = _detect_commands()
    config = dict(DEFAULT_CONFIG)
    config["test_commands"] = detected["test_commands"]
    config["lint_commands"] = detected["lint_commands"]
    config["build_commands"] = detected["build_commands"]

    CONFIG_FILE.write_text(json.dumps(config, indent=2, ensure_ascii=False) + "\n")
    info(f"Created default config at {CONFIG_FILE}")
    if not detected["test_commands"] and not detected["lint_commands"] and not detected["build_commands"]:
        warn("No test/lint/build commands auto-detected. Edit .autoloop/config.json to add them.")
    return config


# -- Runtime Config (config + CLI overrides) ---------------------

class Runtime:
    """Merged config from config.json + CLI overrides."""
    def __init__(self, args):
        self.raw = init_config()
        if args.max_rounds is not None:
            self.raw["max_review_rounds"] = args.max_rounds
        if args.opencode_timeout is not None:
            self.raw["opencode_timeout_seconds"] = args.opencode_timeout
        if args.codex_timeout is not None:
            self.raw["codex_timeout_seconds"] = args.codex_timeout

    def get(self, key, default=None):
        return self.raw.get(key, default)


# -- State ------------------------------------------------------

def load_state() -> dict:
    if STATE_FILE.exists():
        try:
            return json.loads(STATE_FILE.read_text())
        except Exception:
            pass
    return {}


def save_state(state: dict):
    state["updated_at"] = now_iso()
    STATE_FILE.parent.mkdir(parents=True, exist_ok=True)
    STATE_FILE.write_text(json.dumps(state, indent=2, ensure_ascii=False) + "\n")


def init_state(task: str, config: Runtime, max_rounds: int) -> dict:
    state = {
        "task_id": now_ts(),
        "task": task,
        "status": "planning",
        "current_round": 0,
        "max_review_rounds": max_rounds,
        "last_verdict": "",
        "created_at": now_iso(),
        "updated_at": now_iso(),
        "last_log_dir": "",
        "blocked_reason": "",
        "elapsed_plan_s": 0,
        "elapsed_dev_s": 0,
    }
    save_state(state)
    return state


# -- Pre-flight --------------------------------------------------

def preflight_check(config: Runtime):
    issues = []
    opencode_cmd = config.get("opencode_command", "opencode")
    codex_cmd = config.get("codex_command", "codex")

    if shutil.which(opencode_cmd) is None:
        issues.append(f"{opencode_cmd} not found in PATH")
    if shutil.which(codex_cmd) is None:
        issues.append(f"{codex_cmd} not found in PATH")
    if shutil.which("git") is None:
        issues.append("git not found in PATH")

    if issues:
        warn("Pre-flight check found issues:")
        for issue in issues:
            warn(f"  - {issue}")
    else:
        success("Pre-flight check passed: opencode, codex, git all available")


# -- Git --------------------------------------------------------

_RUNTIME_GENERATED = {".autoloop/", "docs/", "logs/"}

_IGNORE_GLOBS = {"*.lock", "package-lock.json", "yarn.lock", "pnpm-lock.yaml",
                 "node_modules", "dist", "build", ".next", "venv", ".git",
                 "__pycache__", ".DS_Store", "*.pyc", "*.pyo"}


def _glob_to_shell(p: str) -> str:
    """Convert a glob pattern like 'node_modules/*' to a shell-safe pathspec."""
    if p.endswith("/*"):
        return p[:-2]
    if p.startswith("*."):
        return f"*.{p[2:]}"
    return p


def is_git_repo() -> bool:
    root = get_project_root()
    r = subprocess.run(["git", "rev-parse", "--is-inside-work-tree"],
                       capture_output=True, text=True, cwd=root)
    return r.returncode == 0 and r.stdout.strip() == "true"


def is_working_tree_clean() -> bool:
    r = subprocess.run(["git", "status", "--porcelain"],
                       capture_output=True, text=True, cwd=get_project_root())
    return r.stdout.strip() == ""


def get_dirty_files() -> list:
    r = subprocess.run(["git", "status", "--porcelain"],
                       capture_output=True, text=True, cwd=get_project_root())
    lines = r.stdout.strip().split("\n")
    dirty = []
    for line in lines:
        if not line.strip():
            continue
        path = line[3:].strip()
        dirty.append(path)
    return dirty


def is_working_tree_clean_except_tool() -> bool:
    dirty = get_dirty_files()
    try:
        tool_prefix = str(TOOL_ROOT.relative_to(get_project_root())) + "/"
    except ValueError:
        tool_prefix = ""
    for path in dirty:
        if tool_prefix and not path.startswith(tool_prefix):
            return False
        if tool_prefix:
            relative = path[len(tool_prefix):]
            if not any(relative == d.rstrip("/") or relative.startswith(d) for d in _RUNTIME_GENERATED):
                return False
        else:
            return False
    return True


def _git_pathspec_excludes(patterns: list) -> list:
    """Convert ignore patterns to git pathspec excludes."""
    excludes = []
    for p in patterns:
        p = p.strip()
        if not p:
            continue
        excludes.append(f":(exclude){p}")
    return excludes


def get_diff_stat() -> str:
    r = subprocess.run(["git", "diff", "--stat", "--", "."],
                       capture_output=True, text=True, cwd=get_project_root())
    return r.stdout.strip() or "(no changes)"


def get_diff(max_lines: int = 500, ignore_patterns: Optional[list] = None) -> str:
    """Return git diff, filtered by ignore_patterns, truncated per-file."""
    root = get_project_root()
    args = ["git", "diff"]
    exclude_patterns = ignore_patterns or []
    for p in exclude_patterns:
        p = p.strip()
        if p:
            args.append(f":(exclude){p}")
    args.append(".")

    r = subprocess.run(args, capture_output=True, text=True, cwd=root)
    raw = r.stdout
    if not raw.strip():
        return "(no diff)"

    return _truncate_diff_per_file(raw, max_lines)


def _truncate_diff_per_file(diff_text: str, per_file_limit: int) -> str:
    """Truncate each file's diff section to per_file_limit lines."""
    lines = diff_text.split("\n")
    result = []
    file_section = []
    in_file = False
    total_lines = 0

    for line in lines:
        if line.startswith("diff --git "):
            if file_section and in_file:
                result.extend(_maybe_truncate_section(file_section, per_file_limit))
                total_lines += len(file_section)
            file_section = [line]
            in_file = True
        elif in_file:
            file_section.append(line)
        else:
            result.append(line)

    if file_section:
        result.extend(_maybe_truncate_section(file_section, per_file_limit))
        total_lines += len(file_section)

    if total_lines > per_file_limit * 3:
        result.append(f"\n... (diff compressed: per-file limit {per_file_limit} lines) ...\n")

    return "\n".join(result)


def _maybe_truncate_section(section: list, limit: int) -> list:
    if len(section) <= limit + 4:
        return section
    head = section[:limit // 2]
    tail = section[-(limit // 2):]
    fname = section[0].replace("diff --git a/", "").split(" b/")[0] if section else "unknown"
    return head + [f"... ({fname} truncated, {len(section)} lines total) ..."] + tail


def get_changed_files() -> str:
    r = subprocess.run(["git", "diff", "--name-only"],
                       capture_output=True, text=True, cwd=get_project_root())
    return r.stdout.strip() or "(none)"


def _diff_lines_added_removed() -> Tuple[int, int]:
    r = subprocess.run(["git", "diff", "--numstat"],
                       capture_output=True, text=True, cwd=get_project_root())
    added = 0
    removed = 0
    for line in r.stdout.strip().split("\n"):
        parts = line.split("\t")
        if len(parts) >= 2:
            try:
                added += int(parts[0]) if parts[0] != "-" else 0
                removed += int(parts[1]) if parts[1] != "-" else 0
            except ValueError:
                pass
    return added, removed


_SKIP_EXTENSIONS = {".pyc", ".pyo", ".so", ".dylib", ".dll", ".exe",
                    ".bin", ".dat", ".zip", ".tar", ".gz", ".7z",
                    ".png", ".jpg", ".jpeg", ".gif", ".ico", ".svg",
                    ".mp3", ".mp4", ".avi", ".mov", ".wav",
                    ".ttf", ".otf", ".woff", ".woff2", ".eot",
                    ".pdf", ".doc", ".docx", ".xls", ".xlsx",
                    ".DS_Store", ".lock", ".map"}


def get_untracked_files() -> list:
    r = subprocess.run(
        ["git", "ls-files", "--others", "--exclude-standard"],
        capture_output=True, text=True, cwd=get_project_root()
    )
    lines = r.stdout.strip().split("\n")
    project_root = get_project_root()
    try:
        tool_rel = str(TOOL_ROOT.relative_to(project_root)) + "/"
    except ValueError:
        tool_rel = ""
    result = []
    for l in lines:
        if not l:
            continue
        if tool_rel and l.startswith(tool_rel):
            continue
        if any(l.startswith(d) for d in _RUNTIME_GENERATED):
            continue
        ext = Path(l).suffix.lower()
        if ext in _SKIP_EXTENSIONS:
            continue
        result.append(l)
    return result


def get_new_file_contents(files: list, max_bytes: int = 50000) -> str:
    parts = []
    root = get_project_root()
    tool_rel = str(TOOL_ROOT) + "/"
    total = 0
    for f in files:
        filepath = root / f
        fp_str = str(filepath.resolve())
        if fp_str.startswith(tool_rel):
            continue
        if not filepath.exists():
            continue
        try:
            content = filepath.read_text()
            if total + len(content) > max_bytes:
                parts.append(f"\n### {f} (omitted: packet size limit)\n")
                break
            total += len(content)
            parts.append(f"\n### {f}\n```\n{content}\n```\n")
        except Exception:
            parts.append(f"\n### {f}\n(unable to read file)\n")
    return "\n".join(parts)


def check_git(require_clean: bool, allow_dirty: bool):
    if shutil.which("git") is None:
        die("git not found in PATH")
    if not is_git_repo():
        die("Not inside a git repository. Project root: " + str(get_project_root()))
    if require_clean and not allow_dirty and not is_working_tree_clean_except_tool():
        dirty = get_dirty_files()
        die(f"Working tree has uncommitted changes:\n" +
            "\n".join(f"  {d}" for d in dirty) +
            "\n\nCommit or stash changes first, or use --allow-dirty to proceed.")


# -- Command Runner ---------------------------------------------

def run_command(cmd, log_file: Path, timeout: int = 600,
                cwd=None, env: Optional[dict] = None) -> Tuple[int, str, str]:
    if isinstance(cmd, str):
        args = ["bash", "-lc", cmd]
    else:
        args = cmd

    cwd = cwd or get_project_root()
    log_file.parent.mkdir(parents=True, exist_ok=True)

    with open(log_file, "a") as lf:
        lf.write(f"# Command: {' '.join(args)}\n")
        lf.write(f"# Time: {now_iso()}\n")
        lf.write(f"# Timeout: {timeout}s\n")
        lf.write(f"# CWD: {cwd}\n\n")

        try:
            proc = subprocess.run(
                args, capture_output=True, text=True, timeout=timeout,
                cwd=cwd, env={**os.environ, **(env or {})}
            )
            exit_code = proc.returncode
            stdout = proc.stdout
            stderr = proc.stderr
        except subprocess.TimeoutExpired:
            exit_code = 124
            stdout = ""
            stderr = f"Command timed out after {timeout}s"
        except FileNotFoundError as e:
            exit_code = 127
            stdout = ""
            stderr = f"Command not found: {e}"
        except Exception as exc:
            exit_code = 1
            stdout = ""
            stderr = str(exc)

        clean_stdout = strip_ansi(stdout)
        clean_stderr = strip_ansi(stderr)

        lf.write(f"## Exit Code: {exit_code}\n\n")
        lf.write("## STDOUT\n")
        lf.write(clean_stdout if clean_stdout else "(empty)")
        lf.write("\n\n## STDERR\n")
        lf.write(clean_stderr if clean_stderr else "(empty)")
        lf.write("\n")

    return exit_code, clean_stdout, clean_stderr


# -- OpenCode Runner --------------------------------------------

def run_opencode(prompt: str, log_file: Path, timeout: int = 1800,
                 workdir=None) -> Tuple[int, str, str]:
    config = load_config()
    opencode_cmd = config.get("opencode_command", "opencode")
    opencode_flags = config.get("opencode_flags", ["--dangerously-skip-permissions"])

    if shutil.which(opencode_cmd) is None:
        die(f"{opencode_cmd} not found in PATH. Install it or update config.")
        return 127, "", f"{opencode_cmd} not found in PATH"

    workdir = workdir or get_project_root()

    with tempfile.NamedTemporaryFile(mode="w", suffix=".md", delete=False,
                                      prefix="autoloop_opencode_") as tf:
        tf.write(prompt)
        prompt_file = tf.name

    LAST_PROMPT.parent.mkdir(parents=True, exist_ok=True)
    LAST_PROMPT.write_text(prompt)

    info(f"Sending prompt to {opencode_cmd}... ({short(prompt, 120)})")

    try:
        args = [opencode_cmd, "run"] + opencode_flags + ["-f", prompt_file,
                "Please read and execute the instructions in the attached file."]
        result = run_command(args, log_file, timeout=timeout, cwd=workdir)
        exit_code, stdout, stderr = result
        if exit_code == 124:
            warn(f"{opencode_cmd} timed out after {timeout}s")
        elif exit_code != 0:
            warn(f"{opencode_cmd} exited with code {exit_code}")
        return exit_code, stdout, stderr
    finally:
        try:
            os.unlink(prompt_file)
        except OSError:
            pass


# -- Codex Runner -----------------------------------------------

def run_codex(prompt: str, log_file: Path, timeout: int = 900,
              workdir=None) -> Tuple[int, str, str]:
    config = load_config()
    codex_cmd = config.get("codex_command", "codex")
    codex_flags = config.get("codex_flags", ["--dangerously-bypass-approvals-and-sandbox"])

    if shutil.which(codex_cmd) is None:
        die(f"{codex_cmd} not found in PATH. Install it or update config.")
        return 127, "", f"{codex_cmd} not found in PATH"

    workdir = workdir or get_project_root()
    info(f"Sending review to {codex_cmd}...")

    args = [codex_cmd, "exec"] + codex_flags + ["-"]
    log_file.parent.mkdir(parents=True, exist_ok=True)

    with open(log_file, "w") as lf:
        lf.write(f"# Command: {' '.join(args)}\n")
        lf.write(f"# Time: {now_iso()}\n")
        lf.write(f"# Timeout: {timeout}s\n\n")
        lf.write("## STDIN (prompt sent to codex)\n")
        lf.write(prompt[:5000])
        if len(prompt) > 5000:
            lf.write(f"\n... (truncated, total {len(prompt)} chars)")
        lf.write("\n\n## OUTPUT\n")

        try:
            proc = subprocess.run(
                args, input=prompt, capture_output=True, text=True, timeout=timeout,
                cwd=workdir, env={**os.environ}
            )
            exit_code = proc.returncode
            stdout = proc.stdout
            stderr = proc.stderr
        except subprocess.TimeoutExpired:
            exit_code = 124
            stdout = ""
            stderr = f"Command timed out after {timeout}s"
        except FileNotFoundError as e:
            exit_code = 127
            stdout = ""
            stderr = f"Command not found: {e}"
        except Exception as exc:
            exit_code = 1
            stdout = ""
            stderr = str(exc)

        clean_stdout = strip_ansi(stdout)
        clean_stderr = strip_ansi(stderr)

        lf.write(f"Exit Code: {exit_code}\n\n")
        lf.write("## STDOUT\n")
        lf.write(clean_stdout if clean_stdout else "(empty)")
        lf.write("\n\n## STDERR\n")
        lf.write(clean_stderr if clean_stderr else "(empty)")
        lf.write("\n")

    return exit_code, clean_stdout, clean_stderr


# -- Prompt Generators ------------------------------------------

def generate_plan_prompt(task: str) -> str:
    return f"""You are the main development agent for this project.
Your job is to read the current project structure and generate a development
specification and task breakdown.

USER REQUIREMENT:
{task}

Please do the following:

1. Read the project root directory, README if exists, key config files
   (package.json, pyproject.toml, Makefile, etc.), and understand the project structure.

2. Create docs/SPEC.md with the following structure:
   - Goal: what we are building
   - Scope: what is in scope
   - Non-goals: what is explicitly out of scope
   - Constraints: technical constraints
   - Acceptance criteria: how to verify completion
   - Risks: potential issues

3. Create docs/TASKS.md with:
   - Ordered task list
   - Execution order and dependencies
   - Files each task will likely modify
   - Estimated test approach for each task

4. Do NOT modify any business code yet. Only create the planning documents.

5. Keep planning executable, phased, and avoid over-engineering.
   Prefer a minimal viable version first.

6. If requirements are unclear, make reasonable assumptions and
   record them in the documents.

Now please execute: read the project, create SPEC.md and TASKS.md.
"""


def generate_dev_prompt(task: str) -> str:
    return f"""You are the main development agent for this project.
Your job is to execute the development tasks according to the plan.

USER REQUIREMENT:
{task}

Please do the following:

1. Read docs/SPEC.md and docs/TASKS.md to understand the plan.

2. Execute the development tasks in order. For each task:
   - Read relevant existing files before modifying
   - Make only the changes needed for that task
   - Do not expand scope beyond the plan
   - Write clean, working code

3. After making changes, update docs/CHANGELOG_AUTOLOOP.md with:
   - What was changed
   - Why it was changed
   - Any assumptions made

4. If requirements are unclear, make reasonable assumptions and
   record them in the CHANGELOG.

5. Do NOT call Codex. You are the sole developer.

6. Keep output concise - key progress to stdout, details to files.

7. When done, provide:
   - A list of changed files
   - Self-test suggestions
   - Any risks or open issues
"""


def generate_fix_prompt(must_fix_items: list, task: str) -> str:
    items_text = "\n".join(f"- {item}" for item in must_fix_items)
    return f"""You are the main development agent for this project.
A code review has identified issues that MUST be fixed.

ORIGINAL REQUIREMENT:
{task}

MUST FIX ITEMS:
{items_text}

Please do the following:

1. Read the relevant source files that need to be modified.
2. Fix ONLY the Must Fix items listed above.
3. Do NOT fix Should Fix items unless they are directly related to a Must Fix.
4. Do NOT expand scope or introduce new features.
5. After fixing, update docs/CHANGELOG_AUTOLOOP.md with the fix details.
6. Do NOT call Codex.

Now please fix the Must Fix items above.
"""


def generate_codex_review_prompt() -> str:
    return """You are a senior code review agent. You are ONLY reviewing the
REVIEW_PACKET below, which contains a git diff, test summary, and risk notes.

Do NOT replan the entire project.
Do NOT expand requirements.
Do NOT ask the developer to rewrite unrelated modules.

Your job: judge whether the current diff satisfies the requirements,
and whether it has obvious bugs, architectural risks, security risks,
test gaps, or engineering quality problems.

Output format (STRICT - use exactly these headers):

# Codex Review Result

## Verdict
PASS / NEEDS_FIX / BLOCKED

## Must Fix
- List only issues that MUST be fixed before delivery. Write "None" if no must-fix items.

## Should Fix
- List suggested improvements that do NOT block delivery. Write "None" if none.

## Risk Points
- List potential risks. Write "None" if none.

## Suggested Patch Instructions for OpenCode
Write concrete, executable fix instructions for OpenCode. Only for Must Fix items.
Do NOT expand scope. Do NOT suggest architectural rewrites.
If no Must Fix items, write "None".

Judgment rules:
1. No blocking issues -> Verdict = PASS
2. Clear bugs, test failures, unmet requirements, or high risk -> Verdict = NEEDS_FIX
3. Insufficient information, incomplete diff, can't assess -> Verdict = BLOCKED
4. Do NOT output redundant explanations
5. Do NOT output suggestions unrelated to the current diff
6. Fix instructions must be specific, not vague
"""


# -- Review Packet Generator ------------------------------------

def generate_review_packet(task: str, log_dir: Path, rt: Runtime, round_num: int) -> str:
    diff_max_lines = rt.get("diff_max_lines", 500)
    ignore_patterns = rt.get("ignore_patterns", [])

    diff_stat = get_diff_stat()
    diff = get_diff(max_lines=diff_max_lines, ignore_patterns=ignore_patterns)
    changed_files = get_changed_files()
    added, removed = _diff_lines_added_removed()

    untracked = get_untracked_files()
    untracked_newfiles = ""
    if untracked:
        untracked_newfiles = "## Untracked New Files (not yet in git)\n```\n"
        untracked_newfiles += "\n".join(untracked)
        untracked_newfiles += "\n```\n\n"
        untracked_newfiles += "## New File Contents\n"
        untracked_newfiles += get_new_file_contents(untracked)

    test_result_path = get_docs_dir() / "TEST_RESULT.md"
    test_summary = ""
    if test_result_path.exists():
        test_summary = test_result_path.read_text()
    else:
        test_summary = "No test results available."

    packet = f"""# Review Packet

## Original Requirement Summary
{short(task, 500)}

## Current Task Goal
Round {round_num}: Execute development per SPEC.md / TASKS.md and fix any review issues.

## Diff Summary
+{added} / -{removed} lines | {changed_files}

## Git Diff Stat
```
{diff_stat}
```

## Git Diff
```
{diff}
```

## Changed Files
```
{changed_files}
```

{untracked_newfiles}
## Test Result Summary
{test_summary}

## OpenCode Self Assessment
(Please review the diff above. The orchestrator cannot self-assess;
Codex review is expected to verify correctness, safety, and completeness.)

- Completed: Implementation per TASKS.md
- Possible risks: See diff for details
- Uncompleted: N/A (all planned tasks attempted)
- Areas for Codex to focus on: Core logic correctness, error handling, edge cases
"""

    packet_path = get_docs_dir() / "REVIEW_PACKET.md"
    packet_path.write_text(packet)
    info(f"Generated review packet: {packet_path}")
    return packet


# -- Codex Verdict Parser ---------------------------------------

def parse_codex_verdict(output: str) -> dict:
    result = {
        "verdict": "UNKNOWN",
        "must_fix": [],
        "should_fix": [],
        "risk_points": [],
        "patch_instructions": "",
        "raw": output
    }
    verdict_match = re.search(r'##\s*Verdict\s*\n\s*(PASS|NEEDS_FIX|BLOCKED)', output, re.IGNORECASE)
    if verdict_match:
        result["verdict"] = verdict_match.group(1).upper()

    must_fix_match = re.search(r'##\s*Must Fix\s*\n(.*?)(?=##\s|$)', output, re.DOTALL | re.IGNORECASE)
    if must_fix_match:
        section = must_fix_match.group(1).strip()
        if section.lower() != "none":
            result["must_fix"] = [
                line.strip("- ").strip()
                for line in section.split("\n")
                if line.strip().startswith("-") or line.strip().startswith("*")
            ]

    should_fix_match = re.search(r'##\s*Should Fix\s*\n(.*?)(?=##\s|$)', output, re.DOTALL | re.IGNORECASE)
    if should_fix_match:
        section = should_fix_match.group(1).strip()
        if section.lower() != "none":
            result["should_fix"] = [
                line.strip("- ").strip()
                for line in section.split("\n")
                if line.strip().startswith("-") or line.strip().startswith("*")
            ]

    risk_match = re.search(r'##\s*Risk Points\s*\n(.*?)(?=##\s|$)', output, re.DOTALL | re.IGNORECASE)
    if risk_match:
        section = risk_match.group(1).strip()
        if section.lower() != "none":
            result["risk_points"] = [
                line.strip("- ").strip()
                for line in section.split("\n")
                if line.strip().startswith("-") or line.strip().startswith("*")
            ]

    patch_match = re.search(
        r'##\s*Suggested Patch Instructions for OpenCode\s*\n(.*?)(?=##\s|$)',
        output, re.DOTALL | re.IGNORECASE
    )
    if patch_match:
        instructions = patch_match.group(1).strip()
        if instructions.lower() != "none":
            result["patch_instructions"] = instructions
    return result


# -- Log tail extractor ------------------------------------------

def _tail_log(log_path: Path, n: int = 10) -> str:
    """Extract last n non-empty lines from a log file."""
    if not log_path.exists():
        return "(log not found)"
    try:
        lines = log_path.read_text().strip().split("\n")
        relevant = [l for l in lines if l.strip() and not l.startswith("#")]
        return "\n".join(relevant[-n:]) if relevant else "(empty log)"
    except Exception:
        return "(unable to read log)"


# -- Final Report Generator -------------------------------------

def generate_final_report(status: str, task: str, log_dir: Path,
                          changed_files: str, test_summary: str,
                          verdict: str, risks: list, blocked_reason: str = "",
                          state: Optional[dict] = None):
    elapsed_info = ""
    if state:
        plan_s = state.get("elapsed_plan_s", 0)
        dev_s = state.get("elapsed_dev_s", 0)
        if plan_s or dev_s:
            elapsed_info = f"\n## Phase Timing\n- Planning: {fmt_elapsed(plan_s)}\n- Development: {fmt_elapsed(dev_s)}\n"

    added, removed = _diff_lines_added_removed()

    report = f"""# OpenCodeAutoLoop Final Report

## Status
{status}

## Original Requirement
{short(task, 500)}

## Completed Work
Development per SPEC.md and TASKS.md executed. See docs/CHANGELOG_AUTOLOOP.md for details.

## Diff Summary
+{added} / -{removed} lines

## Changed Files
```
{changed_files}
```
{elapsed_info}
## Test Results
{test_summary}

## Codex Review Summary
Final Verdict: {verdict}
Last review details in .autoloop/last_review.md

## Remaining Risks
{chr(10).join(f'- {r}' for r in risks) if risks else 'None'}

## Manual Follow-up
{blocked_reason if blocked_reason else 'None'}

## Logs
{log_dir}
"""
    report_path = get_docs_dir() / "FINAL_REPORT.md"
    report_path.write_text(report)
    info(f"Generated final report: {report_path}")
    return report_path


# -- Auto-cleanup ------------------------------------------------

def cleanup_old_logs(retention_days: int):
    if retention_days <= 0:
        return
    cutoff = datetime.now() - timedelta(days=retention_days)
    count = 0
    if get_logs_dir().exists():
        for entry in get_logs_dir().iterdir():
            if not entry.is_dir():
                continue
            try:
                dt = datetime.strptime(entry.name[:8], "%Y%m%d")
                if dt < cutoff:
                    shutil.rmtree(entry)
                    count += 1
            except (ValueError, OSError):
                pass
    if count > 0 and not _quiet:
        info(f"Cleaned up {count} old log directories (>{retention_days}d)")


# -- Dry run mode ------------------------------------------------

def dry_run(task: str, rt: Runtime):
    info("DRY RUN MODE - no opencode/codex calls will be made")
    info(f"  Task: {short(task)}")
    info(f"  Max review rounds: {rt.get('max_review_rounds', 2)}")
    info(f"  OpenCode timeout: {rt.get('opencode_timeout_seconds', 1800)}s")
    info(f"  Codex timeout: {rt.get('codex_timeout_seconds', 900)}s")
    info(f"  Test commands: {rt.get('test_commands', [])}")
    info(f"  Lint commands: {rt.get('lint_commands', [])}")
    info(f"  Build commands: {rt.get('build_commands', [])}")
    info(f"  Auto commit: {rt.get('auto_commit', False)}")
    info(f"  Project root: {get_project_root()}")
    info(f"  Config file: {CONFIG_FILE}")
    info(f"  State file: {STATE_FILE}")
    info(f"  Docs dir: {get_docs_dir()}")
    info(f"  Logs dir: {get_logs_dir()}")
    return 0


# -- Show Status -------------------------------------------------

def show_status():
    ensure_dirs()
    config = load_config()
    state = load_state()

    print(_c("OpenCodeAutoLoop v2 Status", _Colors.BOLD))
    print(f"  Config:  {CONFIG_FILE}")
    print(f"  State:   {STATE_FILE}")
    print(f"  Project: {get_project_root()}")

    if not state:
        print(_c("  No active run. Use --task to start.", _Colors.YELLOW))
    else:
        status = state.get("status", "unknown")
        status_color = {
            "completed": _Colors.GREEN, "blocked": _Colors.RED,
            "planning": _Colors.CYAN, "developing": _Colors.CYAN,
            "testing": _Colors.CYAN, "reviewing": _Colors.CYAN,
            "fixing": _Colors.CYAN
        }.get(status, _Colors.YELLOW)

        print(f"  Status:     {_c(status, status_color)}")
        print(f"  Task:       {short(state.get('task', 'N/A'), 120)}")
        print(f"  Round:      {state.get('current_round', 0)} / {state.get('max_review_rounds', '?')}")
        print(f"  Verdict:    {state.get('last_verdict', 'N/A')}")
        print(f"  Created:    {state.get('created_at', 'N/A')}")
        print(f"  Updated:    {state.get('updated_at', 'N/A')}")
        print(f"  Logs:       {state.get('last_log_dir', 'N/A')}")
        if state.get("blocked_reason"):
            print(f"  Blocked:    {state['blocked_reason']}")

        # List recent log directories
        if get_logs_dir().exists():
            dirs = sorted([d for d in get_logs_dir().iterdir() if d.is_dir()], reverse=True)[:5]
            if dirs:
                print(f"  Recent runs:")
                for d in dirs:
                    print(f"    {d.name}")

    print()
    print(f"  opencode: {'available' if shutil.which(config.get('opencode_command', 'opencode')) else _c('NOT FOUND', _Colors.RED)}")
    print(f"  codex:    {'available' if shutil.which(config.get('codex_command', 'codex')) else _c('NOT FOUND', _Colors.RED)}")
    print(f"  git:      {'available' if shutil.which('git') else _c('NOT FOUND', _Colors.RED)}")


# -- Main Loop --------------------------------------------------

def _block(msg: str, task: str, log_dir: Path, state: dict,
           rt: Runtime, test_summary: str, verdict: str, risks: list,
           code: int = 5, test_log_hint: Optional[Path] = None):
    state["status"] = "blocked"
    state["blocked_reason"] = msg
    save_state(state)
    generate_final_report("blocked", task, log_dir, get_changed_files(),
                          test_summary, verdict, risks, msg, state)

    if test_log_hint and test_log_hint.exists():
        tail = _tail_log(test_log_hint, 8)
        msg += f"\n\nLast test output:\n{tail}"

    die(msg + " Task blocked.", code=code)


def _end_summary(status: str, log_dir: Path, state: dict, verdict: str, total_s: float):
    """Print compact end-of-run summary."""
    added, removed = _diff_lines_added_removed()
    changed = get_changed_files()
    lines = [
        "",
        _c("=" * 60, _Colors.CYAN),
        _c("RUN COMPLETE", _Colors.BOLD),
        _c("=" * 60, _Colors.CYAN),
        f"  Status:     {_c(status, _Colors.GREEN if status == 'completed' else _Colors.RED)}",
        f"  Verdict:    {verdict}",
        f"  Rounds:     {state.get('current_round', 0)}",
        f"  Files:      {changed}",
        f"  Diff:       +{added} / -{removed} lines",
        f"  Duration:   {fmt_elapsed(total_s)}",
        f"  Logs:       {log_dir}",
        f"  Report:     {get_docs_dir() / 'FINAL_REPORT.md'}",
    ]
    for l in lines:
        if not _quiet:
            print(l)


def run_autoloop(task: str, args, rt: Runtime, resume_state: Optional[dict] = None):
    t_start = time.time()
    ensure_dirs()
    cleanup_old_logs(rt.get("log_retention_days", 30))

    if args.dry_run:
        return dry_run(task, rt)

    info(f"Project root: {get_project_root()}")
    preflight_check(rt)

    if shutil.which("git") is None:
        die("git not found in PATH")
    if not is_git_repo():
        die("Not inside a git repository. Current dir: " + str(get_project_root()))

    check_git(rt.get("require_clean_git_before_start", True), args.allow_dirty)

    max_rounds = rt.get("max_review_rounds", 2)
    opencode_timeout = rt.get("opencode_timeout_seconds", 1800)
    codex_timeout = rt.get("codex_timeout_seconds", 900)

    all_test_commands = (
        rt.get("test_commands", []) +
        rt.get("lint_commands", []) +
        rt.get("build_commands", [])
    )

    # Determine starting phase from resume state
    start_phase = "planning"
    start_round = 0
    if resume_state:
        status = resume_state.get("status", "planning")
        start_round = resume_state.get("current_round", 0)
        log_dir_str = resume_state.get("last_log_dir", "")
        task_id_str = resume_state.get("task_id", now_ts())
        if status in ("planning",):
            start_phase = "planning"
        elif status in ("developing",):
            start_phase = "developing"
        elif status in ("testing",):
            start_phase = "testing"
            start_round = max(start_round, 1)
        elif status in ("fixing",):
            start_phase = "fixing"
            start_round = max(start_round, 1)
        elif status in ("reviewing",):
            start_phase = "reviewing"
            start_round = max(start_round, 1)
        else:
            start_phase = "planning"

        if log_dir_str:
            log_dir = Path(log_dir_str)
        else:
            task_id_str = now_ts()
            log_dir = get_logs_dir() / task_id_str
    else:
        task_id_str = now_ts()
        log_dir = get_logs_dir() / task_id_str

    log_dir.mkdir(parents=True, exist_ok=True)
    info(f"Log directory: {log_dir}")

    state = resume_state or init_state(task, rt, max_rounds)
    state["last_log_dir"] = str(log_dir)
    save_state(state)

    consecutive_same_test_fails = 0
    last_test_fail_cmd = ""

    # -- Phase 1: Plan --
    if start_phase == "planning":
        phase_header("PHASE 1: PLANNING")
        t_phase = time.time()
        state["status"] = "planning"
        save_state(state)

        plan_prompt = generate_plan_prompt(task)
        plan_log = log_dir / "opencode-plan.log"
        info("Calling OpenCode to generate SPEC.md and TASKS.md...")

        exit_code, stdout, stderr = run_opencode(plan_prompt, plan_log, timeout=opencode_timeout)

        if exit_code == 124:
            warn("OpenCode plan timed out. Retrying once...")
            exit_code, stdout, stderr = run_opencode(plan_prompt, plan_log, timeout=opencode_timeout)

        elapsed = time.time() - t_phase
        state["elapsed_plan_s"] = elapsed
        save_state(state)

        if exit_code == 124:
            _block("OpenCode planning timed out twice (after retry)",
                   task, log_dir, state, rt, "Planning incomplete", "UNKNOWN", [], code=5)
        elif exit_code != 0:
            _block(f"OpenCode planning failed (exit {exit_code}). SPEC/TASKS not generated.",
                   task, log_dir, state, rt, "Planning failed", "UNKNOWN", [], code=5)

        success(f"Planning phase complete. ({fmt_elapsed(elapsed)})")
    else:
        info(f"Skipping planning phase (resuming from {start_phase})")

    # -- Phase 2: Develop --
    if start_phase in ("planning", "developing"):
        phase_header("PHASE 2: DEVELOPMENT")
        t_phase = time.time()
        state["status"] = "developing"
        state["current_round"] = 0
        save_state(state)

        dev_prompt = generate_dev_prompt(task)
        dev_log = log_dir / "opencode-dev.log"
        info("Calling OpenCode for development...")

        exit_code, stdout, stderr = run_opencode(dev_prompt, dev_log, timeout=opencode_timeout)

        if exit_code == 124:
            warn("OpenCode dev timed out. Retrying once...")
            exit_code, stdout, stderr = run_opencode(dev_prompt, dev_log, timeout=opencode_timeout)

        elapsed = time.time() - t_phase
        state["elapsed_dev_s"] = elapsed
        save_state(state)

        if exit_code == 124:
            _block("OpenCode development timed out twice (after retry)",
                   task, log_dir, state, rt, "Development incomplete", "UNKNOWN", [], code=5)
        elif exit_code != 0:
            _block(f"OpenCode development failed (exit {exit_code}). Review logs.",
                   task, log_dir, state, rt, "Development failed", "UNKNOWN", [], code=5)

        success(f"Development phase complete. ({fmt_elapsed(elapsed)})")
    else:
        info(f"Skipping development phase (resuming from {start_phase})")

    final_verdict = "UNKNOWN"
    final_risks = []

    # Pre-loop: if resuming from "fixing", re-run fix prompt
    if start_phase == "fixing":
        phase_header("RESUMING FIX PHASE")
        state["status"] = "fixing"
        save_state(state)

        must_fix_items = []
        if LAST_REVIEW.exists():
            last_verdict = parse_codex_verdict(LAST_REVIEW.read_text())
            must_fix_items = last_verdict["must_fix"]

        if not must_fix_items:
            warn("Resuming from fixing but no Must Fix items found in last review.")
        else:
            info(f"Re-running fix for {len(must_fix_items)} Must Fix items...")
            fix_prompt = generate_fix_prompt(must_fix_items, task)
            fix_log = log_dir / f"opencode-fix-round-{start_round}-resume.log"
            exit_code, stdout, stderr = run_opencode(fix_prompt, fix_log, timeout=opencode_timeout)
            if exit_code == 124:
                warn("Fix timed out. Retrying once...")
                exit_code, stdout, stderr = run_opencode(fix_prompt, fix_log, timeout=opencode_timeout)
            if exit_code == 124:
                _block("OpenCode fix timed out twice (after retry)",
                       task, log_dir, state, rt, "Fix incomplete", "NEEDS_FIX", [], code=5)
            elif exit_code != 0:
                warn(f"Fix exited with code {exit_code}")
            info("Resumed fix phase complete.")
        start_phase = "testing"

    loop_start_round = max(start_round or 1, 1)

    for round_num in range(loop_start_round, max_rounds + 1):
        print()
        phase_header(f"ROUND {round_num} / {max_rounds}")
        state["current_round"] = round_num
        save_state(state)

        # -- Phase 3: Test --
        info("PHASE 3: TESTING")
        state["status"] = "testing"
        save_state(state)

        test_log = log_dir / f"test-round-{round_num}.log"
        test_results = []

        with open(test_log, "w") as tlf:
            tlf.write(f"# Test Results - Round {round_num}\n")
            tlf.write(f"# Time: {now_iso()}\n\n")

        for cmd in all_test_commands:
            ec, stdout, stderr = run_command(cmd, test_log, timeout=300)
            test_results.append({
                "command": cmd, "exit_code": ec, "passed": ec == 0,
                "stderr": stderr[:300]
            })
            with open(test_log, "a") as tlf:
                tlf.write(f"\n## {cmd}\nExit Code: {ec}\n")
                if ec != 0:
                    tlf.write(f"STDERR: {stderr[:500]}\n")

        passed = all(r["passed"] for r in test_results)
        failed_cmds = [r["command"] for r in test_results if not r["passed"]]

        test_summary_lines = []
        if not all_test_commands:
            test_summary_lines.append("No test commands configured.")
            test_summary_lines.append("Add test/lint/build commands to .autoloop/config.json.")
        else:
            for r in test_results:
                status_str = "PASS" if r["passed"] else "FAIL"
                line = f"- [{status_str}] {r['command']}"
                test_summary_lines.append(line)
                if r["passed"]:
                    success(line)
                else:
                    warn(line)

        test_summary = "\n".join(line.replace("[PASS] ", "PASS: ").replace("[FAIL] ", "FAIL: ") for line in test_summary_lines)

        test_result_md = f"""# Test Results - Round {round_num}
{"All tests passed!" if passed else "Some tests FAILED!"}

{test_summary}
"""
        (get_docs_dir() / "TEST_RESULT.md").write_text(test_result_md)

        if not passed:
            current_fail_cmd = "|".join(failed_cmds)
            if current_fail_cmd == last_test_fail_cmd:
                consecutive_same_test_fails += 1
                if consecutive_same_test_fails >= 2:
                    _block(f"Same test failure repeated {consecutive_same_test_fails} times: {current_fail_cmd}",
                           task, log_dir, state, rt, test_summary, "UNKNOWN", [],
                           code=5, test_log_hint=test_log)
            else:
                last_test_fail_cmd = current_fail_cmd
                consecutive_same_test_fails = 1

            if round_num == 1 and not passed:
                info("Tests failed. Asking OpenCode to fix test failures first...")
                fix_prompt = f"""You are the main development agent. Tests have failed. 
Please fix the code to make these tests pass. Focus only on test failures.

Failed commands:
{chr(10).join(f'- {c}' for c in failed_cmds)}

Read the test output in docs/TEST_RESULT.md and fix the issues.
"""
                fix_log = log_dir / f"opencode-testfix-round-{round_num}.log"
                run_opencode(fix_prompt, fix_log, timeout=opencode_timeout)

                test_log2 = log_dir / f"test-round-{round_num}-retry.log"
                test_results2 = []
                for cmd in all_test_commands:
                    ec, _, _ = run_command(cmd, test_log2, timeout=300)
                    test_results2.append(ec == 0)
                passed = all(test_results2)
                if passed:
                    success("Tests now pass after OpenCode fix.")
                    test_result_md = test_result_md.replace("Some tests FAILED!", "Tests pass after fix.")
                    (get_docs_dir() / "TEST_RESULT.md").write_text(test_result_md)
                else:
                    warn("Tests still failing after OpenCode fix attempt.")

        # -- Phase 4: Review Packet --
        info("PHASE 4: REVIEW PACKET")
        state["status"] = "reviewing"
        save_state(state)

        review_packet = generate_review_packet(task, log_dir, rt, round_num)

        # -- Phase 5: Codex Review --
        info("PHASE 5: CODEX REVIEW")
        codex_prompt = generate_codex_review_prompt() + "\n\n---\n\n## REVIEW PACKET\n\n" + review_packet
        codex_log = log_dir / f"codex-review-round-{round_num}.log"

        exit_code, stdout, stderr = run_codex(codex_prompt, codex_log, timeout=codex_timeout)
        if exit_code == 124:
            _block("Codex review timed out", task, log_dir, state, rt,
                   test_summary, "UNKNOWN", [], code=5)
        elif exit_code != 0:
            _block(f"Codex review failed (exit {exit_code}). Check {codex_log} for details.",
                   task, log_dir, state, rt,
                   test_summary, "UNKNOWN", [], code=5, test_log_hint=codex_log)

        verdict = parse_codex_verdict(stdout)
        final_verdict = verdict["verdict"]
        final_risks = verdict["risk_points"]

        LAST_REVIEW.parent.mkdir(parents=True, exist_ok=True)
        LAST_REVIEW.write_text(stdout)

        verdict_color = {"PASS": _Colors.GREEN, "NEEDS_FIX": _Colors.YELLOW, "BLOCKED": _Colors.RED}.get(final_verdict, _Colors.YELLOW)
        info(f"Codex Verdict: {_c(final_verdict, verdict_color)}")
        if verdict["must_fix"]:
            for item in verdict["must_fix"]:
                warn(f"  Must Fix: {item}")

        state["last_verdict"] = verdict["verdict"]
        save_state(state)

        if verdict["verdict"] == "PASS":
            success("Codex review PASSED. Task complete!")
            state["status"] = "completed"
            save_state(state)
            generate_final_report("completed", task, log_dir, get_changed_files(),
                                  test_summary, "PASS", final_risks, "", state)
            _end_summary("completed", log_dir, state, "PASS", time.time() - t_start)
            return 0

        elif verdict["verdict"] == "BLOCKED":
            _block("Codex returned BLOCKED verdict. Manual intervention required.",
                   task, log_dir, state, rt, test_summary, "BLOCKED", final_risks,
                   code=5, test_log_hint=test_log)

        elif verdict["verdict"] == "NEEDS_FIX":
            if round_num >= max_rounds:
                _block(f"Max review rounds ({max_rounds}) reached with NEEDS_FIX",
                       task, log_dir, state, rt, test_summary, "NEEDS_FIX", final_risks,
                       code=5, test_log_hint=test_log)

            if not verdict["must_fix"]:
                warn("Codex returned NEEDS_FIX but no Must Fix items listed. Proceeding anyway...")
                continue

            info(f"PHASE 5: FIXING ({len(verdict['must_fix'])} Must Fix items)")
            state["status"] = "fixing"
            save_state(state)

            fix_prompt = generate_fix_prompt(verdict["must_fix"], task)
            fix_log = log_dir / f"opencode-fix-round-{round_num}.log"
            exit_code, stdout, stderr = run_opencode(fix_prompt, fix_log, timeout=opencode_timeout)

            if exit_code == 124:
                warn("Fix timed out. Retrying once...")
                exit_code, stdout, stderr = run_opencode(fix_prompt, fix_log, timeout=opencode_timeout)

            if exit_code == 124:
                _block("OpenCode fix timed out twice (after retry)",
                       task, log_dir, state, rt, test_summary, "NEEDS_FIX", final_risks, code=5)
            elif exit_code != 0:
                warn(f"OpenCode fix exited with code {exit_code}")

            info("Fix phase complete. Continuing to next round.")
        else:
            warn(f"Unknown verdict: {verdict['verdict']}. Treating as NEEDS_FIX.")
            if round_num >= max_rounds:
                _block(f"Max review rounds ({max_rounds}) reached with unknown verdict",
                       task, log_dir, state, rt, test_summary, "UNKNOWN", final_risks, code=5)
            continue

    _block(f"Max review rounds ({max_rounds}) reached without PASS",
           task, log_dir, state, rt, "Max rounds reached", final_verdict, final_risks, code=5)


def run_review_only(task: str, rt: Runtime, args):
    state = load_state()
    if not state or not state.get("last_log_dir"):
        die("No previous run state found. Run a full autoloop first.")

    log_dir = Path(state["last_log_dir"])
    round_num = state.get("current_round", 1)

    info("Generating review packet...")
    review_packet = generate_review_packet(task or state.get("task", ""), log_dir, rt, round_num)

    codex_prompt = generate_codex_review_prompt() + "\n\n---\n\n## REVIEW PACKET\n\n" + review_packet
    codex_log = log_dir / f"codex-review-round-{round_num}-standalone.log"

    codex_timeout = rt.get("codex_timeout_seconds", 900)
    exit_code, stdout, stderr = run_codex(codex_prompt, codex_log, timeout=codex_timeout)

    verdict = parse_codex_verdict(stdout)
    info(f"Codex Verdict: {_c(verdict['verdict'], _Colors.CYAN)}")
    if verdict["must_fix"]:
        for item in verdict["must_fix"]:
            warn(f"  Must Fix: {item}")

    LAST_REVIEW.parent.mkdir(parents=True, exist_ok=True)
    LAST_REVIEW.write_text(stdout)
    info(f"Review saved to {LAST_REVIEW}")


def run_fix_only(task: str, rt: Runtime, args):
    state = load_state()
    last_review_content = ""
    if LAST_REVIEW.exists():
        last_review_content = LAST_REVIEW.read_text()

    if not last_review_content:
        die("No last review found. Run a full autoloop or --review-only first.")

    verdict = parse_codex_verdict(last_review_content)
    if not verdict["must_fix"]:
        info("No Must Fix items in last review. Nothing to fix.")
        return

    info(f"Fixing {len(verdict['must_fix'])} Must Fix items...")
    fix_prompt = generate_fix_prompt(verdict["must_fix"], task or state.get("task", ""))

    log_dir = Path(state.get("last_log_dir", str(get_logs_dir())))
    fix_log = log_dir / f"opencode-fix-standalone-{now_ts()}.log"

    opencode_timeout = rt.get("opencode_timeout_seconds", 1800)
    exit_code, stdout, stderr = run_opencode(fix_prompt, fix_log, timeout=opencode_timeout)
    if exit_code == 0:
        success("Fix complete.")
    else:
        warn(f"Fix exited with code {exit_code}")


def run_resume(args, rt: Runtime):
    state = load_state()
    if not state or state.get("status") in ("completed", "blocked", ""):
        die("No incomplete run to resume. state.json status is completed/blocked/empty.")

    status = state.get("status", "idle")
    task = state.get("task", "")
    info(f"Resuming from status: {status} (round {state.get('current_round', 0)})")
    run_autoloop(task, args, rt, resume_state=state)


# -- CLI Entry Point --------------------------------------------

def main():
    parser = argparse.ArgumentParser(
        description="OpenCodeAutoLoop v2 - Local automated development orchestrator",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""Examples:
  python opencode-autoloop/autoloop.py --task "Add a new feature"
  python opencode-autoloop/autoloop.py --task-file requirement.md
  python opencode-autoloop/autoloop.py --resume
  python opencode-autoloop/autoloop.py --status
  python opencode-autoloop/autoloop.py --review-only
  python opencode-autoloop/autoloop.py --fix-only
  python opencode-autoloop/autoloop.py --task "..." --max-rounds 3 --quiet
  python opencode-autoloop/autoloop.py --task "..." --project-root /path/to/project

Phases:
  planning   -> OpenCode generates SPEC.md + TASKS.md
  developing -> OpenCode executes development tasks
  testing    -> Orchestrator runs lint/test/build commands
  reviewing  -> Codex review of REVIEW_PACKET.md (diff-only)
  fixing     -> OpenCode fixes Must Fix items from review
  (loop test -> review -> fix up to max-review-rounds)
  completed  -> Final report generated
  blocked    -> Manual intervention required
"""
    )
    parser.add_argument("--task", help="Development requirement as a string")
    parser.add_argument("--task-file", help="Path to a file containing the requirement")
    parser.add_argument("--resume", action="store_true", help="Resume from last incomplete run")
    parser.add_argument("--review-only", action="store_true", help="Only generate review packet and run Codex review")
    parser.add_argument("--fix-only", action="store_true", help="Only fix Must Fix items from last Codex review")
    parser.add_argument("--status", action="store_true", help="Show current state and exit")
    parser.add_argument("--allow-dirty", action="store_true", help="Proceed even if git working tree is dirty")
    parser.add_argument("--project-root", help="Target project directory (default: cwd)")
    parser.add_argument("--max-rounds", type=int, help="Override max review rounds from config")
    parser.add_argument("--opencode-timeout", type=int, help="Override opencode timeout (seconds)")
    parser.add_argument("--codex-timeout", type=int, help="Override codex timeout (seconds)")
    parser.add_argument("--config", help="Path to config file (default: .autoloop/config.json)")
    parser.add_argument("--dry-run", action="store_true", help="Show configuration and exit without executing")
    parser.add_argument("--quiet", "-q", action="store_true", help="Reduce output verbosity")
    parser.add_argument("--no-color", action="store_true", help="Disable colored output")
    args = parser.parse_args()

    if args.no_color:
        set_no_color()
    if args.quiet:
        set_quiet(True)

    if args.project_root:
        set_project_root(Path(args.project_root))
        info(f"Project root: {get_project_root()}")

    # Handle --config: change CONFIG_FILE globally
    global CONFIG_FILE
    if args.config:
        CONFIG_FILE = Path(args.config).resolve()
        if not CONFIG_FILE.exists():
            die(f"Config file not found: {CONFIG_FILE}")

    ensure_dirs()
    rt = Runtime(args)

    if args.status:
        show_status()
        return

    task = ""
    if args.task_file:
        task_path = Path(args.task_file)
        if not task_path.exists():
            die(f"Task file not found: {args.task_file}")
        task = task_path.read_text().strip()
        if not task:
            die("Task file is empty")
    elif args.task:
        task = args.task
    elif args.resume or args.review_only or args.fix_only:
        task = ""
    else:
        parser.print_help()
        die("Either --task, --task-file, --resume, --review-only, --fix-only, or --status is required")

    if args.resume:
        run_resume(args, rt)
        return

    if args.review_only:
        run_review_only(task, rt, args)
        return

    if args.fix_only:
        run_fix_only(task, rt, args)
        return

    if not task:
        die("No task provided")

    run_autoloop(task, args, rt)


if __name__ == "__main__":
    main()
