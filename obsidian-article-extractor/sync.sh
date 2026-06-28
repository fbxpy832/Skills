#!/usr/bin/env bash
# 将 git 仓库中的 skill 同步到 .codex/skills 和 .agents/skills 安装目录
set -euo pipefail

SRC="$HOME/Documents/RichardHub/Git/obsidian-article-extractor"

for DEST in "$HOME/.codex/skills/obsidian-article-extractor" "$HOME/.agents/skills/obsidian-article-extractor"; do
  echo "→ 同步到 $DEST"
  mkdir -p "$DEST"
  rsync -av --delete \
    --exclude node_modules/ \
    --exclude .git/ \
    --exclude .gitignore \
    --exclude OPTIMIZATION-PLAN.md \
    --exclude TODOs.md \
    "$SRC/" "$DEST/"
  (cd "$DEST" && npm ci --silent 2>/dev/null || true)
  echo "  OK"
done

echo "✅ 同步完成"
