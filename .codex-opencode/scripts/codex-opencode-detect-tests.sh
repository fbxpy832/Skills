#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
BASE="$ROOT/.codex-opencode"
REPORT="$BASE/logs/test.log"
mkdir -p "$BASE/logs" "$BASE/status"

log() { printf '%s\n' "$*" | tee -a "$REPORT" >/dev/null; }
has_cmd() { command -v "$1" >/dev/null 2>&1; }

cd "$ROOT"
: > "$REPORT"
log "# Test Command Detection"
log "Time: $(date '+%Y-%m-%d %H:%M:%S')"
log "Project: $ROOT"
log ""

cmd=""
reason=""

if [[ -f package.json ]]; then
  pm="npm"
  [[ -f pnpm-lock.yaml ]] && pm="pnpm"
  [[ -f yarn.lock ]] && pm="yarn"
  [[ -f bun.lockb || -f bun.lock ]] && pm="bun"
  test_script="$(node -e 'const p=require("./package.json"); console.log((p.scripts&&p.scripts.test)||"")' 2>/dev/null || true)"
  lint_script="$(node -e 'const p=require("./package.json"); console.log((p.scripts&&p.scripts.lint)||"")' 2>/dev/null || true)"
  if [[ -n "$test_script" ]]; then
    cmd="$pm test"
    reason="package.json scripts.test"
  elif [[ -n "$lint_script" ]]; then
    cmd="$pm run lint"
    reason="package.json scripts.lint"
  fi
fi

if [[ -z "$cmd" && -f pyproject.toml ]]; then
  if has_cmd pytest; then
    cmd="pytest"
    reason="pyproject.toml and pytest available"
  else
    cmd="python -m compileall ."
    reason="pyproject.toml without pytest"
  fi
fi

if [[ -z "$cmd" && -f requirements.txt ]]; then
  if has_cmd pytest; then
    cmd="pytest"
    reason="requirements.txt and pytest available"
  else
    cmd="python -m compileall ."
    reason="requirements.txt without pytest"
  fi
fi

if [[ -z "$cmd" && -f go.mod ]]; then
  cmd="go test ./..."
  reason="go.mod"
fi

if [[ -z "$cmd" && -f Cargo.toml ]]; then
  cmd="cargo test"
  reason="Cargo.toml"
fi

if [[ -z "$cmd" && -f Makefile ]]; then
  if grep -Eq '(^|\n)test:' Makefile; then
    cmd="make test"
    reason="Makefile test target"
  fi
fi

if [[ -n "$cmd" ]]; then
  log "Detected test command: $cmd"
  log "Reason: $reason"
  printf '%s\n' "$cmd"
else
  log "No test command detected. Verification should be marked skipped or insufficient, not passed."
  printf '\n'
fi
