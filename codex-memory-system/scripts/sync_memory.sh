#!/bin/bash
# sync_memory.sh - 自动同步 Obsidian 记忆到 Codex native mirror
#
# 用法:
#   ./sync_memory.sh              # 正常同步，日志记录
#   ./sync_memory.sh --force       # 强制重新索引（先清缓存）
#   ./sync_memory.sh --status-only # 只报告状态
set -uo pipefail
PATH="/opt/homebrew/bin:/opt/homebrew/sbin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:$HOME/.local/bin"
export PATH

AUTO_DIR="$HOME/.codex/memory-automation"
LOG_DIR="$AUTO_DIR/logs"
LOG_FILE="$LOG_DIR/sync-$(date +%Y-%m-%d).log"
VAULT_PATH="$HOME/Library/Mobile Documents/iCloud~md~obsidian/Documents/RichardHub"

mkdir -p "$LOG_DIR"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$LOG_FILE"
}

if [ "${1:-}" = "--status-only" ]; then
    echo "Obsidian vault: $VAULT_PATH"
    echo "Codex-Memory:   $(test -d "$VAULT_PATH/Codex-Memory" && echo 'OK' || echo 'MISSING')"
    echo "Codex-Input:    $(test -d "$VAULT_PATH/Codex-Input" && echo 'OK' || echo 'MISSING')"
    echo "codex-mem tool: $(which codex-mem 2>/dev/null || echo 'NOT FOUND')"
    echo "Last sync:      $(ls -lt "$LOG_DIR" 2>/dev/null | head -3)"
    exit 0
fi

if [ "${1:-}" = "--force" ]; then
    log "强制重新索引：重新生成 memory_summary.md"
fi

log "开始同步 ..."

if command -v codex-mem &>/dev/null; then
    log "运行 codex-mem index 更新索引 ..."
    codex-mem index > "$LOG_DIR/index-output.$(date +%Y%m%d%H%M%S).tmp" 2>&1 || log "WARNING: codex-mem index 非零退出"
fi

CTS=$(date '+%Y-%m-%d %H:%M:%S')
TMP_FILE="$HOME/.codex/memories/memory_summary.tmp.$$"
{
    echo "# Codex Memory Summary"
    echo ""
    echo "> Auto-synced at $CTS from $VAULT_PATH"
    echo ""
    echo "## Ground-Truth (Stable Memory)"
    echo ""
    cat "$VAULT_PATH/Codex-Memory/Ground-Truth.md" 2>/dev/null || echo "（未找到）"
    echo ""
    echo "## Codex-Input (Recent Write-ins)"
    echo ""
    for f in "$VAULT_PATH/Codex-Input"/*.md; do
        [ -f "$f" ] || continue
        echo "### $(basename "$f")"
        echo ""
        head -50 "$f"
        echo ""
    done
    echo ""
    echo "## Codex-Input/pending (Candidates)"
    echo ""
    for f in "$VAULT_PATH/Codex-Input/pending/"*.md; do
        [ -f "$f" ] || continue
        echo "#### $(basename "$f")"
        head -10 "$f"
        echo ""
    done
    echo ""
    echo "## Codex-Input/review"
    echo ""
    for f in "$VAULT_PATH/Codex-Input/review/"*.md; do
        [ -f "$f" ] || continue
        echo "#### $(basename "$f")"
        head -10 "$f"
        echo ""
    done
    echo ""
    echo "## Recent Sessions"
    echo ""
    for f in "$VAULT_PATH/Codex-Memory/sessions/"*.md; do
        [ -f "$f" ] || continue
        echo "- $(basename "$f")"
    done
    echo ""
    echo "## Projects"
    for f in "$VAULT_PATH/Codex-Memory/projects/"*.md; do
        [ -f "$f" ] || continue
        echo "- $(basename "$f" .md)"
    done
    echo ""
    echo "## Topics"
    for f in "$VAULT_PATH/Codex-Memory/topics/"*.md; do
        [ -f "$f" ] || continue
        echo "- $(basename "$f" .md)"
    done
} > "$TMP_FILE" && mv "$TMP_FILE" "$HOME/.codex/memories/memory_summary.md"
log "memory_summary.md 已更新 (from Obsidian vault)"

PENDING_COUNT=$(ls "$VAULT_PATH/Codex-Input/pending/"*.md 2>/dev/null | wc -l | tr -d ' ')
REVIEW_COUNT=$(ls "$VAULT_PATH/Codex-Input/review/"*.md 2>/dev/null | wc -l | tr -d ' ')
APPROVED_COUNT=$(ls "$VAULT_PATH/Codex-Input/approved/"*.md 2>/dev/null | wc -l | tr -d ' ')
log "统计: pending=$PENDING_COUNT  review=$REVIEW_COUNT  approved=$APPROVED_COUNT"

find "$LOG_DIR" -name "*.log" -mtime +30 -delete 2>/dev/null || true

log "同步完成"
echo ""
echo "统计: Pending=$PENDING_COUNT | Review=$REVIEW_COUNT | Approved=$APPROVED_COUNT"
echo "日志: $LOG_FILE"
