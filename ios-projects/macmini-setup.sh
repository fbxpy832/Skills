#!/bin/bash
# ============================================
# Mac Mini 开发环境一键同步脚本
# 在 Mac mini 上运行此脚本，自动拉取/同步项目
# ============================================

set -e

GIT_ROOT="$HOME/Documents/RichardHub/Git"
PROJECT="ios-projects/SwiftUtils"

echo "══════════════════════════════════════════"
echo "  Mac Mini iOS 开发环境同步"
echo "══════════════════════════════════════════"
echo ""

# 1. 检查 iCloud 同步状态
echo "☁️  检查 iCloud Drive…"
if [ -d "$HOME/Library/Mobile Documents/com~apple~CloudDocs" ]; then
    echo "✅ iCloud Drive 已启用"
else
    echo "❌ iCloud Drive 未启用，请先在系统设置中开启"
    exit 1
fi

# 2. 等待 iCloud 同步完成
echo "⏳ 等待 iCloud 文件同步…"
echo "   如果项目文件较多，请耐心等待"
echo "   可在 Finder 侧边栏查看 iCloud 同步进度"
echo ""

# 3. 检查项目目录
PROJECT_DIR="$GIT_ROOT/$PROJECT"
if [ -d "$PROJECT_DIR" ]; then
    echo "✅ 项目已同步到本地: $PROJECT_DIR"
else
    echo "⚠️  项目尚未同步到本地"
    echo "   请确保主 Mac 上的文件已通过 iCloud 上传完毕"
    echo "   有时需要等待几分钟，iCloud 文件才会出现在本机"
    echo ""
    echo "   检查路径: $PROJECT_DIR"
    exit 1
fi

# 4. 检查 Git 仓库
cd "$PROJECT_DIR"
if [ -d ".git" ]; then
    echo "✅ Git 仓库已就绪"
    echo "   当前分支: $(git branch --show-current)"
    echo "   最后提交: $(git log -1 --format='%h %s' 2>/dev/null || echo '无提交记录')"
else
    echo "⚠️  Git 仓库未初始化，正在初始化…"
    git init
    git branch -M main
    git add -A
    git commit -m "🎉 从 iCloud 同步 — 初始提交"
    echo "✅ Git 已初始化"
fi

# 5. 检查 Xcode 环境
echo ""
echo "🔧 检查开发环境…"
if xcodebuild -version &>/dev/null; then
    echo "✅ $(xcodebuild -version | head -1)"
else
    echo "❌ Xcode 未安装，请先从 App Store 安装"
    exit 1
fi

if swift --version &>/dev/null; then
    echo "✅ Swift $(swift --version | head -1 | awk '{print $4}')"
fi

# 6. 打开项目
echo ""
echo "══════════════════════════════════════════"
echo "✅ Mac mini 开发环境同步完成！"
echo ""
echo "下一步:"
echo "  1. 双击打开项目:"
echo "     open '$PROJECT_DIR/SwiftUtils.xcodeproj'"
echo ""
echo "  2. 在 Xcode 中选择模拟器，按 Cmd+R 运行"
echo ""
echo "  3. 日常同步建议:"
echo "     - 写完代码先 git commit"
echo "     - iCloud 会自动同步到另一台 Mac"
echo "     - 在另一台 Mac 上 git pull 即可更新"
echo "══════════════════════════════════════════"

# 询问是否立即打开
read -p "🚀 是否立即在 Xcode 中打开项目？(y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    open "$PROJECT_DIR/SwiftUtils.xcodeproj"
fi