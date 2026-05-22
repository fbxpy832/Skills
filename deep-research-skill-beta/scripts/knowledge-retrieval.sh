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

while [[ $# -gt 0 ]]; do
  case "$1" in
    --count)    COUNT="$2"; shift 2 ;;
    --json)     RAW_JSON=true; shift ;;
    --dry-run)  DRY_RUN=true; shift ;;
    --sources)  SOURCES="$2"; shift 2 ;;
    --timeout)  TIMEOUT="$2"; shift 2 ;;
    --query)    QUERY="$2"; shift 2 ;;
    --help|-h)
      echo "Usage: knowledge-retrieval.sh [--query QUERY|QUERY] [--count N] [--sources lark,obsidian,notebooklm] [--json] [--dry-run]"
      exit 0 ;;
    --*)        echo "ERROR: Unknown option: $1" >&2; exit 1 ;;
    *)          QUERY="$1"; shift ;;
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
  exit 0
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

# Execute adapters sequentially
FIRST=true
if [ "$RAW_JSON" = true ]; then
  echo '{"sources":['
fi

run_adapter() {
  local name="$1"
  local script="$SCRIPT_DIR/knowledge-$name.sh"
  if [ "$RAW_JSON" = true ]; then
    [ "$FIRST" = false ] && echo ","
    "$script" "$QUERY" --count "$COUNT" --json --timeout "$TIMEOUT" 2>/dev/null || echo "{\"source_type\":\"$name\",\"success\":false,\"results\":[]}"
    FIRST=false
  else
    echo "=== $name ==="
    "$script" "$QUERY" --count "$COUNT" --timeout "$TIMEOUT" 2>/dev/null || echo "(adapter failed)"
    echo ""
  fi
}

[ "$ENABLE_LARK" = "1" ] && run_adapter "lark"
[ "$ENABLE_OBSIDIAN" = "1" ] && run_adapter "obsidian"
[ "$ENABLE_NOTEBOOKLM" = "1" ] && run_adapter "notebooklm"

if [ "$RAW_JSON" = true ]; then
  echo ']}'
fi