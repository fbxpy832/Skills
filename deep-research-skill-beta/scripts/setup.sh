#!/usr/bin/env bash
set -euo pipefail

# ============================================================================
# setup.sh — Deep Research Skill 安装配置脚本 (Beta)
# ============================================================================
# 功能：
#   1. 自动检测宿主环境（Claude Code / OpenCode）
#   2. 读取宿主中已配置的模型，分类推荐给各个 Agent
#   3. 用户确认/调整模型分配后写入配置
#   4. 搜索 API Key 手动输入（保持原样）
# ============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="${DEEP_RESEARCH_SKILL_CONFIG_DIR:-$HOME/.config/deep-research-skill}"
CONFIG_ENV="$CONFIG_DIR/config.env"
PROVIDERS_FILE="$CONFIG_DIR/providers.env"

mkdir -p "$CONFIG_DIR"
umask 077

# ─── 辅助函数 ───────────────────────────────────────────────────────

prompt_val() {
  local label="$1"
  local default="${2:-}"
  local value
  if [ -n "$default" ]; then
    read -r -p "$label [$default]: " value
    echo "${value:-$default}"
  else
    read -r -p "$label: " value
    echo "$value"
  fi
}

prompt_secret() {
  local label="$1"
  local value
  read -r -s -p "$label (leave blank to skip): " value
  echo >&2
  if [ -n "$value" ]; then
    echo "  ✓ 已配置" >&2
  fi
  echo "$value"
}

shell_quote() {
  printf "%q" "$1"
}

var_name() {
  local result
  result="$(echo "$1" | tr '[:lower:]-./ ' '[:upper:]____' | tr -cd 'A-Z0-9_')"
  if [ -z "$result" ]; then
    result="PROVIDER"
  fi
  echo "$result"
}

# 根据 Agent 名称返回角色: pro / fast / long
role_for_agent() {
  case "$1" in
    planner_agent|analyst_agent|scenario_agent|writer_agent|reviewer_agent) echo "pro" ;;
    source_agent)       echo "fast" ;;
    long_context_agent) echo "long" ;;
    *)                  echo "pro" ;;
  esac
}

# Agent 列表
ALL_AGENTS="planner_agent source_agent long_context_agent analyst_agent scenario_agent writer_agent reviewer_agent"

# ============================================================================
# Phase 1: 宿主环境检测
# ============================================================================

echo "=========================================="
echo "Deep Research Skill 安装配置 (Beta)"
echo "=========================================="
echo ""

HOST_TYPE=""
HOST_NAME=""
OPENCODE_PROVIDERS=()

# --- 检测 Claude Code ---
if [ -f "$HOME/.claude/settings.json" ]; then
  echo "[检测] ✅ Claude Code 配置已发现"
  HOST_TYPE="claude-code"
  HOST_NAME="Claude Code"

  # 读取模型信息：env 自定义变量 > modelOverrides > 标准模型名
  CC_SETTINGS="$HOME/.claude/settings.json"
  eval "$(python3 -c "
import json, re, sys

s = json.load(open(sys.argv[1]))
e = s.get('env', {})
o = s.get('modelOverrides', {})

opus_raw = e.get('ANTHROPIC_DEFAULT_OPUS_MODEL', o.get('claude-opus-4-6', 'claude-opus-4-6'))
sonnet_raw = e.get('ANTHROPIC_DEFAULT_SONNET_MODEL', o.get('claude-sonnet-4-6', 'claude-sonnet-4-6'))
haiku_raw = e.get('ANTHROPIC_DEFAULT_HAIKU_MODEL', o.get('claude-haiku-4-5', 'claude-haiku-4-5'))

opus_id = re.sub(r'\s*\[.*?\]', '', opus_raw).strip()
sonnet_id = re.sub(r'\s*\[.*?\]', '', sonnet_raw).strip()
haiku_id = re.sub(r'\s*\[.*?\]', '', haiku_raw).strip()

oname = e.get('ANTHROPIC_DEFAULT_OPUS_MODEL_NAME', opus_id)
sname = e.get('ANTHROPIC_DEFAULT_SONNET_MODEL_NAME', sonnet_id)
hname = e.get('ANTHROPIC_DEFAULT_HAIKU_MODEL_NAME', haiku_id)

print(f'OPUS_MODEL_ID={opus_id}')
print(f'SONNET_MODEL_ID={sonnet_id}')
print(f'HAIKU_MODEL_ID={haiku_id}')
print(f'OPUS_NAME={oname}')
print(f'SONNET_NAME={sname}')
print(f'HAIKU_NAME={hname}')
" "$CC_SETTINGS" 2>/dev/null)"

  # 确保空值时补默认值
  [ -z "$OPUS_MODEL_ID" ] && OPUS_MODEL_ID="claude-opus-4-6"
  [ -z "$SONNET_MODEL_ID" ] && SONNET_MODEL_ID="claude-sonnet-4-6"
  [ -z "$HAIKU_MODEL_ID" ] && HAIKU_MODEL_ID="claude-haiku-4-5"
  [ -z "$OPUS_NAME" ] && OPUS_NAME="$OPUS_MODEL_ID"
  [ -z "$SONNET_NAME" ] && SONNET_NAME="$SONNET_MODEL_ID"
  [ -z "$HAIKU_NAME" ] && HAIKU_NAME="$HAIKU_MODEL_ID"

  echo "  模型 Tier 映射:"
  echo "    opus  (Pro/推理)     → $OPUS_NAME ($OPUS_MODEL_ID)"
  echo "    sonnet (Flash/初稿)  → $SONNET_NAME ($SONNET_MODEL_ID)"
  echo "    haiku (长文本/轻量)  → $HAIKU_NAME ($HAIKU_MODEL_ID)"
  echo ""
fi

# --- 检测 OpenCode ---
if [ -f "$HOME/.config/opencode/opencode.json" ]; then
  OPENCODE_PROVIDER_LIST=$(python3 -c "
import json
c = json.load(open('$HOME/.config/opencode/opencode.json'))
providers = c.get('provider', {})
for pid, pconf in providers.items():
    models = list(pconf.get('models', {}).keys())
    if models:
        print(f'{pid}:{\",\".join(models)}')
" 2>/dev/null || echo "")

  if [ -n "$OPENCODE_PROVIDER_LIST" ]; then
    echo "[检测] ✅ OpenCode 配置已发现"
    if [ "$HOST_TYPE" = "claude-code" ]; then
      echo "  (作为补充 provider 来源)"
    else
      HOST_TYPE="opencode"
      HOST_NAME="OpenCode"
    fi
    while IFS= read -r line; do
      if [ -n "$line" ]; then
        echo "  Provider: $line"
        OPENCODE_PROVIDERS+=("$line")
      fi
    done <<< "$OPENCODE_PROVIDER_LIST"
    echo ""
  fi
fi

# --- 无检测结果 → 手动配置 ---
if [ -z "$HOST_TYPE" ]; then
  echo "[检测] ⚠️ 未能自动识别宿主环境"
  echo "  将使用手动模式选择 Provider。"
  echo ""
fi

# ============================================================================
# Phase 2: 模型分配 — 自动推荐 + 用户确认
# ============================================================================

echo "=========================================="
echo "Agent 模型分配"
echo "=========================================="
echo ""

PROVIDER_ID=""
PROVIDER_NAME=""

if [ "$HOST_TYPE" = "claude-code" ]; then
  # ─── Claude Code 模式 ───────────────────────────────────────────────
  PROVIDER_ID="claude-code"
  PROVIDER_NAME="Claude Code"

  echo "根据 Claude Code 配置，推荐以下 Agent 模型分配："
  echo ""

  # 角色 → tier 映射说明
  # pro  → opus   ($OPUS_MODEL_ID)
  # fast → sonnet ($SONNET_MODEL_ID)
  # long → haiku  ($HAIKU_MODEL_ID)

  show_tier() {
    local role="$1"
    case "$role" in
      pro)  echo "opus   ← $OPUS_MODEL_ID (Pro/推理)" ;;
      fast) echo "sonnet ← $SONNET_MODEL_ID (Flash/初稿)" ;;
      long) echo "haiku  ← $HAIKU_MODEL_ID (长文本/轻量)" ;;
    esac
  }

  printf "  %-25s %-10s %-s\n" "Agent" "角色" "推荐模型"
  printf "  %-25s %-10s %-s\n" "─────────────────────────" "──────────" "──────────────────────────────"
  for agent in $ALL_AGENTS; do
    role="$(role_for_agent "$agent")"
    tier_hint="$(show_tier "$role")"
    printf "  %-25s %-10s %-s\n" "$agent" "($role)" "$tier_hint"
  done
  echo ""

  assign_ok="$(prompt_val "应用以上分配？" "Y")"
  if [[ "$assign_ok" =~ ^[Nn] ]]; then
    echo ""
    echo "进入手动分配模式："
    echo ""
    echo "可用模型 tier（在 Claude Code 中通过 model=opus/sonnet/haiku 选择）："
    echo "  1) opus   → $OPUS_MODEL_ID (Pro/推理)"
    echo "  2) sonnet → $SONNET_MODEL_ID (Flash/初稿)"
    echo "  3) haiku  → $HAIKU_MODEL_ID (长文本/轻量)"
    echo ""

    for agent in $ALL_AGENTS; do
      role="$(role_for_agent "$agent")"
      case "$role" in
        pro)   default_tier="opus" ;;
        fast)  default_tier="sonnet" ;;
        long)  default_tier="haiku" ;;
      esac
      tier_choice="$(prompt_val "  $agent 使用的模型 tier" "$default_tier")"
      case "$tier_choice" in
        opus|sonnet|haiku) ;;
        *) echo "  (无效输入，使用 opus)"; tier_choice="opus" ;;
      esac
      declare "MANUAL_${agent}=$PROVIDER_ID/$tier_choice"
    done
  fi

elif [ "$HOST_TYPE" = "opencode" ] || [ ${#OPENCODE_PROVIDERS[@]} -gt 0 ]; then
  # ─── OpenCode 模式 ────────────────────────────────────────────────
  echo "从 OpenCode 配置中发现以下 Provider："
  echo ""
  idx=1
  for line in "${OPENCODE_PROVIDERS[@]}"; do
    pid="${line%%:*}"
    models="${line#*:}"
    echo "  $idx) $pid — 可用模型: $models"
    idx=$((idx + 1))
  done
  echo ""
  provider_choice="$(prompt_val "选择 Provider" "1")"
  # 数组索引从 0 开始
  arr_idx=$((provider_choice - 1))
  selected_provider=""
  i=0
  for line in "${OPENCODE_PROVIDERS[@]}"; do
    if [ "$i" = "$arr_idx" ]; then
      selected_provider="${line%%:*}"
      break
    fi
    i=$((i + 1))
  done
  if [ -z "$selected_provider" ]; then
    # 取第一个
    for line in "${OPENCODE_PROVIDERS[@]}"; do
      selected_provider="${line%%:*}"
      break
    done
  fi
  echo ""

  # 读取模型列表
  all_models_str=$(python3 -c "
import json
c = json.load(open('$HOME/.config/opencode/opencode.json'))
models = list(c.get('provider', {}).get('$selected_provider', {}).get('models', {}).keys())
print(' '.join(models))
" 2>/dev/null || echo "")
  all_models=($all_models_str)

  echo "为 $selected_provider 的模型分配角色："
  echo "  每个模型可以担任：pro(推理分析) / fast(搜索初稿) / long(长文档)"
  echo ""

  pro_model="$(prompt_val "  Pro/推理模型" "${all_models[0]:-}")"
  fast_model="$(prompt_val "  Fast/搜索模型" "${all_models[1]:-${all_models[0]:-}}")"
  long_model="$(prompt_val "  Long/长文档模型" "${all_models[2]:-${all_models[0]:-}}")"

  PROVIDER_ID="$selected_provider"

  for agent in $ALL_AGENTS; do
    role="$(role_for_agent "$agent")"
    case "$role" in
      pro)   model_id="$pro_model" ;;
      fast)  model_id="$fast_model" ;;
      long)  model_id="$long_model" ;;
    esac
    declare "MANUAL_${agent}=$PROVIDER_ID/$model_id"
  done

else
  # ─── 无宿主检测 → 手动选择 ─────────────────────────────────────────
  echo "请选择模型提供商："
  echo "  1) Claude Code（三级模型：opus/sonnet/haiku）"
  echo "  2) DeepSeek OpenAI-compatible"
  echo "  3) Moonshot / Kimi"
  echo "  4) OpenAI"
  echo "  5) OpenRouter"
  echo "  6) SiliconFlow"
  echo "  7) Custom"
  echo ""
  provider_choice="$(prompt_val "选择" "1")"
  echo ""

  PROVIDER_ID=""
  PROVIDER_NAME=""
  default_base=""
  default_auth_env=""

  case "$provider_choice" in
    2) PROVIDER_ID="deepseek";    PROVIDER_NAME="DeepSeek";         default_base="https://api.deepseek.com/v1";           default_auth_env="DEEPSEEK_API_KEY" ;;
    3) PROVIDER_ID="moonshot";    PROVIDER_NAME="Moonshot/Kimi";    default_base="https://api.moonshot.cn/v1";            default_auth_env="MOONSHOT_API_KEY" ;;
    4) PROVIDER_ID="openai";      PROVIDER_NAME="OpenAI";           default_base="https://api.openai.com/v1";             default_auth_env="OPENAI_API_KEY" ;;
    5) PROVIDER_ID="openrouter";  PROVIDER_NAME="OpenRouter";       default_base="https://openrouter.ai/api/v1";           default_auth_env="OPENROUTER_API_KEY" ;;
    6) PROVIDER_ID="siliconflow"; PROVIDER_NAME="SiliconFlow";      default_base="https://api.siliconflow.cn/v1";          default_auth_env="SILICONFLOW_API_KEY" ;;
    7) PROVIDER_ID="custom";      PROVIDER_NAME="Custom";           default_base="";                                       default_auth_env="CUSTOM_OPENAI_API_KEY" ;;
    *) PROVIDER_ID="claude-code"; PROVIDER_NAME="Claude Code";     default_base="";                                       default_auth_env="" ;;
  esac

  if [ "$PROVIDER_ID" = "claude-code" ]; then
    echo "Claude Code 使用三级模型 tier："
    echo "  model=opus   → Pro/推理"
    echo "  model=sonnet → Flash/初稿"
    echo "  model=haiku  → 长文本/轻量"
    echo ""
    read -r -p "  opus 模型 ID (默认 claude-opus-4-6): " input_opus
    read -r -p "  sonnet 模型 ID (默认 claude-sonnet-4-6): " input_sonnet
    read -r -p "  haiku 模型 ID (默认 claude-haiku-4-5): " input_haiku
    echo ""

    PRO_MODEL="${input_opus:-claude-opus-4-6}"
    FAST_MODEL="${input_sonnet:-claude-sonnet-4-6}"
    LONG_MODEL="${input_haiku:-claude-haiku-4-5}"

    for agent in $ALL_AGENTS; do
      role="$(role_for_agent "$agent")"
      case "$role" in
        pro)  declare "MANUAL_${agent}=$PROVIDER_ID/$PRO_MODEL" ;;
        fast) declare "MANUAL_${agent}=$PROVIDER_ID/$FAST_MODEL" ;;
        long) declare "MANUAL_${agent}=$PROVIDER_ID/$LONG_MODEL" ;;
      esac
    done
  else
    base_url="$(prompt_val "Endpoint base URL" "$default_base")"
    auth_env="$(prompt_val "API key 环境变量名" "$default_auth_env")"
    credential=""
    if [ -n "$auth_env" ]; then
      credential="$(prompt_secret "$auth_env 值")"
    fi
    echo ""
    echo "为各角色分配模型 ID（输入模型的具体 ID，如 deepseek-chat、gpt-4 等）："
    echo ""
    pro_model="$(prompt_val "  Pro/推理模型 ID" "")"
    fast_model="$(prompt_val "  Fast/搜索模型 ID" "")"
    long_model="$(prompt_val "  Long/长文档模型 ID" "")"

    for agent in $ALL_AGENTS; do
      role="$(role_for_agent "$agent")"
      case "$role" in
        pro)  model_id="$pro_model" ;;
        fast) model_id="$fast_model" ;;
        long) model_id="$long_model" ;;
      esac
      declare "MANUAL_${agent}=$PROVIDER_ID/$model_id"
    done
  fi
fi

# ============================================================================
# Phase 3: 读取最终分配结果
# ============================================================================

echo ""
echo "=========================================="
echo "最终 Agent 模型分配确认"
echo "=========================================="
echo ""

# 如果是 Claude Code 自动分配模式（没有手动覆盖），直接设置默认值
if [ "$HOST_TYPE" = "claude-code" ] && [ -z "${MANUAL_planner_agent:+x}" ]; then
  planner_route="$PROVIDER_ID/opus"
  source_route="$PROVIDER_ID/sonnet"
  long_context_route="$PROVIDER_ID/haiku"
  analyst_route="$PROVIDER_ID/opus"
  scenario_route="$PROVIDER_ID/opus"
  writer_route="$PROVIDER_ID/opus"
  reviewer_route="$PROVIDER_ID/opus"
else
  # 从 MANUAL_* 变量读取
  planner_route="${MANUAL_planner_agent:-<未设置>}"
  source_route="${MANUAL_source_agent:-<未设置>}"
  long_context_route="${MANUAL_long_context_agent:-<未设置>}"
  analyst_route="${MANUAL_analyst_agent:-<未设置>}"
  scenario_route="${MANUAL_scenario_agent:-<未设置>}"
  writer_route="${MANUAL_writer_agent:-<未设置>}"
  reviewer_route="${MANUAL_reviewer_agent:-<未设置>}"
fi

printf "  %-25s %-s\n" "Agent" "分配模型"
printf "  %-25s %-s\n" "─────────────────────────" "──────────────────────────────"
printf "  %-25s %-s\n" "planner_agent"      "$planner_route"
printf "  %-25s %-s\n" "source_agent"       "$source_route"
printf "  %-25s %-s\n" "long_context_agent"  "$long_context_route"
printf "  %-25s %-s\n" "analyst_agent"      "$analyst_route"
printf "  %-25s %-s\n" "scenario_agent"     "$scenario_route"
printf "  %-25s %-s\n" "writer_agent"       "$writer_route"
printf "  %-25s %-s\n" "reviewer_agent"     "$reviewer_route"
echo ""
confirm="$(prompt_val "确认以上分配？" "Y")"
if [[ "$confirm" =~ ^[Nn] ]]; then
  echo "已取消。可以重新运行 setup.sh 重新配置。"
  exit 1
fi

# ============================================================================
# Phase 3.5: 知识库路径配置（自动检测 + 确认）
# ============================================================================

echo ""
echo "=========================================="
echo "知识库路径配置"
echo "=========================================="
echo ""

# Obsidian Vault: auto-detect from obsidian-article-extractor config, then common path
DETECTED_VAULT=""
if [ -f "$HOME/.config/obsidian-article-extractor/vault-path" ]; then
  DETECTED_VAULT=$(cat "$HOME/.config/obsidian-article-extractor/vault-path" 2>/dev/null || echo "")
fi
if [ -z "$DETECTED_VAULT" ] && [ -d "$HOME/Library/Mobile Documents/iCloud~md~obsidian/Documents/RichardHub" ]; then
  DETECTED_VAULT="$HOME/Library/Mobile Documents/iCloud~md~obsidian/Documents/RichardHub"
fi
echo "  Obsidian Vault 路径用于搜索本地 Markdown 笔记和技术 Wiki。"
obsidian_vault="$(prompt_val "Obsidian Vault 路径" "${DETECTED_VAULT:-}")"

# NotebookLM: auto-detect notebook ID from context.json
DETECTED_NOTEBOOK=""
if [ -f "$HOME/.notebooklm/context.json" ]; then
  DETECTED_NOTEBOOK=$(python3 -c "import json; print(json.load(open('$HOME/.notebooklm/context.json')).get('notebook_id',''))" 2>/dev/null || echo "")
fi
echo "  NotebookLM Notebook ID 用于查询 AI 分析笔记。留空自动检测。"
notebooklm_id="$(prompt_val "NotebookLM Notebook ID" "${DETECTED_NOTEBOOK:-auto}")"

# Lark Wiki: check availability
LARK_AVAILABLE="no"
if command -v lark-cli &>/dev/null && [ -f "$HOME/.lark-cli/config.json" ]; then
  LARK_AVAILABLE="yes"
  echo "[检测] ✅ lark-cli 已就绪，飞书知识库将自动启用"
fi

# ============================================================================
# Phase 4: 搜索 API Key
# ============================================================================

echo ""
echo "=========================================="
echo "搜索 API Key 配置"
echo "=========================================="
echo ""
echo "说明：至少配置一个搜索 API Key 才能进行联网搜索。"
echo "  博查 (Bocha) — 中文搜索，国内直连，推荐"
echo "  Brave — 中英文通用，需代理"
echo "  Exa — 英文语义搜索，直连"
echo ""

brave_key="$(prompt_secret "BRAVE_API_KEY")"
bocha_key="$(prompt_secret "BOCHA_API_KEY")"
exa_key="$(prompt_secret "EXA_API_KEY")"

# ============================================================================
# Phase 5: 输出目录
# ============================================================================

echo ""
echo "=========================================="
echo "输出目录设置"
echo "=========================================="
echo ""

output_dir="$(prompt_val "Default output directory" "$HOME/Deep-Research-Outputs")"
mkdir -p "$output_dir"

# ============================================================================
# Phase 6: 写入配置
# ============================================================================

echo ""
echo "正在写入配置..."

# Claude Code 环境写入额外描述
OPUS_DESC="${OPUS_MODEL_ID:-}"
SONNET_DESC="${SONNET_MODEL_ID:-}"
HAIKU_DESC="${HAIKU_MODEL_ID:-}"

{
  echo "# Deep Research Skill local config"
  echo "# Generated by scripts/setup.sh. Do not commit this file."
  echo "export DEEP_RESEARCH_OUTPUT_DIR=$(shell_quote "$output_dir")"
  echo ""

  if [ "$HOST_TYPE" = "claude-code" ]; then
  echo "# ─── Provider: Claude Code ────────────────────────────────────"
  echo "# Agent model routing configured for Claude Code."
  echo "#   opus   → $OPUS_DESC (Pro/推理)"
  echo "#   sonnet → $SONNET_DESC (Flash/初稿)"
  echo "#   haiku  → $HAIKU_DESC (长文本/轻量)"
  echo "# Subagents are spawned via Claude Code's Agent tool with model=opus|sonnet|haiku."
  echo "export DEEP_RESEARCH_PROVIDER_IDS=claude-code"
  echo "export DEEP_RESEARCH_PROVIDER_CLAUDE_CODE_ID=claude-code"
  echo "export DEEP_RESEARCH_PROVIDER_CLAUDE_CODE_NAME=Claude Code"
  echo "export DEEP_RESEARCH_PROVIDER_CLAUDE_CODE_OPUS_MODEL=$(shell_quote "$OPUS_DESC")"
  echo "export DEEP_RESEARCH_PROVIDER_CLAUDE_CODE_SONNET_MODEL=$(shell_quote "$SONNET_DESC")"
  echo "export DEEP_RESEARCH_PROVIDER_CLAUDE_CODE_HAIKU_MODEL=$(shell_quote "$HAIKU_DESC")"
  echo ""
  fi

  echo "# ─── Agent Model Routing ──────────────────────────────────────"
  echo "export DEEP_RESEARCH_MODEL_PLANNER_AGENT=$(shell_quote "$planner_route")"
  echo "export DEEP_RESEARCH_MODEL_SOURCE_AGENT=$(shell_quote "$source_route")"
  echo "export DEEP_RESEARCH_MODEL_LONG_CONTEXT_AGENT=$(shell_quote "$long_context_route")"
  echo "export DEEP_RESEARCH_MODEL_ANALYST_AGENT=$(shell_quote "$analyst_route")"
  echo "export DEEP_RESEARCH_MODEL_SCENARIO_AGENT=$(shell_quote "$scenario_route")"
  echo "export DEEP_RESEARCH_MODEL_WRITER_AGENT=$(shell_quote "$writer_route")"
  echo "export DEEP_RESEARCH_MODEL_REVIEWER_AGENT=$(shell_quote "$reviewer_route")"
  echo ""

  if [ -n "$obsidian_vault" ]; then
    echo "# Obsidian Vault"
    echo "export DEEP_RESEARCH_OBSIDIAN_VAULT_DIR=$(shell_quote "$obsidian_vault")"
    echo ""
  fi
  if [ "$LARK_AVAILABLE" = "yes" ]; then
    echo "# Lark/Feishu Wiki (auto-detected)"
    echo "export DEEP_RESEARCH_LARK_ENABLED=true"
    echo ""
  fi
  if [ -n "$notebooklm_id" ] && [ "$notebooklm_id" != "auto" ]; then
    echo "# NotebookLM"
    echo "export DEEP_RESEARCH_NOTEBOOKLM_NOTEBOOK_ID=$(shell_quote "$notebooklm_id")"
    echo ""
  fi

  if [ -n "$brave_key" ]; then
    echo "# Brave Search API"
    echo "export BRAVE_API_KEY=$(shell_quote "$brave_key")"
  fi
  if [ -n "$bocha_key" ]; then
    echo "# Bocha AI Search API"
    echo "export BOCHA_API_KEY=$(shell_quote "$bocha_key")"
  fi
  if [ -n "$exa_key" ]; then
    echo "# Exa Search API"
    echo "export EXA_API_KEY=$(shell_quote "$exa_key")"
  fi
} > "$CONFIG_ENV"

chmod 600 "$CONFIG_ENV"

echo ""
echo "=========================================="
echo "配置完成"
echo "=========================================="
echo ""
echo "配置文件: $CONFIG_ENV"
echo ""
echo "下一步："
echo "  确保 search API key 对应的环境变量已 export 到当前 shell"
echo "  或 source 配置文件:"
echo "    source $CONFIG_ENV"
echo ""