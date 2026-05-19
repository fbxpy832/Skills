#!/usr/bin/env bash
set -euo pipefail

# ============================================================================
# run-eval.sh — Deep Research Skill Eval Harness
# ============================================================================
# Validates that runner artifacts exist and contain the required model/source/
# search/audit fields per the host adapter contract.
#
# Usage:
#   run-eval.sh [--dry-run] [--runner generic|opencode] [--task all|business_decision|...]
#
# In dry-run mode, this script validates that the runner CAN produce artifacts
# without executing live agents. It runs the specified runner in --dry-run mode
# and checks all required artifact files.
# ============================================================================

DRY_RUN="${DRY_RUN:-0}"
RUNNER="${DEEP_RESEARCH_EVAL_RUNNER:-generic}"
TASK_SELECT="${DEEP_RESEARCH_EVAL_TASK:-all}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) DRY_RUN="1"; shift ;;
    --runner)
      if [ $# -lt 2 ] || { [ "$2" != "generic" ] && [ "$2" != "opencode" ]; }; then
        echo "Usage: run-eval.sh [--dry-run] [--runner generic|opencode] [task]" >&2
        echo "Valid runners: generic, opencode" >&2
        exit 2
      fi
      RUNNER="$2"; shift 2 ;;
    generic|opencode) RUNNER="$1"; shift ;;
    all|business_decision|government_report|technical_route|investment_analysis|general_research)
      TASK_SELECT="$1"; shift ;;
    *) shift ;;
  esac
done

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
SCRIPTS_DIR="$SKILL_DIR/scripts"
EVAL_DIR="$SCRIPT_DIR"
TEMP_DIR="${DEEP_RESEARCH_EVAL_TEMP:-/tmp/deep-research-eval-$$}"
# If user supplied a custom temp dir, create a run-specific subdir inside it
if [ -n "${DEEP_RESEARCH_EVAL_TEMP:-}" ]; then
  TEMP_DIR="${DEEP_RESEARCH_EVAL_TEMP}/eval-run-$$"
fi
REPO_ROOT="${DEEP_RESEARCH_EVAL_REPO_ROOT:-$(cd "$SKILL_DIR/.." && pwd)}"

PASSED=0
FAILED=0
TOTAL=0

cleanup() {
  case "$TEMP_DIR" in
    /tmp/deep-research-eval-*|*/deep-research-eval-*|*/eval-run-*)
      rm -rf "$TEMP_DIR" 2>/dev/null || true ;;
    *) echo "Refusing to clean up non-eval temp dir: $TEMP_DIR" >&2 ;;
  esac
}
trap cleanup EXIT

mkdir -p "$TEMP_DIR"

echo "=== Deep Research Eval Harness ==="
echo "Runner: $RUNNER"
echo "Task: $TASK_SELECT"
echo "Dry run: $DRY_RUN"
echo "Temp: $TEMP_DIR"
echo ""

check_artifact() {
  local file="$1"
  local label="$2"
  if [ -f "$file" ]; then
    echo "  [PASS] $label: $file"
    return 0
  else
    echo "  [FAIL] $label: MISSING ($file)"
    return 1
  fi
}

check_dir() {
  local dir="$1"
  local label="$2"
  if [ -d "$dir" ] && [ "$(ls -A "$dir" 2>/dev/null)" ]; then
    echo "  [PASS] $label: $dir (has files)"
    return 0
  else
    echo "  [FAIL] $label: MISSING or EMPTY ($dir)"
    return 1
  fi
}

check_content() {
  local file="$1"
  local pattern="$2"
  local label="$3"
  if [ -f "$file" ] && grep -q "$pattern" "$file" 2>/dev/null; then
    echo "  [PASS] $label: found '$pattern' in $file"
    return 0
  else
    echo "  [FAIL] $label: '$pattern' NOT found in $file"
    return 1
  fi
}

run_eval_for_task() {
  local task_file="$1"
  local task_name
  task_name="$(basename "$task_file" .yaml)"

  echo ""
  echo "--- Evaluating: $task_name ---"
  TOTAL=$((TOTAL + 1))

  # Create task markdown from YAML
  local task_md="$TEMP_DIR/${task_name}-task.md"
  local title
  title=$(grep '^title:' "$task_file" | sed 's/^title: *//' | tr -d '"')
  local desc
  desc=$(grep '^description:' "$task_file" | sed 's/^description: *//')
  local mode
  mode=$(grep '^mode:' "$task_file" | sed 's/^mode: *//')

  cat > "$task_md" <<EOF
# $title

$desc

Task type: $task_name
Requested mode: $mode
EOF

  local output_dir="$TEMP_DIR/outputs/$task_name"
  local exit_code=0

  # Run the appropriate runner in dry-run mode
  local runner_script
  if [ "$RUNNER" = "opencode" ]; then
    runner_script="$SCRIPTS_DIR/opencode-research-runner.sh"
  else
    runner_script="$SCRIPTS_DIR/generic-research-runner.sh"
  fi

  if [ ! -x "$runner_script" ]; then
    echo "  [FAIL] Runner not executable: $runner_script"
    FAILED=$((FAILED + 1))
    return 1
  fi

  echo "  Running: $runner_script $mode $task_md $output_dir $REPO_ROOT --dry-run --sequential"
  if ! "$runner_script" "$mode" "$task_md" "$output_dir" "$REPO_ROOT" --dry-run --sequential > "$TEMP_DIR/${task_name}-stdout.log" 2>&1; then
    echo "  [FAIL] Runner exited with error (exit code: $?)"
    cat "$TEMP_DIR/${task_name}-stdout.log"
    FAILED=$((FAILED + 1))
    return 1
  fi

  local task_passed=1

  # Check required artifacts
  check_artifact "$output_dir/run-summary.md" "run-summary.md" || task_passed=0
  check_artifact "$output_dir/execution-context.md" "execution-context.md" || task_passed=0
  check_artifact "$output_dir/source_failure_log.md" "source_failure_log.md" || task_passed=0
  check_artifact "$output_dir/events.ndjson" "events.ndjson" || task_passed=0
  check_dir "$output_dir/prompts" "prompts/" || task_passed=0
  check_dir "$output_dir/outputs" "outputs/" || task_passed=0
  check_dir "$output_dir/logs" "logs/" || task_passed=0

  # Check events.ndjson content
  if [ -f "$output_dir/events.ndjson" ]; then
    check_content "$output_dir/events.ndjson" "phase.*run.*status.*started" "events: run started" || task_passed=0
    check_content "$output_dir/events.ndjson" "phase.*run.*status.*completed" "events: run completed" || task_passed=0

    # Validate each line is valid JSON
    local json_valid=1
    while IFS= read -r line; do
      if ! echo "$line" | python3 -c "import json,sys; json.loads(sys.stdin.read())" 2>/dev/null; then
        json_valid=0
      fi
    done < "$output_dir/events.ndjson"
    if [ "$json_valid" = "1" ]; then
      echo "  [PASS] events: all lines are valid JSON"
    else
      echo "  [FAIL] events: some lines are NOT valid JSON"
      task_passed=0
    fi
  fi

  # Check run-summary.md content
  if [ -f "$output_dir/run-summary.md" ]; then
    check_content "$output_dir/run-summary.md" "requested_model" "summary: has model mapping" || task_passed=0
    check_content "$output_dir/run-summary.md" "actual_model_detection_status" "summary: has detection status" || task_passed=0
  fi

  # Check execution-context.md content
  if [ -f "$output_dir/execution-context.md" ]; then
    check_content "$output_dir/execution-context.md" "actual_model_detection_status" "context: has detection status" || task_passed=0
    check_content "$output_dir/execution-context.md" "model_route_execution_status" "context: has route status" || task_passed=0
  fi

  # Report result
  if [ "$task_passed" = "1" ]; then
    echo ""
    echo "  Result: PASS"
    PASSED=$((PASSED + 1))
  else
    echo ""
    echo "  Result: FAIL"
    FAILED=$((FAILED + 1))
  fi
}

# Determine which tasks to run
if [ "$TASK_SELECT" = "all" ]; then
  TASKS=("$EVAL_DIR"/*.yaml)
else
  TASKS=("$EVAL_DIR/${TASK_SELECT}.yaml")
fi

for task_file in "${TASKS[@]}"; do
  if [ -f "$task_file" ] && [ "$(basename "$task_file")" != "rubric.yaml" ]; then
    run_eval_for_task "$task_file"
  fi
done

# Summary
echo ""
echo "========================================"
echo "Eval Summary"
echo "========================================"
echo "Tasks evaluated: $TOTAL"
echo "Passed: $PASSED"
echo "Failed: $FAILED"
echo ""

if [ "$FAILED" -gt 0 ]; then
  echo "RESULT: SOME TASKS FAILED"
  exit 1
else
  echo "RESULT: ALL TASKS PASSED"
  exit 0
fi
