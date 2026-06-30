#!/usr/bin/env bash
set -euo pipefail

REPORT_FILE="${1:-}"
MODE="${MODE:-balanced}"
SOURCE_LOG=""

shift || true
while [ "$#" -gt 0 ]; do
  case "$1" in
    --mode) MODE="${2:-balanced}"; shift 2 ;;
    --source-log) SOURCE_LOG="${2:-}"; shift 2 ;;
    --help|-h)
      echo "Usage: audit-report.sh REPORT.md [--mode MODE] [--source-log FILE]"
      exit 0
      ;;
    *)
      echo "ERROR: Unknown argument: $1" >&2
      exit 2
      ;;
  esac
done

if [ -z "$REPORT_FILE" ] || [ ! -f "$REPORT_FILE" ]; then
  echo "ERROR: report file not found: ${REPORT_FILE:-missing}" >&2
  exit 1
fi

declared_mode="$(grep -m1 -i '研究模式\|运行模式\|mode:' "$REPORT_FILE" 2>/dev/null | sed 's/^.*[:：]//; s/[>`*"]//g; s/^ *//; s/ *$//' || true)"
if printf '%s' "$declared_mode" | grep -qi 'high_quality'; then
  MODE="high_quality"
elif printf '%s' "$declared_mode" | grep -qi 'balanced'; then
  MODE="balanced"
elif printf '%s' "$declared_mode" | grep -qi 'cost_saving'; then
  MODE="cost_saving"
elif printf '%s' "$declared_mode" | grep -qi 'draft_fast'; then
  MODE="draft_fast"
fi

failures=0
warnings=0
major_issues=""
minor_issues=""

add_major() {
  failures=$((failures + 1))
  major_issues="${major_issues}- $1
"
}

add_minor() {
  warnings=$((warnings + 1))
  minor_issues="${minor_issues}- $1
"
}

contains() {
  grep -qi "$1" "$REPORT_FILE" 2>/dev/null
}

line_count="$(wc -l < "$REPORT_FILE" | tr -d ' ')"
url_count="$((grep -Eo 'https?://[^] )]+' "$REPORT_FILE" 2>/dev/null || true) | wc -l | tr -d ' ')"
citation_count="$(grep -ci '^来源类型:\|来源类型:' "$REPORT_FILE" 2>/dev/null || true)"
citation_count="$(printf '%s' "$citation_count" | tr -d ' ')"
table_line_count="$(grep -c '^|' "$REPORT_FILE" 2>/dev/null || true)"
table_line_count="$(printf '%s' "$table_line_count" | tr -d ' ')"
h2_count="$(grep -c '^## ' "$REPORT_FILE" 2>/dev/null || true)"
h2_count="$(printf '%s' "$h2_count" | tr -d ' ')"

if [ "${url_count:-0}" -eq 0 ] && [ "${citation_count:-0}" -lt 3 ]; then
  add_major "缺少可追溯来源。未发现 URL 或足够的标准来源条目，不能支撑深度研究结论。"
fi

if ! contains '来源类型\|external_authoritative\|external_media\|local_vault\|model_reasoning'; then
  add_major "缺少来源类型分类。必须区分 external_authoritative / external_media / local_vault / model_reasoning 等。"
fi

if ! contains '来源等级\|级别:.*[SABCD]\|S/A/B/C/D'; then
  add_major "缺少来源等级。核心数据无法判断是否达到 S/A/B 级支撑要求。"
fi

if ! contains '数据缺口\|待补充核验\|必须补充核验\|需进一步核验'; then
  add_major "缺少数据缺口或待核验清单。"
fi

if ! contains '人工复核\|人工核验\|需复核'; then
  add_major "缺少人工复核事项。"
fi

if ! contains '反证\|失败案例\|替代路径\|不确定性'; then
  add_major "缺少反证、失败案例或不确定性扫描。"
fi

if ! contains '真实模型检测状态\|模型使用未能自动验证\|not_verified\|verified'; then
  add_major "缺少真实模型检测状态，或模型声明不可审计。"
fi

if ! contains '模型路由执行状态\|real_switch\|instruction_level_recommendation\|unable_to_verify'; then
  add_minor "缺少模型路由执行状态。"
fi

if ! contains '搜索状态\|search_status'; then
  add_major "缺少搜索状态。"
fi

if ! contains 'source_failure_log'; then
  add_major "缺少 source_failure_log 状态。"
fi

if contains '机器审计 FAIL\|audit_grade[:=].*FAIL\|审计等级.*待审'; then
  add_major "报告正文声明机器审计 FAIL 或待审，最终审计不得返回 PASS。"
fi

if contains '搜索状态.*部分成功\|search_status[:=].*partial_success'; then
  if [ "$MODE" = "high_quality" ]; then
    add_major "high_quality 模式下搜索仅部分成功，审计等级不得为 PASS。"
  else
    add_minor "搜索状态为部分成功，交付摘要需说明替代方案和剩余风险。"
  fi
fi

if contains '质量审计[:：].*通过\|audit_grade[:：].*PASS'; then
  if [ "${url_count:-0}" -eq 0 ] || ! contains 'audit_grade\|审计等级'; then
    add_major "报告声称质量审计通过，但缺少机器可审计的 audit_grade、来源和证据字段。"
  fi
fi

if [ "$MODE" = "high_quality" ] && contains 'not_verified\|未能自动验证'; then
  add_major "high_quality 模式下模型不可验证，审计等级不得为 PASS。"
fi

if grep -Ei '\|.*(腾讯网|搜狐|网易|博客园|知乎|财富号|新浪财经).*external_authoritative|external_authoritative.*(腾讯网|搜狐|网易|博客园|知乎|财富号|新浪财经)' "$REPORT_FILE" >/dev/null 2>&1; then
  add_major "来源等级疑似过高：媒体转载、博客或财富号不得标为 external_authoritative。"
fi

if [ -n "$SOURCE_LOG" ] && [ -f "$SOURCE_LOG" ]; then
  failure_count="$(grep -c 'failure_time:' "$SOURCE_LOG" 2>/dev/null || true)"
  failure_count="$(printf '%s' "${failure_count:-0}" | tr -cd '0-9')"
  if [ "${failure_count:-0}" -gt 0 ] && contains '正式版\|质量审计[:：].*通过\|audit_grade[:：].*PASS'; then
    add_major "source_failure_log 存在失败记录，但报告仍呈现为正式通过。"
  fi
fi

if [ "${h2_count:-0}" -gt 0 ] && [ "${table_line_count:-0}" -gt "$((line_count / 3))" ]; then
  add_minor "表格占比偏高，需增加连续分析和表格后的决策含义。"
fi

if contains '市场规模\|营收\|CAGR\|成本\|亿元\|万'; then
  if ! contains '保守情景\|中性情景\|积极情景'; then
    add_major "涉及市场空间、营收或成本测算，但缺少保守/中性/积极三情景。"
  fi
fi

if [ "$failures" -gt 0 ]; then
  audit_grade="FAIL"
  report_usability="仅供参考"
elif [ "$warnings" -gt 0 ]; then
  audit_grade="CONDITIONAL_PASS"
  report_usability="内部初稿"
else
  audit_grade="PASS"
  report_usability="正式版"
fi

cat <<EOF
audit_grade=$audit_grade
report_usability=$report_usability
major_issue_count=$failures
minor_issue_count=$warnings
url_count=${url_count:-0}
citation_count=${citation_count:-0}
table_line_count=${table_line_count:-0}
line_count=${line_count:-0}
major_issues:
${major_issues:-}
minor_issues:
${minor_issues:-}
EOF

if [ "$audit_grade" = "FAIL" ]; then
  exit 3
fi
