#!/usr/bin/env bash
# hermes-dev-skill/tests/manual/smoke.sh
# End-to-end smoke test. Runs against a real project (passed as $1) and
# asserts the state machine, CLI, and basic plumbing work. Does NOT call
# real Codex / Claude Code (those require the user to be present for
# model invocation).
#
# Usage: bash tests/manual/smoke.sh <project_path>
set -euo pipefail

PROJECT="${1:-}"
if [ -z "$PROJECT" ]; then
    echo "usage: $0 <project_path>" >&2
    exit 1
fi
if [ ! -d "$PROJECT" ]; then
    echo "project $PROJECT does not exist" >&2
    exit 1
fi

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
export PYTHONPATH="$REPO_ROOT:${PYTHONPATH:-}"
export HOME=$(mktemp -d)
mkdir -p "$HOME/.hermes"

PASS=0
FAIL=0
check() {
    local desc="$1"
    local result="$2"
    if [ "$result" = "0" ]; then
        echo "  PASS: $desc"
        PASS=$((PASS+1))
    else
        echo "  FAIL: $desc"
        FAIL=$((FAIL+1))
    fi
}

echo "=== hermes-dev-skill smoke test ==="
echo "Project: $PROJECT"
echo "Isolated HOME: $HOME"
echo ""

# 1. CLI works
hermes-dev --help >/dev/null
check "hermes-dev --help exits 0" $?

# 2. Register the project
hermes-dev register smoke "$PROJECT" >/dev/null
check "register smoke" $?

# 3. Create a job
JOB_ID=$(hermes-dev new "smoke test job")
check "new returns a job_id" $?

# 4. Set project state
python -m scripts.lib.state atomic_update \
    "$HOME/.hermes/runs/$JOB_ID/state.json" \
    "{\"project\": {\"name\": \"smoke\", \"path\": \"$PROJECT\", \"branch\": \"hermes-dev/$JOB_ID\", \"base_branch\": \"main\", \"is_git\": True}}"
check "set project in state" $?

# 5. Status reports the project
STATUS_OUT=$(hermes-dev status "$JOB_ID")
echo "$STATUS_OUT" | grep -q "smoke"
check "status shows project" $?

# 6. List shows the job
LIST_OUT=$(hermes-dev list)
echo "$LIST_OUT" | grep -q "1 job"
check "list shows 1 job" $?

# 7. Cancel
hermes-dev cancel "$JOB_ID" >/dev/null
check "cancel succeeds" $?
STATUS=$(python -m scripts.lib.state get "$HOME/.hermes/runs/$JOB_ID/state.json" status)
[ "$STATUS" = "halted" ]
check "status is halted" $?

# 8. Unregister
hermes-dev unregister smoke >/dev/null
check "unregister succeeds" $?

echo ""
echo "=== Result: $PASS passed, $FAIL failed ==="
[ "$FAIL" = "0" ]
