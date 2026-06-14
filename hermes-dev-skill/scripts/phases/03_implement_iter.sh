#!/usr/bin/env bash
# hermes-dev-skill/scripts/phases/03_implement_iter.sh
# Follow-up round: re-invoke Claude Code with the previous round's review
# feedback. Round number is passed in.
set -euo pipefail
JOB_ID="${1:?usage: $0 <job_id> <round>}"
ROUND="${2:?usage: $0 <job_id> <round>}"

# This is structurally identical to 03_implement.sh with the round arg
# explicitly provided; reuse by calling it.
SKILL_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
bash "$SKILL_DIR/scripts/phases/03_implement.sh" "$JOB_ID" "$ROUND"
