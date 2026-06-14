#!/usr/bin/env bash
# hermes-dev-skill/scripts/phases/04_review_one.sh
# Run a single round of Codex review.
set -euo pipefail
JOB_ID="${1:?usage: $0 <job_id> <round>}"
ROUND="${2:?usage: $0 <job_id> <round>}"

RUNS_DIR="$HOME/.hermes/runs/$JOB_ID"
PROJECT_PATH=$(python -m scripts.lib.state get "$RUNS_DIR/state.json" project.path)
IS_GIT=$(python -m scripts.lib.state get "$RUNS_DIR/state.json" project.is_git)
BASE_BRANCH=$(python -m scripts.lib.state get "$RUNS_DIR/state.json" project.base_branch 2>/dev/null || echo "main")
CODEX_MODEL=$(python -m scripts.lib.state get "$RUNS_DIR/state.json" \
    user_overrides.codex_model 2>/dev/null || echo "")
CODEX_MODEL=${CODEX_MODEL:-gpt-5.5}
SKILL_DIR="$(cd "$(dirname "$0")/../.." && pwd)"

mkdir -p "$RUNS_DIR/review-rounds"

if [ "$IS_GIT" = "True" ] || [ "$IS_GIT" = "true" ]; then
    DIFF=$(cd "$PROJECT_PATH" && git diff "$BASE_BRANCH"..HEAD)
    DIFF_FILE="$RUNS_DIR/review-rounds/diff-round-$ROUND.txt"
    echo "$DIFF" > "$DIFF_FILE"
    REVIEW_INPUT_KIND="diff"
    SANDBOX_FLAGS="--sandbox danger-full-access"
    INPUT_BLOCK="Kind: cumulative git diff against base branch
Diff file: $DIFF_FILE (read this file directly)
$(cat "$DIFF_FILE")"
else
    REVIEW_INPUT_KIND="directory"
    SANDBOX_FLAGS="--sandbox workspace-write --add-dir $PROJECT_PATH"
    INPUT_BLOCK="Kind: directory tree (project is not a git repo)
Project path: $PROJECT_PATH
Read files from disk under that path as needed.
Do not require a diff blob; explore the tree."
fi

PROMPT="$(cat $SKILL_DIR/scripts/codex_prompts/review.md)

=== SPEC ===
$(cat $RUNS_DIR/spec.md)

=== PLAN ===
$(cat $RUNS_DIR/plan.md)

=== REVIEW INPUT ===
$INPUT_BLOCK

=== OUTPUT INSTRUCTIONS ===
Write your review to $RUNS_DIR/review-rounds/round-$ROUND.md.
End the file with a single line: VERDICT: APPROVED  or  VERDICT: REJECTED
Use the format - [P0] / - [P1] / - [P2] for issue entries."

codex --model "$CODEX_MODEL" $SANDBOX_FLAGS -p "$PROMPT" \
      --output-format json > "$RUNS_DIR/review-rounds/round-$ROUND.raw.json"

if [ ! -s "$RUNS_DIR/review-rounds/round-$ROUND.md" ]; then
    echo "[phase4] Codex did not produce round-$ROUND.md" >&2
    python -m scripts.lib.state atomic_update "$RUNS_DIR/state.json" \
        '{"status": "halted"}'
    exit 1
fi
