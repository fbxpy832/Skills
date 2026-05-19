#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
BASE="$ROOT/.codex-opencode"
RESET_LOGS=0
RESET_RUNS=0
CONFIRM_RUNS=0

for arg in "$@"; do
  case "$arg" in
    --logs) RESET_LOGS=1 ;;
    --runs) RESET_RUNS=1 ;;
    --confirm-runs-delete) CONFIRM_RUNS=1 ;;
    -h|--help)
      echo "Usage: bash .codex-opencode/scripts/codex-opencode-reset.sh [--logs] [--runs --confirm-runs-delete]"
      exit 0
      ;;
    *) echo "Unknown argument: $arg" >&2; exit 1 ;;
  esac
done

mkdir -p "$BASE/status" "$BASE/logs" "$BASE/runs" "$BASE/reports"
find "$BASE/status" -type f ! -name '.gitkeep' -delete

cat > "$BASE/status/live.md" <<'EOF'
# Codex ↔ OpenCode / OMA AutoLoop Live Status

Current status: idle
Current round: 0 / 0
Current phase: reset
Last update: reset

Task summary:
No task is running.

OMA status: unknown
OMA mode: auto
Current OMA agent: unknown
Current model: unknown
OpenCode plan: opencode_go
Fallback mode: enabled

Latest result:
Status reset.

Next action:
Run preflight or start an autoloop task.

Last error:
None
EOF

cat > "$BASE/status/state.json" <<'EOF'
{
  "status": "idle",
  "round": 0,
  "max_rounds": 0,
  "phase": "reset",
  "task": "",
  "last_update": null,
  "last_error": null,
  "test_status": "unknown",
  "review_status": "unknown",
  "security_status": "unknown",
  "run_dir": null,
  "oma": {
    "available": null,
    "mode": "auto",
    "current_agent": "unknown",
    "current_model": "unknown",
    "expected_plan": "opencode_go",
    "trigger_test_status": "unknown",
    "fallback_to_plain_opencode": true
  }
}
EOF

if [[ "$RESET_LOGS" -eq 1 ]]; then
  find "$BASE/logs" -type f ! -name '.gitkeep' -delete
fi

if [[ "$RESET_RUNS" -eq 1 ]]; then
  if [[ "$CONFIRM_RUNS" -ne 1 ]]; then
    echo "Refusing to delete runs without --confirm-runs-delete." >&2
    exit 2
  fi
  find "$BASE/runs" -mindepth 1 -maxdepth 1 -type d -exec rm -rf {} +
fi

echo "Reset complete. Config, reports, and run history are preserved unless explicitly confirmed."
