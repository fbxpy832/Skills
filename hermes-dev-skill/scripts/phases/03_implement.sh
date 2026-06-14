#!/usr/bin/env bash
# hermes-dev-skill/scripts/phases/03_implement.sh
# Phase 3 (first round): invoke Claude Code to implement the spec.
# The follow-up round (after a review) is 03_implement_iter.sh.
set -euo pipefail
JOB_ID="${1:-}"
ROUND="${2:-1}"
if [ -z "$JOB_ID" ]; then
    echo "usage: $0 <job_id> [round]" >&2
    exit 1
fi

RUNS_DIR="$HOME/.hermes/runs/$JOB_ID"
PROJECT_PATH=$(python -m scripts.lib.state get "$RUNS_DIR/state.json" project.path)
IS_GIT=$(python -m scripts.lib.state get "$RUNS_DIR/state.json" project.is_git)
BASE_BRANCH=$(python -m scripts.lib.state get "$RUNS_DIR/state.json" project.base_branch 2>/dev/null || echo "main")
CLAUDE_MODEL=$(python -m scripts.lib.state get "$RUNS_DIR/state.json" \
    user_overrides.claude_model 2>/dev/null || echo "")
CLAUDE_MODEL=${CLAUDE_MODEL:-claude-opus-4-8}
SKILL_DIR="$(cd "$(dirname "$0")/../.." && pwd)"

# Pre-flight: ensure branch exists (first round only)
if [ "$IS_GIT" = "True" ] || [ "$IS_GIT" = "true" ]; then
    BRANCH="hermes-dev/$JOB_ID"
    if [ "$ROUND" = "1" ]; then
        python -m scripts.lib.git_ops create_branch "$PROJECT_PATH" "$JOB_ID" base="$BASE_BRANCH"
        python -m scripts.lib.state atomic_update "$RUNS_DIR/state.json" \
            "{\"project\": {\"branch\": \"$BRANCH\"}}"
    fi
fi

# Build the prompt
PROMPT="$(cat $SKILL_DIR/scripts/claude_contract.md)

=== JOB CONTEXT ===
- Job ID: $JOB_ID
- Project: $PROJECT_PATH
- Branch: $(python -m scripts.lib.state get $RUNS_DIR/state.json project.branch 2>/dev/null || echo unknown)
- Run dir: $RUNS_DIR

=== SPEC ===
$(cat $RUNS_DIR/spec.md)

=== PLAN ===
$(cat $RUNS_DIR/plan.md)

=== LAST REVIEW FEEDBACK ===
$(cat $RUNS_DIR/review-rounds/round-$((ROUND-1)).md 2>/dev/null || echo 'NONE — first implementation round')"

# Invoke Claude Code
echo "[phase3] invoking Claude Code ($CLAUDE_MODEL) round $ROUND"
cd "$PROJECT_PATH"
claude --model "$CLAUDE_MODEL" \
       --cwd "$PROJECT_PATH" \
       -p "$PROMPT" \
       --output-format json \
       > "$RUNS_DIR/claude-impl-round-$ROUND.json"

# Update state
python -m scripts.lib.state atomic_update "$RUNS_DIR/state.json" \
    "{\"phase\": \"review\", \"phase_round\": $ROUND}"

python -m scripts.lib.feishu send_text \
    "Job #${JOB_ID:0:6} 开发完成，进入 Review 第 $ROUND 轮"

echo "[phase3] done"
