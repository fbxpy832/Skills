#!/usr/bin/env bash
# Tests for handlers/on_continue.sh. Runs against a fake HOME and a
# temporary HERMES_DEV_SKILL_DIR copy so the real skill files are
# never overwritten.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

# Set up isolated HOME
export HOME=$(mktemp -d)
mkdir -p "$HOME/.hermes"

# Set up a temp copy of the skill so we can stub 04_review.sh
TEST_SKILL="$(mktemp -d)"
mkdir -p "$TEST_SKILL/scripts/phases" "$TEST_SKILL/scripts/lib" "$TEST_SKILL/scripts/handlers"
cp "$REPO_ROOT/scripts/lib/state.py" "$TEST_SKILL/scripts/lib/"
cp "$REPO_ROOT/scripts/lib/feishu.py" "$TEST_SKILL/scripts/lib/"
cp "$REPO_ROOT/scripts/handlers/on_continue.sh" "$TEST_SKILL/scripts/handlers/"
cat > "$TEST_SKILL/scripts/phases/04_review.sh" <<'EOF'
#!/usr/bin/env bash
echo "[stub] 04_review $1"
exit 0
EOF
chmod +x "$TEST_SKILL/scripts/phases/04_review.sh"

# Create a job
JOB_ID="20260101-1200-abc123"
RUNS_DIR="$HOME/.hermes/runs/$JOB_ID"
mkdir -p "$RUNS_DIR"

PYTHONPATH="$REPO_ROOT:$TEST_SKILL:$TEST_SKILL" python -m scripts.lib.state write "$RUNS_DIR" '{
  "job_id": "'$JOB_ID'",
  "status": "halted",
  "phase": "review",
  "phase_round": 5,
  "user_overrides": {"max_review_rounds": 5, "extra_review_rounds_added": 0}
}'

# Stub hermes send on PATH
TEST_BIN="$(mktemp -d)"
cat > "$TEST_BIN/hermes" <<'EOF'
#!/usr/bin/env bash
echo "message_id: om_test"
EOF
chmod +x "$TEST_BIN/hermes"

# Run the handler with the temp skill dir
export PATH="$TEST_BIN:$PATH"
export HERMES_DEV_SKILL_DIR="$TEST_SKILL"
export PYTHONPATH="$REPO_ROOT:$TEST_SKILL"

bash "$TEST_SKILL/scripts/handlers/on_continue.sh" "$JOB_ID"

# Verify state was updated
NEW_MAX=$(PYTHONPATH="$REPO_ROOT:$TEST_SKILL" python -m scripts.lib.state get "$RUNS_DIR/state.json" user_overrides.max_review_rounds)
if [ "$NEW_MAX" = "10" ]; then
    echo "PASS: max_review_rounds incremented to 10"
else
    echo "FAIL: max_review_rounds is '$NEW_MAX', expected 10"
    exit 1
fi
