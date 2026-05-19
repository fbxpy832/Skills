#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
BASE="$ROOT/.codex-opencode"
LIVE="$BASE/status/live.md"
STATE="$BASE/status/state.json"

if [[ -f "$LIVE" ]]; then
  cat "$LIVE"
else
  echo "No live status file found at $LIVE"
fi

echo
echo "## Key State"
if [[ -f "$STATE" ]]; then
  python3 - "$STATE" <<'PY'
import json, sys
data=json.load(open(sys.argv[1]))
keys=["status","round","max_rounds","phase","test_status","review_status","security_status","run_dir","last_error"]
for k in keys:
    print(f"{k}: {data.get(k)}")
oma=data.get("oma",{})
print(f"oma.available: {oma.get('available')}")
print(f"oma.mode: {oma.get('mode')}")
print(f"oma.current_agent: {oma.get('current_agent')}")
print(f"oma.current_model: {oma.get('current_model')}")
print(f"oma.trigger_test_status: {oma.get('trigger_test_status')}")
PY
else
  echo "No state file found at $STATE"
fi

echo
echo "## Latest Run"
latest="$(find "$BASE/runs" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | sort | tail -n 1 || true)"
if [[ -n "$latest" ]]; then
  echo "$latest"
  find "$latest" -maxdepth 1 \( -name 'test-round-*.log' -o -name 'codex-review-round-*.md' \) | sort | tail -n 4
else
  echo "No runs yet."
fi
