#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-balanced}"
AGENT="${2:-planner_agent}"

CONFIG_ENV="${DEEP_RESEARCH_CONFIG_ENV:-${DEEP_RESEARCH_SKILL_CONFIG_DIR:-$HOME/.config/deep-research-skill}/config.env}"
if [ -f "$CONFIG_ENV" ]; then
  # shellcheck disable=SC1090
  source "$CONFIG_ENV"
fi

DEEPSEEK_V4_FLASH="deepseek/deepseek-v4-flash"

local_override() {
  case "$1" in
    planner_agent) echo "${DEEP_RESEARCH_MODEL_PLANNER_AGENT:-}" ;;
    source_agent) echo "${DEEP_RESEARCH_MODEL_SOURCE_AGENT:-}" ;;
    long_context_agent) echo "${DEEP_RESEARCH_MODEL_LONG_CONTEXT_AGENT:-}" ;;
    analyst_agent) echo "${DEEP_RESEARCH_MODEL_ANALYST_AGENT:-}" ;;
    scenario_agent) echo "${DEEP_RESEARCH_MODEL_SCENARIO_AGENT:-}" ;;
    writer_agent) echo "${DEEP_RESEARCH_MODEL_WRITER_AGENT:-}" ;;
    reviewer_agent) echo "${DEEP_RESEARCH_MODEL_REVIEWER_AGENT:-}" ;;
    *) echo "" ;;
  esac
}

route() {
  local mode="$1"
  local agent="$2"
  local override

  override="$(local_override "$agent")"
  if [ -n "$override" ]; then
    echo "$override"
    return 0
  fi

  case "$mode:$agent" in
    balanced:*|cost_saving:*|high_quality:*|long_context:*|draft_fast:*)
      echo "$DEEPSEEK_V4_FLASH" ;;

    *)
      echo "$DEEPSEEK_V4_FLASH" ;;
  esac
}

route "$MODE" "$AGENT"
