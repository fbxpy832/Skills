#!/usr/bin/env bash
# ============================================================================
# setup-config.sh — Deep Research Skill 一键配置脚本
# ============================================================================
# 在 macOS 终端中运行此脚本，自动完成：
#   1. 复制完整 skill 到 ~/.claude/skills/deep-research-skill-beta/
#   2. 生成并安装 config.env 到 ~/.config/deep-research-skill/
#   3. 同步 config.env 到 skill 目录，供 Claude Desktop / Cowork 沙箱读取
#   4. 提示输入搜索 API Key
#   5. 设置权限和输出目录
#
# 用法：
#   cd ~/Documents/RichardHub/Git/deep-research-skill-beta
#   bash setup-config.sh
# ============================================================================

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

info()  { echo -e "${BLUE}[INFO]${NC} $*"; }
ok()    { echo -e "${GREEN}[OK]${NC} $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; }

echo "=========================================="
echo "Deep Research Skill — 一键配置"
echo "=========================================="
echo ""

# ─── 1. 检测源目录 ────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_SRC="$SCRIPT_DIR"

if [ ! -f "$SKILL_SRC/SKILL.md" ]; then
  echo -e "${RED}[ERROR]${NC} 未找到 SKILL.md，请在 deep-research-skill-beta 目录中运行此脚本"
  echo "  当前目录: $SCRIPT_DIR"
  exit 1
fi
ok "源目录: $SKILL_SRC"

# ─── 跨平台检测 ─────────────────────────────────────────────────────
# shellcheck disable=SC1091
source "$SKILL_SRC/scripts/lib/platform.sh" 2>/dev/null || true
DETECTED_OS="$(dr_detect_os 2>/dev/null || echo "darwin")"
PYTHON_BIN="$(dr_detect_python 2>/dev/null || true)"

# ─── 2. 复制 skill 到 ~/.claude/skills/ ─────────────────────
SKILL_DST="$HOME/.claude/skills/deep-research-skill-beta"
info "目标目录: $SKILL_DST"

if [ -d "$SKILL_DST" ]; then
  warn "目标目录已存在"
  echo -n "  是否覆盖？[y/N] "
  read -r overwrite
  if [[ "$overwrite" =~ ^[Yy] ]]; then
    rm -rf "$SKILL_DST"
  else
    info "跳过 skill 复制（保留现有版本）"
  fi
fi

if [ ! -d "$SKILL_DST" ]; then
  mkdir -p "$SKILL_DST"
  # 优先 rsync（macOS/Linux），回退 cp -R（Windows Git Bash 不带 rsync）
  if command -v rsync &>/dev/null; then
    rsync -a \
      --exclude='.deep-research-runs' \
      --exclude='.worktrees' \
      --exclude='.gitignore' \
      --exclude='eval' \
      --exclude='__MACOSX' \
      --exclude='._*' \
      --exclude='.DS_Store' \
      --exclude='config.env' \
      --exclude='install.sh' \
      "$SKILL_SRC/" "$SKILL_DST/"
  else
    cp -R "$SKILL_SRC/." "$SKILL_DST/"
    rm -rf "$SKILL_DST/.deep-research-runs" "$SKILL_DST/.worktrees" \
           "$SKILL_DST/.gitignore" "$SKILL_DST/eval" \
           "$SKILL_DST/__MACOSX" "$SKILL_DST/.DS_Store"
    find "$SKILL_DST" -name '._*' -delete 2>/dev/null || true
  fi
  dr_chmod_safe +x "$SKILL_DST/scripts/"*.sh 2>/dev/null || true
  ok "Skill 文件已复制"
fi

# ─── 3. 创建配置目录 ──────────────────────────────────────────
CONFIG_DIR="$HOME/.config/deep-research-skill"
mkdir -p "$CONFIG_DIR"
dr_chmod_safe 700 "$CONFIG_DIR"
ok "配置目录: $CONFIG_DIR"

EXISTING_CONFIG="$CONFIG_DIR/config.env"
if [ -f "$EXISTING_CONFIG" ]; then
  # shellcheck disable=SC1090
  source "$EXISTING_CONFIG"
  info "已读取现有配置，搜索 key 输入留空将保留旧值"
fi

# ─── 4. 交互式配置 ────────────────────────────────────────────
echo ""
echo "=========================================="
echo "Agent 模型分配"
echo "=========================================="
echo ""
echo "  推荐分配 (Claude Desktop / Cowork):"
echo "  ┌─────────────────────────┬────────┬──────────────────────────┐"
echo "  │ Agent                   │ 角色   │ 模型                     │"
echo "  ├─────────────────────────┼────────┼──────────────────────────┤"
echo "  │ planner_agent           │ opus   │ Pro/推理                  │"
echo "  │ source_agent            │ sonnet │ Flash/初稿                │"
echo "  │ long_context_agent      │ haiku  │ 长文本/轻量              │"
echo "  │ analyst_agent           │ opus   │ Pro/推理                  │"
echo "  │ scenario_agent          │ opus   │ Pro/推理                  │"
echo "  │ writer_agent            │ opus   │ Pro/推理                  │"
echo "  │ reviewer_agent          │ opus   │ Pro/推理                  │"
echo "  └─────────────────────────┴────────┴──────────────────────────┘"
echo ""
echo -n "  应用推荐分配？[Y/n] "
read -r assign_ok

if [[ "$assign_ok" =~ ^[Nn] ]]; then
  echo ""
  echo "  请手动指定每个 agent 的模型 tier (opus/sonnet/haiku):"
  for agent in planner_agent source_agent long_context_agent analyst_agent scenario_agent writer_agent reviewer_agent; do
    case "$agent" in
      planner_agent|analyst_agent|scenario_agent|writer_agent|reviewer_agent) default="opus" ;;
      source_agent) default="sonnet" ;;
      long_context_agent) default="haiku" ;;
    esac
    read -r -p "    $agent [$default]: " tier_choice
    tier_choice="${tier_choice:-$default}"
    eval "${agent}_tier=\"$tier_choice\""
  done
else
  planner_agent_tier="opus"
  source_agent_tier="sonnet"
  long_context_agent_tier="haiku"
  analyst_agent_tier="opus"
  scenario_agent_tier="opus"
  writer_agent_tier="opus"
  reviewer_agent_tier="opus"
fi

# ─── 4.5 宿主选择（WorkBuddy 检测 + 选平台） ─────────────────────
HOST_TYPE="claude-desktop"  # 默认
WB_DETECTED=false

if [ "$DETECTED_OS" = "darwin" ] || [ "$DETECTED_OS" = "windows-gitbash" ]; then
  while IFS= read -r wb_path; do
    [ -z "$wb_path" ] && continue
    if [ -f "$wb_path" ]; then
      WB_DETECTED=true
      break
    fi
  done < <(dr_workbuddy_settings_paths "$DETECTED_OS" 2>/dev/null || true)
fi

if [ "$WB_DETECTED" = true ]; then
  echo ""
  echo "=========================================="
  echo "宿主选择"
  echo "=========================================="
  echo ""
  echo "  检测到 WorkBuddy 桌面版，请选择配置目标宿主："
  echo "  1) WorkBuddy（推荐）— 指令级路由"
  echo "  2) Claude Desktop / Cowork"
  echo -n "  选择 [1]: "
  read -r host_choice
  host_choice="${host_choice:-1}"
  if [ "$host_choice" = "1" ] || [ "$host_choice" = "" ]; then
    HOST_TYPE="workbuddy"
    info "目标宿主: WorkBuddy"
    WB_WORKSPACE="$(dr_workbuddy_workspace_dir "$DETECTED_OS" 2>/dev/null || true)"
    if [ -n "$WB_WORKSPACE" ]; then
      echo "  沙箱工作目录: $WB_WORKSPACE"
    fi
  else
    info "目标宿主: Claude Desktop / Cowork"
  fi
  echo ""
fi

# ─── 5. 搜索 API Key ──────────────────────────────────────────
echo ""
echo "=========================================="
echo "搜索 API Key 配置"
echo "=========================================="
echo ""
echo "  至少需要一个搜索 API Key 才能联网搜索。"
echo "  Bocha (博查) — 中文搜索，国内直连，推荐"
echo "  Brave — 中英文通用，需代理"
echo "  Exa — 英文语义搜索"
echo ""

# 读取已有的 key（如果有的话）
OLD_BRAVE="${BRAVE_API_KEY:-}"
OLD_BOCHA="${BOCHA_API_KEY:-}"
OLD_EXA="${EXA_API_KEY:-}"

read -r -s -p "  BOCHA_API_KEY${OLD_BOCHA:+ [已配置]}: " bocha_key
echo
bocha_key="${bocha_key:-$OLD_BOCHA}"

read -r -s -p "  BRAVE_API_KEY${OLD_BRAVE:+ [已配置]}: " brave_key
echo
brave_key="${brave_key:-$OLD_BRAVE}"

read -r -s -p "  EXA_API_KEY${OLD_EXA:+ [已配置]}: " exa_key
echo
exa_key="${exa_key:-$OLD_EXA}"

if [ -z "$bocha_key" ] && [ -z "$brave_key" ] && [ -z "$exa_key" ]; then
  warn "未配置任何搜索 API Key，联网搜索将不可用"
fi

# ─── 6. 输出目录 ──────────────────────────────────────────────
echo ""
echo "=========================================="
echo "输出目录"
echo "=========================================="
echo ""
DEFAULT_OUTPUT="$HOME/Deep-Research-Outputs"
read -r -p "  研究报告输出目录 [$DEFAULT_OUTPUT]: " output_dir
output_dir="${output_dir:-$DEFAULT_OUTPUT}"
mkdir -p "$output_dir"
ok "输出目录: $output_dir"

# ─── 7. 写入配置 ──────────────────────────────────────────────
CONFIG_FILE="$CONFIG_DIR/config.env"
shell_quote() { printf "%q" "$1"; }

cat > "$CONFIG_FILE" << EOF
# Deep Research Skill local config
# Generated by setup-config.sh on $(date '+%Y-%m-%d %H:%M:%S')
# Do not commit this file.

export DEEP_RESEARCH_OUTPUT_DIR=$(shell_quote "$output_dir")

# ─── Provider ─────────────────────────────────────────────────
EOF

if [ "$HOST_TYPE" = "workbuddy" ]; then
  cat >> "$CONFIG_FILE" << 'CONFIGEOF'
# These routes are instruction-level recommendations — the host's
# WorkBuddy gateway handles actual model dispatch. Reports must say
# "model use not automatically verified".
export DEEP_RESEARCH_PROVIDER_IDS=workbuddy
export DEEP_RESEARCH_PROVIDER_WORKBUDDY_ID=workbuddy
export DEEP_RESEARCH_PROVIDER_WORKBUDDY_NAME="WorkBuddy (CodeBuddy Desktop)"
export DEEP_RESEARCH_PROVIDER_WORKBUDDY_OPUS_MODEL=opus
export DEEP_RESEARCH_PROVIDER_WORKBUDDY_SONNET_MODEL=sonnet
export DEEP_RESEARCH_PROVIDER_WORKBUDDY_HAIKU_MODEL=haiku
CONFIGEOF
PROVIDER_PREFIX="workbuddy"
else
  cat >> "$CONFIG_FILE" << 'CONFIGEOF'
# These routes are instruction-level recommendations. The final report must
# say "model use not automatically verified" unless the host UI/logs verify it.
export DEEP_RESEARCH_PROVIDER_IDS=claude-desktop
export DEEP_RESEARCH_PROVIDER_CLAUDE_DESKTOP_ID=claude-desktop
export DEEP_RESEARCH_PROVIDER_CLAUDE_DESKTOP_NAME="Claude Desktop / Cowork"
export DEEP_RESEARCH_PROVIDER_CLAUDE_DESKTOP_OPUS_MODEL="claude-opus-4-6"
export DEEP_RESEARCH_PROVIDER_CLAUDE_DESKTOP_SONNET_MODEL="claude-sonnet-4-6"
export DEEP_RESEARCH_PROVIDER_CLAUDE_DESKTOP_HAIKU_MODEL="claude-haiku-4-5"
CONFIGEOF
PROVIDER_PREFIX="claude-desktop"
fi

{
  echo ""
  echo "# ─── Agent Model Routing ──────────────────────────────────────"
  echo "export DEEP_RESEARCH_MODEL_PLANNER_AGENT=\"${PROVIDER_PREFIX}/${planner_agent_tier}\""
  echo "export DEEP_RESEARCH_MODEL_SOURCE_AGENT=\"${PROVIDER_PREFIX}/${source_agent_tier}\""
  echo "export DEEP_RESEARCH_MODEL_LONG_CONTEXT_AGENT=\"${PROVIDER_PREFIX}/${long_context_agent_tier}\""
  echo "export DEEP_RESEARCH_MODEL_ANALYST_AGENT=\"${PROVIDER_PREFIX}/${analyst_agent_tier}\""
  echo "export DEEP_RESEARCH_MODEL_SCENARIO_AGENT=\"${PROVIDER_PREFIX}/${scenario_agent_tier}\""
  echo "export DEEP_RESEARCH_MODEL_WRITER_AGENT=\"${PROVIDER_PREFIX}/${writer_agent_tier}\""
  echo "export DEEP_RESEARCH_MODEL_REVIEWER_AGENT=\"${PROVIDER_PREFIX}/${reviewer_agent_tier}\""
  echo ""
  echo "# ─── Platform ────────────────────────────────────────────────"
  echo "export DEEP_RESEARCH_PLATFORM_OS=${DETECTED_OS}"
  if [ "$HOST_TYPE" = "workbuddy" ] && [ -n "${WB_WORKSPACE:-}" ]; then
    echo "export DEEP_RESEARCH_WORKBUDDY_WORKSPACE_DIR=$(shell_quote "$WB_WORKSPACE")"
  fi
} >> "$CONFIG_FILE"

[ -n "$bocha_key" ] && echo "export BOCHA_API_KEY=$(shell_quote "$bocha_key")" >> "$CONFIG_FILE"
[ -n "$brave_key" ] && echo "export BRAVE_API_KEY=$(shell_quote "$brave_key")" >> "$CONFIG_FILE"
[ -n "$exa_key" ] && echo "export EXA_API_KEY=$(shell_quote "$exa_key")" >> "$CONFIG_FILE"

dr_chmod_safe 600 "$CONFIG_FILE"
ok "配置已写入: $CONFIG_FILE"

# 同步到 skill 目录，scripts/check-config.sh 会优先读取它。
if [ -d "$SKILL_DST" ]; then
  cp "$CONFIG_FILE" "$SKILL_DST/config.env"
  dr_chmod_safe 600 "$SKILL_DST/config.env"
  ok "配置已同步到 Skill 目录: $SKILL_DST/config.env"
fi

# WorkBuddy 沙箱额外同步
if [ "$HOST_TYPE" = "workbuddy" ] && [ -n "${WB_WORKSPACE:-}" ] && [ -d "$WB_WORKSPACE" ]; then
  cp "$CONFIG_FILE" "$WB_WORKSPACE/.deep-research.env"
  dr_chmod_safe 600 "$WB_WORKSPACE/.deep-research.env"
  ok "配置已同步到 WorkBuddy 沙箱: $WB_WORKSPACE/.deep-research.env"
fi

# ─── 8. 验证 ──────────────────────────────────────────────────
echo ""
echo "=========================================="
echo "验证安装"
echo "=========================================="
echo ""

# 验证 skill 文件
errors=0
for f in SKILL.md model-routing.yaml source-policy.yaml scripts/setup.sh scripts/check-config.sh scripts/search.sh scripts/model-router.sh scripts/generic-research-runner.sh scripts/knowledge-retrieval.sh scripts/lib/config-resolver.sh; do
  if [ -f "$SKILL_DST/$f" ]; then
    ok "  $f"
  else
    echo -e "  ${RED}❌ $f MISSING${NC}"
    errors=$((errors + 1))
  fi
done

# 验证配置
echo ""
if [ -f "$CONFIG_FILE" ]; then
  ok "config.env 已就绪"
  source "$CONFIG_FILE"
  echo "  Provider: $DEEP_RESEARCH_PROVIDER_IDS"
  echo "  Platform OS: ${DEEP_RESEARCH_PLATFORM_OS:-$(dr_detect_os 2>/dev/null || echo 'unknown')}"
  echo "  Planner: $DEEP_RESEARCH_MODEL_PLANNER_AGENT"
  echo "  Source: $DEEP_RESEARCH_MODEL_SOURCE_AGENT"
  echo "  Long Context: $DEEP_RESEARCH_MODEL_LONG_CONTEXT_AGENT"

  keys_count=0
  [ -n "${BOCHA_API_KEY:-}" ] && keys_count=$((keys_count + 1))
  [ -n "${BRAVE_API_KEY:-}" ] && keys_count=$((keys_count + 1))
  [ -n "${EXA_API_KEY:-}" ] && keys_count=$((keys_count + 1))
  echo "  搜索 API Keys: $keys_count 个已配置"
  echo "  输出目录: $DEEP_RESEARCH_OUTPUT_DIR"
else
  echo -e "  ${RED}❌ config.env 未找到${NC}"
  errors=$((errors + 1))
fi

echo ""
if [ -x "$SKILL_DST/scripts/check-config.sh" ]; then
  info "运行 Skill 配置检查:"
  (cd "$SKILL_DST" && bash scripts/check-config.sh | sed -E 's#(config_env=).*#\\1***redacted_path***#')
fi

echo ""
if [ "$errors" -gt 0 ]; then
  echo -e "${RED}安装完成，但有 $errors 个问题需要解决${NC}"
else
  echo -e "${GREEN}✅ 安装配置完成！${NC}"
fi

echo ""
echo "=========================================="
echo "使用方式"
echo "=========================================="
echo ""
echo "  激活配置（每次打开新终端需要执行）："
echo "    source $CONFIG_FILE"
echo ""
echo "  或添加到 shell 配置自动加载（可选，按你的 shell 选择）："
SHELL_RC="$(dr_shell_rc_path "$DETECTED_OS" 2>/dev/null || echo "")"
if [ -n "$SHELL_RC" ]; then
  echo "    echo 'source $CONFIG_FILE' >> $SHELL_RC"
fi
echo "  Windows Git Bash: echo 'source $CONFIG_FILE' >> ~/.bashrc"
echo ""
echo "  Claude Desktop / Cowork 中直接对话即可触发研究；Skill 会先运行 scripts/check-config.sh。"
echo "  搜索连通性测试："
echo "    cd $SKILL_DST"
echo "    bash scripts/check-config.sh"
echo "    bash scripts/search.sh \"测试搜索\" --parallel --count 2"
echo ""
echo "  注意：generic-research-runner.sh 在未设置 HOST_RUN_CMD 时只是 dry-run，不能代表真实研究完成。"
echo ""
