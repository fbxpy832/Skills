#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
BASE="$ROOT/.codex-opencode"
STATUS="$BASE/status"
LOGS="$BASE/logs"
PROMPTS="$BASE/prompts"
REPORTS="$BASE/reports"
RUNS="$BASE/runs"
CONFIG="$BASE/config.json"
mkdir -p "$STATUS" "$LOGS" "$PROMPTS" "$REPORTS" "$RUNS"

TASK=""
TASK_FILE=""
MAX_ROUNDS=""
TEST_COMMAND=""
DRY_RUN=0
OMA_MODE=""

usage() {
  cat <<'EOF'
Usage:
  bash .codex-opencode/scripts/codex-opencode-autoloop.sh --task "request"
  bash .codex-opencode/scripts/codex-opencode-autoloop.sh --task-file .codex-opencode/task.md
  bash .codex-opencode/scripts/codex-opencode-autoloop.sh --task "request" --max-rounds 5 --test "npm test"
  bash .codex-opencode/scripts/codex-opencode-autoloop.sh --task "request" --dry-run
  bash .codex-opencode/scripts/codex-opencode-autoloop.sh --task "request" --oma-mode auto|forced_oma|plain_opencode|manual_agent
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --task) TASK="${2:-}"; shift 2 ;;
    --task-file) TASK_FILE="${2:-}"; shift 2 ;;
    --max-rounds) MAX_ROUNDS="${2:-}"; shift 2 ;;
    --test) TEST_COMMAND="${2:-}"; shift 2 ;;
    --dry-run) DRY_RUN=1; shift ;;
    --oma-mode) OMA_MODE="${2:-}"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; usage; exit 1 ;;
  esac
done

cd "$ROOT"
if [[ -n "$TASK_FILE" ]]; then
  [[ -f "$TASK_FILE" ]] || { echo "Task file not found: $TASK_FILE" >&2; exit 1; }
  TASK="$(cat "$TASK_FILE")"
fi
[[ -n "$TASK" ]] || { echo "A task is required. Use --task or --task-file." >&2; exit 1; }

json_get() {
  local expr="$1" default="$2"
  python3 - "$CONFIG" "$expr" "$default" <<'PY'
import json, sys
path, expr, default = sys.argv[1:]
try:
    data=json.load(open(path))
    cur=data
    for part in expr.split("."):
        if isinstance(cur, dict): cur=cur.get(part)
        else: cur=None
    if cur is None or cur == "": print(default)
    elif isinstance(cur, bool): print("true" if cur else "false")
    elif isinstance(cur, list): print("\n".join(map(str, cur)))
    else: print(cur)
except Exception:
    print(default)
PY
}

OPENCODE_COMMAND="$(json_get opencode_command opencode)"
OPENCODE_ARGS=()
while IFS= read -r arg; do
  [[ -n "$arg" ]] && OPENCODE_ARGS+=("$arg")
done < <(json_get opencode_run_args run)
[[ -n "$MAX_ROUNDS" ]] || MAX_ROUNDS="$(json_get max_rounds 5)"
[[ -n "$TEST_COMMAND" ]] || TEST_COMMAND="$(json_get test_command "")"
[[ -n "$OMA_MODE" ]] || OMA_MODE="$(json_get oma.mode auto)"
FALLBACK="$(json_get oma.fallback_to_plain_opencode true)"
EXPECTED_PLAN="$(json_get oma.expected_plan opencode_go)"

RUN_ID="$(date '+%Y%m%d-%H%M%S')"
RUN_DIR="$RUNS/$RUN_ID"
mkdir -p "$RUN_DIR"
ORCH_LOG="$LOGS/orchestrator.log"
OPENCODE_LOG="$LOGS/opencode.log"
CODEX_REVIEW_LOG="$LOGS/codex-review.log"
TEST_LOG="$LOGS/test.log"
OMA_LOG="$LOGS/oma.log"

sanitize() {
  sed -E \
    -e 's/\x1B\[[0-9;?]*[ -\/]*[@-~]//g' \
    -e 's/sk-[A-Za-z0-9_-]{12,}/sk-REDACTED/g' \
    -e 's/ghp_[A-Za-z0-9_]{12,}/ghp_REDACTED/g' \
    -e 's/(Bearer[[:space:]]+)[A-Za-z0-9._~+\/=-]{10,}/\1REDACTED/Ig' \
    -e 's/AKIA[0-9A-Z]{12,}/AKIAREDACTED/g' \
    -e 's/(password=)[^[:space:]&]+/\1REDACTED/Ig' \
    -e 's/(token=)[^[:space:]&]+/\1REDACTED/Ig' \
    -e 's/(cookie=)[^[:space:]&]+/\1REDACTED/Ig'
}

run_limited() {
  local seconds="$1"; shift
  if command -v timeout >/dev/null 2>&1; then
    timeout "$seconds" "$@"
  else
    perl -e 'alarm shift; exec @ARGV' "$seconds" "$@"
  fi
}

short_task() { printf '%s' "$TASK" | tr '\n' ' ' | cut -c 1-240; }

update_state() {
  local status="$1" round="$2" phase="$3" result="$4" next="$5" error="${6:-None}" agent="${7:-unknown}" test_status="${8:-unknown}" review_status="${9:-unknown}" security_status="${10:-unknown}"
  local now
  now="$(date '+%Y-%m-%d %H:%M:%S')"
  cat > "$STATUS/live.md" <<EOF
# Codex ↔ OpenCode / OMA AutoLoop Live Status

Current status: $status
Current round: $round / $MAX_ROUNDS
Current phase: $phase
Last update: $now

Task summary:
$(short_task)

OMA status: $OMA_AVAILABLE
OMA mode: $OMA_MODE
Current OMA agent: $agent
Current model: unknown
OpenCode plan: $EXPECTED_PLAN
Fallback mode: $FALLBACK

Latest result:
$result

Next action:
$next

Last error:
$error
EOF
  python3 - "$STATUS/state.json" "$status" "$round" "$MAX_ROUNDS" "$phase" "$TASK" "$now" "$error" "$test_status" "$review_status" "$security_status" "$RUN_DIR" "$OMA_AVAILABLE" "$OMA_MODE" "$agent" "$EXPECTED_PLAN" "$FALLBACK" <<'PY'
import json, sys
path,status,round_,max_rounds,phase,task,now,error,test,review,security,run_dir,oma_available,mode,agent,plan,fallback=sys.argv[1:]
try: data=json.load(open(path))
except Exception: data={}
data.update(status=status, round=int(round_), max_rounds=int(max_rounds), phase=phase, task=task,
            last_update=now, last_error=None if error=="None" else error, test_status=test,
            review_status=review, security_status=security, run_dir=run_dir)
data.setdefault("oma", {})
data["oma"].update(available=(True if oma_available=="available" else False if oma_available=="unavailable" else None),
                   mode=mode, current_agent=agent, current_model="unknown", expected_plan=plan,
                   fallback_to_plain_opencode=(fallback=="true"))
json.dump(data, open(path,"w"), indent=2, ensure_ascii=False)
PY
}

finish_report() {
  local result="$1" rounds="$2" remaining="$3" next_cmd="$4"
  local diffstat
  diffstat="$(git diff --stat 2>/dev/null | sanitize || true)"
  local files
  files="$(git diff --name-only 2>/dev/null | sanitize || true)"
  cat > "$REPORTS/final-report.md" <<EOF
# Codex ↔ OpenCode / OMA AutoLoop Final Report

## Task
$TASK

## Result
$result

## Rounds
$rounds

## OMA Status
$OMA_AVAILABLE

## OpenCode Status
$OPENCODE_AVAILABLE

## Model / Agent Summary
See .codex-opencode/reports/oma-model-audit.md and .codex-opencode/status/oma-preflight.md.

## Changes
${files:-No changed files detected.}

## Test Summary
Command: ${TEST_COMMAND:-not detected}

Latest status is in .codex-opencode/logs/test.log and the latest run directory.

## Security Summary
See .codex-opencode/logs/security.log.

## Codex Review Summary
See .codex-opencode/logs/codex-review.log and $RUN_DIR/codex-review-round-*.md.

## Final Diff Summary
\`\`\`
${diffstat:-No diff.}
\`\`\`

## Remaining Issues
$remaining

## User Action Needed
Review the files above if the result is failed or needs_user_action.

## Next Suggested Command
$next_cmd
EOF
}

run_opencode() {
  local prompt_file="$1" output_file="$2"
  if [[ "$DRY_RUN" -eq 1 ]]; then
    {
      echo "DRY RUN: would invoke $OPENCODE_COMMAND ${OPENCODE_ARGS[*]}"
      echo
      cat "$prompt_file"
    } | sanitize > "$output_file"
    return 0
  fi
  if ! command -v "$OPENCODE_COMMAND" >/dev/null 2>&1; then
    echo "OpenCode command not found: $OPENCODE_COMMAND" > "$output_file"
    return 127
  fi
  set +e
  run_limited 1800 "$OPENCODE_COMMAND" "${OPENCODE_ARGS[@]}" < "$prompt_file" > "$output_file.tmp" 2>&1
  local rc=$?
  if [[ "$rc" -ne 0 ]]; then
    run_limited 1800 "$OPENCODE_COMMAND" "${OPENCODE_ARGS[@]}" "$(cat "$prompt_file")" > "$output_file.tmp" 2>&1
    rc=$?
  fi
  set -e
  sanitize < "$output_file.tmp" > "$output_file"
  cat "$output_file" >> "$OPENCODE_LOG"
  rm -f "$output_file.tmp"
  return "$rc"
}

detect_oma() {
  if [[ -f "$STATUS/oma-preflight.json" ]]; then
    python3 - "$STATUS/oma-preflight.json" <<'PY'
import json, sys
try:
    d=json.load(open(sys.argv[1]))
    print("available" if d.get("oma_available") else "unknown")
except Exception:
    print("unknown")
PY
  else
    echo "unknown"
  fi
}

OPENCODE_AVAILABLE="unavailable"
command -v "$OPENCODE_COMMAND" >/dev/null 2>&1 && OPENCODE_AVAILABLE="available"
OMA_AVAILABLE="$(detect_oma)"

case "$OMA_MODE" in
  auto|forced_oma|plain_opencode|manual_agent) ;;
  *) echo "Invalid --oma-mode: $OMA_MODE" >&2; exit 1 ;;
esac
if [[ "$OMA_MODE" == "forced_oma" && "$OMA_AVAILABLE" != "available" ]]; then
  update_state failed 0 preflight "OMA is required but not available." "Run preflight and fix OMA/OpenCode configuration." "forced_oma requested but OMA unavailable"
  finish_report failed 0 "OMA unavailable and forced_oma disallows fallback." "bash .codex-opencode/scripts/codex-opencode-preflight.sh"
  exit 2
fi
if [[ "$OMA_MODE" == "auto" && "$OMA_AVAILABLE" != "available" && "$FALLBACK" != "true" ]]; then
  update_state failed 0 preflight "OMA unavailable and fallback is disabled." "Enable fallback or fix OMA." "OMA unavailable"
  finish_report failed 0 "OMA unavailable and fallback disabled." "Edit .codex-opencode/config.json or rerun preflight."
  exit 2
fi
if [[ "$OPENCODE_AVAILABLE" != "available" && "$DRY_RUN" -ne 1 ]]; then
  update_state failed 0 preflight "OpenCode command is unavailable." "Install/expose opencode in PATH." "opencode not found"
  finish_report failed 0 "OpenCode CLI not found." "bash .codex-opencode/scripts/codex-opencode-preflight.sh"
  exit 127
fi

printf '%s\n' "$TASK" > "$RUN_DIR/task.md"
{
  echo "# Initial Context"
  echo
  echo "Project: $ROOT"
  echo "Run: $RUN_ID"
  echo "OMA mode: $OMA_MODE"
  echo "OMA available: $OMA_AVAILABLE"
  echo "OpenCode available: $OPENCODE_AVAILABLE"
  echo
  echo "## Git Status"
  echo '```'
  git status --short 2>/dev/null | sanitize || true
  echo '```'
} > "$RUN_DIR/initial-context.md"

if [[ -z "$TEST_COMMAND" ]]; then
  TEST_COMMAND="$(bash "$BASE/scripts/codex-opencode-detect-tests.sh" | tail -n 1 || true)"
fi

: > "$ORCH_LOG"; : > "$OPENCODE_LOG"; : > "$CODEX_REVIEW_LOG"; : > "$OMA_LOG"
update_state running 0 planning "Autoloop initialized." "Starting round 1." None unknown unknown unknown unknown

final_result="failed"
rounds_done=0
remaining="Max rounds reached or review failed."

for round in $(seq 1 "$MAX_ROUNDS"); do
  rounds_done="$round"
  update_state running "$round" planning "Creating round plan." "Calling OpenCode/OMA planner." None planner unknown unknown unknown
  plan_file="$RUN_DIR/plan-round-$round.md"
  prompt_file="$RUN_DIR/opencode-round-$round.prompt.md"
  output_file="$RUN_DIR/opencode-round-$round.output.md"
  repair_file="$RUN_DIR/repair-round-$round.prompt.md"
  review_file="$RUN_DIR/codex-review-round-$round.md"
  diff_file="$RUN_DIR/diff-round-$round.patch"
  test_file="$RUN_DIR/test-round-$round.log"
  security_file="$RUN_DIR/security-round-$round.log"

  cat > "$plan_file" <<EOF
# Plan Round $round

Task:
$TASK

Mode:
$OMA_MODE

Guidance:
- Keep changes minimal and inside project scope.
- Do not modify secrets, tokens, cookies, .env files, SSH keys, certificates, or system configuration.
- Do not install dependencies unless explicitly allowed by .codex-opencode/config.json.
- Do not claim tests passed unless they actually ran.
EOF

  if [[ "$round" -eq 1 ]]; then
    cat "$PROMPTS/oma-coder-prompt.md" "$RUN_DIR/task.md" "$plan_file" > "$prompt_file"
  else
    cat "$PROMPTS/repair-prompt.md" "$RUN_DIR/task.md" "$repair_file" > "$prompt_file"
  fi
  {
    echo
    echo "## Runtime Instructions"
    echo "OMA mode: $OMA_MODE"
    echo "If CLI agent selection is not supported, role selection is prompt-based, not CLI-enforced."
    echo "Write a concise summary, changed files, tests run, and risks."
  } >> "$prompt_file"

  update_state running "$round" opencode_developing "OpenCode/OMA is working." "Waiting for worker output." None coder unknown unknown unknown
  if ! run_opencode "$prompt_file" "$output_file"; then
    update_state failed "$round" opencode_developing "OpenCode failed." "Review output and fix CLI/auth/model issue." "OpenCode invocation failed" coder unknown failed unknown
    finish_report failed "$round" "OpenCode failed. See $output_file." "bash .codex-opencode/scripts/codex-opencode-preflight.sh"
    exit 3
  fi
  cp "$output_file" "$RUN_DIR/oma-coder-round-$round.output.md"

  update_state running "$round" testing "Running local tests." "Collecting test results." None tester unknown unknown unknown
  if [[ -n "$TEST_COMMAND" ]]; then
    set +e
    bash -lc "$TEST_COMMAND" > "$test_file.tmp" 2>&1
    test_rc=$?
    set -e
    sanitize < "$test_file.tmp" > "$test_file"
    cat "$test_file" > "$TEST_LOG"
    rm -f "$test_file.tmp"
    if [[ "$test_rc" -eq 0 ]]; then test_status="passed"; else test_status="failed"; fi
  else
    test_status="skipped"
    echo "No test command detected. Verification is insufficient and must not be reported as passed." > "$test_file"
    cp "$test_file" "$TEST_LOG"
  fi
  cp "$test_file" "$RUN_DIR/oma-tester-round-$round.output.md"

  update_state running "$round" security_check "Running security check." "Reviewing diff and logs." None reviewer "$test_status" unknown unknown
  set +e
  ROUND="$round" MAX_ROUNDS="$MAX_ROUNDS" TASK_SUMMARY="$(short_task)" OMA_MODE="$OMA_MODE" bash "$BASE/scripts/codex-opencode-security-check.sh" > "$security_file" 2>&1
  sec_rc=$?
  set -e
  cat "$security_file" >> "$LOGS/security.log"
  if [[ "$sec_rc" -ne 0 ]]; then
    finish_report needs_user_action "$round" "Security check requires user action." "Review .codex-opencode/logs/security.log"
    exit 4
  fi
  security_status="passed"

  git diff -- . ':(exclude).codex-opencode/*' > "$diff_file" 2>/dev/null || true

  update_state running "$round" codex_reviewing "Codex review is evaluating evidence." "Preparing pass/fail decision." None reviewer "$test_status" unknown "$security_status"
  diff_empty=0
  [[ ! -s "$diff_file" ]] && diff_empty=1
  result="PASS"
  problems=""
  required=""
  if [[ "$test_status" == "failed" ]]; then
    result="FAIL"; problems+="Tests failed. "; required+="Fix failing tests and rerun. "
  fi
  if [[ "$diff_empty" -eq 1 && "$DRY_RUN" -ne 1 ]]; then
    result="FAIL"; problems+="No project diff detected. "; required+="Make the requested code changes or explain why none are needed. "
  fi
  if [[ "$test_status" == "skipped" ]]; then
    problems+="No test command was detected; verification is insufficient. "
  fi

  cat > "$review_file" <<EOF
# Codex Review Round $round

Result: $result

## Requirement Match
Best-effort automated review based on worker output, diff, and logs. Codex final human-grade review should inspect this file before trusting high-risk changes.

## Test Result
$test_status

## Security Result
$security_status

## Diff Review
\`\`\`
$(git diff --stat 2>/dev/null | sanitize || true)
\`\`\`

## Problems Found
${problems:-No blocking problem detected by automated checks.}

## Required Fixes
${required:-None.}

## Suggested Fixes
Keep changes scoped and add targeted tests when possible.

## Repair Prompt
Fix only these issues: ${required:-No repair required.}
EOF
  cat "$review_file" >> "$CODEX_REVIEW_LOG"
  cp "$review_file" "$RUN_DIR/oma-reviewer-round-$round.output.md"

  if [[ "$result" == "PASS" ]]; then
    final_result="completed"
    remaining="$([[ "$test_status" == "skipped" ]] && echo 'Functional result accepted with verification limitation: no automated test command was detected.' || echo 'No remaining blocking issue detected.')"
    update_state completed "$round" completed "Review passed." "Inspect final report." None reviewer "$test_status" PASS "$security_status"
    finish_report "$final_result" "$round" "$remaining" "bash .codex-opencode/scripts/codex-opencode-status.sh"
    echo "Autoloop completed. See $REPORTS/final-report.md"
    exit 0
  fi

  cat > "$repair_file" <<EOF
# Repair Prompt Round $round

Codex Review failed.

Required fixes:
$required

Problems:
$problems

Use the existing diff and test log:
- $diff_file
- $test_file

Only fix the required issues. Do not expand scope.
EOF
  update_state running "$round" repairing "Review failed; repair prompt prepared." "Starting next round if available." None repair "$test_status" FAIL "$security_status"
done

update_state failed "$rounds_done" completed "Max rounds reached without PASS." "Inspect final report and latest repair prompt." "max rounds reached" reviewer unknown FAIL unknown
finish_report failed "$rounds_done" "$remaining" "Inspect $RUN_DIR/repair-round-$rounds_done.prompt.md and rerun autoloop."
exit 5
