#!/usr/bin/env bash
# hermes-dev-skill/scripts/phases/04_review.sh
# The review loop. Each iteration:
#   1. If round > 1, re-invoke Claude Code with prior review feedback
#   2. Run Codex review
#   3. Parse verdict; if APPROVED, transition to handoff
#   4. If max rounds reached, halt and escalate
set -euo pipefail
JOB_ID="${1:?usage: $0 <job_id>}"
SKILL_DIR="$(cd "$(dirname "$0")/../.." && pwd)"

RUNS_DIR="$HOME/.hermes/runs/$JOB_ID"
MAX=$(python -m scripts.lib.state get "$RUNS_DIR/state.json" \
    user_overrides.max_review_rounds)
ROUND=$(python -m scripts.lib.state get "$RUNS_DIR/state.json" phase_round 1)

while [ "$ROUND" -le "$MAX" ]; do
    if [ "$ROUND" -gt 1 ]; then
        bash "$SKILL_DIR/scripts/phases/03_implement_iter.sh" "$JOB_ID" "$ROUND"
    fi

    bash "$SKILL_DIR/scripts/phases/04_review_one.sh" "$JOB_ID" "$ROUND"

    REVIEW_FILE="$RUNS_DIR/review-rounds/round-$ROUND.md"
    VERDICT=$(python -c "
from scripts.lib.review_parser import parse_file
import sys
p = parse_file('$REVIEW_FILE')
print(p['verdict'])
print(p['p0'])
print(p['p1'])
")
    V=$(echo "$VERDICT" | sed -n 1p)
    P0=$(echo "$VERDICT" | sed -n 2p)
    P1=$(echo "$VERDICT" | sed -n 3p)

    python -m scripts.lib.feishu send_text \
        "Job #${JOB_ID:0:6} Review 第 $ROUND 轮：$V (P0=$P0, P1=$P1)"

    if [ "$V" = "APPROVED" ] && [ "$P0" = "0" ] && [ "$P1" = "0" ]; then
        python -m scripts.lib.state atomic_update "$RUNS_DIR/state.json" \
            '{"phase": "handoff", "status": "running"}'
        bash "$SKILL_DIR/scripts/phases/05_handoff.sh" "$JOB_ID"
        exit 0
    fi

    ROUND=$((ROUND + 1))
    python -m scripts.lib.state atomic_update "$RUNS_DIR/state.json" \
        "{\"phase_round\": $ROUND}"
done

# Cap exceeded
python -m scripts.lib.feishu send_text \
    "Job #${JOB_ID:0:6} 已迭代 $MAX 轮未通过 Review，建议人工介入。请查看最后一轮 review。"
python -m scripts.lib.state atomic_update "$RUNS_DIR/state.json" \
    '{"status": "halted"}'
