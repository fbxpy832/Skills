#!/usr/bin/env bash
set -euo pipefail

# ============================================================================
# knowledge-obsidian.sh — Obsidian Vault Search Adapter
# ============================================================================
# Searches Markdown files in the configured Obsidian Vault.
#
# Usage:
#   knowledge-obsidian.sh "search query" [--count N] [--json] [--dry-run]
#   knowledge-obsidian.sh --check
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
    --help|-h)
      echo "Usage: knowledge-obsidian.sh [--query QUERY|QUERY] [--count N] [--json] [--dry-run] [--check]"
      exit 0 ;;
    --*)        echo "ERROR: Unknown option: $1" >&2; exit 1 ;;
    *)          QUERY="$1"; shift ;;
  esac
done

# Availability check
if [ "$CHECK" = true ]; then
  if ! command -v rg &>/dev/null; then echo "ERROR: rg (ripgrep) not found. Install with: brew install ripgrep" >&2; exit 1; fi
  VAULT_DIR="${DEEP_RESEARCH_OBSIDIAN_VAULT_DIR:-}"
  if [ -z "$VAULT_DIR" ]; then echo "ERROR: DEEP_RESEARCH_OBSIDIAN_VAULT_DIR not set" >&2; exit 1; fi
  if [ ! -d "$VAULT_DIR" ]; then echo "ERROR: Vault dir not found: $VAULT_DIR" >&2; exit 1; fi
  echo "AVAILABLE: Obsidian Vault at $VAULT_DIR"
  exit 0
fi

if [ -z "${QUERY:-}" ]; then echo "ERROR: Missing search query." >&2; exit 1; fi

VAULT_DIR="${DEEP_RESEARCH_OBSIDIAN_VAULT_DIR:-}"
if [ -z "$VAULT_DIR" ] || [ ! -d "$VAULT_DIR" ]; then
  echo "ERROR: DEEP_RESEARCH_OBSIDIAN_VAULT_DIR not set or invalid: $VAULT_DIR" >&2
  exit 2
fi

if [ "$DRY_RUN" = true ]; then
  echo "DRY RUN: rg -l -i --glob '*.md' -g '!.obsidian' -g '!.git' \"$QUERY\" \"$VAULT_DIR\""
  exit 0
fi

# Find matching .md files using find + rg (bash 3.2 compatible, no mapfile/globstar)
FILES=""
while IFS= read -r -d '' FILE; do
  if rg -l -i --max-count 1 "$QUERY" "$FILE" &>/dev/null; then
    FILES="$FILES|$FILE"
  fi
done < <(find "$VAULT_DIR" -name '*.md' -not -path '*/.obsidian/*' -not -path '*/.git/*' -type f 2>/dev/null)

if [ -z "$FILES" ]; then
  if [ "$RAW_JSON" = true ]; then
    echo '{"source_type":"obsidian","query":"","success":true,"results":[]}'
  else
    echo "[obsidian] (no results)"
  fi
  exit 0
fi

RESULTS_COUNT=0
FIRST_RESULT=true
if [ "$RAW_JSON" = true ]; then
  echo "{\"source_type\":\"obsidian\",\"query\":$(printf '%s' "$QUERY" | python3 -c "import sys,json; print(json.dumps(sys.stdin.read().strip()))"),\"success\":true,\"results\":["
fi

# Process each file
SAVEIFS=$IFS
IFS='|'
for FILE in $FILES; do
  [ -z "$FILE" ] && continue
  [ $RESULTS_COUNT -ge "$COUNT" ] && break

  REL_PATH="${FILE#$VAULT_DIR/}"
  DIR_NAME="$(dirname "$REL_PATH")"

  # Classify by directory
  case "$DIR_NAME" in
    llm-wiki*|karpathy-wiki*)  SOURCE_SUBTYPE="local_wiki"; SOURCE_LEVEL="B" ;;
    *)                         SOURCE_SUBTYPE="local_vault"; SOURCE_LEVEL="B" ;;
  esac

  # Get title (first # line) or filename
  TITLE="$(grep -m1 '^# ' "$FILE" 2>/dev/null | sed 's/^# //' || echo "$(basename "$FILE" .md)")"

  # Get content preview
  PREVIEW="$(rg -N --max-length 200 "$QUERY" "$FILE" 2>/dev/null | head -3 | tr '\n' ' ' | head -c 200 || echo "")"
  [ -z "$PREVIEW" ] && PREVIEW="$(head -30 "$FILE" | tail -20 | tr '\n' ' ' | head -c 200)"

  # Get file modification date
  MOD_DATE=$(date -r "$FILE" "+%Y-%m-%d" 2>/dev/null || echo "unknown")

  RESULTS_COUNT=$((RESULTS_COUNT + 1))

  if [ "$RAW_JSON" = true ]; then
    [ "$FIRST_RESULT" = false ] && echo ","
    FIRST_RESULT=false
    echo "{\"title\":$(printf '%s' "$TITLE" | python3 -c "import sys,json; print(json.dumps(sys.stdin.read().strip()))"),\"path\":$(printf '%s' "$REL_PATH" | python3 -c "import sys,json; print(json.dumps(sys.stdin.read().strip()))"),\"content_preview\":$(printf '%s' "$PREVIEW" | python3 -c "import sys,json; print(json.dumps(sys.stdin.read().strip()))"),\"source_level\":\"$SOURCE_LEVEL\",\"source_subtype\":\"$SOURCE_SUBTYPE\",\"metadata\":{\"file_date\":\"$MOD_DATE\",\"directory\":\"$DIR_NAME\"}}"
  else
    echo "[obsidian:$SOURCE_SUBTYPE] $TITLE"
    echo "  $REL_PATH"
    echo "  ${PREVIEW:0:200}"
    echo "  date: $MOD_DATE  level: $SOURCE_LEVEL"
    echo ""
  fi
done
IFS=$SAVEIFS

if [ "$RAW_JSON" = true ]; then
  echo "]}"
fi