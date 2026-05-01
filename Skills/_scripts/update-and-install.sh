#!/usr/bin/env bash
# update-and-install.sh
# 从 Git 拉取最新源仓库 → 安装到 CC Switch

set -euo pipefail

REPO="$HOME/Documents/RichardHub/Git/Skills"
INSTALL_SCRIPT="$REPO/_scripts/install-to-ccswitch.sh"

cd "$REPO"

echo "=== 第一步: 检查 Git 仓库 ==="
if [ -d ".git" ]; then
  echo "✅ 是 Git 仓库"
  echo ""
  echo "=== 第二步: git pull ==="
  if git pull --ff-only; then
    echo "✅ 拉取成功"
  else
    echo "❌ git pull 失败，请手动解决冲突后重试"
    exit 1
  fi
else
  echo "⚠ 不是 Git 仓库，跳过 git pull"
fi

echo ""
echo "=== 第三步: 安装到 CC Switch ==="
if [ -f "$INSTALL_SCRIPT" ]; then
  bash "$INSTALL_SCRIPT"
else
  echo "❌ 安装脚本不存在: $INSTALL_SCRIPT"
  exit 1
fi

echo ""
echo "=== 完成 ==="
echo "请打开 CC Switch → 刷新 Skills → 用「文件复制」模式同步到目标工具"
