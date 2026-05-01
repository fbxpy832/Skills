#!/usr/bin/env bash
# check-install-status.sh
# 对比源仓库与 CC Switch 的 Skill 安装状态
# 兼容 macOS 系统 bash (v3)

set -euo pipefail

SRC="$HOME/Documents/RichardHub/Git/Skills"
DST="$HOME/.cc-switch/skills"

EXCLUDE_DIRS=".git _scripts _archive _reports _templates node_modules .cache"

echo "=== Skill 安装状态对比 ==="
printf "%-35s %-8s %-10s %-8s %s\n" "Skill" "源存在" "已安装" "SKILL.md" "状态"
printf "%s\n" "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

HAS_ISSUE=0

# 收集所有 src skills
for dir in "$SRC"/*/; do
  name=$(basename "$dir")
  skip=0
  for ex in $EXCLUDE_DIRS; do
    [ "$name" = "$ex" ] && skip=1 && break
  done
  [ $skip -eq 1 ] && continue

  src_has_md="否"
  [ -f "$dir/SKILL.md" ] && src_has_md="是"

  if [ ! -f "$dir/SKILL.md" ] && [ ! -f "$dir/README.md" ]; then
    continue
  fi

  dst_has_md="否"
  if [ -d "$DST/$name" ]; then
    [ -f "$DST/$name/SKILL.md" ] && dst_has_md="是"
  fi

  if [ -d "$DST/$name" ]; then
    if [ "$src_has_md" = "是" ] && [ "$dst_has_md" = "是" ]; then
      status="✅ 已安装"
    else
      status="⚠ 需检查"
      HAS_ISSUE=1
    fi
    printf "%-35s %-8s %-10s %-8s %s\n" "$name" "是" "是" "$dst_has_md" "$status"
  else
    printf "%-35s %-8s %-10s %-8s %s\n" "$name" "是" "否" "—" "⏳ 未安装"
    HAS_ISSUE=1
  fi
done

# 检查 DST 中多余的 skill
for dir in "$DST"/*/; do
  [ -d "$dir" ] || continue
  name=$(basename "$dir")
  if [ ! -d "$SRC/$name" ]; then
    printf "%-35s %-8s %-10s %-8s %s\n" "$name" "否" "是" "—" "⚠ 源缺失"
    HAS_ISSUE=1
  fi
done

echo ""
if [ $HAS_ISSUE -eq 0 ]; then
  echo "✅ 源仓库与 CC Switch 完全一致"
else
  echo "⚠ 存在差异，请运行 ./_scripts/install-to-ccswitch.sh 同步"
fi
