#!/usr/bin/env bash
set -euo pipefail

# Model Router - 按 mode + agent 输出建议的能力级别
# 输出: "high" / "fast" / "long_context"
# 具体使用的模型取决于 CLI / Agent 环境的实际可用性

MODE="${1:-balanced}"
AGENT="${2:-planner_agent}"

route() {
  local mode="$1"
  local agent="$2"

  case "$mode:$agent" in
    balanced:planner_agent|balanced:analyst_agent|balanced:scenario_agent|balanced:writer_agent|balanced:reviewer_agent)
      echo "high" ;;
    balanced:source_agent)
      echo "fast" ;;
    balanced:long_context_agent)
      echo "long_context" ;;

    cost_saving:planner_agent|cost_saving:source_agent|cost_saving:analyst_agent|cost_saving:scenario_agent|cost_saving:writer_agent)
      echo "fast" ;;
    cost_saving:long_context_agent)
      echo "long_context" ;;
    cost_saving:reviewer_agent)
      echo "high" ;;

    high_quality:source_agent)
      echo "fast" ;;
    high_quality:long_context_agent)
      echo "long_context" ;;
    high_quality:*)
      echo "high" ;;

    long_context:source_agent)
      echo "fast" ;;
    long_context:long_context_agent)
      echo "long_context" ;;
    long_context:*)
      echo "high" ;;

    draft_fast:planner_agent|draft_fast:source_agent|draft_fast:analyst_agent|draft_fast:scenario_agent|draft_fast:writer_agent)
      echo "fast" ;;
    draft_fast:long_context_agent)
      echo "long_context" ;;
    draft_fast:reviewer_agent)
      echo "high" ;;

    *)
      echo "high" ;;
  esac
}

route "$MODE" "$AGENT"
