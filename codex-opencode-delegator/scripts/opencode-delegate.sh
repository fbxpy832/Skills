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

OPENCODE_BIN="${OPENCODE_BIN:-}"
if [ -z "$OPENCODE_BIN" ]; then
  if command -v opencode >/dev/null 2>&1; then
    OPENCODE_BIN="$(command -v opencode)"
  elif [ -x "/opt/homebrew/bin/opencode" ]; then
    OPENCODE_BIN="/opt/homebrew/bin/opencode"
  elif [ -x "$HOME/.opencode/bin/opencode" ]; then
    OPENCODE_BIN="$HOME/.opencode/bin/opencode"
  else
    OPENCODE_BIN=""
  fi
fi

if [ -z "$OPENCODE_BIN" ] || [ ! -x "$OPENCODE_BIN" ]; then
  echo "ERROR: opencode CLI not found. Please install and login to OpenCode first."
  exit 1
fi

export HOME="${HOME:-/Users/xpy}"
export XDG_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
export XDG_STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"

mkdir -p "$XDG_DATA_HOME/opencode" "$XDG_STATE_HOME/opencode"

if [ ! -w "$XDG_DATA_HOME/opencode" ]; then
  echo "ERROR: OpenCode data directory is not writable: $XDG_DATA_HOME/opencode"
  echo "Do not use sudo from this script. Grant Codex write permission or fix ownership manually."
  exit 1
fi

if [ ! -w "$XDG_STATE_HOME/opencode" ]; then
  echo "ERROR: OpenCode state directory is not writable: $XDG_STATE_HOME/opencode"
  echo "Do not use sudo from this script. Grant Codex write permission or fix ownership manually."
  exit 1
fi

export HTTP_PROXY="${HTTP_PROXY:-http://127.0.0.1:7890}"
export HTTPS_PROXY="${HTTPS_PROXY:-http://127.0.0.1:7890}"
export ALL_PROXY="${ALL_PROXY:-socks5://127.0.0.1:7890}"
export NO_PROXY="${NO_PROXY:-localhost,127.0.0.1,::1}"

cd "$PROJECT_DIR"

echo "Delegating task to OpenCode CLI"
echo "Mode: $MODE"
echo "Stage: $STAGE"
echo "Task type: $TASK_TYPE"
echo "Selected model: $MODEL"
echo "Project directory: $PROJECT_DIR"
echo "OpenCode binary: $OPENCODE_BIN"
echo "OpenCode data dir: $XDG_DATA_HOME/opencode"
echo "OpenCode state dir: $XDG_STATE_HOME/opencode"
echo ""

"$OPENCODE_BIN" run --model "$MODEL" "$(cat "$PROMPT_FILE")"
