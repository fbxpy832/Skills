#!/usr/bin/env bash
set -euo pipefail

# ============================================================================
# knowledge-retrieval.sh — Unified Knowledge Retrieval Entry Point
# ============================================================================
# Routes queries to all enabled knowledge source adapters and merges results.
#
# Usage:
#   knowledge-retrieval.sh "query"                  # All configured sources
#   knowledge-retrieval.sh "query" --sources lark,obsidian  # Specific sources
#   knowledge-retrieval.sh "query" --dry-run        # Preview mode
#   knowledge-retrieval.sh "query" --json           # JSON output
#   knowledge-retrieval.sh "query" --allow-empty    # Exit 0 even with no sources
# ============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_ENV="${DEEP_RESEARCH_CONFIG_ENV:-${DEEP_RESEARCH_SKILL_CONFIG_DIR:-$HOME/.config/deep-research-skill}/config.env}"
[ -f "$CONFIG_ENV" ] && source "$CONFIG_ENV"

COUNT=5
RAW_JSON=false
DRY_RUN=false
SOURCES=""
TIMEOUT=15
QUERY=""
ALLOW_EMPTY=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --count)      COUNT="$2"; shift 2 ;;
    --json)       RAW_JSON=true; shift ;;
    --dry-run)    DRY_RUN=true; shift ;;
    --sources)    SOURCES="$2"; shift 2 ;;
    --timeout)    TIMEOUT="$2"; shift 2 ;;
    --allow-empty) ALLOW_EMPTY=true; shift ;;
    --query)      QUERY="$2"; shift 2 ;;
    --help|-h)
      echo "Usage: knowledge-retrieval.sh [--query QUERY|QUERY] [--count N] [--sources lark,obsidian,notebooklm] [--json] [--dry-run] [--allow-empty]"
      exit 0 ;;
    --*)          echo "ERROR: Unknown option: $1" >&2; exit 1 ;;
    *)            QUERY="$1"; shift ;;
  esac
done

if [ -z "${QUERY:-}" ]; then echo "ERROR: Missing query." >&2; exit 1; fi

# Determine which sources to enable (bash 3.2 compatible — no declare -A)
ENABLE_LARK=0
ENABLE_OBSIDIAN=0
ENABLE_NOTEBOOKLM=0

if [ -n "$SOURCES" ]; then
  # Parse comma-separated source list
  case ",$SOURCES," in
    *,lark,*)       ENABLE_LARK=1 ;;
  esac
  case ",$SOURCES," in
    *,obsidian,*)   ENABLE_OBSIDIAN=1 ;;
  esac
  case ",$SOURCES," in
    *,notebooklm,*) ENABLE_NOTEBOOKLM=1 ;;
  esac
else
  # Auto-detect: check each adapter via --check
  if "$SCRIPT_DIR/knowledge-lark.sh" --check &>/dev/null; then ENABLE_LARK=1; fi
  if "$SCRIPT_DIR/knowledge-obsidian.sh" --check &>/dev/null; then ENABLE_OBSIDIAN=1; fi
  if "$SCRIPT_DIR/knowledge-notebooklm.sh" --check &>/dev/null; then ENABLE_NOTEBOOKLM=1; fi
fi

# Collect adapter paths
ADAPTERS=""
[ "$ENABLE_LARK" = "1" ] && ADAPTERS="$ADAPTERS|lark"
[ "$ENABLE_OBSIDIAN" = "1" ] && ADAPTERS="$ADAPTERS|obsidian"
[ "$ENABLE_NOTEBOOKLM" = "1" ] && ADAPTERS="$ADAPTERS|notebooklm"

if [ -z "$ADAPTERS" ]; then
  echo "WARNING: No knowledge sources available." >&2
  echo "Run scripts/setup.sh to configure, or install: lark-cli, notebooklm CLI" >&2
  if [ "$ALLOW_EMPTY" = true ]; then
    exit 0
  fi
  echo "KNOWLEDGE_SEARCH_STATUS: unavailable" >&2
  echo "FAILURE_TYPE: local_source_unavailable" >&2
  echo "FAILED_SOURCE_TYPE: local_vault" >&2
  echo "FAILED_SOURCE_DETAIL: No knowledge adapters configured or available" >&2
  echo "ATTEMPTED_BACKENDS: lark,obsidian,notebooklm" >&2
  exit 1
fi

# Display mode
if [ "$DRY_RUN" = true ]; then
  echo "DRY RUN: knowledge-retrieval.sh"
  echo "  Query: $QUERY"
  echo "  Sources:$(echo "$ADAPTERS" | tr '|' '\n' | while IFS= read -r S; do [ -n "$S" ] && echo "    - $S"; done)"
  echo "  Enabled adapters:"
  [ "$ENABLE_LARK" = "1" ] && echo "    - knowledge-lark.sh"
  [ "$ENABLE_OBSIDIAN" = "1" ] && echo "    - knowledge-obsidian.sh"
  [ "$ENABLE_NOTEBOOKLM" = "1" ] && echo "    - knowledge-notebooklm.sh"
  exit 0
fi

# Track per-source status
SOURCE_STATUS=""
TOTAL_ADAPTERS=0
SUCCESS_ADAPTERS=0
FAILED_ADAPTERS=0
EMPTY_ADAPTERS=0

# Execute adapters sequentially
FIRST=true
if [ "$RAW_JSON" = true ]; then
  echo '{"sources":['
fi

run_adapter() {
  local name="$1"
  local script="$SCRIPT_DIR/knowledge-$name.sh"
  TOTAL_ADAPTERS=$((TOTAL_ADAPTERS + 1))

  if [ "$RAW_JSON" = true ]; then
    local tmp_out="/tmp/knowledge-retrieval-$$-$name"
    if "$script" "$QUERY" --count "$COUNT" --json --timeout "$TIMEOUT" >"$tmp_out" 2>/dev/null; then
      local result_count
      result_count=$(python3 -c "import json,sys; d=json.load(open('$tmp_out')); print(len(d.get('results',[])+d.get('sources',[])+d.get('items',[])))" 2>/dev/null || echo "0")
      if [ "$result_count" -gt 0 ]; then
        SUCCESS_ADAPTERS=$((SUCCESS_ADAPTERS + 1))
        SOURCE_STATUS="${SOURCE_STATUS}$name:success "
        [ "$FIRST" = false ] && echo ","
        cat "$tmp_out"
      else
        EMPTY_ADAPTERS=$((EMPTY_ADAPTERS + 1))
        SOURCE_STATUS="${SOURCE_STATUS}$name:no_results "
        [ "$FIRST" = false ] && echo ","
        echo "{\"source_type\":\"$name\",\"success\":true,\"results\":[],\"status\":\"no_results\"}"
      fi
    else
      FAILED_ADAPTERS=$((FAILED_ADAPTERS + 1))
      SOURCE_STATUS="${SOURCE_STATUS}$name:failed "
      [ "$FIRST" = false ] && echo ","
      echo "{\"source_type\":\"$name\",\"success\":false,\"results\":[],\"status\":\"failed\"}"
    fi
    rm -f "$tmp_out"
    FIRST=false
  else
    echo "=== $name ==="
    local adapter_output
    adapter_output=$("$script" "$QUERY" --count "$COUNT" --timeout "$TIMEOUT" 2>/dev/null) || true
    if [ -n "$adapter_output" ]; then
      # Check if output actually has results (not just error/empty)
      local has_content
      has_content=$(echo "$adapter_output" | grep -c "^\[" 2>/dev/null || echo "0")
      if [ "$has_content" -gt 0 ]; then
        echo "$adapter_output"
        SUCCESS_ADAPTERS=$((SUCCESS_ADAPTERS + 1))
        SOURCE_STATUS="${SOURCE_STATUS}$name:success "
        echo "[STATUS] $name: success" >&2
      else
        echo "(adapter returned no results)"
        EMPTY_ADAPTERS=$((EMPTY_ADAPTERS + 1))
        SOURCE_STATUS="${SOURCE_STATUS}$name:no_results "
        echo "[STATUS] $name: no_results" >&2
      fi
    else
      echo "(adapter failed)"
      FAILED_ADAPTERS=$((FAILED_ADAPTERS + 1))
      SOURCE_STATUS="${SOURCE_STATUS}$name:failed "
      echo "[STATUS] $name: failed" >&2
    fi
    echo ""
    FIRST=false
  fi
}

[ "$ENABLE_LARK" = "1" ] && run_adapter "lark"
[ "$ENABLE_OBSIDIAN" = "1" ] && run_adapter "obsidian"
[ "$ENABLE_NOTEBOOKLM" = "1" ] && run_adapter "notebooklm"

if [ "$RAW_JSON" = true ]; then
  echo ']}'
fi

# Determine overall status
local_knowledge_status="success"
if [ "$FAILED_ADAPTERS" -gt 0 ] && [ "$SUCCESS_ADAPTERS" -eq 0 ]; then
  local_knowledge_status="failed"
elif [ "$FAILED_ADAPTERS" -gt 0 ] || [ "$EMPTY_ADAPTERS" -gt 0 ]; then
  if [ "$SUCCESS_ADAPTERS" -eq 0 ]; then
    local_knowledge_status="no_results"
  else
    local_knowledge_status="partial_success"
  fi
fi

echo "KNOWLEDGE_SEARCH_STATUS: $local_knowledge_status" >&2
echo "SOURCE_STATUS: ${SOURCE_STATUS:-}" >&2
echo "FAILURE_TYPE: local_source_unavailable" >&2
echo "FAILED_SOURCE_TYPE: local_vault" >&2
echo "FAILED_SOURCE_DETAIL: $FAILED_ADAPTERS adapter(s) failed, $EMPTY_ADAPTERS returned no results out of $TOTAL_ADAPTERS total" >&2
echo "ATTEMPTED_BACKENDS: lark,obsidian,notebooklm" >&2
echo "FALLBACK_PATH: none (knowledge adapters)" >&2
echo "SUGGESTED_NEXT_QUERIES: Configure knowledge adapters via setup.sh or use --allow-empty to skip" >&2

if [ "$local_knowledge_status" = "failed" ] || [ "$local_knowledge_status" = "no_results" ]; then
  exit 1
fi

exit 0