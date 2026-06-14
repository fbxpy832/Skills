#!/usr/bin/env bash
# hermes-dev-skill/scripts/phases/02_spec_plan.sh
# Phase 2: invoke Codex to generate spec.md and plan.md, then run a
# self-check pass. Up to 2 retries if self-check fails.
set -euo pipefail
JOB_ID="${1:-}"
if [ -z "$JOB_ID" ]; then
    echo "usage: $0 <job_id>" >&2
    exit 1
fi

RUNS_DIR="$HOME/.hermes/runs/$JOB_ID"
CODEX_MODEL=$(python -m scripts.lib.state get "$RUNS_DIR/state.json" \
    user_overrides.codex_model 2>/dev/null || echo "")
CODEX_MODEL=${CODEX_MODEL:-gpt-5.5}
SKILL_DIR="$(cd "$(dirname "$0")/../.." && pwd)"

# Sanity check requirements.md exists (Phase 1 must have produced it)
if [ ! -f "$RUNS_DIR/requirements.md" ]; then
    echo "[phase2] requirements.md missing in $RUNS_DIR" >&2
    exit 1
fi

# Build the spec/plan prompt
PROMPT="$(cat $SKILL_DIR/scripts/codex_prompts/spec_plan.md)

=== REQUIREMENTS ===
$(cat $RUNS_DIR/requirements.md)

=== PROJECT CONTEXT ===
- Path: $(python -m scripts.lib.state get $RUNS_DIR/state.json project.path)
- Default branch: $(python -m scripts.lib.state get $RUNS_DIR/state.json project.base_branch 2>/dev/null || echo main)

=== OUTPUT INSTRUCTIONS ===
Write two files into the runs directory:
- $RUNS_DIR/spec.md
- $RUNS_DIR/plan.md

Both files must follow the schema in codex_prompts/spec_plan.md."

echo "[phase2] invoking Codex ($CODEX_MODEL) for spec/plan"
codex --model "$CODEX_MODEL" \
      --sandbox danger-full-access \
      -p "$PROMPT" \
      --output-format json \
      > "$RUNS_DIR/codex-spec-plan.raw.json"

# Validate the output files exist
for f in spec.md plan.md; do
    if [ ! -s "$RUNS_DIR/$f" ]; then
        echo "[phase2] Codex did not produce $f" >&2
        python -m scripts.lib.state atomic_update "$RUNS_DIR/state.json" \
            '{"status": "halted"}'
        python -m scripts.lib.feishu send_text \
            "Job #${JOB_ID:0:6} Phase 2 失败：Codex 未生成 $f，请人工介入"
        exit 1
    fi
done

# Self-check
SELF_CHECK_PROMPT="$(cat $SKILL_DIR/scripts/codex_prompts/self_check.md)

=== SPEC ===
$(cat $RUNS_DIR/spec.md)

=== PLAN ===
$(cat $RUNS_DIR/plan.md)"

MAX_RETRIES=2
ATTEMPT=0
VERDICT="FAIL"
while [ $ATTEMPT -le $MAX_RETRIES ]; do
    echo "[phase2] self-check attempt $((ATTEMPT+1))"
    codex --model "$CODEX_MODEL" \
          --sandbox danger-full-access \
          -p "$SELF_CHECK_PROMPT" \
          --output-format json \
          > "$RUNS_DIR/self-check.raw.json"
    VERDICT=$(grep -E '^VERDICT:' "$RUNS_DIR/self-check.md" 2>/dev/null | tail -1 | awk '{print $2}' || echo "FAIL")
    if [ "$VERDICT" = "PASS" ]; then
        break
    fi
    ATTEMPT=$((ATTEMPT + 1))
done

if [ "$VERDICT" != "PASS" ]; then
    python -m scripts.lib.state atomic_update "$RUNS_DIR/state.json" \
        '{"status": "halted"}'
    python -m scripts.lib.feishu send_card \
        "Job #${JOB_ID:0:6} 自审未通过" \
        '[{"key": "请查看", "value": "self-check.md"}]' \
        '[{"text": "查看 self-check", "url": "file://'$RUNS_DIR'/self-check.md", "type": "primary"}]'
    exit 1
fi

# Save a checkpoint and move to phase 3
python -c "
from scripts.lib import checkpoint
checkpoint.save('$RUNS_DIR', 2, ['requirements.md', 'spec.md', 'plan.md', 'self-check.md'])
"
python -m scripts.lib.state atomic_update "$RUNS_DIR/state.json" \
    '{"phase": "implement"}'

python -m scripts.lib.feishu send_card \
    "Job #${JOB_ID:0:6} — Spec/Plan 已生成并自审通过" \
    '[{"key": "阶段", "value": "进入开发"}]' \
    '[{"text": "查看 Spec", "url": "file://'$RUNS_DIR'/spec.md", "type": "primary"},
      {"text": "查看 Plan", "url": "file://'$RUNS_DIR'/plan.md"}]'

echo "[phase2] done"
