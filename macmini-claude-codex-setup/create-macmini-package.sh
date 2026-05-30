#!/usr/bin/env bash
set -euo pipefail

STAMP="$(date +%Y%m%d-%H%M%S)"
OUT="${1:-$HOME/Desktop/claude-codex-macmini-$STAMP.tgz}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
STAGE="$(mktemp -d "${TMPDIR:-/tmp}/claude-codex-macmini.XXXXXX")"

cleanup() {
  rm -rf "$STAGE"
}
trap cleanup EXIT

copy_if_exists() {
  local src="$1"
  local dst="$2"
  if [ -e "$src" ]; then
    mkdir -p "$(dirname "$dst")"
    ditto "$src" "$dst"
    echo "included: $src"
  else
    echo "skipped:  $src"
  fi
}

mkdir -p "$STAGE/payload/Home"
mkdir -p "$STAGE/payload/Library/Application Support"
mkdir -p "$STAGE/payload/Library/Preferences"

copy_if_exists "$HOME/.claude" "$STAGE/payload/Home/.claude"
copy_if_exists "$HOME/.codex" "$STAGE/payload/Home/.codex"
copy_if_exists "$HOME/.agents" "$STAGE/payload/Home/.agents"
copy_if_exists "$HOME/.cc-switch" "$STAGE/payload/Home/.cc-switch"
copy_if_exists "$HOME/.claude-to-im" "$STAGE/payload/Home/.claude-to-im"

copy_if_exists "$HOME/Library/Application Support/Codex" "$STAGE/payload/Library/Application Support/Codex"
copy_if_exists "$HOME/Library/Application Support/com.openai.codex" "$STAGE/payload/Library/Application Support/com.openai.codex"

copy_if_exists "$HOME/Library/Preferences/com.openai.codex.plist" "$STAGE/payload/Library/Preferences/com.openai.codex.plist"
copy_if_exists "$HOME/Library/Preferences/com.ccswitch.desktop.plist" "$STAGE/payload/Library/Preferences/com.ccswitch.desktop.plist"

if [ "${INCLUDE_CLAUDE_DESKTOP:-0}" = "1" ]; then
  copy_if_exists "$HOME/Library/Application Support/Claude" "$STAGE/payload/Library/Application Support/Claude"
  copy_if_exists "$HOME/Library/Application Support/Claude-3p" "$STAGE/payload/Library/Application Support/Claude-3p"
  copy_if_exists "$HOME/Library/Preferences/com.anthropic.claudefordesktop.plist" "$STAGE/payload/Library/Preferences/com.anthropic.claudefordesktop.plist"
fi

cat > "$STAGE/MANIFEST.txt" <<EOF
Created: $(date)
Source host: $(hostname)
Source user: $(whoami)
Claude Code: $(claude --version 2>/dev/null || echo unknown)
Codex: $(codex --version 2>/dev/null || echo unknown)
Node: $(node --version 2>/dev/null || echo unknown)
NPM: $(npm --version 2>/dev/null || echo unknown)
Homebrew: $(brew --version 2>/dev/null | head -n 1 || echo unknown)

This archive contains local auth/config data. Keep it private.
EOF

cp "$SCRIPT_DIR/install-on-macmini.sh" "$STAGE/install-on-macmini.sh"
chmod +x "$STAGE/install-on-macmini.sh"

mkdir -p "$(dirname "$OUT")"
tar -C "$STAGE" -czf "$OUT" .
chmod 600 "$OUT"

echo
echo "Created migration package:"
echo "$OUT"
echo
echo "Copy it to the Mac mini, then run:"
echo "  mkdir -p ~/claude-codex-macmini && tar -xzf ~/$(basename "$OUT") -C ~/claude-codex-macmini && ~/claude-codex-macmini/install-on-macmini.sh"
