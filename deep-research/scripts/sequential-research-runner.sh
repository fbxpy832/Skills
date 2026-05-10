#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-balanced}"
TASK_FILE="${2:-}"
OUTPUT_DIR="${3:-}"
PROJECT_DIR="${4:-$(pwd)}"
DRY_RUN="${DRY_RUN:-0}"

for arg in "$@"; do
  if [ "$arg" = "--dry-run" ]; then
    DRY_RUN="1"
  fi
done

if [ -z "$TASK_FILE" ]; then
  echo "ERROR: Missing task file."
  echo "Usage: sequential-research-runner.sh MODE TASK_FILE [OUTPUT_DIR] [PROJECT_DIR] [--dry-run]"
  echo "Example: sequential-research-runner.sh high_quality /tmp/task.md /tmp/research-run /Users/xpy/Documents/RichardHub/Git"
  exit 1
fi

if [ ! -f "$TASK_FILE" ]; then
  echo "ERROR: Task file not found: $TASK_FILE"
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
ROUTER="$SCRIPT_DIR/model-router.sh"

if [ ! -x "$ROUTER" ]; then
  echo "ERROR: Model router is not executable: $ROUTER"
  exit 1
fi

if [ -z "$OUTPUT_DIR" ] || [ "$OUTPUT_DIR" = "--dry-run" ]; then
  RUN_ID="$(date +%Y%m%d-%H%M%S)"
  OUTPUT_DIR="$PROJECT_DIR/.deep-research-runs/$RUN_ID"
fi

mkdir -p "$OUTPUT_DIR/prompts" "$OUTPUT_DIR/outputs"

CLI_BIN="${CLI_BIN:-}"
if [ -z "$CLI_BIN" ]; then

  for cmd in opencode codex claude gemini aider; do
    if command -v "$cmd" >/dev/null 2>&1; then
      CLI_BIN="$(command -v "$cmd")"
      break
    fi
  done
fi





DEFAULT_AGENTS="planner_agent,source_agent,long_context_agent,analyst_agent,scenario_agent,writer_agent,reviewer_agent"
AGENT_LIST="${DEEP_RESEARCH_AGENTS:-$DEFAULT_AGENTS}"

IFS=',' read -r -a AGENTS <<< "$AGENT_LIST"

summary_file="$OUTPUT_DIR/run-summary.md"
task_text="$(cat "$TASK_FILE")"

cat > "$summary_file" <<EOF
# Deep Research Sequential Run

- Mode: $MODE
- Task file: $TASK_FILE
- Project dir: $PROJECT_DIR
- Skill dir: $SKILL_DIR
- Output dir: $OUTPUT_DIR
- Agents: $AGENT_LIST
- Dry run: $DRY_RUN

## Model Mapping

EOF

index=0
previous_outputs=""

for agent in "${AGENTS[@]}"; do
  index=$((index + 1))
  model="$("$ROUTER" "$MODE" "$agent")"
  prompt_file="$OUTPUT_DIR/prompts/$(printf "%02d" "$index")-$agent.md"
  output_file="$OUTPUT_DIR/outputs/$(printf "%02d" "$index")-$agent.md"

  cat >> "$summary_file" <<EOF
- $agent: $model
EOF

  cat > "$prompt_file" <<EOF
You are running the Deep Research Skill as subagent: $agent.

Run mode: $MODE
Selected model: $model
Project directory: $PROJECT_DIR
Skill directory: $SKILL_DIR

User research task:

---
$task_text
---

Required skill files to follow:

- $SKILL_DIR/SKILL.md
- $SKILL_DIR/model-routing.yaml
- $SKILL_DIR/references/workflow.md
- $SKILL_DIR/references/task-classification.md
- $SKILL_DIR/references/subagents.md
- $SKILL_DIR/references/source-audit.md
- $SKILL_DIR/references/quality-review.md
- $SKILL_DIR/references/output-rules.md
- $SKILL_DIR/references/user-context.md when the task involves the user's business context.
- $SKILL_DIR/templates/*.md as needed by task type.

Previous subagent outputs:

$previous_outputs

Agent-specific instruction:

1. Follow only the responsibilities and output contract for $agent in references/subagents.md.
2. Do not decide the final report unless you are writer_agent or reviewer_agent.
3. Do not invent sources, data, financial assumptions, legal facts, policies, prices, market sizes, or dates.
4. If source quality is insufficient, write the data gap explicitly.
5. If you need a missing previous output, state the dependency instead of guessing.
6. Output structured Markdown with clear YAML-like fields matching the contract for $agent.

Special rules:

- reviewer_agent must audit the writer output against references/quality-review.md.
- writer_agent must include mode, subagent/model mapping, source limitations, data gaps, and next-step recommendation.
- If this run is effectively sequential rather than parallel, state that in the final delivery metadata.
EOF

  echo "Prepared $agent with model $model"
  echo "Prompt: $prompt_file"

  if [ "$DRY_RUN" = "1" ]; then
    {
      echo "# Dry Run: $agent"
      echo ""
      echo "- Mode: $MODE"
      echo "- Model: $model"
      echo "- Prompt file: $prompt_file"
      echo "- Output file: $output_file"
    } > "$output_file"
  else
    if [ -z "$CLI_BIN" ] || [ ! -x "$CLI_BIN" ]; then
      echo "ERROR: No CLI tool found. Set CLI_BIN or install a supported CLI."
      echo "Supported CLIs: opencode, codex, claude, gemini, aider, or any CLI that accepts a prompt via stdin or arguments."
      exit 1
    fi

    (
      cd "$PROJECT_DIR"
      if [ -n "${CLI_RUN_TEMPLATE:-}" ]; then
        eval "$(echo "$CLI_RUN_TEMPLATE" | sed "s|\${CLI_BIN}|$CLI_BIN|g; s|\${MODEL}|$model|g; s|\${PROMPT}|$(cat "$prompt_file")|g")"
      else
        "$CLI_BIN" run "$(cat "$prompt_file")"
      fi
    ) > "$output_file"
  fi

  previous_outputs="$previous_outputs

[$agent output]
File: $output_file
$(cat "$output_file")
"
done

cat >> "$summary_file" <<EOF

## Outputs

EOF

for f in "$OUTPUT_DIR"/outputs/*.md; do
  echo "- $f" >> "$summary_file"
done

echo ""
echo "Deep Research sequential run complete."
echo "Summary: $summary_file"
echo "Outputs: $OUTPUT_DIR/outputs"
