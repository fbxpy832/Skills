#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-balanced}"
AGENT="${2:-planner_agent}"

DEEPSEEK_V4_PRO="opencode-go/deepseek-v4-pro"
DEEPSEEK_V4_FLASH="opencode-go/deepseek-v4-flash"
KIMI_26="opencode-go/kimi-k2.6"

route() {
  local mode="$1"
  local agent="$2"

  case "$mode:$agent" in
    balanced:planner_agent|balanced:analyst_agent|balanced:scenario_agent|balanced:writer_agent|balanced:reviewer_agent)
      echo "$DEEPSEEK_V4_PRO" ;;
    balanced:source_agent)
      echo "$DEEPSEEK_V4_FLASH" ;;
    balanced:long_context_agent)
      echo "$KIMI_26" ;;

    cost_saving:planner_agent|cost_saving:source_agent|cost_saving:analyst_agent|cost_saving:scenario_agent|cost_saving:writer_agent)
      echo "$DEEPSEEK_V4_FLASH" ;;
    cost_saving:long_context_agent)
      echo "$KIMI_26" ;;
    cost_saving:reviewer_agent)
      echo "$DEEPSEEK_V4_PRO" ;;

    high_quality:source_agent)
      echo "$DEEPSEEK_V4_FLASH" ;;
    high_quality:long_context_agent)
      echo "$KIMI_26" ;;
    high_quality:*)
      echo "$DEEPSEEK_V4_PRO" ;;

    long_context:source_agent)
      echo "$DEEPSEEK_V4_FLASH" ;;
    long_context:long_context_agent)
      echo "$KIMI_26" ;;
    long_context:*)
      echo "$DEEPSEEK_V4_PRO" ;;

    draft_fast:planner_agent|draft_fast:source_agent|draft_fast:analyst_agent|draft_fast:scenario_agent|draft_fast:writer_agent)
      echo "$DEEPSEEK_V4_FLASH" ;;
    draft_fast:long_context_agent)
      echo "$KIMI_26" ;;
    draft_fast:reviewer_agent)
      echo "$DEEPSEEK_V4_PRO" ;;

    *)
      echo "$DEEPSEEK_V4_PRO" ;;
  esac
}

route "$MODE" "$AGENT"
