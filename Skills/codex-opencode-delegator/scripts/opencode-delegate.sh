#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-quality}"
STAGE="${2:-execute}"
TASK_TYPE="${3:-execute}"
PROMPT_FILE="${4:-}"
PROJECT_DIR="${5:-$(pwd)}"

if [ -z "$PROMPT_FILE" ]; then
  echo "ERROR: Missing prompt file."
  echo "Usage: opencode-delegate.sh MODE STAGE TASK_TYPE PROMPT_FILE PROJECT_DIR"
  exit 1
fi

if [ ! -f "$PROMPT_FILE" ]; then
  echo "ERROR: Prompt file not found: $PROMPT_FILE"
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MODEL="$("$SCRIPT_DIR/model-router.sh" "$MODE" "$STAGE" "$TASK_TYPE")"

if [ "$MODEL" = "codex-review" ]; then
  echo "Review should be handled by Codex."
  echo "Mode: $MODE"
  echo "Stage: $STAGE"
  echo "Task type: $TASK_TYPE"
  exit 0
fi

if ! command -v opencode >/dev/null 2>&1; then
  echo "ERROR: opencode CLI not found. Please install and login to OpenCode first."
  exit 1
fi

cd "$PROJECT_DIR"

echo "Delegating task to OpenCode CLI"
echo "Mode: $MODE"
echo "Stage: $STAGE"
echo "Task type: $TASK_TYPE"
echo "Selected model: $MODEL"
echo "Project directory: $PROJECT_DIR"
echo ""

opencode run --model "$MODEL" "$(cat "$PROMPT_FILE")"
