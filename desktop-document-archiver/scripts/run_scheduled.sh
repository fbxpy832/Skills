#!/bin/zsh
set -euo pipefail

CODEX_HOME="${CODEX_HOME:-$HOME/.codex}"
SKILL_ROOT="$CODEX_HOME/skills/desktop-document-archiver"
LOG_DIR="$HOME/Library/Logs/DesktopDocumentArchiver"
export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
mkdir -p "$LOG_DIR"

exec /opt/homebrew/bin/python3 "$SKILL_ROOT/scripts/desktop_document_archiver.py" process \
  >> "$LOG_DIR/launchd.log" 2>> "$LOG_DIR/launchd.err"
