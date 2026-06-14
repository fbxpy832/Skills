#!/usr/bin/env bash
# hermes-dev-skill/install.sh
# Per-user install: config dir, runs dir, bin symlink. Does NOT configure
# launchd / cron (that's the Hermes host's job).
set -euo pipefail

SKILL_DIR="$(cd "$(dirname "$0")" && pwd)"
HERMES_DIR="$HOME/.hermes"
CONFIG_DIR="$HERMES_DIR/hermes-dev"
RUNS_DIR="$HERMES_DIR/runs"
BIN_DIR="${HOME}/.local/bin"

echo "Installing hermes-dev-skill"
echo "  Skill dir:  $SKILL_DIR"
echo "  Config dir: $CONFIG_DIR"
echo "  Runs dir:   $RUNS_DIR"
echo "  Bin dir:    $BIN_DIR"

# 1. Config dir + config.yaml (only if missing)
mkdir -p "$CONFIG_DIR"
if [ ! -f "$CONFIG_DIR/config.yaml" ]; then
    cp "$SKILL_DIR/config.example.yaml" "$CONFIG_DIR/config.yaml"
    chmod 600 "$CONFIG_DIR/config.yaml"
    echo "  Wrote $CONFIG_DIR/config.yaml"
else
    echo "  $CONFIG_DIR/config.yaml already exists, leaving alone"
fi

# 2. Runs dir
mkdir -p "$RUNS_DIR"
echo "  Runs dir: $RUNS_DIR"

# 3. Bin symlink
mkdir -p "$BIN_DIR"
if [ -L "$BIN_DIR/hermes-dev" ] || [ -e "$BIN_DIR/hermes-dev" ]; then
    echo "  $BIN_DIR/hermes-dev already exists, leaving alone"
else
    ln -s "$SKILL_DIR/scripts/hermes_dev.py" "$BIN_DIR/hermes-dev"
    chmod +x "$BIN_DIR/hermes-dev"
    echo "  Symlinked $BIN_DIR/hermes-dev -> $SKILL_DIR/scripts/hermes_dev.py"
fi

# 4. Optional: add ~/.local/bin to PATH if not already
if [[ ":$PATH:" != *":$BIN_DIR:"* ]]; then
    echo ""
    echo "NOTE: $BIN_DIR is not in your PATH. Add this to your shell rc:"
    echo "  export PATH=\"$BIN_DIR:\$PATH\""
fi

echo ""
echo "Install complete. Verify with:"
echo "  hermes-dev --help"
