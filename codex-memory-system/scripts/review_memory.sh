#!/bin/bash
# review_memory.sh - 记忆健康审计
#
# 每日审计：检查重复、过期、冲突、无来源记忆。
# 输出到 Codex-Input/review/memory-audit-YYYY-MM-DD.md
set -uo pipefail

AUTO_DIR="$HOME/.codex/memory-automation"
LOG_DIR="$AUTO_DIR/logs"
VAULT_PATH="$HOME/Library/Mobile Documents/iCloud~md~obsidian/Documents/RichardHub"
REVIEW_DIR="$VAULT_PATH/Codex-Input/review"
NATIVE_DIR="$HOME/.codex/memories"

mkdir -p "$LOG_DIR" "$REVIEW_DIR"

REPORT="$REVIEW_DIR/memory-audit-$(date +%Y-%m-%d).md"

exec 1> >(tee "$REPORT")
exec 2>&1

echo "# 记忆健康审计报告"
echo ""
echo "生成时间: $(date '+%Y-%m-%d %H:%M:%S')"
echo ""

# ---------- 目录统计 ----------
memory_dirs() {
    echo "## 目录统计"
    echo ""
    echo "| 目录 | 文件数 |"
    echo "|------|--------|"
    for d in "$VAULT_PATH/Codex-Memory/Ground-Truth.md" \
             "$VAULT_PATH/Codex-Memory/projects/" \
             "$VAULT_PATH/Codex-Memory/sessions/" \
             "$VAULT_PATH/Codex-Memory/topics/" \
             "$VAULT_PATH/Codex-Input/" \
             "$VAULT_PATH/Codex-Input/pending/" \
             "$VAULT_PATH/Codex-Input/review/" \
             "$VAULT_PATH/Codex-Input/approved/"; do
        if [ -f "$d" ]; then
            echo "| $d | 1 |"
        elif [ -d "$d" ]; then
            count=$(find "$d" -maxdepth 1 -name '*.md' 2>/dev/null | wc -l | tr -d ' ')
            echo "| $(basename "$(dirname "$d")")/$(basename "$d")/ | $count |"
        fi
    done
    echo ""
    echo "| NVIDIA memory summaries |"
    for f in "$NATIVE_DIR"/{memory_summary.md,MEMORY.md,raw_memories.md}; do
        if [ -f "$f" ]; then
            lines=$(wc -l < "$f" | tr -d ' ')
            echo "| $(basename "$f") | $lines 行 |"
        fi
    done
    echo ""
}

# ---------- 过期检测：会话 > 90 天 ----------
stale_sessions() {
    echo "## 过期检测"
    echo ""
    local stale_count=0
    for f in "$VAULT_PATH/Codex-Memory/sessions/"*.md; do
        [ -f "$f" ] || continue
        age=$(( ($(date +%s) - $(stat -f %m "$f")) / 86400 ))
        if [ "$age" -gt 90 ]; then
            echo "- $(basename "$f")  ($age 天前)"
            stale_count=$((stale_count + 1))
        fi
    done
    if [ "$stale_count" -eq 0 ]; then
        echo "无过期会话 (>90 天)"
    fi
    echo ""
}

# ---------- 冲突检测：相同关键词不同结论 ----------
conflict_check() {
    echo "## 潜在冲突记忆"
    echo ""
    # 检查 Ground-Truth 和 Codex-Input 中是否有明显冲突的陈述
    local conflicts=0
    for kw in "pricing" "price" "费用" "缓存" "cache" "proxy" "router" "model" "gpt-5"; do
        hits_gt=$(rg -ic "$kw" "$VAULT_PATH/Codex-Memory/Ground-Truth.md" 2>/dev/null || echo 0)
        hits_input=$(rg -ic "$kw" "$VAULT_PATH/Codex-Input"/*.md 2>/dev/null | grep -v '^0$' | head -3) || true
        if [ "$hits_gt" -gt 0 ] && [ -n "$hits_input" ]; then
            echo "- 关键词 '$kw' 同时出现在 Ground-Truth 和 Codex-Input，建议检查一致性"
            conflicts=$((conflicts + 1))
        fi
    done
    if [ "$conflicts" -eq 0 ]; then
        echo "未发现明显冲突"
    fi
    echo ""
}

# ---------- 无来源检测 ----------
unverified_check() {
    echo "## 无来源/未验证记忆"
    echo ""
    local unverified=0
    for f in "$VAULT_PATH/Codex-Memory/projects/"*.md; do
        [ -f "$f" ] || continue
        if ! grep -q "last_verified\|verified_at\|updated_at" "$f" 2>/dev/null; then
            echo "- $(basename "$f")  缺少 last_verified 字段"
            unverified=$((unverified + 1))
        fi
    done
    if [ "$unverified" -eq 0 ]; then
        echo "所有项目文件都有验证时间戳"
    fi
    echo ""
}

# ---------- 待处理项汇总 ----------
pending_summary() {
    echo "## 待审批汇总"
    echo ""
    pending=$(find "$VAULT_PATH/Codex-Input/pending/" -maxdepth 1 -name '*.md' 2>/dev/null | wc -l | tr -d ' ')
    review=$(find "$VAULT_PATH/Codex-Input/review/" -maxdepth 1 -name '*.md' 2>/dev/null | wc -l | tr -d ' ')
    approved=$(find "$VAULT_PATH/Codex-Input/approved/" -maxdepth 1 -name '*.md' 2>/dev/null | wc -l | tr -d ' ')
    echo "- Pending (待审核): $pending"
    echo "- Review (待审查冲突/问题): $review"
    echo "- Approved (待 promote): $approved"
    echo ""
    if [ "$pending" -gt 0 ]; then
        echo "### Pending 列表"
        for f in "$VAULT_PATH/Codex-Input/pending/"*.md; do
            [ -f "$f" ] || continue
            type=$(grep "^type:" "$f" 2>/dev/null | head -1 | sed 's/type: //')
            conf=$(grep "^confidence:" "$f" 2>/dev/null | head -1 | sed 's/confidence: //')
            echo "- $(basename "$f")  (type=$type, confidence=$conf)"
        done
        echo ""
    fi
}

# ---------- 高频使用建议 ----------
usage_tips() {
    echo "## 使用建议"
    echo ""
    echo "- 查看 Ground-Truth: memory_search.sh --ground-truth"
    echo "- 搜索记忆: memory_search.sh '<关键词>'"
    echo "- 中文检索: memory_search.sh --rsearch '<中文>'"
    echo "- 手动 sync: sync_memory.sh"
    echo "- 抽取候选: python3 $AUTO_DIR/scripts/extract_candidates.py"
    echo "- promote 到 Ground-Truth: mv Codex-Input/approved/xxx.md Codex-Memory/"
    echo ""
}

memory_dirs
stale_sessions
conflict_check
unverified_check
pending_summary
usage_tips

echo "报告已写入: $REPORT"

# 日志
echo "[$(date '+%Y-%m-%d %H:%M:%S')] review report generated: $REPORT" >> "$LOG_DIR/review.log"

# 清理 60 天前的报告
find "$REVIEW_DIR" -name "memory-audit-*.md" -mtime +60 -delete 2>/dev/null || true

exec 1>&- 2>&-
echo "Done."
exit 0
