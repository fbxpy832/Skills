#!/usr/bin/env bash
# install-to-ccswitch.sh
# 将源仓库中的 Skill 安装到 CC Switch 工作目录
# 源: ~/Documents/RichardHub/Git/Skills
# 目标: ~/.cc-switch/skills

set -euo pipefail

SRC="$HOME/Documents/RichardHub/Git/Skills"
DST="$HOME/.cc-switch/skills"

EXCLUDE_DIRS=".git _scripts _archive _reports _templates node_modules .cache"
RSYNC_EXCLUDES="--exclude=.git --exclude=.DS_Store --exclude=node_modules --exclude=.cache --exclude=*.log --exclude=*.tmp --exclude=.env --exclude=.env.* --exclude=secrets.* --exclude=*.key --exclude=*.pem"

if [ ! -d "$SRC" ]; then
  echo "❌ 源仓库不存在: $SRC"
  exit 1
fi

mkdir -p "$DST"

echo "📋 扫描源仓库 Skill..."
echo ""

SKILLS=()
SKIP_LIST=()

for dir in "$SRC"/*/; do
  name=$(basename "$dir")

  # 跳过排除目录
  skip=0
  for ex in $EXCLUDE_DIRS; do
    [ "$name" = "$ex" ] && skip=1 && break
  done
  [ $skip -eq 1 ] && { SKIP_LIST+=("$name"); continue; }

  # 检查是否为 Skill（需含 SKILL.md 或 README.md）
  if [ -f "$dir/SKILL.md" ] || [ -f "$dir/README.md" ]; then
    SKILLS+=("$name")
  else
    SKIP_LIST+=("$name")
  fi
done

if [ ${#SKILLS[@]} -eq 0 ]; then
  echo "⚠ 没有发现可安装的 Skill。"
  exit 0
fi

echo "即将安装以下 ${#SKILLS[@]} 个 Skill 到 $DST:"
for s in "${SKILLS[@]}"; do
  echo "   📦 $s"
done
echo ""

# 安装每个 Skill
INSTALLED=()
FAILED=()
for s in "${SKILLS[@]}"; do
  src_dir="$SRC/$s"
  dst_dir="$DST/$s"

  # 确保目标目录存在（用于 rsync --delete）
  mkdir -p "$dst_dir"

  if rsync -a --delete $RSYNC_EXCLUDES "$src_dir/" "$dst_dir/"; then
    INSTALLED+=("$s")
  else
    FAILED+=("$s")
  fi
done

echo ""
echo "=== 安装结果 ==="
echo "✅ 成功: ${#INSTALLED[@]} 个"
for s in "${INSTALLED[@]}"; do
  echo "   ✅ $s"
done

if [ ${#FAILED[@]} -gt 0 ]; then
  echo "❌ 失败: ${#FAILED[@]} 个"
  for s in "${FAILED[@]}"; do
    echo "   ❌ $s"
  done
fi

echo ""
echo "=============================="
echo "下一步:"
echo "1. 打开 CC Switch"
echo "2. 刷新 Skills"
echo "3. 用「文件复制」模式同步到 Claude / Codex / OpenCode / Hermes / OpenClaw"
echo "=============================="
