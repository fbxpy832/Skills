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

export HOME="${HOME:-/Users/xpy}"
export XDG_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
export XDG_STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"

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

# Check individual database file writability.
# The directory check above passes even when the DB/WAL/SHM files
# themselves are not writable to the current process (e.g. sandbox
# file-level restrictions).
DB_PATH="$XDG_DATA_HOME/opencode/opencode.db"
for f in "$DB_PATH" "$DB_PATH-wal" "$DB_PATH-shm"; do
  if [ -f "$f" ] && [ ! -w "$f" ]; then
    echo "ERROR: Database file is not writable: $f"
    echo "Check owner, mode, extended attributes, and ACLs:"
    ls -le@ "$f" 2>&1 || true
    echo ""
    echo "To fix:"
    echo "  chown $(id -u):$(id -g) $f"
    echo "  chmod 600 $f"
    echo "If inside a sandbox (Codex App, etc.), grant write access to: $XDG_DATA_HOME/opencode"
    exit 1
  fi
done

# Check SQLite WAL health before delegating.
# OpenCode fails with PRAGMA wal_checkpoint(PASSIVE) when WAL frames
# accumulate or the DB is inaccessible from the Codex sandbox.
if [ -f "$DB_PATH" ]; then
  if ! command -v sqlite3 >/dev/null 2>&1; then
    echo "ERROR: Database exists at $DB_PATH but sqlite3 is not available."
    echo "Install sqlite3 or check the database manually:"
    ls -la "$DB_PATH"* 2>&1 || true
    echo ""
    echo "To bypass this check manually, remove or rename the database file."
    echo "Do NOT use sudo from this script."
    exit 1
  fi
  set +e
  SQLITE_OUTPUT=$(sqlite3 "$DB_PATH" "PRAGMA wal_checkpoint(TRUNCATE);" 2>&1)
  SQLITE_EXIT=$?
  set -e
  if [ $SQLITE_EXIT -ne 0 ]; then
    echo ""
    echo "ERROR: SQLite health check failed (exit code $SQLITE_EXIT)."
    echo "SQLite output: $SQLITE_OUTPUT"
    echo ""
    echo "The Codex sandbox or current process cannot write to the SQLite database."
    echo "Check permissions and extended attributes on:"
    ls -le@ "$DB_PATH"* 2>&1 || true
    echo ""
    echo "Recent log files (last 3):"
    ls -t "$XDG_DATA_HOME/opencode/log" 2>/dev/null | head -3 || echo "  (no log directory)"
    echo ""
    echo "To fix:"
    echo "  1. Backup: cp $DB_PATH $DB_PATH.bak"
    echo "  2. Check owner: ls -le@ $DB_PATH*"
    echo "  3. Check extended attributes: xattr -l $DB_PATH*"
    echo "  4. Repair: chown $(id -u):$(id -g) $XDG_DATA_HOME/opencode"
    echo "  5. Repair: chmod 600 $DB_PATH $DB_PATH-wal $DB_PATH-shm"
    echo "If inside a sandbox (Codex App, etc.), grant write access to: $XDG_DATA_HOME/opencode"
    echo "Do NOT use sudo from this script."
    exit 1
  fi
  CKPT_FRAMES=$(echo "$SQLITE_OUTPUT" | awk -F'|' '{print $3}')
  if echo "$CKPT_FRAMES" | grep -qE '^[0-9]+$' && [ "$CKPT_FRAMES" -gt 0 ] 2>/dev/null; then
    echo "[delegate] SQLite: checkpointed $CKPT_FRAMES WAL frames"
  fi
fi

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

set +e
"$OPENCODE_BIN" run --model "$MODEL" "$(cat "$PROMPT_FILE")"
OC_EXIT_CODE=$?
set -e

if [ $OC_EXIT_CODE -ne 0 ]; then
  echo ""
  echo "ERROR: OpenCode exited with code $OC_EXIT_CODE"
  echo "Recent log files (last 3):"
  ls -t "$XDG_DATA_HOME/opencode/log" 2>/dev/null | head -3 || echo "  (no log directory)"
  echo "Database files:"
  ls -la "$DB_PATH"* 2>&1 || true
  exit $OC_EXIT_CODE
fi
