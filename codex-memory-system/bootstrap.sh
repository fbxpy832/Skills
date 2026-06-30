#!/bin/bash
# bootstrap.sh - Codex 记忆自动化系统安装器
#
# 用法:
#   ./bootstrap.sh                    # 标准安装
#   ./bootstrap.sh --vault <路径>     # 指定 Obsidian vault 路径
#   ./bootstrap.sh --dry-run          # 预览，不实际安装
#
# 在新 Mac 上:
#   1. 确保 iCloud 已同步 Obsidian vault
#   2. 运行本脚本
#   3. 检查验证输出
set -uo pipefail

PKG_DIR="$(cd "$(dirname "$0")" && pwd)"

# ---------- 颜色 & 辅助 ----------
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
info()  { echo -e "  ${GREEN}->${NC} $*"; }
warn()  { echo -e "  ${YELLOW}WARN${NC} $*"; }
err()   { echo -e "  ${RED}ERROR${NC} $*"; }
title() { echo -e "\n${GREEN}===${NC} $* ${GREEN}===${NC}"; }
DRY_RUN=false
VAULT_PATH=""

while [ $# -gt 0 ]; do
    case "$1" in
        --vault) VAULT_PATH="$2"; shift ;;
        --dry-run) DRY_RUN=true ;;
        --help) head -20 "$0"; exit 0 ;;
        *) err "未知选项: $1"; exit 1 ;;
    esac
    shift
done

run() {
    if $DRY_RUN; then echo -e "  ${YELLOW}[DRY-RUN]${NC} $*"; return 0; fi
    "$@"
}

# ---------- 0. 依赖检查 ----------
title "依赖检查"
DEPS_OK=true
for cmd in python3 rg; do
    if command -v "$cmd" &>/dev/null; then
        info "$cmd: $(command -v "$cmd")"
    else
        err "$cmd 未安装，请运行: brew install $cmd"
        DEPS_OK=false
    fi
done
$DEPS_OK || exit 1

# ---------- 1. Vault 路径检测 ----------
title "Obsidian Vault 检测"

CANDIDATE_ROOTS=(
    "$HOME/Library/Mobile Documents/iCloud~md~obsidian/Documents/RichardHub"
    "$HOME/Library/Mobile Documents/com~apple~CloudDocs/Obsidian/Richardhub"
    "$HOME/Documents/RichardHub/RichardHub"
)

if [ -n "$VAULT_PATH" ]; then
    VAULT="$VAULT_PATH"
elif [ -f "$HOME/.config/obsidian-article-extractor/vault-path" ]; then
    VAULT=$(cat "$HOME/.config/obsidian-article-extractor/vault-path" | sed "s|^~|$HOME|")
else
    VAULT=""
    for root in "${CANDIDATE_ROOTS[@]}"; do
        if [ -d "$root/Codex-Memory" ]; then
            VAULT="$root"
            break
        fi
    done
fi

if [ -z "$VAULT" ]; then
    warn "未自动找到 Obsidian vault。"
    warn "请确认 iCloud 同步已完成: ls ~/Library/Mobile\\ Documents/iCloud~md~obsidian/Documents/"
    warn "然后手动指定: ./bootstrap.sh --vault /path/to/vault"
    exit 1
fi
info "Vault: $VAULT"

if [ ! -d "$VAULT/Codex-Memory" ]; then
    err "Vault 中缺少 Codex-Memory/ 目录"
    exit 1
fi

# ---------- 2. 安装脚本 ----------
title "安装自动化脚本"

AUTO_DIR="$HOME/.codex/memory-automation"
run mkdir -p "$AUTO_DIR/scripts" "$AUTO_DIR/logs"

for f in "$PKG_DIR/scripts/"*.sh "$PKG_DIR/scripts/extract_candidates.py"; do
    fn=$(basename "$f")
    run cp "$f" "$AUTO_DIR/scripts/$fn"
    run chmod +x "$AUTO_DIR/scripts/$fn"
    info "installed: $fn"
done

# ---------- 3. 安装 codex-mem CLI ----------
title "安装 codex-mem CLI"

run mkdir -p "$HOME/.local/bin"
run cp "$PKG_DIR/cli/codex-mem" "$HOME/.local/bin/codex-mem"
run chmod +x "$HOME/.local/bin/codex-mem"

for cmd in memory_search.sh sync_memory.sh review_memory.sh run_all.sh; do
    run ln -sf "$AUTO_DIR/scripts/$cmd" "$HOME/.local/bin/$cmd"
    info "linked: $cmd"
done

if ! grep -q '.local/bin' "$HOME/.zshrc" 2>/dev/null; then
    echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$HOME/.zshrc"
    info "已将 ~/.local/bin 加入 PATH (需 source ~/.zshrc 或重启终端)"
fi

info "codex-mem: $(command -v codex-mem 2>/dev/null || echo '需要重启终端或 source ~/.zshrc')"

# ---------- 4. 安装 shell 启动同步钩子 ----------
title "安装 shell 启动同步钩子"

ZSHRC="$HOME/.zshrc"
STARTUP_SYNC_MARKER="codex-memory startup sync"

if grep -q "$STARTUP_SYNC_MARKER" "$ZSHRC" 2>/dev/null; then
    info "~/.zshrc 已包含启动同步钩子"
else
    if $DRY_RUN; then
        echo -e "  ${YELLOW}[DRY-RUN]${NC} 将向 $ZSHRC 追加 codex-memory 启动同步钩子"
    else
        touch "$ZSHRC"
        cat >> "$ZSHRC" <<'EOF'

# >>> codex-memory startup sync >>>
# Run memory sync in the background for interactive shells with a cooldown.
if [[ $- == *i* ]]; then
  _codex_mem_startup_sync() {
    local sync_script="$HOME/.codex/memory-automation/scripts/sync_memory.sh"
    local stamp_file="$HOME/.codex/memory-automation/.startup-sync-stamp"
    local now cooldown last_run
    [[ -x "$sync_script" ]] || return 0
    cooldown=300
    now=$(date +%s)
    last_run=0
    [[ -f "$stamp_file" ]] && last_run=$(cat "$stamp_file" 2>/dev/null || echo 0)
    if (( now - last_run >= cooldown )); then
      mkdir -p "${stamp_file:h}"
      print -r -- "$now" > "$stamp_file"
      nohup "$sync_script" >/dev/null 2>&1 &!
    fi
  }
  _codex_mem_startup_sync
  unset -f _codex_mem_startup_sync
fi
# <<< codex-memory startup sync <<<
EOF
        info "已向 ~/.zshrc 追加启动同步钩子（300 秒冷却，后台执行）"
    fi
fi

# ---------- 5. 创建 Obsidian 管线目录 ----------
title "创建 Obsidian 记忆管线目录"

for d in pending review approved; do
    target="$VAULT/Codex-Input/$d"
    if [ ! -d "$target" ]; then
        run mkdir -p "$target"
        info "创建: $d/"
    else
        info "已存在: $d/"
    fi
done

# ---------- 6. 安装 launchd ----------
title "安装 launchd 定时任务"

run mkdir -p "$HOME/Library/LaunchAgents"

for plist in "$PKG_DIR/launchd/"*.plist; do
    fn=$(basename "$plist")
    dest="$HOME/Library/LaunchAgents/$fn"
    if $DRY_RUN; then
        echo -e "  ${YELLOW}[DRY-RUN]${NC} sed替换__HOME__ → $HOME 并写入 $dest"
        continue
    fi
    sed "s|__HOME__|$HOME|g" "$plist" > "$dest"
    # 卸载旧的再加载
    launchctl unload "$dest" 2>/dev/null || true
    launchctl load "$dest"
    info "loaded: $fn"
done

# ---------- 7. 首次运行 ----------
title "首次运行"

if $DRY_RUN; then
    info "[DRY-RUN] 将执行:"
    info "  python3 $AUTO_DIR/scripts/extract_candidates.py --days 30"
    info "  bash $AUTO_DIR/scripts/sync_memory.sh"
    info "  bash $AUTO_DIR/scripts/review_memory.sh"
    info ""
    info "部署验证:"
    info "  codex-mem status"
    info "  $AUTO_DIR/scripts/sync_memory.sh --status-only"
else
    echo ""
    info "抽取候选记忆 ..."
    python3 "$AUTO_DIR/scripts/extract_candidates.py" --days 30 || warn "抽取未完全成功"

    info "首次同步 ..."
    bash "$AUTO_DIR/scripts/sync_memory.sh" || warn "同步未完全成功"

    info "生成审计报告 ..."
    bash "$AUTO_DIR/scripts/review_memory.sh" || warn "审计未完全成功"
fi

# ---------- 8. 验证 ----------
title "验证"

if $DRY_RUN; then
    info "安装预览完成。实际安装时移除 --dry-run 参数。"
    exit 0
fi

echo ""
info "codex-mem status:"
codex-mem status 2>&1 || warn "codex-mem status 失败"

echo ""
info "sync status:"
bash "$AUTO_DIR/scripts/sync_memory.sh" --status-only

echo ""
info "shell startup sync:"
if grep -q "$STARTUP_SYNC_MARKER" "$ZSHRC" 2>/dev/null; then
    info "~/.zshrc: 已配置"
else
    warn "~/.zshrc: 未检测到启动同步钩子"
fi

echo ""
echo -e "  ${GREEN}Pending: $(ls "$VAULT/Codex-Input/pending/"*.md 2>/dev/null | wc -l | tr -d ' ')${NC}"
echo -e "  ${GREEN}Review:  $(ls "$VAULT/Codex-Input/review/"*.md 2>/dev/null | wc -l | tr -d ' ')${NC}"
echo -e "  ${GREEN}Approved: $(ls "$VAULT/Codex-Input/approved/"*.md 2>/dev/null | wc -l | tr -d ' ')${NC}"

echo ""
title "安装完成"
echo ""
echo "  日常命令:"
echo "    memory_search.sh '<关键词>'       统一搜索"
echo "    memory_search.sh --rsearch '中文'  中文搜索"
echo "    sync_memory.sh                    手动同步"
echo "    review_memory.sh                  生成审计报告"
echo "    run_all.sh                        完整每日管线"
echo ""
echo "  候选记忆自动写入 Obsidian vault:"
echo "    Codex-Input/pending/   <- 待审核"
echo "    Codex-Input/review/    <- 冲突/问题"
echo "    Codex-Input/approved/  <- 待 promote"
echo ""
echo "  日志目录: $AUTO_DIR/logs/"
echo "  launchd: sync 登录时 + 每 15 分钟 / daily 每日 9:00"
echo "  shell: 新交互会话启动时后台同步（300 秒冷却）"
