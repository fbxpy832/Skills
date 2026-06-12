#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# shellcheck disable=SC1091
source "$SCRIPT_DIR/lib/platform.sh"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/lib/config-resolver.sh"

DETECTED_OS="$(dr_detect_os)"
PYTHON_BIN="$(dr_detect_python || true)"

WB_WORKSPACE=""
if command -v dr_workbuddy_workspace_dir >/dev/null 2>&1; then
  WB_WORKSPACE="$(dr_workbuddy_workspace_dir "$DETECTED_OS" 2>/dev/null || true)"
fi

if deep_research_source_config; then
  config_exists="yes"
else
  config_exists="no"
fi

keys_count=0
[ -n "${BOCHA_API_KEY:-}" ] && keys_count=$((keys_count + 1))
[ -n "${BRAVE_API_KEY:-}" ] && keys_count=$((keys_count + 1))
[ -n "${EXA_API_KEY:-}" ] && keys_count=$((keys_count + 1))
[ -n "${BAIDU_API_KEY:-}" ] && [ -n "${BAIDU_SECRET_KEY:-}" ] && keys_count=$((keys_count + 1))

models_count=0
for var in \
  DEEP_RESEARCH_MODEL_PLANNER_AGENT \
  DEEP_RESEARCH_MODEL_SOURCE_AGENT \
  DEEP_RESEARCH_MODEL_LONG_CONTEXT_AGENT \
  DEEP_RESEARCH_MODEL_ANALYST_AGENT \
  DEEP_RESEARCH_MODEL_SCENARIO_AGENT \
  DEEP_RESEARCH_MODEL_WRITER_AGENT \
  DEEP_RESEARCH_MODEL_REVIEWER_AGENT
do
  eval "value=\${$var:-}"
  [ -n "$value" ] && models_count=$((models_count + 1))
done

# ─── 平台诊断 ──────────────────────────────────────────────────────────
echo "config_env=$CONFIG_ENV"
echo "config_exists=$config_exists"
echo "search_keys_configured=$keys_count"
echo "agent_models_configured=$models_count"
echo "platform_os=$DETECTED_OS"
baidu_configured="no"
[ -n "${BAIDU_API_KEY:-}" ] && [ -n "${BAIDU_SECRET_KEY:-}" ] && baidu_configured="yes"
echo "baidu_configured=$baidu_configured"
if [ -n "$PYTHON_BIN" ]; then
  echo "python_available=yes"
  echo "python_command=$PYTHON_BIN"
else
  echo "python_available=no"
  echo "python_command="
fi
if [ -n "$WB_WORKSPACE" ]; then
  echo "workbuddy_workspace=$WB_WORKSPACE"
  if [ -d "$WB_WORKSPACE" ]; then
    echo "workbuddy_workspace_exists=yes"
  else
    echo "workbuddy_workspace_exists=no"
  fi
else
  echo "workbuddy_workspace="
  echo "workbuddy_workspace_exists=no"
fi

# 代理可达检测
if [ -n "${DEEP_RESEARCH_PROXY_URL:-}" ]; then
  if command -v curl >/dev/null 2>&1; then
    if curl -s --connect-timeout 3 "$DEEP_RESEARCH_PROXY_URL" >/dev/null 2>&1; then
      echo "proxy_reachable=yes"
    else
      echo "proxy_reachable=no"
    fi
  else
    echo "proxy_reachable=skipped"
  fi
else
  echo "proxy_reachable=skipped"
fi

# ─── 状态判定 ──────────────────────────────────────────────────────────
if [ "$config_exists" = "yes" ] && [ "$keys_count" -gt 0 ]; then
  echo "status=ok"
  exit 0
fi

echo "status=missing_or_incomplete"
exit 1
