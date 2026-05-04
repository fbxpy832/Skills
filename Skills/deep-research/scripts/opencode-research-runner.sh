#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-balanced}"
TASK_FILE="${2:-}"
OUTPUT_DIR="${3:-}"
PROJECT_DIR="${4:-$(pwd)}"
DRY_RUN="${DRY_RUN:-0}"
EXECUTION_MODE="${DEEP_RESEARCH_EXECUTION_MODE:-parallel}"

for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN="1" ;;
    --parallel) EXECUTION_MODE="parallel" ;;
    --sequential) EXECUTION_MODE="sequential" ;;
  esac
done

if [ -z "$TASK_FILE" ]; then
  echo "ERROR: Missing task file."
  echo "Usage: opencode-research-runner.sh MODE TASK_FILE [OUTPUT_DIR] [PROJECT_DIR] [--dry-run] [--parallel|--sequential]"
  echo "Example: opencode-research-runner.sh high_quality /tmp/task.md /tmp/research-run /Users/xpy/Documents/RichardHub/Git --parallel"
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

if [ -z "$OUTPUT_DIR" ] || [ "$OUTPUT_DIR" = "--dry-run" ] || [ "$OUTPUT_DIR" = "--parallel" ] || [ "$OUTPUT_DIR" = "--sequential" ]; then
  RUN_ID="$(date +%Y%m%d-%H%M%S)"
  OUTPUT_DIR="$PROJECT_DIR/.deep-research-runs/$RUN_ID"
fi

mkdir -p "$OUTPUT_DIR/prompts" "$OUTPUT_DIR/outputs" "$OUTPUT_DIR/logs"

OPENCODE_BIN="${OPENCODE_BIN:-}"
if [ -z "$OPENCODE_BIN" ]; then
  if command -v opencode >/dev/null 2>&1; then
    OPENCODE_BIN="$(command -v opencode)"
  elif [ -x "/opt/homebrew/bin/opencode" ]; then
    OPENCODE_BIN="/opt/homebrew/bin/opencode"
  elif [ -x "$HOME/.opencode/bin/opencode" ]; then
    OPENCODE_BIN="$HOME/.opencode/bin/opencode"
  else
    OPENCODE_BIN=""
  fi
fi

export HOME="${HOME:-/Users/xpy}"
export XDG_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
export XDG_STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"

if [ "$DRY_RUN" != "1" ]; then
  mkdir -p "$XDG_DATA_HOME/opencode" "$XDG_STATE_HOME/opencode"

  if [ ! -w "$XDG_DATA_HOME/opencode" ]; then
    echo "ERROR: OpenCode data directory is not writable: $XDG_DATA_HOME/opencode"
    exit 1
  fi

  if [ ! -w "$XDG_STATE_HOME/opencode" ]; then
    echo "ERROR: OpenCode state directory is not writable: $XDG_STATE_HOME/opencode"
    exit 1
  fi
fi

export HTTP_PROXY="${HTTP_PROXY:-http://127.0.0.1:7890}"
export HTTPS_PROXY="${HTTPS_PROXY:-http://127.0.0.1:7890}"
export ALL_PROXY="${ALL_PROXY:-socks5://127.0.0.1:7890}"
export NO_PROXY="${NO_PROXY:-localhost,127.0.0.1,::1}"

DEFAULT_AGENTS="planner_agent,source_agent,long_context_agent,analyst_agent,scenario_agent,writer_agent,reviewer_agent"
AGENT_LIST="${DEEP_RESEARCH_AGENTS:-$DEFAULT_AGENTS}"
task_text="$(cat "$TASK_FILE")"
summary_file="$OUTPUT_DIR/run-summary.md"

agent_enabled() {
  case ",$AGENT_LIST," in
    *",$1,"*) return 0 ;;
    *) return 1 ;;
  esac
}

agent_index() {
  case "$1" in
    planner_agent) echo "01" ;;
    source_agent) echo "02" ;;
    long_context_agent) echo "03" ;;
    analyst_agent) echo "04" ;;
    scenario_agent) echo "05" ;;
    writer_agent) echo "06" ;;
    reviewer_agent) echo "07" ;;
    *) echo "99" ;;
  esac
}

agent_output_file() {
  local agent="$1"
  echo "$OUTPUT_DIR/outputs/$(agent_index "$agent")-$agent.md"
}

agent_prompt_file() {
  local agent="$1"
  echo "$OUTPUT_DIR/prompts/$(agent_index "$agent")-$agent.md"
}

collect_outputs() {
  local deps=("$@")
  local dep output

  for dep in "${deps[@]}"; do
    output="$(agent_output_file "$dep")"
    if [ -f "$output" ]; then
      echo ""
      echo "[$dep output]"
      echo "File: $output"
      cat "$output"
      echo ""
    fi
  done
}

deps_for_agent() {
  case "$1" in
    planner_agent)
      ;;
    source_agent|long_context_agent)
      echo "planner_agent"
      ;;
    analyst_agent|scenario_agent)
      echo "planner_agent source_agent long_context_agent"
      ;;
    writer_agent)
      echo "planner_agent source_agent long_context_agent analyst_agent scenario_agent"
      ;;
    reviewer_agent)
      echo "planner_agent source_agent long_context_agent analyst_agent scenario_agent writer_agent"
      ;;
    *)
      echo "planner_agent"
      ;;
  esac
}

write_prompt() {
  local agent="$1"
  local model="$2"
  local prompt_file="$3"
  local deps_text="$4"

  cat > "$prompt_file" <<EOF
You are running the Deep Research Skill as subagent: $agent.

Run mode: $MODE
Execution mode: $EXECUTION_MODE
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

Dependency outputs:

$deps_text

Agent-specific instruction:

1. Follow only the responsibilities and output contract for $agent in references/subagents.md.
2. Do not decide the final report unless you are writer_agent or reviewer_agent.
3. Do not invent sources, data, financial assumptions, legal facts, policies, prices, market sizes, or dates.
4. If source quality is insufficient, write the data gap explicitly.
5. If you need a missing dependency output, state the dependency instead of guessing.
6. Output structured Markdown with clear YAML-like fields matching the contract for $agent.

Parallel execution rules:

- source_agent and long_context_agent may run concurrently after planner_agent.
- analyst_agent and scenario_agent may run concurrently after source_agent and long_context_agent.
- writer_agent must wait for analysis and scenario outputs.
- reviewer_agent must wait for writer_agent and audit it against references/quality-review.md.

Special rules:

- writer_agent must include mode, execution mode, subagent/model mapping, source limitations, data gaps, and next-step recommendation.
- reviewer_agent must state whether the final report is publish-ready.
EOF
}

run_agent() {
  local agent="$1"

  if ! agent_enabled "$agent"; then
    echo "Skipping disabled $agent"
    return 0
  fi

  local model prompt_file output_file deps_text deps_display start_time end_time
  local -a deps=()
  model="$("$ROUTER" "$MODE" "$agent")"
  prompt_file="$(agent_prompt_file "$agent")"
  output_file="$(agent_output_file "$agent")"
  read -r -a deps <<< "$(deps_for_agent "$agent")"
  if [ "${#deps[@]}" -gt 0 ]; then
    deps_text="$(collect_outputs "${deps[@]}")"
    deps_display="${deps[*]}"
  else
    deps_text=""
    deps_display="none"
  fi
  start_time="$(date '+%Y-%m-%d %H:%M:%S')"

  write_prompt "$agent" "$model" "$prompt_file" "$deps_text"

  echo "Prepared $agent with model $model"
  echo "Prompt: $prompt_file"

  if [ "$DRY_RUN" = "1" ]; then
    {
      echo "# Dry Run: $agent"
      echo ""
      echo "- Mode: $MODE"
      echo "- Execution mode: $EXECUTION_MODE"
      echo "- Model: $model"
      echo "- Started: $start_time"
      echo "- Prompt file: $prompt_file"
      echo "- Output file: $output_file"
      echo "- Dependencies: $deps_display"
    } > "$output_file"
  else
    if [ -z "$OPENCODE_BIN" ] || [ ! -x "$OPENCODE_BIN" ]; then
      echo "ERROR: opencode CLI not found. Set OPENCODE_BIN or install/login to OpenCode."
      return 1
    fi

    (
      cd "$PROJECT_DIR"
      "$OPENCODE_BIN" run --model "$model" "$(cat "$prompt_file")"
    ) > "$output_file"
  fi

  end_time="$(date '+%Y-%m-%d %H:%M:%S')"
  {
    echo "agent=$agent"
    echo "model=$model"
    echo "prompt=$prompt_file"
    echo "output=$output_file"
    echo "started=$start_time"
    echo "ended=$end_time"
  } > "$OUTPUT_DIR/logs/$(agent_index "$agent")-$agent.log"
}

run_stage_parallel() {
  local stage_name="$1"
  shift
  local agents=("$@")
  local pids=()
  local names=()
  local agent pid failed=0

  echo ""
  echo "== Stage: $stage_name =="

  for agent in "${agents[@]}"; do
    if agent_enabled "$agent"; then
      run_agent "$agent" &
      pid="$!"
      pids+=("$pid")
      names+=("$agent")
      echo "Started $agent in background pid=$pid"
    fi
  done

  for i in "${!pids[@]}"; do
    if wait "${pids[$i]}"; then
      echo "Completed ${names[$i]}"
    else
      echo "FAILED ${names[$i]}"
      failed=1
    fi
  done

  if [ "$failed" != "0" ]; then
    echo "ERROR: Stage failed: $stage_name"
    exit 1
  fi
}

run_stage_sequential() {
  local stage_name="$1"
  shift
  local agents=("$@")
  local agent

  echo ""
  echo "== Stage: $stage_name =="

  for agent in "${agents[@]}"; do
    run_agent "$agent"
  done
}

run_stage() {
  if [ "$EXECUTION_MODE" = "parallel" ]; then
    run_stage_parallel "$@"
  else
    run_stage_sequential "$@"
  fi
}

cat > "$summary_file" <<EOF
# Deep Research OpenCode Run

- Mode: $MODE
- Execution mode: $EXECUTION_MODE
- Task file: $TASK_FILE
- Project dir: $PROJECT_DIR
- Skill dir: $SKILL_DIR
- Output dir: $OUTPUT_DIR
- Agents: $AGENT_LIST
- Dry run: $DRY_RUN

## Stage Plan

1. planner_agent
2. source_agent + long_context_agent (parallel when enabled)
3. analyst_agent + scenario_agent (parallel when enabled)
4. writer_agent
5. reviewer_agent

## Model Mapping

EOF

for agent in planner_agent source_agent long_context_agent analyst_agent scenario_agent writer_agent reviewer_agent; do
  if agent_enabled "$agent"; then
    echo "- $agent: $( "$ROUTER" "$MODE" "$agent" )" >> "$summary_file"
  fi
done

run_stage "planning" planner_agent
run_stage "evidence_collection" source_agent long_context_agent
run_stage "analysis_and_scenario" analyst_agent scenario_agent
run_stage "writing" writer_agent
run_stage "review" reviewer_agent

cat >> "$summary_file" <<EOF

## Outputs

EOF

for f in "$OUTPUT_DIR"/outputs/*.md; do
  [ -f "$f" ] && echo "- $f" >> "$summary_file"
done

cat >> "$summary_file" <<EOF

## Logs

EOF

for f in "$OUTPUT_DIR"/logs/*.log; do
  [ -f "$f" ] && echo "- $f" >> "$summary_file"
done

echo ""
echo "Deep Research OpenCode run complete."
echo "Summary: $summary_file"
echo "Outputs: $OUTPUT_DIR/outputs"
