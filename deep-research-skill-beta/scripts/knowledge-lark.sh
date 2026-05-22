#!/usr/bin/env bash
set -euo pipefail

# ============================================================================
# knowledge-lark.sh — Lark/Feishu Wiki Search Adapter
# ============================================================================
# Searches Feishu knowledge spaces and retrieves matching documents.
# Requires lark-cli to be installed and authenticated.
#
# Usage:
#   knowledge-lark.sh "search query" [--count N] [--json] [--dry-run]
#   knowledge-lark.sh --check
# ============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_ENV="${DEEP_RESEARCH_CONFIG_ENV:-${DEEP_RESEARCH_SKILL_CONFIG_DIR:-$HOME/.config/deep-research-skill}/config.env}"
[ -f "$CONFIG_ENV" ] && source "$CONFIG_ENV"

COUNT=5
RAW_JSON=false
DRY_RUN=false
CHECK=false
QUERY=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --count)    COUNT="$2"; shift 2 ;;
    --json)     RAW_JSON=true; shift ;;
    --dry-run)  DRY_RUN=true; shift ;;
    --check)    CHECK=true; shift ;;
    --query)    QUERY="$2"; shift 2 ;;
    --help|-h)  echo "Usage: knowledge-lark.sh [--query QUERY|QUERY] [--count N] [--json] [--dry-run] [--check]"; exit 0 ;;
    --*)        echo "ERROR: Unknown option: $1" >&2; exit 1 ;;
    *)          QUERY="$1"; shift ;;
  esac
done

# Availability check
if [ "$CHECK" = true ]; then
  if ! command -v lark-cli &>/dev/null; then echo "ERROR: lark-cli not found" >&2; exit 1; fi
  if [ ! -f "$HOME/.lark-cli/config.json" ]; then echo "ERROR: lark-cli not configured. Run: lark-cli auth login" >&2; exit 1; fi
  echo "AVAILABLE: lark-cli ready"
  exit 0
fi

if [ -z "${QUERY:-}" ]; then echo "ERROR: Missing search query." >&2; exit 1; fi
if ! command -v lark-cli &>/dev/null; then echo "ERROR: lark-cli not found" >&2; exit 2; fi

if [ "$DRY_RUN" = true ]; then
  echo "DRY RUN: lark-cli docs +search \"$QUERY\" --limit $COUNT"
  exit 0
fi

# Step 1: Search for documents
SEARCH_OUTPUT=$(lark-cli docs +search "$QUERY" --limit "$COUNT" 2>/dev/null || true)
if [ -z "$SEARCH_OUTPUT" ]; then
  if [ "$RAW_JSON" = true ]; then
    echo '{"source_type":"lark_wiki","query":"","success":true,"results":[]}'
  else
    echo "[lark_wiki] (no results)"
  fi
  exit 0
fi

# Step 2: Parse search results and fetch content
RESULTS_COUNT=0
FIRST_RESULT=true
if [ "$RAW_JSON" = true ]; then
  echo "{\"source_type\":\"lark_wiki\",\"query\":$(printf '%s' "$QUERY" | python3 -c "import sys,json; print(json.dumps(sys.stdin.read().strip()))"),\"success\":true,\"results\":["
fi

while IFS= read -r LINE; do
  [ -z "$LINE" ] && continue
  [ $RESULTS_COUNT -ge "$COUNT" ] && break

  DOC_TOKEN=$(echo "$LINE" | awk -F'|' '{print $1}' | tr -d ' ')
  TITLE=$(echo "$LINE" | awk -F'|' '{print $2}' | sed 's/^ *//;s/ *$//')
  URL=$(echo "$LINE" | awk -F'|' '{print $3}' | tr -d ' ')
  SPACE=$(echo "$LINE" | awk -F'|' '{print $4}' | tr -d ' ')
  SUMMARY=$(echo "$LINE" | awk -F'|' '{print $5}' | sed 's/^ *//;s/ *$//' | head -c 200)

  [ -z "$DOC_TOKEN" ] && continue
  [ -z "$TITLE" ] && TITLE="$DOC_TOKEN"

  # Fetch document content for richer preview
  DOC_CONTENT=""
  if [ -n "$DOC_TOKEN" ]; then
    DOC_CONTENT=$(lark-cli docs +fetch "$DOC_TOKEN" 2>/dev/null | head -c 300 || echo "")
  fi

  PREVIEW="${SUMMARY:-${DOC_CONTENT:0:200}}"
  RESULTS_COUNT=$((RESULTS_COUNT + 1))

  if [ "$RAW_JSON" = true ]; then
    [ "$FIRST_RESULT" = false ] && echo ","
    FIRST_RESULT=false
    echo "{\"title\":$(printf '%s' "$TITLE" | python3 -c "import sys,json; print(json.dumps(sys.stdin.read().strip()))"),\"path\":$(printf '%s' "$URL" | python3 -c "import sys,json; print(json.dumps(sys.stdin.read().strip()))"),\"content_preview\":$(printf '%s' "$PREVIEW" | python3 -c "import sys,json; print(json.dumps(sys.stdin.read().strip()))"),\"source_level\":\"A\",\"source_subtype\":\"wiki_doc\",\"metadata\":{\"space\":\"$SPACE\",\"doc_token\":\"$DOC_TOKEN\"}}"
  else
    echo "[lark_wiki] $TITLE"
    echo "  $URL"
    echo "  ${PREVIEW:0:200}"
    echo "  space: $SPACE  level: A"
    echo ""
  fi
done <<< "$SEARCH_OUTPUT"

if [ "$RAW_JSON" = true ]; then
  echo "]}"
fi