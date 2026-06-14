#!/usr/bin/env bash
# hermes-dev-skill/scripts/phases/05_handoff.sh
# Final handoff: send a summary card with branch info, diffstat, and
# next-step instructions to the user.
set -euo pipefail
JOB_ID="${1:?usage: $0 <job_id>}"
RUNS_DIR="$HOME/.hermes/runs/$JOB_ID"

PROJECT_PATH=$(python -m scripts.lib.state get "$RUNS_DIR/state.json" project.path)
BRANCH=$(python -m scripts.lib.state get "$RUNS_DIR/state.json" project.branch)
BASE_BRANCH=$(python -m scripts.lib.state get "$RUNS_DIR/state.json" project.base_branch 2>/dev/null || echo "main")
IS_GIT=$(python -m scripts.lib.state get "$RUNS_DIR/state.json" project.is_git)

if [ "$IS_GIT" = "True" ] || [ "$IS_GIT" = "true" ]; then
    SHORTSTAT=$(cd "$PROJECT_PATH" && git diff --shortstat "$BASE_BRANCH"..HEAD 2>/dev/null || echo "n/a")
    COMMIT_COUNT=$(cd "$PROJECT_PATH" && git rev-list --count "$BASE_BRANCH"..HEAD 2>/dev/null || echo "0")
else
    SHORTSTAT="(non-git project)"
    COMMIT_COUNT="0"
fi

SUMMARY=$(cat "$RUNS_DIR/claude-summary.md" 2>/dev/null || echo "(no summary)")

python -m scripts.lib.feishu send_card \
    "Job #${JOB_ID:0:6} 完成" \
    "[{\"key\": \"Branch\", \"value\": \"$BRANCH\"},
      {\"key\": \"Diffstat\", \"value\": \"$SHORTSTAT\"},
      {\"key\": \"Commits\", \"value\": \"$COMMIT_COUNT\"},
      {\"key\": \"Summary\", \"value\": \"$SUMMARY\"}]" \
    "[{\"text\": \"查看 Spec\", \"url\": \"file://$RUNS_DIR/spec.md\"},
      {\"text\": \"查看 Plan\", \"url\": \"file://$RUNS_DIR/plan.md\"},
      {\"text\": \"需要继续?\", \"value\": {\"action\": \"continue\"}, \"type\": \"primary\"}]"

# Do not mark done yet — wait for user ack in Hermes
echo "[phase5] handoff sent"
