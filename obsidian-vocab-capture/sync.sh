#!/usr/bin/env bash
# 将 git 仓库中的 skill 同步到 .codex/skills 和 .agents/skills 安装目录
set -euo pipefail

SRC="$HOME/Documents/RichardHub/Git/obsidian-vocab-capture"

for DEST in "$HOME/.codex/skills/obsidian-vocab-capture" "$HOME/.agents/skills/obsidian-vocab-capture"; do
  echo "→ 同步到 $DEST"
  mkdir -p "$DEST"
  rsync -av --delete \
    --exclude .git/ \
    --exclude .gitignore \
    --exclude __pycache__/ \
    --exclude .pytest_cache/ \
    --exclude '*.pyc' \
    "$SRC/" "$DEST/"
  echo "  OK"
done

echo "✅ 同步完成"
echo ""
echo "Python 包已通过 pipx 以 editable 模式安装（pipx install -e .），修改 src/ 后无需重新安装。"
