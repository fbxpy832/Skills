#!/usr/bin/env bash
set -euo pipefail

# ============================================================================
# knowledge-notebooklm.sh — NotebookLM Knowledge Adapter
# ============================================================================
# Queries the current NotebookLM notebook: reads content + asks questions.
# Requires notebooklm CLI to be installed and authenticated.
#
# Usage:
#   knowledge-notebooklm.sh "search query" [--count N] [--json] [--dry-run]
#   knowledge-notebooklm.sh --check
# ============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_ENV="${DEEP_RESEARCH_CONFIG_ENV:-${DEEP_RESEARCH_SKILL_CONFIG_DIR:-$HOME/.config/deep-research-skill}/config.env}"
[ -f "$CONFIG_ENV" ] && source "$CONFIG_ENV"

COUNT=5
RAW_JSON=false
DRY_RUN=false
CHECK=false
QUERY=""
NOTEBOOK_ID="${DEEP_RESEARCH_NOTEBOOKLM_NOTEBOOK_ID:-}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --count)    COUNT="$2"; shift 2 ;;
    --json)     RAW_JSON=true; shift ;;
    --dry-run)  DRY_RUN=true; shift ;;
    --check)    CHECK=true; shift ;;
    --query)    QUERY="$2"; shift 2 ;;
    --help|-h)  echo "Usage: knowledge-notebooklm.sh [--query QUERY|QUERY] [--count N] [--json] [--dry-run] [--check]"; exit 0 ;;
    --*)        echo "ERROR: Unknown option: $1" >&2; exit 1 ;;
    *)          QUERY="$1"; shift ;;
  esac
done

# Availability check
if [ "$CHECK" = true ]; then
  if ! command -v notebooklm &>/dev/null; then echo "ERROR: notebooklm CLI not found" >&2; exit 1; fi
  echo "AVAILABLE: notebooklm CLI ready"
  exit 0
fi

if [ -z "${QUERY:-}" ]; then echo "ERROR: Missing search query." >&2; exit 1; fi
if ! command -v notebooklm &>/dev/null; then echo "ERROR: notebooklm CLI not found" >&2; exit 2; fi

# Auto-detect notebook ID from context.json if not set
if [ -z "$NOTEBOOK_ID" ] && [ -f "$HOME/.notebooklm/context.json" ]; then
  NOTEBOOK_ID=$(python3 -c "import json; print(json.load(open('$HOME/.notebooklm/context.json')).get('notebook_id',''))" 2>/dev/null || echo "")
fi

if [ "$DRY_RUN" = true ]; then
  echo "DRY RUN: notebooklm ask \"$QUERY\" (notebook: ${NOTEBOOK_ID:-auto})"
  exit 0
fi

RESULTS_COUNT=0
FIRST_RESULT=true
if [ "$RAW_JSON" = true ]; then
  echo "{\"source_type\":\"notebooklm\",\"query\":$(printf '%s' "$QUERY" | python3 -c "import sys,json; print(json.dumps(sys.stdin.read().strip()))"),\"success\":true,\"results\":["
fi

# Method 1: Ask NotebookLM a question
ASK_RESULT=""
if [ -n "$NOTEBOOK_ID" ]; then
  ASK_RESULT=$(notebooklm use "$NOTEBOOK_ID" 2>/dev/null && notebooklm ask "$QUERY" 2>/dev/null || echo "")
else
  ASK_RESULT=$(notebooklm ask "$QUERY" 2>/dev/null || echo "")
fi

if [ -n "$ASK_RESULT" ]; then
  PREVIEW=$(echo "$ASK_RESULT" | head -c 200)
  RESULTS_COUNT=$((RESULTS_COUNT + 1))
  if [ "$RAW_JSON" = true ]; then
    echo "{\"title\":\"NotebookLM Analysis: $QUERY\",\"path\":\"notebooklm://ask\",\"content_preview\":$(printf '%s' "$PREVIEW" | python3 -c "import sys,json; print(json.dumps(sys.stdin.read().strip()))"),\"source_level\":\"C\",\"source_subtype\":\"model_reasoning\",\"metadata\":{\"method\":\"ask\",\"notebook_id\":\"$NOTEBOOK_ID\"}}"
    FIRST_RESULT=false
  else
    echo "[notebooklm:model_reasoning] NotebookLM Analysis: $QUERY"
    echo "  notebooklm://ask"
    echo "  ${PREVIEW:0:200}"
    echo "  method: ask  level: C (AI analysis)"
    echo ""
  fi
fi

# Method 2: List sources in the notebook (for reference)
if [ -n "$NOTEBOOK_ID" ] && command -v notebooklm &>/dev/null; then
  while IFS= read -r SRC; do
    [ -z "$SRC" ] && continue
    [ $RESULTS_COUNT -ge "$COUNT" ] && break
    SRC_TITLE=$(echo "$SRC" | sed 's/^\[.*\] *//' | head -c 100)
    RESULTS_COUNT=$((RESULTS_COUNT + 1))
    if [ "$RAW_JSON" = true ]; then
      [ "$FIRST_RESULT" = false ] && echo ","
      FIRST_RESULT=false
      echo "{\"title\":$(printf '%s' "$SRC_TITLE" | python3 -c "import sys,json; print(json.dumps(sys.stdin.read().strip()))"),\"path\":\"notebooklm://source\",\"content_preview\":\"\",\"source_level\":\"B\",\"source_subtype\":\"uploaded_files\",\"metadata\":{\"method\":\"source_list\",\"notebook_id\":\"$NOTEBOOK_ID\"}}"
    else
      echo "[notebooklm:uploaded_files] $SRC_TITLE"
      echo "  notebooklm://source"
      echo "  level: B (source material)"
      echo ""
    fi
  done < <(notebooklm source list 2>/dev/null | head -n "$COUNT" || true)
fi

if [ "$RAW_JSON" = true ]; then
  echo "]}"
fi

# If no results at all
if [ $RESULTS_COUNT -eq 0 ]; then
  if [ "$RAW_JSON" = true ]; then
    echo '{"source_type":"notebooklm","query":"","success":true,"results":[]}'
  else
    echo "[notebooklm] (no results)"
  fi
  exit 0
fi