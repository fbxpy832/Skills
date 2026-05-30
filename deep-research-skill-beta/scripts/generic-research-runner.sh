#!/usr/bin/env bash
set -euo pipefail

# ============================================================================
# generic-research-runner.sh — Host-Neutral Deep Research Runner
# ============================================================================
# This runner generates prompts, artifacts, and event streams without
# depending on any specific host (OpenCode, Codex, Claude Code, etc.).
#
# In dry-run mode (default behavior when no HOST_RUN_CMD is set), it
# generates all prompt files, artifact files, and events.ndjson.
#
# In live mode, set HOST_RUN_CMD to a command that takes: model prompt_file output_file
#   export HOST_RUN_CMD="opencode run --model"
#   generic-research-runner.sh balanced task.md
#
# Usage:
#   generic-research-runner.sh MODE TASK_FILE [OUTPUT_DIR] [PROJECT_DIR] [--dry-run] [--parallel|--sequential]
#   TASK_FILE can be '-' to read from stdin
#
# Environment:
#   HOST_RUN_CMD           - Command prefix for live agent execution (optional)
#   HOST_RUN_TIMEOUT       - Timeout in seconds for each agent (default: 600)
#   DEEP_RESEARCH_AGENTS   - Comma-separated agent list (default: all 7)
# ============================================================================

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
  echo "Usage: generic-research-runner.sh MODE TASK_FILE [OUTPUT_DIR] [PROJECT_DIR] [--dry-run] [--parallel|--sequential]"
  echo "       TASK_FILE can be '-' to read from stdin"
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

HOST_RUN_CMD="${HOST_RUN_CMD:-}"
HOST_RUN_TIMEOUT="${HOST_RUN_TIMEOUT:-600}"

# If no HOST_RUN_CMD and not explicitly --dry-run, default to dry-run
if [ -z "$HOST_RUN_CMD" ] && [ "$DRY_RUN" != "1" ]; then
  echo "INFO: No HOST_RUN_CMD set. Defaulting to dry-run mode (prompts and artifacts only)."
  echo "      Set HOST_RUN_CMD to enable live execution. Example:"
  echo "      export HOST_RUN_CMD='opencode run --model'"
  DRY_RUN="1"
fi

if [ -z "$OUTPUT_DIR" ] || [ "$OUTPUT_DIR" = "--dry-run" ] || [ "$OUTPUT_DIR" = "--parallel" ] || [ "$OUTPUT_DIR" = "--sequential" ]; then
  RUN_ID="$(date +%Y%m%d-%H%M%S)"
  OUTPUT_BASE="${DEEP_RESEARCH_OUTPUT_DIR:-$PROJECT_DIR/.deep-research-runs}"
  OUTPUT_DIR="$OUTPUT_BASE/$RUN_ID"
fi

RUN_ID="$(basename "$OUTPUT_DIR")"
mkdir -p "$OUTPUT_DIR/prompts" "$OUTPUT_DIR/outputs" "$OUTPUT_DIR/logs"

# ─── Artifact file paths ───────────────────────────────────────────
summary_file="$OUTPUT_DIR/run-summary.md"
execution_context_file="$OUTPUT_DIR/execution-context.md"
source_failure_log_file="$OUTPUT_DIR/source_failure_log.md"
events_file="$OUTPUT_DIR/events.ndjson"

# ─── Event writing ─────────────────────────────────────────────────
write_event() {
  local timestamp phase agent status requested_model detected_model_status message error
  timestamp="$(date '+%Y-%m-%dT%H:%M:%S%z')"
  phase="${1:-}"
  agent="${2:-}"
  status="${3:-}"
  requested_model="${4:-}"
  detected_model_status="${5:-not_verified}"
  message="${6:-}"
  error="${7:-}"

  # Escape strings for JSON using python3; fallback to manual escaping
  local esc_phase esc_agent esc_status esc_model esc_msg esc_err
  esc_phase=$(printf '%s' "$phase" | python3 -c "import sys,json; print(json.dumps(sys.stdin.read().rstrip('\n')))" 2>/dev/null) || esc_phase="\"$(printf '%s' "$phase" | sed 's/\\/\\\\/g; s/"/\\"/g')\""
  esc_agent=$(printf '%s' "$agent" | python3 -c "import sys,json; print(json.dumps(sys.stdin.read().rstrip('\n')))" 2>/dev/null) || esc_agent="\"$(printf '%s' "$agent" | sed 's/\\/\\\\/g; s/"/\\"/g')\""
  esc_status=$(printf '%s' "$status" | python3 -c "import sys,json; print(json.dumps(sys.stdin.read().rstrip('\n')))" 2>/dev/null) || esc_status="\"$(printf '%s' "$status" | sed 's/\\/\\\\/g; s/"/\\"/g')\""
  esc_model=$(printf '%s' "$requested_model" | python3 -c "import sys,json; print(json.dumps(sys.stdin.read().rstrip('\n')))" 2>/dev/null) || esc_model="\"$(printf '%s' "$requested_model" | sed 's/\\/\\\\/g; s/"/\\"/g')\""
  esc_msg=$(printf '%s' "$message" | python3 -c "import sys,json; print(json.dumps(sys.stdin.read().rstrip('\n')))" 2>/dev/null) || esc_msg="\"$(printf '%s' "$message" | sed 's/\\/\\\\/g; s/"/\\"/g')\""
  esc_err=$(printf '%s' "$error" | python3 -c "import sys,json; print(json.dumps(sys.stdin.read().rstrip('\n')))" 2>/dev/null) || esc_err="\"$(printf '%s' "$error" | sed 's/\\/\\\\/g; s/"/\\"/g')\""
  esc_detected=$(printf '%s' "$detected_model_status" | python3 -c "import sys,json; print(json.dumps(sys.stdin.read().rstrip('\n')))" 2>/dev/null) || esc_detected="\"$(printf '%s' "$detected_model_status" | sed 's/\\/\\\\/g; s/"/\\"/g')\""
  esc_runid=$(printf '%s' "$RUN_ID" | python3 -c "import sys,json; print(json.dumps(sys.stdin.read().rstrip('\n')))" 2>/dev/null) || esc_runid="\"$(printf '%s' "$RUN_ID" | sed 's/\\/\\\\/g; s/"/\\"/g')\""
  esc_ts=$(printf '%s' "$timestamp" | python3 -c "import sys,json; print(json.dumps(sys.stdin.read().rstrip('\n')))" 2>/dev/null) || esc_ts="\"$(printf '%s' "$timestamp" | sed 's/\\/\\\\/g; s/"/\\"/g')\""
 
  printf '{"timestamp":%s,"run_id":%s,"phase":%s,"agent":%s,"status":%s,"requested_model":%s,"detected_model_status":%s,"message":%s,"error":%s}\n' \
    "$esc_ts" "$esc_runid" "$esc_phase" "$esc_agent" "$esc_status" "$esc_model" "$esc_detected" "$esc_msg" "$esc_err" \
    >> "$events_file"
}

# ─── Agent helpers ─────────────────────────────────────────────────
DEFAULT_AGENTS="planner_agent,source_agent,long_context_agent,analyst_agent,scenario_agent,writer_agent,reviewer_agent"
AGENT_LIST="${DEEP_RESEARCH_AGENTS:-$DEFAULT_AGENTS}"
task_text="$(cat "$TASK_FILE")"

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

stage_name_for_agent() {
  case "$1" in
    planner_agent)      echo "stage_1_planning" ;;
    source_agent|long_context_agent) echo "stage_2_evidence_collection" ;;
    analyst_agent|scenario_agent)    echo "stage_3_analysis_and_scenario" ;;
    writer_agent)       echo "stage_4_writing" ;;
    reviewer_agent)     echo "stage_5_review" ;;
    *)                  echo "stage_unknown" ;;
  esac
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
    planner_agent) ;;
    source_agent|long_context_agent)
      echo "planner_agent" ;;
    analyst_agent|scenario_agent)
      echo "planner_agent source_agent long_context_agent" ;;
    writer_agent)
      echo "planner_agent source_agent long_context_agent analyst_agent scenario_agent" ;;
    reviewer_agent)
      echo "planner_agent source_agent long_context_agent analyst_agent scenario_agent writer_agent" ;;
    *)
      echo "planner_agent" ;;
  esac
}

write_prompt() {
  local agent="$1"
  local model="$2"
  local prompt_file="$3"
  local deps_text="$4"

  cat > "$prompt_file" <<DEEP_RESEARCH_PROMPT_EOF
You are running the Deep Research Skill as subagent: $agent.

Run mode: $MODE
Execution mode: $EXECUTION_MODE
Requested model route: $model
Actual model detection status: not_verified
Model route execution status: unable_to_verify
Project directory: $PROJECT_DIR
Skill directory: $SKILL_DIR
Runner type: generic (host-neutral)

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
- $SKILL_DIR/references/host-adapter-contract.md for protocol requirements.

Host notes:
- This is a host-neutral run. The runner generates prompts and collects artifacts.
- Treat the requested model route as advisory. The actual executing host determines model selection.
- Report model detection status honestly: write "模型使用未能自动验证" if unverified.

Dependency outputs:

$deps_text

Agent-specific instruction:

1. Follow only the responsibilities and output contract for $agent in references/subagents.md.
2. Do not decide the final report unless you are writer_agent or reviewer_agent.
3. Do not invent sources, data, financial assumptions, legal facts, policies, prices, market sizes, or dates.
4. If source quality is insufficient, write the data gap explicitly.
5. If you need a missing dependency output, state the dependency instead of guessing.
6. Output structured Markdown with clear YAML-like fields matching the contract for $agent.
7. Never claim a model was "actually used" unless execution logs or host state explicitly verify it.
8. If actual model detection is not available, write "模型使用未能自动验证".

Parallel execution rules:

- source_agent and long_context_agent may run concurrently after planner_agent.
- analyst_agent and scenario_agent may run concurrently after source_agent and long_context_agent.
- writer_agent must wait for analysis and scenario outputs.
- reviewer_agent must wait for writer_agent and audit it against references/quality-review.md.

Special rules:

- source_agent: Use $SCRIPT_DIR/search.sh "query" [--parallel] [--json] for all external web searches.
- source_agent: Use $SCRIPT_DIR/knowledge-retrieval.sh "query" [--json] for all internal knowledge base searches.
- source_agent: Execution context with search preflight is at $execution_context_file.
- source_agent: Source failure log is at $source_failure_log_file. Append entries on web search or knowledge retrieval failure.
- source_agent: On search failure, output: failed_source_type, failure_type, attempted_backends, fallback_path, search_status, suggested_next_queries.
- writer_agent: Read $source_failure_log_file and $execution_context_file. Determine search_status, report_usability, audit_grade from these.
- writer_agent: If source_failure_log_file has failure entries, include degradation markers in filename and report header.
- writer_agent: Filename format: 研究主题-报告类型[-来源类型][-离线初稿|-待联网核验版][-v2]-YYYY-MM-DD.md
- writer_agent: Report title format (h1): # 研究主题：报告类型
- reviewer_agent: Check $source_failure_log_file. If it contains real failure entries, high_quality audit_grade must NOT be PASS.
- reviewer_agent: If search_status is failed/partial_success, verify that filename and report header contain degradation markers.
- writer_agent must include mode, execution mode, subagent/model mapping, source limitations, data gaps, and next-step recommendation.
- writer_agent must include real_model_detection_status, model_route_execution_status, search_status, audit_grade placeholder, report_usability, and required_source_verification.
- reviewer_agent must state PASS / CONDITIONAL_PASS / FAIL and whether the final report is publish-ready.
- high_quality must not PASS if actual model cannot be verified, if web/source collection failed, or if source_failure_log contains failure entries.
DEEP_RESEARCH_PROMPT_EOF
}

run_agent() {
  local agent="$1"

  if ! agent_enabled "$agent"; then
    write_event "$(stage_name_for_agent "$agent")" "$agent" "skipped" "" "not_verified" "Skipping disabled $agent" ""
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

  stage="$(stage_name_for_agent "$agent")"
  write_event "$stage" "$agent" "started" "$model" "not_verified" "Starting $agent" ""

  write_prompt "$agent" "$model" "$prompt_file" "$deps_text"

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
      echo ""
      echo "## Agent Prompt"
      echo ""
      echo "The full prompt for this agent is at: $prompt_file"
    } > "$output_file"

    write_event "$stage" "$agent" "completed" "$model" "not_verified" "Dry-run completed for $agent" ""
  else
    # Live execution via HOST_RUN_CMD
    if [ -z "$HOST_RUN_CMD" ]; then
      echo "ERROR: HOST_RUN_CMD is not set. Cannot execute agent live."
      write_event "$stage" "$agent" "failed" "$model" "not_verified" "HOST_RUN_CMD not set" "No host command configured"
      return 1
    fi

    # Invoke the host with: HOST_RUN_CMD model < prompt_file > output_file
    if ! (
      timeout "$HOST_RUN_TIMEOUT" $HOST_RUN_CMD "$model" < "$prompt_file" > "$output_file" 2>&1
    ); then
      echo "WARNING: $agent execution via HOST_RUN_CMD failed."
      write_event "$stage" "$agent" "failed" "$model" "not_verified" "$agent execution failed" "Host command returned error"
      return 1
    fi

    write_event "$stage" "$agent" "completed" "$model" "not_verified" "Completed $agent" ""
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
    echo "runner=generic"
  } > "$OUTPUT_DIR/logs/$(agent_index "$agent")-$agent.log"
}

# ─── Stage execution ───────────────────────────────────────────────
run_stage_parallel() {
  local stage_name="$1"
  shift
  local agents=("$@")
  local pids=()
  local names=()
  local agent pid failed=0

  echo ""
  echo "== Stage: $stage_name =="
  write_event "$stage_name" "" "started" "" "not_verified" "Stage $stage_name started" ""

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
    write_event "$stage_name" "" "failed" "" "not_verified" "Stage $stage_name failed" "One or more agents failed"
    echo "ERROR: Stage failed: $stage_name"
    exit 1
  fi

  write_event "$stage_name" "" "completed" "" "not_verified" "Stage $stage_name completed" ""
}

run_stage_sequential() {
  local stage_name="$1"
  shift
  local agents=("$@")
  local agent

  echo ""
  echo "== Stage: $stage_name =="
  write_event "$stage_name" "" "started" "" "not_verified" "Stage $stage_name started" ""

  for agent in "${agents[@]}"; do
    run_agent "$agent"
  done

  write_event "$stage_name" "" "completed" "" "not_verified" "Stage $stage_name completed" ""
}

run_stage() {
  if [ "$EXECUTION_MODE" = "parallel" ]; then
    run_stage_parallel "$@"
  else
    run_stage_sequential "$@"
  fi
}

# ─── Initialize artifacts ──────────────────────────────────────────
write_event "run" "" "started" "" "not_verified" "Deep Research run started (generic runner)" ""

cat > "$summary_file" <<EOF
# Deep Research Generic Run

- Mode: $MODE
- Execution mode: $EXECUTION_MODE
- Runner type: generic (host-neutral)
- Task file: $TASK_FILE
- Project dir: $PROJECT_DIR
- Skill dir: $SKILL_DIR
- Output dir: $OUTPUT_DIR
- Run ID: $RUN_ID
- Agents: $AGENT_LIST
- Dry run: $DRY_RUN
- Host run cmd: ${HOST_RUN_CMD:-none}
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
- runner_type: generic
- dry_run: $DRY_RUN
- config_env: $CONFIG_ENV
- configured_providers: ${DEEP_RESEARCH_PROVIDER_IDS:-not_configured}
- actual_model_detection_status: not_verified
- model_route_execution_status: unable_to_verify
- model_statement_rule: Do not claim a requested model was actually used unless host logs, command output, or UI state verifies it.
- high_quality_limit: If actual model cannot be verified, high_quality output cannot be PASS.
- host_adapter_contract: See references/host-adapter-contract.md

## Search Preflight

- search_script: $SCRIPT_DIR/search.sh
- knowledge_retrieval_script: $SCRIPT_DIR/knowledge-retrieval.sh
- BOCHA_API_KEY: $(if [ -n "${BOCHA_API_KEY:-}" ]; then echo "configured"; else echo "NOT_SET"; fi)
- EXA_API_KEY: $(if [ -n "${EXA_API_KEY:-}" ]; then echo "configured"; else echo "NOT_SET"; fi)
- BRAVE_API_KEY: $(if [ -n "${BRAVE_API_KEY:-}" ]; then echo "configured"; else echo "NOT_SET"; fi)
- external_search_available: $(if [ -n "${BOCHA_API_KEY:-}${EXA_API_KEY:-}${BRAVE_API_KEY:-}" ]; then echo "true"; else echo "false"; fi)
- cache_dir: $(mkdir -p "${XDG_CACHE_HOME:-$HOME/.cache}/deep-research-skill" 2>/dev/null; echo "${XDG_CACHE_HOME:-$HOME/.cache}/deep-research-skill")
- count_file: $(mkdir -p "${XDG_STATE_HOME:-$HOME/.local/state}/deep-research-skill" 2>/dev/null; echo "${XDG_STATE_HOME:-$HOME/.local/state}/deep-research-skill/search-count")

## Knowledge Source Preflight

- knowledge_lark: $(if "$SCRIPT_DIR/knowledge-lark.sh" --check &>/dev/null 2>&1; then echo "available"; else echo "unavailable"; fi)
- knowledge_obsidian: $(if "$SCRIPT_DIR/knowledge-obsidian.sh" --check &>/dev/null 2>&1; then echo "available"; else echo "unavailable"; fi)
- knowledge_notebooklm: $(if "$SCRIPT_DIR/knowledge-notebooklm.sh" --check &>/dev/null 2>&1; then echo "available"; else echo "unavailable"; fi)

## Search Budget

- budget: $(if [ "$MODE" = "high_quality" ]; then echo "15"; elif [ "$MODE" = "balanced" ]; then echo "8"; else echo "3"; fi)

## Required Agent Commands

- source_agent must call: $SCRIPT_DIR/search.sh "query" [--parallel] [--json]
- source_agent must call: $SCRIPT_DIR/knowledge-retrieval.sh "query" [--json]
EOF

cat > "$source_failure_log_file" <<EOF
# Source Failure Log

If source collection, web search, fetch, or source validation fails, append entries using the YAML schema defined in references/source-failure-log.md.

EOF

# If NO search API keys available, write source_failure_log entry
if [ -z "${BOCHA_API_KEY:-}" ] && [ -z "${EXA_API_KEY:-}" ] && [ -z "${BRAVE_API_KEY:-}" ]; then
  cat >> "$source_failure_log_file" <<EOF

## Failure Entry

\`\`\`yaml
source_failure_log:
  - failure_time: "$(date '+%Y-%m-%d %H:%M:%S')"
    failed_task: "外部搜索初始化"
    failed_source_type: "external_authoritative"
    failed_source_detail: "No search API keys configured (BOCHA_API_KEY/EXA_API_KEY/BRAVE_API_KEY)"
    failure_type: "web_search_failed"
    failure_stage: "Phase_2_资料搜索"
    affected_scope: "全文"
    affected_conclusions: "所有依赖外部搜索的结论"
    fallback_handling: "仅依赖本地资料和 AI 推理"
    fallback_source_level: "none"
    confidence_impact: "high"
    report_usability_marking: "离线初稿"
    audit_grade_cap: "CONDITIONAL_PASS"
    required_manual_sources:
      - 配置至少一个搜索 API key 后重新运行
    suggested_databases_or_keywords:
      - 手动搜索相关关键词并补充
\`\`\`
EOF
  echo "WARNING: No search API keys configured. external_search_available=false" >&2
fi

# Also check knowledge adapters and log if none available
if ! "$SCRIPT_DIR/knowledge-lark.sh" --check &>/dev/null 2>&1 && \
   ! "$SCRIPT_DIR/knowledge-obsidian.sh" --check &>/dev/null 2>&1 && \
   ! "$SCRIPT_DIR/knowledge-notebooklm.sh" --check &>/dev/null 2>&1; then
  cat >> "$source_failure_log_file" <<EOF

## Failure Entry

\`\`\`yaml
source_failure_log:
  - failure_time: "$(date '+%Y-%m-%d %H:%M:%S')"
    failed_task: "知识库检索初始化"
    failed_source_type: "local_vault"
    failed_source_detail: "No knowledge adapters available (lark/obsidian/notebooklm)"
    failure_type: "local_source_unavailable"
    failure_stage: "Phase_2_资料搜索"
    affected_scope: "内部资料相关章节"
    affected_conclusions: "依赖内部知识库的结论"
    fallback_handling: "仅依赖外部搜索和 AI 推理"
    fallback_source_level: "none"
    confidence_impact: "reduced"
    report_usability_marking: "内部初稿"
    audit_grade_cap: "CONDITIONAL_PASS"
    required_manual_sources:
      - 配置知识库适配器或手动补充内部资料
    suggested_databases_or_keywords:
      - 根据任务类型补充内部资料
\`\`\`
EOF
  echo "WARNING: No knowledge adapters configured. Local knowledge unavailable." >&2
fi

# Model mapping for summary and execution context
for agent in planner_agent source_agent long_context_agent analyst_agent scenario_agent writer_agent reviewer_agent; do
  if agent_enabled "$agent"; then
    requested_model="$( "$ROUTER" "$MODE" "$agent" )"
    echo "- $agent: requested_model=$requested_model; actual_model_detection_status=not_verified" >> "$summary_file"
    echo "- $agent: requested_model=$requested_model; actual_model_detection_status=not_verified" >> "$execution_context_file"
  fi
done

# ─── Execute stages ────────────────────────────────────────────────
run_stage "stage_1_planning" planner_agent
run_stage "stage_2_evidence_collection" source_agent long_context_agent
run_stage "stage_3_analysis_and_scenario" analyst_agent scenario_agent
run_stage "stage_4_writing" writer_agent
run_stage "stage_5_review" reviewer_agent

# ─── Finalize: generate final report file ─────────────────────────
finalize_report() {
  local writer_file="$OUTPUT_DIR/outputs/06-writer_agent.md"
  local final_dir="${DEEP_RESEARCH_OUTPUT_DIR:-$OUTPUT_DIR/final}"
  mkdir -p "$final_dir"

  if [ ! -f "$writer_file" ]; then
    echo "WARNING: writer_agent output not found, skipping final report generation." >&2
    write_event "run" "" "finalize_skipped" "" "not_verified" "Final report skipped (writer output not found)" ""
    return 0
  fi

  # Extract metadata from writer output or use task file summary as fallback
  local report_title research_topic report_type search_status source_types report_usability
  report_title=$(grep -i "^report_title:\|^# " "$writer_file" 2>/dev/null | head -1 | sed 's/^.*://; s/^# //; s/^ *//; s/ *$//' | head -c 80 || echo "")
  research_topic=$(head -1 "$TASK_FILE" 2>/dev/null | sed 's/^# *//; s/[\/:*?"<>|]//g; s/ *$//' | head -c 60 || echo "research")
  report_type=$(grep -i "report_type:\|任务类型:" "$writer_file" "$execution_context_file" 2>/dev/null | head -1 | sed 's/^.*://; s/^ *//; s/ *$//' | head -c 30 || echo "研究报告")
  search_status=$(grep -i "search_status:" "$writer_file" "$source_failure_log_file" 2>/dev/null | head -1 | sed 's/^.*://; s/^ *//; s/ *$//' | head -c 20 || echo "unknown")
  source_types=$(grep -i "source_types:\|来源使用情况:" "$writer_file" 2>/dev/null | head -1 | sed 's/^.*://; s/^ *//; s/ *$//' | head -c 40 || echo "")
  report_usability=$(grep -i "report_usability:\|报告可用性:" "$writer_file" 2>/dev/null | head -1 | sed 's/^.*://; s/^ *//; s/ *$//' | head -c 20 || echo "正式版")

  # Clean up research topic and report type
  if [ -z "$report_title" ] || [ "$report_title" = "标题" ]; then
    report_title="$research_topic"
  fi
  if [ -z "$research_topic" ] || [ "$research_topic" = "标题" ]; then
    research_topic="$report_title"
  fi

  # Build filename components
  local topic_clean type_clean source_tag deg_tag version_tag date_tag filename
  topic_clean=$(echo "$research_topic" | sed 's/[\/:*?"<>|]//g; s/  */ /g; s/^ *//; s/ *$//' | head -c 60)
  type_clean=$(echo "$report_type" | sed 's/[\/:*?"<>|]//g; s/  */ /g; s/^ *//; s/ *$//' | head -c 30)
  date_tag=$(date '+%Y-%m-%d')

  # Determine source composition tag
  source_tag=""
  if [ -n "$source_types" ]; then
    local has_external has_local has_model
    has_external=$(echo "$source_types" | grep -ci "external" || echo "0")
    has_local=$(echo "$source_types" | grep -ci "local\|vault\|wiki" || echo "0")
    has_model=$(echo "$source_types" | grep -ci "model_reasoning\|推理" || echo "0")
    if [ "$has_external" -gt 0 ] && [ "$has_local" -gt 0 ] && [ "$has_model" -gt 0 ]; then
      source_tag="-多源版"
    elif [ "$has_local" -gt 0 ] && [ "$has_model" -gt 0 ] && [ "$has_external" -eq 0 ]; then
      source_tag="-Vault版"
    elif [ "$has_model" -gt 0 ] && [ "$has_external" -eq 0 ] && [ "$has_local" -eq 0 ]; then
      source_tag="-模型推理版"
    fi
  fi

  # Determine degradation tag
  deg_tag=""
  if echo "$search_status" | grep -qi "failed\|no_results" 2>/dev/null; then
    deg_tag="-离线初稿"
  elif echo "$search_status" | grep -qi "partial_success" 2>/dev/null; then
    if echo "$report_usability" | grep -qi "内部初稿" 2>/dev/null; then
      deg_tag="-待联网核验版"
    else
      deg_tag="-离线初稿"
    fi
  fi

  # Check source_failure_log for real entries to decide degradation
  if [ -f "$source_failure_log_file" ]; then
    local failure_count
    failure_count=$(grep -c "failure_time:" "$source_failure_log_file" 2>/dev/null || true)
    failure_count="${failure_count:-0}"
    failure_count=$(echo "$failure_count" | tr -cd '0-9' | head -c 10)
    if [ "${failure_count:-0}" -gt 0 ] && [ -z "$deg_tag" ]; then
      deg_tag="-待联网核验版"
    fi
  fi

  # Build final filename: 研究主题-报告类型[-来源类型][-离线初稿|-待联网核验版][-v2]-YYYY-MM-DD.md
  local base_name
  base_name="${topic_clean}-${type_clean}${source_tag}${deg_tag}"

  # Check for version conflict
  version_tag=""
  filename="${base_name}-${date_tag}.md"
  if [ -f "$final_dir/$filename" ]; then
    local v=2
    while [ -f "${final_dir}/${base_name}-v${v}-${date_tag}.md" ]; do
      v=$((v + 1))
    done
    version_tag="-v${v}"
    filename="${base_name}${version_tag}-${date_tag}.md"
  fi

  # Read writer_agent body (skip first H1 line if present, we write our own)
  local writer_body=""
  if [ -f "$writer_file" ]; then
    writer_body=$(awk 'NR==1 && /^# / {next} {print}' "$writer_file" 2>/dev/null || cat "$writer_file")
  fi

  # Build the final report — write to final_dir, NOT CWD
  {
    echo "# ${topic_clean}：${type_clean}"
    echo ""
    if [ -n "$deg_tag" ]; then
      echo "---"
      echo "⚠️ 本报告为${deg_tag#-} / 待联网核验版"
      echo "搜索状态: ${search_status:-unknown}"
      echo "报告可用性: ${report_usability:-内部初稿}"
      echo "版次说明: 本稿基于当前可用的 (本地资料 / 部分外部资料 / AI 推理) 生成，部分核心数据未得到权威来源核验。"
      echo "---"
      echo ""
    fi
    # Include the full writer_agent report body (actual research content)
    if [ -n "$writer_body" ]; then
      echo "$writer_body"
      echo ""
    else
      echo "（writer_agent 输出为空，无法生成完整报告）"
      echo ""
    fi
    # Append metadata footer
    echo "---"
    echo ""
    echo "## 报告信息"
    echo ""
    echo "- 生成日期: $(date '+%Y-%m-%d')"
    echo "- 运行模式: $MODE"
    echo "- 搜索状态: ${search_status:-unknown}"
    echo "- 报告可用性: ${report_usability:-正式版}"
    echo "- 来源类型: ${source_types:-未分类}"
    if [ -n "$deg_tag" ]; then
      echo "- 降级标记: ${deg_tag#-}"
    fi
    if [ -f "$source_failure_log_file" ]; then
      local fc
      fc=$(grep -c "failure_time:" "$source_failure_log_file" 2>/dev/null || true)
      fc="${fc:-0}"
      fc=$(echo "$fc" | tr -cd '0-9')
      echo "- source_failure_log: ${fc} entries"
    fi
    echo ""
    if [ -n "$deg_tag" ]; then
      echo "## 联网核验恢复清单"
      echo ""
      echo "本次研究存在以下来源缺口，联网核验版生成前需补充："
      echo ""
      echo "| 序号 | 研究维度 | 缺失来源类型 | 核验优先级 |"
      echo "|------|---------|-------------|-----------|"
      echo "| 1 | 全部 | 待从 writer_agent 输出中提取 | 高 |"
      echo ""
    fi
  } > "$final_dir/$filename" 2>/dev/null

  write_event "run" "" "finalized" "" "not_verified" "Final report: $final_dir/$filename" ""
  echo "Final report: $final_dir/$filename"
}

finalize_report

# ─── Finalize artifacts ────────────────────────────────────────────
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
- events_log: $events_file
- reporting_rule: Requested model routes must not be described as verified actual model usage.
EOF

write_event "run" "" "completed" "" "not_verified" "Deep Research run completed (generic runner)" ""

cat >> "$summary_file" <<EOF

## Events

Events were written to: $events_file
Total events: $(wc -l < "$events_file" 2>/dev/null || echo "0")
EOF

echo ""
echo "Deep Research generic run complete."
echo "Summary: $summary_file"
echo "Events: $events_file"
echo "Outputs: $OUTPUT_DIR/outputs"
echo ""
echo "Artifacts produced:"
echo "  - run-summary.md: $( [ -f "$summary_file" ] && echo 'yes' || echo 'MISSING' )"
echo "  - execution-context.md: $( [ -f "$execution_context_file" ] && echo 'yes' || echo 'MISSING' )"
echo "  - source_failure_log.md: $( [ -f "$source_failure_log_file" ] && echo 'yes' || echo 'MISSING' )"
echo "  - events.ndjson: $( [ -f "$events_file" ] && echo 'yes' || echo 'MISSING' )"
