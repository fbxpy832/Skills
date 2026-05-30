#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PAYLOAD="$SCRIPT_DIR/payload"
BACKUP_DIR="$HOME/.claude-codex-restore-backup/$(date +%Y%m%d-%H%M%S)"

if [ ! -d "$PAYLOAD" ]; then
  echo "payload not found next to install-on-macmini.sh"
  exit 1
fi

ensure_homebrew() {
  if ! command -v brew >/dev/null 2>&1; then
    echo "Installing Homebrew..."
    NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  fi

  if [ -x /opt/homebrew/bin/brew ]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
  elif [ -x /usr/local/bin/brew ]; then
    eval "$(/usr/local/bin/brew shellenv)"
  fi
}

backup_if_exists() {
  local target="$1"
  if [ -e "$target" ]; then
    mkdir -p "$BACKUP_DIR$(dirname "$target")"
    ditto "$target" "$BACKUP_DIR$target"
    echo "backed up: $target"
  fi
}

restore_if_exists() {
  local src="$1"
  local target="$2"
  if [ -e "$src" ]; then
    backup_if_exists "$target"
    mkdir -p "$(dirname "$target")"
    rm -rf "$target"
    ditto "$src" "$target"
    echo "restored:  $target"
  fi
}

echo "Installing base tools..."
ensure_homebrew
brew install node ripgrep uv jq git || true
brew install --cask codex cc-switch || true
npm install -g @anthropic-ai/claude-code @larksuite/cli agent-browser

echo
echo "Restoring configs..."
restore_if_exists "$PAYLOAD/Home/.claude" "$HOME/.claude"
restore_if_exists "$PAYLOAD/Home/.codex" "$HOME/.codex"
restore_if_exists "$PAYLOAD/Home/.agents" "$HOME/.agents"
restore_if_exists "$PAYLOAD/Home/.cc-switch" "$HOME/.cc-switch"
restore_if_exists "$PAYLOAD/Home/.claude-to-im" "$HOME/.claude-to-im"

restore_if_exists "$PAYLOAD/Library/Application Support/Codex" "$HOME/Library/Application Support/Codex"
restore_if_exists "$PAYLOAD/Library/Application Support/com.openai.codex" "$HOME/Library/Application Support/com.openai.codex"
restore_if_exists "$PAYLOAD/Library/Application Support/Claude" "$HOME/Library/Application Support/Claude"
restore_if_exists "$PAYLOAD/Library/Application Support/Claude-3p" "$HOME/Library/Application Support/Claude-3p"

restore_if_exists "$PAYLOAD/Library/Preferences/com.openai.codex.plist" "$HOME/Library/Preferences/com.openai.codex.plist"
restore_if_exists "$PAYLOAD/Library/Preferences/com.ccswitch.desktop.plist" "$HOME/Library/Preferences/com.ccswitch.desktop.plist"
restore_if_exists "$PAYLOAD/Library/Preferences/com.anthropic.claudefordesktop.plist" "$HOME/Library/Preferences/com.anthropic.claudefordesktop.plist"

chmod 700 "$HOME/.claude" "$HOME/.codex" "$HOME/.cc-switch" "$HOME/.claude-to-im" 2>/dev/null || true
chmod 600 "$HOME/.claude-to-im/config.env" "$HOME/.claude/settings.json" "$HOME/.codex/config.toml" 2>/dev/null || true

echo
echo "Starting helper apps..."
open -a "CC Switch" 2>/dev/null || true
open -a "Codex" 2>/dev/null || true

echo
echo "Verification:"
claude --version 2>/dev/null || true
codex --version 2>/dev/null || true
node --version 2>/dev/null || true
brew --version 2>/dev/null | head -n 1 || true

echo
echo "Done. Existing files, if any, were backed up under:"
echo "$BACKUP_DIR"
echo
echo "If CC Switch is not selected after launch, open it once and select the same Claude provider."
