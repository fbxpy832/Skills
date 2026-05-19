#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
BASE="$ROOT/.codex-opencode"
STATUS="$BASE/status"
LOGS="$BASE/logs"
REPORTS="$BASE/reports"
mkdir -p "$STATUS" "$LOGS" "$REPORTS"

PREFLIGHT_MD="$STATUS/preflight.md"
PREFLIGHT_JSON="$STATUS/preflight.json"
OMA_MD="$STATUS/oma-preflight.md"
OMA_JSON="$STATUS/oma-preflight.json"
TRIGGER_MD="$STATUS/oma-trigger-test.md"
SECURITY_LOG="$LOGS/security.log"

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

cmd_status() {
  local label="$1"; shift
  {
    echo "### $label"
    if command -v "$1" >/dev/null 2>&1 || [[ "$1" == /* ]]; then
      run_limited 20 "$@" 2>&1 | sanitize || true
    else
      echo "Command not found: $1"
    fi
    echo
  }
}

run_limited() {
  local seconds="$1"; shift
  if command -v timeout >/dev/null 2>&1; then
    timeout "$seconds" "$@"
  else
    perl -e 'alarm shift; exec @ARGV' "$seconds" "$@"
  fi
}

path_probe() {
  local p="$1"
  local expanded="${p/#\~/$HOME}"
  local exists=false readable=false writable=false
  [[ -e "$expanded" ]] && exists=true
  [[ -r "$expanded" ]] && readable=true
  [[ -w "$expanded" ]] && writable=true
  printf '| `%s` | %s | %s | %s |\n' "$p" "$exists" "$readable" "$writable"
}

cd "$ROOT"
: > "$SECURITY_LOG"
cat > "$PREFLIGHT_MD" <<EOF
# Codex ↔ OpenCode / OMA Preflight

Time: $(date '+%Y-%m-%d %H:%M:%S')
Project: $ROOT

## System

- uname: $(uname -a | sanitize)
- shell: ${SHELL:-unknown}
- user: $(id -un 2>/dev/null || whoami)
- pwd: $ROOT

## Codex Environment Capability

- Can write project directory: $([[ -w "$ROOT" ]] && echo yes || echo no)
- Can create .codex-opencode: $([[ -d "$BASE" && -w "$BASE" ]] && echo yes || echo no)
- Can execute local shell: yes
- Can read generated logs: $([[ -r "$LOGS" ]] && echo yes || echo no)

## Git Status

EOF

if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  {
    echo "- Is git repository: yes"
    echo "- Branch: $(git branch --show-current 2>/dev/null || echo unknown)"
    echo
    echo "### git status --short"
    echo '```'
    git status --short 2>/dev/null | sanitize
    echo '```'
    echo
    echo "### git diff --stat"
    echo '```'
    git diff --stat 2>/dev/null | sanitize
    echo '```'
  } >> "$PREFLIGHT_MD"
else
  echo "- Is git repository: no. No repository will be initialized automatically." >> "$PREFLIGHT_MD"
fi

{
  echo
  echo "## OpenCode"
  command -v opencode >/dev/null 2>&1 && echo "- which opencode: $(command -v opencode)" || echo "- which opencode: not found"
  cmd_status "opencode --version" opencode --version
  cmd_status "opencode --help" opencode --help
  cmd_status "opencode run --help" opencode run --help
  echo "If opencode is missing, install or expose it in PATH for the Codex App environment, then rerun preflight."
  echo
  echo "## OpenCode Directory Permissions"
  echo '| Path | Exists | Readable | Writable |'
  echo '| --- | --- | --- | --- |'
  path_probe "~/.local/share/opencode"
  path_probe "~/.local/state/opencode"
  path_probe "~/.config/opencode"
  path_probe "~/Library/Application Support/opencode"
  path_probe "$ROOT/.opencode"
} >> "$PREFLIGHT_MD"

cat > "$OMA_MD" <<EOF
# OMA Preflight

Time: $(date '+%Y-%m-%d %H:%M:%S')

## OMA Commands

EOF
{
  for bin in oma oh-my-openagent openagent; do
    command -v "$bin" >/dev/null 2>&1 && echo "- which $bin: $(command -v "$bin")" || echo "- which $bin: not found"
    cmd_status "$bin --version" "$bin" --version
    cmd_status "$bin --help" "$bin" --help
  done
  echo "Missing standalone OMA commands does not prove OMA is absent; it may be loaded through OpenCode configuration."
  echo
  echo "## OMA and Agent Configuration Paths"
  echo '| Path | Exists | Readable | Writable |'
  echo '| --- | --- | --- | --- |'
  for p in \
    "~/.config/oh-my-openagent" "~/.config/oma" "~/.oh-my-openagent" "~/.oma" "~/.openagent" \
    "~/.config/opencode" "~/.local/share/opencode" "~/.local/state/opencode" \
    "$ROOT/.oma" "$ROOT/.openagent" "$ROOT/.opencode" "$ROOT/AGENTS.md" "$ROOT/SOUL.md" \
    "$ROOT/TOOLS.md" "$ROOT/IDENTITY.md" "$ROOT/USER.md"; do
    path_probe "$p"
  done
  echo
  echo "## Keyword Search"
} >> "$OMA_MD"

search_roots=("$ROOT/.oma" "$ROOT/.openagent" "$ROOT/.opencode" "$ROOT/AGENTS.md" "$ROOT/SOUL.md" "$ROOT/TOOLS.md" "$ROOT/IDENTITY.md" "$ROOT/USER.md" "$HOME/.config/oh-my-openagent" "$HOME/.config/oma" "$HOME/.oh-my-openagent" "$HOME/.oma" "$HOME/.openagent" "$HOME/.config/opencode" "$HOME/.local/share/opencode" "$HOME/.local/state/opencode")
keywords='oma|oh-my-openagent|openagent|agent|subagent|model|provider|opencode go|opencode_go|planner|coder|reviewer|tester|repair|MiniMax|Qwen|GLM|DeepSeek|Claude|GPT'
{
  echo "Files with matching keywords are listed without file contents to avoid leaking secrets."
  echo '```'
  for p in "${search_roots[@]}"; do
    [[ -e "$p" ]] || continue
    if [[ -f "$p" ]]; then
      grep -IliE "$keywords" "$p" 2>/dev/null || true
    else
      find "$p" -type f -maxdepth 4 2>/dev/null | while IFS= read -r f; do
        grep -IliE "$keywords" "$f" 2>/dev/null || true
      done
    fi
  done | sort -u | sanitize
  echo '```'
  echo
  echo "## Agent Summary"
  echo "Best-effort summary from file names and safe keyword presence. Original OMA config files were not modified."
  echo
} >> "$OMA_MD"

agent_files="$(mktemp)"
for p in "${search_roots[@]}"; do
  [[ -e "$p" ]] || continue
  if [[ -f "$p" ]]; then
    grep -IliE 'planner|coder|developer|reviewer|tester|repair|model|provider' "$p" 2>/dev/null || true
  else
    find "$p" -type f -maxdepth 4 2>/dev/null | while IFS= read -r f; do
      grep -IliE 'planner|coder|developer|reviewer|tester|repair|model|provider' "$f" 2>/dev/null || true
    done
  fi
done | sort -u > "$agent_files"

{
  if [[ -s "$agent_files" ]]; then
    while IFS= read -r f; do
      echo "- $(printf '%s' "$f" | sanitize)"
    done < "$agent_files"
  else
    echo "- No readable OMA agent configuration files detected."
  fi
} >> "$OMA_MD"
rm -f "$agent_files"

opencode_available=false
oma_available=false
trigger_status="unknown"
oma_command_available=false
if command -v opencode >/dev/null 2>&1; then opencode_available=true; fi
if command -v oma >/dev/null 2>&1 || command -v oh-my-openagent >/dev/null 2>&1 || command -v openagent >/dev/null 2>&1; then
  oma_command_available=true
fi

cat > "$TRIGGER_MD" <<EOF
# OMA Trigger Test

Time: $(date '+%Y-%m-%d %H:%M:%S')

EOF

if [[ "$opencode_available" == true ]]; then
  prompt="Non-destructive environment check only. Do not modify files. Report the active agent, model, provider, whether OMA or Oh My OpenAgent is active, and then stop."
  set +e
  printf '%s\n' "$prompt" | run_limited 90 opencode run > "$TRIGGER_MD.tmp" 2>&1
  rc=$?
  set -e
  {
    echo "Command attempted: opencode run <non-destructive status prompt>"
    echo "Exit code: $rc"
    echo
    echo '```'
    sanitize < "$TRIGGER_MD.tmp"
    echo '```'
  } >> "$TRIGGER_MD"
  rm -f "$TRIGGER_MD.tmp"
  if [[ "$rc" -eq 0 ]] && grep -Eqi 'oma|oh.my.openagent|openagent' "$TRIGGER_MD.tmp"; then
    trigger_status="passed"
  else
    trigger_status="unknown"
    cat >> "$TRIGGER_MD" <<'EOF'

Current unable to confirm OpenCode CLI can automatically trigger OMA; later runs will follow config.json fallback strategy.
EOF
  fi
else
  trigger_status="skipped"
  echo "opencode was not found, so trigger test was skipped." >> "$TRIGGER_MD"
fi

if [[ "$oma_command_available" == true || "$trigger_status" == "passed" ]]; then
  oma_available=true
fi

python3 - "$PREFLIGHT_JSON" "$ROOT" "$opencode_available" <<'PY'
import json, sys, datetime, os
path, root, opencode = sys.argv[1], sys.argv[2], sys.argv[3] == "true"
data = {
  "time": datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
  "project": root,
  "can_write_project": os.access(root, os.W_OK),
  "can_execute_shell": True,
  "is_git_repo": os.system("git rev-parse --is-inside-work-tree >/dev/null 2>&1") == 0,
  "opencode_available": opencode
}
json.dump(data, open(path, "w"), indent=2, ensure_ascii=False)
PY

python3 - "$OMA_JSON" "$oma_available" "$trigger_status" <<'PY'
import json, sys, datetime
path, available, trigger = sys.argv[1], sys.argv[2] == "true", sys.argv[3]
data = {
  "time": datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
  "oma_available": available,
  "trigger_test_status": trigger,
  "note": "OMA availability is best-effort unless trigger_test_status is passed."
}
json.dump(data, open(path, "w"), indent=2, ensure_ascii=False)
PY

cat > "$REPORTS/oma-model-audit.md" <<EOF
# OMA Model Audit

Generated: $(date '+%Y-%m-%d %H:%M:%S')

## Detected Agents and Models

See .codex-opencode/status/oma-preflight.md for detected files and command output.

未能读取到 OMA 配置或模型列表，因此无法确认当前 OMA agent 模型选择是否合理。

## Checklist

- Agents list: unknown unless shown in oma-preflight.md
- Models per agent: unknown
- Role mapping: unknown
- OpenCode Go plan usage: unknown
- Model callability: $trigger_status
- planner / coder / reviewer / tester / repair split: unknown
- Same high-cost model risk: unable to judge
- Weak coder model risk: unable to judge
- Weak reviewer model risk: unable to judge
- Coder/reviewer same-model blind spot: unable to judge
- Context length risk: unable to judge
- Token consumption risk: unable to judge
- Missing tester agent: unable to judge
- Missing reviewer agent: unable to judge
- Missing repair agent: unable to judge
- Excessive permissions: unable to judge
- Missing file/tool permissions: unable to judge
- OpenCode Go model list readable: unknown
- Fit for Codex ↔ OpenCode autoloop: unable to judge

## Conclusion

无法判断
EOF

cat > "$REPORTS/oma-model-recommendation.md" <<'EOF'
# OMA Model Recommendation

This report gives recommendations only. It does not modify OMA or OpenCode configuration.

No concrete model list was safely detected during preflight. Do not hard-code GPT, Claude, Gemini, or other external model names unless OpenCode / OMA reports them as available under the user's current plan.

## Role Strategy

planner agent:
Use a strong reasoning model with stable context and moderate cost. It plans architecture and task decomposition, not bulk coding.

coder agent:
Use a strong coding model with reliable tool use and instruction following. It performs actual file edits.

tester agent:
Use a fast, low-cost model with stable log analysis. It identifies commands, interprets failures, and suggests tests.

reviewer agent:
Use a strict reasoning model that is not too lenient. Prefer a different model from coder when available to reduce blind spots.

repair agent:
Use a patch-focused coding model. It may match coder or use a faster model for targeted fixes.

## OpenCode Go Notes

Use only models reported by OpenCode / OMA as available. If OpenCode Go does not support explicit model or agent selection, keep role separation prompt-based and let Codex perform final review.
EOF

cat > "$STATUS/live.md" <<EOF
# Codex ↔ OpenCode / OMA AutoLoop Live Status

Current status: idle
Current round: 0 / 0
Current phase: preflight_completed
Last update: $(date '+%Y-%m-%d %H:%M:%S')

Task summary:
Preflight completed.

OMA status: $([[ "$oma_available" == true ]] && echo available || echo unknown)
OMA mode: auto
Current OMA agent: unknown
Current model: unknown
OpenCode plan: opencode_go
Fallback mode: enabled

Latest result:
OpenCode available: $opencode_available. OMA trigger test: $trigger_status.

Next action:
Review .codex-opencode/status/preflight.md and start an autoloop task.

Last error:
None
EOF

python3 - "$STATUS/state.json" "$opencode_available" "$oma_available" "$trigger_status" <<'PY'
import json, sys, datetime
path, opencode, oma, trigger = sys.argv[1], sys.argv[2] == "true", sys.argv[3] == "true", sys.argv[4]
try: data=json.load(open(path))
except Exception: data={}
data.update(status="idle", phase="preflight_completed", last_update=datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S"), last_error=None)
data.setdefault("oma", {})
data["oma"].update(available=oma, trigger_test_status=trigger, mode=data["oma"].get("mode","auto"), expected_plan="opencode_go")
data["opencode_available"]=opencode
json.dump(data, open(path, "w"), indent=2, ensure_ascii=False)
PY

echo "Preflight complete. See $PREFLIGHT_MD and $OMA_MD"
