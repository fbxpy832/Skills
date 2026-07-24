#!/bin/zsh
set -euo pipefail

SOURCE_ROOT="$(cd "$(dirname "$0")" && pwd)"
CODEX_HOME="${CODEX_HOME:-$HOME/.codex}"
TARGET_ROOT="$CODEX_HOME/skills/desktop-document-archiver"

mkdir -p "$CODEX_HOME/skills"
rsync -a --delete \
  --exclude '.git/' \
  --exclude 'install.sh' \
  --exclude 'update.sh' \
  "$SOURCE_ROOT/" "$TARGET_ROOT/"
chmod +x "$TARGET_ROOT/scripts/run_scheduled.sh"

exec /usr/bin/env python3 "$TARGET_ROOT/scripts/desktop_document_archiver.py" install-schedule
