#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="${DEEP_RESEARCH_SKILL_CONFIG_DIR:-$HOME/.config/deep-research-skill}"
CONFIG_ENV="$CONFIG_DIR/config.env"
PROVIDERS_FILE="$CONFIG_DIR/providers.env"

mkdir -p "$CONFIG_DIR"
umask 077

prompt() {
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

provider_defaults() {
  case "$1" in
    deepseek)
      echo "deepseek|DeepSeek|https://api.deepseek.com/v1|DEEPSEEK_API_KEY|deepseek-v4-flash|deepseek-v4-flash|deepseek-v4-flash"
      ;;
    moonshot)
      echo "moonshot|Moonshot / Kimi|https://api.moonshot.cn/v1|MOONSHOT_API_KEY|kimi-k2-0905-preview|kimi-k2-0905-preview|kimi-k2-0905-preview"
      ;;
    openrouter)
      echo "openrouter|OpenRouter|https://openrouter.ai/api/v1|OPENROUTER_API_KEY|deepseek/deepseek-r1|deepseek/deepseek-chat|moonshotai/kimi-k2"
      ;;
    siliconflow)
      echo "siliconflow|SiliconFlow|https://api.siliconflow.cn/v1|SILICONFLOW_API_KEY|deepseek-ai/DeepSeek-R1|deepseek-ai/DeepSeek-V3|moonshotai/Kimi-K2-Instruct"
      ;;
    custom|*)
      echo "custom|Custom OpenAI-compatible|https://example.com/v1|CUSTOM_OPENAI_API_KEY|provider/pro-model|provider/fast-model|provider/long-context-model"
      ;;
  esac
}

choose_template() {
  echo "Choose provider template:" >&2
  echo "  1) DeepSeek OpenAI-compatible" >&2
  echo "  2) Moonshot / Kimi OpenAI-compatible" >&2
  echo "  3) OpenRouter" >&2
  echo "  4) SiliconFlow" >&2
  echo "  5) Custom OpenAI-compatible" >&2
  local choice
  choice="$(prompt "Provider template" "1")"
  case "$choice" in
    1) echo "deepseek" ;;
    2) echo "moonshot" ;;
    3) echo "openrouter" ;;
    4) echo "siliconflow" ;;
    5) echo "custom" ;;
    *) echo "deepseek" ;;
  esac
}

echo "Deep Research Skill setup"
echo ""
echo "This writes local-only secrets to:"
echo "  $CONFIG_ENV"
echo "This config is host-agnostic. Codex, OpenCode, Claude Code, CloudCode, GUI, TU/terminal runners, and other agents can read it."
echo ""

provider_count="$(prompt "How many model providers do you want to configure" "1")"
case "$provider_count" in
  ''|*[!0-9]*) provider_count=1 ;;
esac
[ "$provider_count" -lt 1 ] && provider_count=1

provider_ids=()
provider_records=()

provider_record() {
  local wanted="$1"
  local record id
  for record in "${provider_records[@]}"; do
    IFS='|' read -r id _rest <<< "$record"
    if [ "$id" = "$wanted" ]; then
      echo "$record"
      return 0
    fi
  done
  return 1
}

provider_field() {
  local wanted="$1"
  local field="$2"
  local record id name base auth key pro fast long
  record="$(provider_record "$wanted")" || return 1
  IFS='|' read -r id name base auth key pro fast long <<< "$record"
  case "$field" in
    name) echo "$name" ;;
    base) echo "$base" ;;
    auth) echo "$auth" ;;
    key) echo "$key" ;;
    pro) echo "$pro" ;;
    fast) echo "$fast" ;;
    long) echo "$long" ;;
    *) return 1 ;;
  esac
}

for i in $(seq 1 "$provider_count"); do
  echo ""
  echo "Provider $i / $provider_count"
  kind="$(choose_template)"
  IFS='|' read -r id_default name_default base_default auth_default pro_default fast_default long_default <<< "$(provider_defaults "$kind")"

  provider_id="$(prompt "Provider id used in model routes" "$id_default")"
  provider_id="${provider_id// /-}"
  provider_display="$(prompt "Display name" "$name_default")"
  base_url="$(prompt "Endpoint base URL (blank for host-managed token plans)" "$base_default")"
  auth_env="$(prompt "API key environment variable name" "$auth_default")"

  credential=""
  if [ -n "$auth_env" ]; then
    credential="$(prompt_secret "$auth_env")"
  fi

  pro_model="$(prompt "Default Pro/reasoning model id for this provider" "$pro_default")"
  fast_model="$(prompt "Default fast/source model id for this provider" "$fast_default")"
  long_model="$(prompt "Default long-context model id for this provider" "$long_default")"

  provider_ids+=("$provider_id")
  provider_records+=("$provider_id|$provider_display|$base_url|$auth_env|$credential|$pro_model|$fast_model|$long_model")
done

default_provider="${provider_ids[0]}"

model_for_role() {
  local provider="$1"
  local role="$2"
  case "$role" in
    fast) provider_field "$provider" fast ;;
    long) provider_field "$provider" long ;;
    pro|*) provider_field "$provider" pro ;;
  esac
}

prompt_agent_route() {
  local agent="$1"
  local role="$2"
  local provider_default="${3:-$default_provider}"
  local provider model
  provider="$(prompt "$agent provider id" "$provider_default")"
  if ! provider_record "$provider" >/dev/null; then
    echo "Unknown provider '$provider'; using '$default_provider'." >&2
    provider="$default_provider"
  fi
  model="$(prompt "$agent model id" "$(model_for_role "$provider" "$role")")"
  echo "$provider/$model"
}

echo ""
echo "Assign models per research agent. Use provider ids from: ${provider_ids[*]}"
planner_route="$(prompt_agent_route "planner_agent" "pro")"
source_route="$(prompt_agent_route "source_agent" "fast")"
long_context_route="$(prompt_agent_route "long_context_agent" "long")"
analyst_route="$(prompt_agent_route "analyst_agent" "pro")"
scenario_route="$(prompt_agent_route "scenario_agent" "pro")"
writer_route="$(prompt_agent_route "writer_agent" "pro")"
reviewer_route="$(prompt_agent_route "reviewer_agent" "pro")"

echo ""
echo "Search tools are required for non-offline research. Enter keys now or leave blank and export them later."
brave_key="$(prompt_secret "BRAVE_API_KEY")"
bocha_key="$(prompt_secret "BOCHA_API_KEY")"
exa_key="$(prompt_secret "EXA_API_KEY")"

echo ""
echo "Choose where Deep Research should write reports and run artifacts by default."
output_dir="$(prompt "Default output directory" "$HOME/Deep-Research-Outputs")"
mkdir -p "$output_dir"

{
  echo "# Deep Research Skill local config"
  echo "# Generated by scripts/setup.sh. Do not commit this file."
  echo "export DEEP_RESEARCH_OUTPUT_DIR=$(shell_quote "$output_dir")"
  echo ""
  echo "export DEEP_RESEARCH_PROVIDER_IDS=$(shell_quote "${provider_ids[*]}")"
  echo ""
  for provider_id in "${provider_ids[@]}"; do
    safe="$(var_name "$provider_id")"
    provider_display="$(provider_field "$provider_id" name)"
    base_url="$(provider_field "$provider_id" base)"
    auth_env="$(provider_field "$provider_id" auth)"
    credential="$(provider_field "$provider_id" key)"
    pro_model="$(provider_field "$provider_id" pro)"
    fast_model="$(provider_field "$provider_id" fast)"
    long_model="$(provider_field "$provider_id" long)"
    echo "export DEEP_RESEARCH_PROVIDER_${safe}_ID=$(shell_quote "$provider_id")"
    echo "export DEEP_RESEARCH_PROVIDER_${safe}_NAME=$(shell_quote "$provider_display")"
    echo "export DEEP_RESEARCH_PROVIDER_${safe}_BASE_URL=$(shell_quote "$base_url")"
    echo "export DEEP_RESEARCH_PROVIDER_${safe}_AUTH_ENV=$(shell_quote "$auth_env")"
    echo "export DEEP_RESEARCH_PROVIDER_${safe}_PRO_MODEL=$(shell_quote "$pro_model")"
    echo "export DEEP_RESEARCH_PROVIDER_${safe}_FAST_MODEL=$(shell_quote "$fast_model")"
    echo "export DEEP_RESEARCH_PROVIDER_${safe}_LONG_CONTEXT_MODEL=$(shell_quote "$long_model")"
    [ -n "$credential" ] && echo "export DEEP_RESEARCH_PROVIDER_${safe}_API_KEY=$(shell_quote "$credential")"
    echo ""
  done
  echo "export DEEP_RESEARCH_MODEL_PLANNER_AGENT=$(shell_quote "$planner_route")"
  echo "export DEEP_RESEARCH_MODEL_SOURCE_AGENT=$(shell_quote "$source_route")"
  echo "export DEEP_RESEARCH_MODEL_LONG_CONTEXT_AGENT=$(shell_quote "$long_context_route")"
  echo "export DEEP_RESEARCH_MODEL_ANALYST_AGENT=$(shell_quote "$analyst_route")"
  echo "export DEEP_RESEARCH_MODEL_SCENARIO_AGENT=$(shell_quote "$scenario_route")"
  echo "export DEEP_RESEARCH_MODEL_WRITER_AGENT=$(shell_quote "$writer_route")"
  echo "export DEEP_RESEARCH_MODEL_REVIEWER_AGENT=$(shell_quote "$reviewer_route")"
  echo ""
  [ -n "$brave_key" ] && echo "export BRAVE_API_KEY=$(shell_quote "$brave_key")"
  [ -n "$bocha_key" ] && echo "export BOCHA_API_KEY=$(shell_quote "$bocha_key")"
  [ -n "$exa_key" ] && echo "export EXA_API_KEY=$(shell_quote "$exa_key")"
} > "$CONFIG_ENV"

{
  echo "# Provider registry for humans and rollout scripts"
  for provider_id in "${provider_ids[@]}"; do
    echo "[$provider_id]"
    echo "name=$(provider_field "$provider_id" name)"
    echo "base_url=$(provider_field "$provider_id" base)"
    echo "auth_env=$(provider_field "$provider_id" auth)"
    echo "pro_model=$(provider_field "$provider_id" pro)"
    echo "fast_model=$(provider_field "$provider_id" fast)"
    echo "long_context_model=$(provider_field "$provider_id" long)"
    echo ""
  done
} > "$PROVIDERS_FILE"

chmod 600 "$CONFIG_ENV" "$PROVIDERS_FILE"

echo ""
install_choice="$(prompt "Optional: install/update OpenCode provider metadata now (no secrets are written to OpenCode config)" "N")"
case "$install_choice" in
  y|Y|yes|YES)
    "$SCRIPT_DIR/install-opencode-providers.sh"
    ;;
  *)
    echo "Skipped OpenCode provider metadata install. Other hosts can read $CONFIG_ENV directly. You can run scripts/install-opencode-providers.sh later."
    ;;
esac

echo ""
echo "Setup complete."
echo "Config: $CONFIG_ENV"
echo "Tip: rerun this script whenever you want to switch provider, endpoint, keys, or per-agent models."
