#!/bin/bash
# memory_search.sh - 统一记忆检索入口
#
# 用法:
#   ./memory_search.sh "关键词"
#   ./memory_search.sh --rsearch "中文关键词"
#   ./memory_search.sh --all "关键词"
#   ./memory_search.sh --ground-truth
set -euo pipefail

AUTO_DIR="$HOME/.codex/memory-automation"
LOG_DIR="$AUTO_DIR/logs"
VAULT_PATH="$HOME/Library/Mobile Documents/iCloud~md~obsidian/Documents/RichardHub"

mkdir -p "$LOG_DIR"

search_obsidian() {
    local kw="$1"
    echo "== Obsidian Vault 全文搜索: $kw =="
    codex-mem search "$kw" 2>/dev/null || rg -il "$kw" "$VAULT_PATH/Codex-Memory" "$VAULT_PATH/Codex-Input" 2>/dev/null | head -20
}

rsearch_obsidian() {
    local kw="$1"
    echo "== Obsidian Vault 中文搜索 (codex-mem rsearch): $kw =="
    rg -il "$kw" "$VAULT_PATH/Codex-Memory" "$VAULT_PATH/Codex-Input" 2>/dev/null | head -20
}

search_native() {
    local kw="$1"
    echo "== Codex Native Memory 搜索: $kw =="
    for f in "$HOME/.codex/memories/memory_summary.md" "$HOME/.codex/memories/MEMORY.md" "$HOME/.codex/memories/raw_memories.md"; do
        if [ -f "$f" ] && rg -q "$kw" "$f" 2>/dev/null; then
            echo "--- $(basename "$f") ---"
            rg -nC2 "$kw" "$f" 2>/dev/null
        fi
    done
}

search_rollout() {
    local kw="$1"
    echo "== Rollout Summaries 搜索: $kw =="
    local rs="$HOME/.codex/memories/rollout_summaries"
    if [ -d "$rs" ]; then
        rg -il "$kw" "$rs" 2>/dev/null | head -10
    fi
}

if [ "$#" -eq 0 ]; then
    echo "用法: memory_search.sh [选项] <关键词>"
    echo "选项:"
    echo "  (默认)      普通搜索（Obsidian + Native + Rollout）"
    echo "  --rsearch   中文搜索（自动 fallback 到中文专用搜索）"
    echo "  --all       全量搜索（含 Obsidian 项目卡、会话页）"
    echo "  --ground-truth  输出 Ground-Truth.md 全文"
    echo "  --help      本帮助"
    exit 0
fi

case "${1:-}" in
    --help)
        "$0"
        exit 0
        ;;
    --ground-truth)
        codex-mem ground-truth 2>/dev/null || cat "$VAULT_PATH/Codex-Memory/Ground-Truth.md" 2>/dev/null || echo "未找到 Ground-Truth.md"
        exit 0
        ;;
    --rsearch)
        shift
        kw="$*"
        echo "================================================"
        rsearch_obsidian "$kw"
        echo "================================================"
        search_rollout "$kw"
        ;;
    --all)
        shift
        kw="$*"
        echo "================================================"
        search_obsidian "$kw"
        echo "================================================"
        search_native "$kw"
        echo "================================================"
        search_rollout "$kw"
        ;;
    *)
        kw="$*"
        echo "================================================"
        search_obsidian "$kw"
        echo "================================================"
        search_native "$kw"
        echo "================================================"
        # 中文自动 fallback：如果 Obsidian 搜索没命中且含中文，提示用 --rsearch
        if echo "$kw" | rg -q '[\x{4e00}-\x{9fff}]'; then
            search_rollout "$kw"
            echo ""
            echo "提示: 中文搜索可能未覆盖全部。尝试:"
            echo "  memory_search.sh --rsearch $kw"
        fi
        ;;
esac
echo ""
echo "日志: $LOG_DIR/search.log"
echo "[$(date '+%Y-%m-%d %H:%M:%S')] search: $*" >> "$LOG_DIR/search.log"
