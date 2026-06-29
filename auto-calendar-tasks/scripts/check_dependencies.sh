#!/usr/bin/env bash
set -euo pipefail

target="${1:-all}"
status=0

check_cmd() {
  local cmd="$1"
  if command -v "$cmd" >/dev/null 2>&1; then
    printf '[OK] %s: %s\n' "$cmd" "$(command -v "$cmd")"
  else
    printf '[MISSING] %s\n' "$cmd" >&2
    status=1
  fi
}

check_path() {
  local label="$1"
  local path="$2"
  if [ -e "$path" ]; then
    printf '[OK] %s: %s\n' "$label" "$path"
  else
    printf '[MISSING] %s: %s\n' "$label" "$path" >&2
    status=1
  fi
}

case "$target" in
  apple)
    check_cmd osascript
    check_cmd python3
    ;;
  lark|feishu)
    check_cmd lark-cli
    check_path lark-shared-skill "$HOME/.codex/memories/skills/lark-shared"
    check_path lark-calendar-skill "$HOME/.codex/memories/skills/lark-calendar"
    check_path lark-task-skill "$HOME/.codex/memories/skills/lark-task"
    ;;
  all)
    "$0" apple || status=1
    "$0" lark || status=1
    ;;
  *)
    printf 'Usage: %s [apple|lark|all]\n' "$0" >&2
    exit 2
    ;;
esac

exit "$status"
