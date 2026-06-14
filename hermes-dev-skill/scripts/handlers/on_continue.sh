#!/usr/bin/env bash
# hermes-dev-skill/scripts/handlers/on_continue.sh
# Invoked by Hermes when the user says "@bot 继续" or taps a "continue" card
# button. Atomically increments max_review_rounds by 5 and resumes the
# review loop if the job is currently halted.
set -euo pipefail

JOB_ID="$1"
if [ -z "$JOB_ID" ]; then
    echo "usage: $0 <job_id>" >&2
    exit 1
fi

RUNS_DIR="$HOME/.hermes/runs/$JOB_ID"
if [ ! -d "$RUNS_DIR" ]; then
    echo "job $JOB_ID not found" >&2
    exit 1
fi

# SKILL_DIR resolution: respect HERMES_DEV_SKILL_DIR override (used by
# tests to point at a copy of the skill without overwriting real scripts).
SKILL_DIR="${HERMES_DEV_SKILL_DIR:-$(cd "$(dirname "$0")/../.." && pwd)}"

# Atomic update of state.json
python -m scripts.lib.state atomic_update "$RUNS_DIR/state.json" '
{
  "user_overrides": {
    "max_review_rounds": (current["user_overrides"]["max_review_rounds"] + 5),
    "extra_review_rounds_added": (current["user_overrides"]["extra_review_rounds_added"] + 5)
  }
}
'

NEW_MAX=$(python -m scripts.lib.state get "$RUNS_DIR/state.json" \
    user_overrides.max_review_rounds)
python -m scripts.lib.feishu send_text \
    "Job #${JOB_ID:0:6} 已增加 5 轮 review 上限，现在最多 $NEW_MAX 轮"

CURRENT_STATUS=$(python -m scripts.lib.state get "$RUNS_DIR/state.json" status)
if [ "$CURRENT_STATUS" = "halted" ]; then
    bash "$SKILL_DIR/scripts/phases/04_review.sh" "$JOB_ID"
fi
