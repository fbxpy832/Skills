#!/bin/bash
# run_all.sh - 记忆自动化主调度器
#
# 由 launchd 调用。每天执行一次：
#   1. 抽取候选记忆
#   2. 同步到 native mirror
#   3. 生成审计报告
set -uo pipefail
PATH="/opt/homebrew/bin:/opt/homebrew/sbin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:$HOME/.local/bin"
export PATH
export PIPEFAIL=1

AUTO_DIR="$HOME/.codex/memory-automation"
SCRIPTS="$AUTO_DIR/scripts"
LOG_DIR="$AUTO_DIR/logs"

mkdir -p "$LOG_DIR"
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
echo "[$TIMESTAMP] === 开始每日记忆自动化 ==="

EXIT_CODE=0

# 1. 抽取候选记忆
echo "--- 步骤 1: 抽取候选记忆 ---"
python3 "$SCRIPTS/extract_candidates.py" --days 14 2>&1 | tee -a "$LOG_DIR/daily-$(date +%Y-%m-%d).log" || EXIT_CODE=$?

# 2. 同步到 native mirror
echo "--- 步骤 2: 同步到 Codex native mirror ---"
bash "$SCRIPTS/sync_memory.sh" 2>&1 | tee -a "$LOG_DIR/daily-$(date +%Y-%m-%d).log" || EXIT_CODE=$?

# 3. 生成审计报告
echo "--- 步骤 3: 记忆健康审计 ---"
bash "$SCRIPTS/review_memory.sh" 2>&1 | tee -a "$LOG_DIR/daily-$(date +%Y-%m-%d).log" || EXIT_CODE=$?

echo "[$TIMESTAMP] === 每日记忆自动化完成 ==="
exit $EXIT_CODE
echo "" >> "$LOG_DIR/daily-$(date +%Y-%m-%d).log"
echo "---" >> "$LOG_DIR/daily-$(date +%Y-%m-%d).log"
