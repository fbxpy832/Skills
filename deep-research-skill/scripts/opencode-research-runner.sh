#!/usr/bin/env bash
set -euo pipefail

DRY_RUN="${DRY_RUN:-0}"
EXECUTION_MODE="${DEEP_RESEARCH_EXECUTION_MODE:-parallel}"
POSITIONAL_ARGS=()

for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN="1" ;;
    --parallel) EXECUTION_MODE="parallel" ;;
    --sequential) EXECUTION_MODE="sequential" ;;
    *) POSITIONAL_ARGS+=("$arg") ;;
  esac
done

MODE="${POSITIONAL_ARGS[0]:-balanced}"
TASK_FILE="${POSITIONAL_ARGS[1]:-}"
OUTPUT_DIR="${POSITIONAL_ARGS[2]:-}"
PROJECT_DIR="${POSITIONAL_ARGS[3]:-$(pwd)}"

if [ -z "$TASK_FILE" ]; then
  echo "ERROR: Missing task file."
  echo "Usage: opencode-research-runner.sh MODE TASK_FILE [OUTPUT_DIR] [PROJECT_DIR] [--dry-run] [--parallel|--sequential]"
  echo "       TASK_FILE can be '-' to read from stdin"
  echo "Example: opencode-research-runner.sh high_quality /tmp/task.md /tmp/research-run /Users/xpy/Documents/RichardHub/Git --parallel"
  echo "         echo 'task description' | opencode-research-runner.sh high_quality - --parallel"
  exit 1
fi

if [ "$TASK_FILE" = "-" ]; then
  TASK_FILE=$(mktemp /tmp/deep-research-task-XXXXXX)
  cat > "$TASK_FILE"
  trap "rm -f '$TASK_FILE'" EXIT
fi

if [ ! -f "$TASK_FILE" ]; then
  echo "ERROR: Task file not found: $TASK_FILE"
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
ROUTER="$SCRIPT_DIR/model-router.sh"
CONFIG_ENV="${DEEP_RESEARCH_CONFIG_ENV:-${DEEP_RESEARCH_SKILL_CONFIG_DIR:-$HOME/.config/deep-research-skill}/config.env}"

if [ -f "$CONFIG_ENV" ]; then
  # shellcheck disable=SC1090
  source "$CONFIG_ENV"
else
  echo "WARNING: Local config not found: $CONFIG_ENV"
  echo "Run $SCRIPT_DIR/setup.sh to configure model providers, endpoints, credentials, and search API keys."
fi

if [ ! -x "$ROUTER" ]; then
  echo "ERROR: Model router is not executable: $ROUTER"
  exit 1
fi

provider_var_name() {
  local result
  result="$(echo "$1" | tr '[:lower:]-./ ' '[:upper:]____' | tr -cd 'A-Z0-9_')"
  if [ -z "$result" ]; then
    result="PROVIDER"
  fi
  echo "$result"
}

provider_from_model() {
  case "$1" in
    */*) echo "${1%%/*}" ;;
    *) echo "" ;;
  esac
}

export_provider_env_for_model() {
  local model="$1"
  local provider safe auth_env_var key_var base_var auth_env key base_url
  provider="$(provider_from_model "$model")"
  [ -n "$provider" ] || return 0

  safe="$(provider_var_name "$provider")"
  auth_env_var="DEEP_RESEARCH_PROVIDER_${safe}_AUTH_ENV"
  key_var="DEEP_RESEARCH_PROVIDER_${safe}_API_KEY"
  base_var="DEEP_RESEARCH_PROVIDER_${safe}_BASE_URL"

  auth_env="${!auth_env_var:-}"
  key="${!key_var:-}"
  base_url="${!base_var:-}"

  if [ -n "$auth_env" ] && [ -n "$key" ]; then
    export "$auth_env=$key"
  fi

  # Common OpenAI-compatible fallbacks used by provider SDKs and wrappers.
  case "$provider" in
    openai)
      [ -n "$key" ] && export OPENAI_API_KEY="$key"
      [ -n "$base_url" ] && export OPENAI_BASE_URL="$base_url"
      ;;
    deepseek)
      [ -n "$key" ] && export DEEPSEEK_API_KEY="$key"
      ;;
    moonshot|kimi)
      [ -n "$key" ] && export MOONSHOT_API_KEY="$key"
      ;;
    openrouter)
      [ -n "$key" ] && export OPENROUTER_API_KEY="$key"
      ;;
    siliconflow)
      [ -n "$key" ] && export SILICONFLOW_API_KEY="$key"
      ;;
  esac
}

if [ -z "$OUTPUT_DIR" ] || [ "$OUTPUT_DIR" = "--dry-run" ] || [ "$OUTPUT_DIR" = "--parallel" ] || [ "$OUTPUT_DIR" = "--sequential" ]; then
  RUN_ID="$(date +%Y%m%d-%H%M%S)"
  OUTPUT_BASE="${DEEP_RESEARCH_OUTPUT_DIR:-$PROJECT_DIR/.deep-research-runs}"
  OUTPUT_DIR="$OUTPUT_BASE/$RUN_ID"
fi

mkdir -p "$OUTPUT_DIR/prompts" "$OUTPUT_DIR/outputs" "$OUTPUT_DIR/logs"
source_failure_log_file="$OUTPUT_DIR/source_failure_log.md"
execution_context_file="$OUTPUT_DIR/execution-context.md"

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

if [ -z "${HOME:-}" ]; then
  echo "ERROR: HOME is not set in environment. Cannot determine user home directory."
  exit 1
fi
export HOME
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

# Proxy setup — only set if already in environment or port 7890 is reachable
if [ -n "${HTTP_PROXY:-}" ] || [ -n "${HTTPS_PROXY:-}" ]; then
  # Already set by environment, don't override
  :
elif (command -v nc && nc -z -w 1 127.0.0.1 7890 2>/dev/null) || \
     (command -v curl && curl -sI --connect-timeout 2 -x http://127.0.0.1:7890 http://www.baidu.com >/dev/null 2>&1); then
  export HTTP_PROXY="http://127.0.0.1:7890"
  export HTTPS_PROXY="http://127.0.0.1:7890"
  export ALL_PROXY="socks5://127.0.0.1:7890"
  export NO_PROXY="localhost,127.0.0.1,::1"
  echo "[proxy] Local proxy detected at 127.0.0.1:7890, proxy enabled"
else
  echo "[proxy] No local proxy detected, running without proxy"
  unset HTTP_PROXY HTTPS_PROXY ALL_PROXY
fi

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

agent_to_phase() {
  case "$1" in
    planner_agent)      echo "Phase_2_资料搜索" ;;
    source_agent)       echo "Phase_2_资料搜索" ;;
    long_context_agent) echo "Phase_2_资料搜索" ;;
    analyst_agent)      echo "Phase_3_事实核验" ;;
    scenario_agent)     echo "Phase_5_情景测算" ;;
    writer_agent)       echo "Phase_6_报告写作" ;;
    reviewer_agent)     echo "Phase_7_质量审计" ;;
    *)                  echo "全文" ;;
  esac
}

append_source_failure_log() {
  local agent="$1"
  local failed_task="${2:-}"
  local failure_type="${3:-}"
  local affected_scope="${4:-}"
  local fallback_handling="${5:-}"
  local failed_source_type="${6:-}"
  local failed_source_detail="${7:-}"
  local affected_conclusions="${8:-}"
  local fallback_source_level="${9:-}"
  local confidence_impact="${10:-reduced}"
  local report_usability_marking="${11:-待核验}"
  local audit_grade_cap="${12:-CONDITIONAL_PASS}"
  local failure_stage failure_time
  failure_stage="$(agent_to_phase "$agent")"
  failure_time="$(date '+%Y-%m-%d %H:%M:%S')"

  cat >> "$source_failure_log_file" <<EOF

## Failure Entry

\`\`\`yaml
source_failure_log:
  - failure_time: "$failure_time"
    failed_task: "$failed_task"
    failed_source_type: "$failed_source_type"
    failed_source_detail: "$failed_source_detail"
    failure_type: "$failure_type"
    failure_stage: "$failure_stage"
    affected_scope: "$affected_scope"
    affected_conclusions: "$affected_conclusions"
    fallback_handling: "$fallback_handling"
    fallback_source_level: "$fallback_source_level"
    confidence_impact: "$confidence_impact"
    report_usability_marking: "$report_usability_marking"
    audit_grade_cap: "$audit_grade_cap"
    required_manual_sources:
      - 补充 S/A/B 级来源并记录发布时间、获取时间和统计口径
    suggested_databases_or_keywords:
      - 根据 task_type 和任务目标补充检索关键词
\`\`\`

EOF
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
Requested model route: $model
Actual model detection status: not_verified
Model route execution status: unable_to_verify
Project directory: $PROJECT_DIR
Skill directory: $SKILL_DIR

User research task:

---
$task_text
---

Required skill files to follow:

- $SKILL_DIR/SKILL.md
- $SKILL_DIR/source-policy.yaml
- $SKILL_DIR/model-routing.yaml
- $SKILL_DIR/references/workflow.md
- $SKILL_DIR/references/task-classification.md
- $SKILL_DIR/references/subagents.md
- $SKILL_DIR/references/source-audit.md
- $SKILL_DIR/references/source-boundaries.md
- $SKILL_DIR/references/source-failure-log.md
- $SKILL_DIR/references/quality-review.md
- $SKILL_DIR/references/execution-consistency.md
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
7. Treat the requested model route as a requested model only. Do not write that the model was actually used unless execution logs or OpenCode state explicitly verify it.
8. If actual model detection is not available, write "模型使用未能自动验证".

Parallel execution rules:

- source_agent and long_context_agent may run concurrently after planner_agent.
- analyst_agent and scenario_agent may run concurrently after source_agent and long_context_agent.
- writer_agent must wait for analysis and scenario outputs.
- reviewer_agent must wait for writer_agent and audit it against references/quality-review.md.

Special rules:

- writer_agent must include mode, execution mode, subagent/model mapping, source limitations, data gaps, and next-step recommendation.
- writer_agent must include real_model_detection_status, model_route_execution_status, search_status, audit_grade placeholder, report_usability, and required_source_verification.
- reviewer_agent must state PASS / CONDITIONAL_PASS / FAIL and whether the final report is publish-ready.
- high_quality must not PASS if actual model cannot be verified, if web/source collection failed, or if source_failure_log contains failure entries.
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
  export_provider_env_for_model "$model"

  echo "Prepared $agent with model $model"
  echo "Prompt: $prompt_file"

  if [ "$DRY_RUN" = "1" ]; then
    {
      echo "# Dry Run: $agent"
      echo ""
      echo "- Mode: $MODE"
      echo "- Execution mode: $EXECUTION_MODE"
      echo "- Requested model route: $model"
      echo "- Actual model detection status: not_verified"
      echo "- Model route execution status: instruction_level_recommendation"
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

    if ! (
      cd "$PROJECT_DIR"
      if [ -n "${OPENCODE_TIMEOUT:-}" ] && [ "$OPENCODE_TIMEOUT" -gt 0 ] 2>/dev/null; then
        "$OPENCODE_BIN" run --model "$model" < "$prompt_file" &
        _oc_pid=$!
        (
          sleep "$OPENCODE_TIMEOUT"
          kill $_oc_pid 2>/dev/null || true
        ) &
        _watchdog=$!
        wait $_oc_pid 2>/dev/null
        _oc_exit=$?
        kill $_watchdog 2>/dev/null || true
        exit $_oc_exit
      else
        "$OPENCODE_BIN" run --model "$model" < "$prompt_file"
      fi
    ) > "$output_file"; then
      append_source_failure_log "$agent" "${agent} execution failed" "agent_execution_failed" "Subagent output unavailable or incomplete." "Mark report as draft and require manual verification."
      return 1
    fi
  fi

  end_time="$(date '+%Y-%m-%d %H:%M:%S')"
  {
    echo "agent=$agent"
    echo "requested_model=$model"
    echo "actual_model_detection_status=not_verified"
    echo "model_route_execution_status=unable_to_verify"
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
- Config env: $CONFIG_ENV
- Configured providers: ${DEEP_RESEARCH_PROVIDER_IDS:-not_configured}

## Stage Plan

1. planner_agent
2. source_agent + long_context_agent (parallel when enabled)
3. analyst_agent + scenario_agent (parallel when enabled)
4. writer_agent
5. reviewer_agent

## Model Mapping

EOF

cat > "$execution_context_file" <<EOF
# Execution Context

- mode: $MODE
- execution_mode: $EXECUTION_MODE
- dry_run: $DRY_RUN
- config_env: $CONFIG_ENV
- configured_providers: ${DEEP_RESEARCH_PROVIDER_IDS:-not_configured}
- actual_model_detection_status: not_verified
- model_route_execution_status: unable_to_verify
- model_statement_rule: Do not claim a requested model was actually used unless OpenCode logs, command output, or UI state verifies it.
- high_quality_limit: If actual model cannot be verified, high_quality output cannot be PASS.

EOF

cat > "$source_failure_log_file" <<EOF
# Source Failure Log

If source collection, web search, fetch, or source validation fails, append entries using this shape:

\`\`\`yaml
source_failure_log:
  - failure_time:
    failed_task:
    failed_source_type:
    failed_source_detail:
    failure_type:
    failure_stage:
    affected_scope:
    affected_conclusions:
    fallback_handling:
    fallback_source_level:
    confidence_impact:
    report_usability_marking:
    audit_grade_cap:
    required_manual_sources:
    suggested_databases_or_keywords:
\`\`\`
EOF

for agent in planner_agent source_agent long_context_agent analyst_agent scenario_agent writer_agent reviewer_agent; do
  if agent_enabled "$agent"; then
    requested_model="$( "$ROUTER" "$MODE" "$agent" )"
    echo "- $agent: requested_model=$requested_model; actual_model_detection_status=not_verified" >> "$summary_file"
    echo "- $agent: requested_model=$requested_model; actual_model_detection_status=not_verified" >> "$execution_context_file"
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

cat >> "$summary_file" <<EOF

## Execution Consistency

- actual_model_detection_status: not_verified
- model_route_execution_status: unable_to_verify
- source_failure_log: $source_failure_log_file
- execution_context: $execution_context_file
- reporting_rule: Requested model routes must not be described as verified actual model usage.
EOF

echo ""
echo "Deep Research OpenCode run complete."
echo "Summary: $summary_file"
echo "Outputs: $OUTPUT_DIR/outputs"
