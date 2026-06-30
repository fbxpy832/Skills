#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
PROJECT_DIR="${PROJECT_DIR:-$(pwd)}"

# shellcheck disable=SC1091
source "$SCRIPT_DIR/lib/config-resolver.sh"

_RUNTIME_OUTPUT_DIR="${DEEP_RESEARCH_OUTPUT_DIR:-}"
_RUNTIME_STRICT_OUTPUT_DIR="${DEEP_RESEARCH_STRICT_OUTPUT_DIR:-}"
deep_research_source_config || true
[ -n "$_RUNTIME_OUTPUT_DIR" ] && DEEP_RESEARCH_OUTPUT_DIR="$_RUNTIME_OUTPUT_DIR"
[ -n "$_RUNTIME_STRICT_OUTPUT_DIR" ] && DEEP_RESEARCH_STRICT_OUTPUT_DIR="$_RUNTIME_STRICT_OUTPUT_DIR"

WRITER_FILE=""
TASK_FILE=""
RUN_DIR=""
MODE="${MODE:-balanced}"
SOURCE_LOG=""
EXECUTION_CONTEXT=""

while [ "$#" -gt 0 ]; do
  case "$1" in
    --writer) WRITER_FILE="${2:-}"; shift 2 ;;
    --task) TASK_FILE="${2:-}"; shift 2 ;;
    --run-dir) RUN_DIR="${2:-}"; shift 2 ;;
    --mode) MODE="${2:-balanced}"; shift 2 ;;
    --source-log) SOURCE_LOG="${2:-}"; shift 2 ;;
    --execution-context) EXECUTION_CONTEXT="${2:-}"; shift 2 ;;
    --help|-h)
      echo "Usage: finalize-report.sh --writer FILE --task FILE --run-dir DIR [--mode MODE] [--source-log FILE] [--execution-context FILE]"
      exit 0
      ;;
    *)
      echo "ERROR: Unknown argument: $1" >&2
      exit 2
      ;;
  esac
done

if [ -z "$WRITER_FILE" ] || [ ! -f "$WRITER_FILE" ]; then
  echo "ERROR: writer output not found: ${WRITER_FILE:-missing}" >&2
  exit 1
fi

if [ -z "$TASK_FILE" ] || [ ! -f "$TASK_FILE" ]; then
  echo "ERROR: task file not found: ${TASK_FILE:-missing}" >&2
  exit 1
fi

if [ -z "$RUN_DIR" ]; then
  RUN_DIR="$(dirname "$(dirname "$WRITER_FILE")")"
fi

CONFIGURED_FINAL_DIR="${DEEP_RESEARCH_OUTPUT_DIR:-}"
FINAL_DIR="${CONFIGURED_FINAL_DIR:-$RUN_DIR/final}"
OUTPUT_DIR_STATUS="configured"
OUTPUT_DIR_NOTE=""

if ! mkdir -p "$FINAL_DIR" 2>/dev/null || [ ! -d "$FINAL_DIR" ] || [ ! -w "$FINAL_DIR" ]; then
  if [ "${DEEP_RESEARCH_STRICT_OUTPUT_DIR:-0}" = "1" ]; then
    echo "ERROR: final output directory is not writable: $FINAL_DIR" >&2
    exit 1
  fi
  OUTPUT_DIR_STATUS="fallback"
  OUTPUT_DIR_NOTE="Configured output directory is not writable or not visible from this runtime: $FINAL_DIR"
  FINAL_DIR="$RUN_DIR/final"
  mkdir -p "$FINAL_DIR"
  if [ ! -d "$FINAL_DIR" ] || [ ! -w "$FINAL_DIR" ]; then
    echo "ERROR: fallback output directory is not writable: $FINAL_DIR" >&2
    exit 1
  fi
fi

first_match() {
  local pattern="$1"
  shift
  grep -h -i "$pattern" "$@" 2>/dev/null | head -1 | sed 's/^.*://; s/^# //; s/^ *//; s/ *$//' || true
}

safe_name() {
  sed 's/[\/:*?"<>|]//g; s/  */ /g; s/^ *//; s/ *$//' | cut -c 1-"$1"
}

report_title="$(grep -h -i "^report_title:\|^# " "$WRITER_FILE" 2>/dev/null | head -1 | sed 's/^.*://; s/^# //; s/^ *//; s/ *$//' | cut -c 1-80 || true)"
research_topic="$(head -1 "$TASK_FILE" 2>/dev/null | sed 's/^# *//' | safe_name 60 || true)"
report_type="$(first_match "report_type:\|任务类型:" "$WRITER_FILE" "${EXECUTION_CONTEXT:-/dev/null}" | cut -c 1-30)"
search_status="$(first_match "search_status:\|搜索状态:" "$WRITER_FILE" "${SOURCE_LOG:-/dev/null}" | cut -c 1-30)"
source_types="$(first_match "source_types:\|来源使用情况:" "$WRITER_FILE" | cut -c 1-60)"
report_usability="$(first_match "report_usability:\|报告可用性:" "$WRITER_FILE" | cut -c 1-30)"

[ -n "$research_topic" ] || research_topic="${report_title:-research}"
[ -n "$report_type" ] || report_type="研究报告"
[ -n "$search_status" ] || search_status="unknown"
[ -n "$report_usability" ] || report_usability="正式版"

topic_clean="$(printf '%s' "$research_topic" | safe_name 60)"
type_clean="$(printf '%s' "$report_type" | safe_name 30)"
[ -n "$topic_clean" ] || topic_clean="research"
[ -n "$type_clean" ] || type_clean="研究报告"

source_tag=""
if [ -n "$source_types" ]; then
  has_external="$(printf '%s' "$source_types" | grep -ci "external" || true)"
  has_local="$(printf '%s' "$source_types" | grep -ci "local\|vault\|wiki" || true)"
  has_model="$(printf '%s' "$source_types" | grep -ci "model_reasoning\|推理" || true)"
  if [ "${has_external:-0}" -gt 0 ] && [ "${has_local:-0}" -gt 0 ]; then
    source_tag="-多源版"
  elif [ "${has_local:-0}" -gt 0 ] && [ "${has_external:-0}" -eq 0 ]; then
    source_tag="-Vault版"
  elif [ "${has_model:-0}" -gt 0 ] && [ "${has_external:-0}" -eq 0 ] && [ "${has_local:-0}" -eq 0 ]; then
    source_tag="-模型推理版"
  fi
fi

deg_tag=""
if printf '%s' "$search_status" | grep -qi "failed\|no_results" 2>/dev/null; then
  deg_tag="-离线初稿"
elif printf '%s' "$search_status" | grep -qi "partial_success" 2>/dev/null; then
  deg_tag="-待联网核验版"
fi

if [ -n "$SOURCE_LOG" ] && [ -f "$SOURCE_LOG" ]; then
  failure_count="$(grep -c "failure_time:" "$SOURCE_LOG" 2>/dev/null || true)"
  failure_count="$(printf '%s' "${failure_count:-0}" | tr -cd '0-9')"
  if [ "${failure_count:-0}" -gt 0 ] && [ -z "$deg_tag" ]; then
    deg_tag="-待联网核验版"
  fi
else
  failure_count="0"
fi

date_tag="$(date '+%Y-%m-%d')"
base_name="${topic_clean}-${type_clean}${source_tag}${deg_tag}"
filename="${base_name}-${date_tag}.md"

if [ -f "$FINAL_DIR/$filename" ]; then
  v=2
  while [ -f "$FINAL_DIR/${base_name}-v${v}-${date_tag}.md" ]; do
    v=$((v + 1))
  done
  filename="${base_name}-v${v}-${date_tag}.md"
fi

FINAL_PATH="$FINAL_DIR/$filename"
writer_body="$(awk 'NR==1 && /^# / {next} {print}' "$WRITER_FILE")"

{
  echo "# ${topic_clean}：${type_clean}"
  echo ""
  if [ -n "$deg_tag" ]; then
    echo "---"
    echo "报告状态: ${deg_tag#-}"
    echo "搜索状态: $search_status"
    echo "报告可用性: $report_usability"
    echo "---"
    echo ""
  fi
  printf '%s\n' "$writer_body"
  echo ""
  echo "---"
  echo ""
  echo "## 报告信息"
  echo ""
  echo "- 生成日期: $date_tag"
  echo "- 运行模式: $MODE"
  echo "- 搜索状态: $search_status"
  echo "- 报告可用性: $report_usability"
  echo "- 来源类型: ${source_types:-未分类}"
  echo "- source_failure_log: ${failure_count:-0} entries"
  echo "- 配置输出目录: ${CONFIGURED_FINAL_DIR:-未配置}"
  echo "- 输出目录状态: $OUTPUT_DIR_STATUS"
  if [ -n "$OUTPUT_DIR_NOTE" ]; then
    echo "- 输出目录说明: $OUTPUT_DIR_NOTE"
  fi
  echo "- 最终保存路径: $FINAL_PATH"
} > "$FINAL_PATH"

if [ ! -s "$FINAL_PATH" ]; then
  echo "ERROR: final report was not written: $FINAL_PATH" >&2
  exit 1
fi

AUDIT_GRADE="not_run"
AUDIT_OUTPUT=""
if [ -x "$SCRIPT_DIR/audit-report.sh" ]; then
  AUDIT_OUTPUT="$("$SCRIPT_DIR/audit-report.sh" "$FINAL_PATH" --mode "$MODE" --source-log "${SOURCE_LOG:-}" 2>&1 || true)"
  AUDIT_GRADE="$(printf '%s\n' "$AUDIT_OUTPUT" | sed -n 's/^audit_grade=//p' | head -1)"
  [ -n "$AUDIT_GRADE" ] || AUDIT_GRADE="unknown"
  {
    echo ""
    echo "---"
    echo ""
    echo "## 自动审计结果"
    echo ""
    echo '```text'
    printf '%s\n' "$AUDIT_OUTPUT"
    echo '```'
  } >> "$FINAL_PATH"
fi

printf 'final_report_path=%s\n' "$FINAL_PATH"
printf 'final_output_dir=%s\n' "$FINAL_DIR"
printf 'final_output_dir_status=%s\n' "$OUTPUT_DIR_STATUS"
printf 'final_audit_grade=%s\n' "$AUDIT_GRADE"
if [ -n "$OUTPUT_DIR_NOTE" ]; then
  printf 'final_output_dir_note=%s\n' "$OUTPUT_DIR_NOTE"
fi
