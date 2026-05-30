#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
BASE="$ROOT/.codex-opencode"
LOG="$BASE/logs/security.log"
LIVE="$BASE/status/live.md"
STATE="$BASE/status/state.json"
FINAL="$BASE/reports/final-report.md"
mkdir -p "$BASE/logs" "$BASE/status" "$BASE/reports"

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

write_stop_state() {
  local reason="$1"
  local now
  now="$(date '+%Y-%m-%d %H:%M:%S')"
  cat > "$LIVE" <<EOF
# Codex ↔ OpenCode / OMA AutoLoop Live Status

Current status: needs_user_action
Current round: ${ROUND:-0} / ${MAX_ROUNDS:-0}
Current phase: security_check
Last update: $now

Task summary:
${TASK_SUMMARY:-Unknown}

OMA status: unknown
OMA mode: ${OMA_MODE:-auto}
Current OMA agent: unknown
Current model: unknown
OpenCode plan: opencode_go
Fallback mode: unknown

Latest result:
Security check found high-risk behavior.

Next action:
Review $LOG and decide whether to continue manually.

Last error:
$reason
EOF
  python3 - "$STATE" "$reason" <<'PY'
import json, sys, datetime
path, reason = sys.argv[1], sys.argv[2]
try:
    data=json.load(open(path))
except Exception:
    data={}
data.update(status="needs_user_action", phase="security_check", last_error=reason,
            security_status="needs_user_action",
            last_update=datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S"))
json.dump(data, open(path, "w"), indent=2, ensure_ascii=False)
PY
  cat > "$FINAL" <<EOF
# Codex ↔ OpenCode / OMA AutoLoop Final Report

## Task
${TASK_SUMMARY:-Unknown}

## Result
needs_user_action

## Security Summary
$reason

## User Action Needed
Review .codex-opencode/logs/security.log before continuing.
EOF
}

cd "$ROOT"
: > "$LOG"
printf '# Security Check\nTime: %s\nProject: %s\n\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$ROOT" >> "$LOG"

tmp="$(mktemp)"
{
  git diff --name-status -- . ':(exclude).codex-opencode/*' 2>/dev/null || true
  git diff --stat -- . ':(exclude).codex-opencode/*' 2>/dev/null || true
  git diff -- . ':(exclude).codex-opencode/*' 2>/dev/null || true
  [[ -f "$BASE/logs/opencode.log" ]] && cat "$BASE/logs/opencode.log"
  [[ -f "$BASE/logs/test.log" ]] && cat "$BASE/logs/test.log"
} | sanitize > "$tmp"

risk=0
reasons=()

deleted_count="$(git diff --name-status -- . ':(exclude).codex-opencode/*' 2>/dev/null | awk '$1=="D"{c++} END{print c+0}')"
if [[ "$deleted_count" -ge 20 ]]; then
  risk=1; reasons+=("Large file deletion detected: $deleted_count deleted files")
fi

while IFS= read -r path; do
  [[ -z "$path" ]] && continue
  case "$path" in
    .env|.env.*|*/.env|*/.env.*|*.pem|*.key|id_rsa|id_ed25519|*/id_rsa|*/id_ed25519|*token*|*cookie*|*secret*|*.crt|*.p12)
      risk=1; reasons+=("High-risk file modified: $path")
      ;;
  esac
  case "$path" in
    /etc/*|/usr/*|/System/*|/Library/*|../*)
      risk=1; reasons+=("Path appears outside project scope: $path")
      ;;
  esac
done < <(git diff --name-only -- . ':(exclude).codex-opencode/*' 2>/dev/null || true)

patterns=(
  '(^|[^[:alnum:]_])sudo([^[:alnum:]_]|$)'
  'rm[[:space:]]+-rf'
  'chmod[[:space:]]+-R[[:space:]]+777'
  'curl[^|]*\|[[:space:]]*(bash|sh)'
  '(npm|pnpm|yarn|bun|pip|poetry|uv|cargo|go)[[:space:]]+(install|add|get)'
  'sk-[A-Za-z0-9_-]{12,}'
  'ghp_[A-Za-z0-9_]{12,}'
  'Bearer[[:space:]]+[A-Za-z0-9._~+/=-]{10,}'
  'AKIA[0-9A-Z]{12,}'
  '(password|token|cookie)='
)

for pat in "${patterns[@]}"; do
  if grep -Eqi "$pat" "$tmp"; then
    risk=1; reasons+=("Risk pattern detected: $pat")
  fi
done

if git diff --shortstat -- . ':(exclude).codex-opencode/*' 2>/dev/null | grep -Eq '([5-9][0-9]{3,}|[1-9][0-9]{4,}) (insertions|deletions)'; then
  risk=1; reasons+=("Large diff volume may indicate unrelated refactor")
fi

cat "$tmp" >> "$LOG"
rm -f "$tmp"

if [[ "$risk" -eq 1 ]]; then
  {
    printf '\n## Result\nneeds_user_action\n\n'
    printf '## Reasons\n'
    printf -- '- %s\n' "${reasons[@]}"
  } >> "$LOG"
  write_stop_state "$(printf '%s; ' "${reasons[@]}")"
  exit 2
fi

printf '\n## Result\npassed\n' >> "$LOG"
printf 'passed\n'
