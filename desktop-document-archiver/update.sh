#!/bin/zsh
set -euo pipefail

SOURCE_ROOT="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(git -C "$SOURCE_ROOT" rev-parse --show-toplevel)"

git -C "$REPO_ROOT" pull --ff-only
exec "$SOURCE_ROOT/install.sh"
