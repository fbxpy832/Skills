#!/usr/bin/env bash
set -euo pipefail

CONFIG_ENV="${DEEP_RESEARCH_CONFIG_ENV:-${DEEP_RESEARCH_SKILL_CONFIG_DIR:-$HOME/.config/deep-research-skill}/config.env}"
OPENCODE_CONFIG="${OPENCODE_CONFIG:-$HOME/.config/opencode/opencode.json}"
DRY_RUN="${DRY_RUN:-0}"

for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=1 ;;
    -h|--help)
      echo "Usage: install-opencode-providers.sh [--dry-run]"
      exit 0
      ;;
    *) echo "Unknown argument: $arg" >&2; exit 1 ;;
  esac
done

if [ ! -f "$CONFIG_ENV" ]; then
  echo "ERROR: Deep Research config not found: $CONFIG_ENV" >&2
  echo "Run scripts/setup.sh first." >&2
  exit 1
fi

# shellcheck disable=SC1090
source "$CONFIG_ENV"

mkdir -p "$(dirname "$OPENCODE_CONFIG")"

python3 - "$OPENCODE_CONFIG" "$DRY_RUN" <<'PY'
import json
import os
import re
import shutil
import sys
from datetime import datetime

path, dry_run = sys.argv[1], sys.argv[2] == "1"

def safe(provider_id: str) -> str:
    return re.sub(r"[^A-Z0-9_]", "_", provider_id.upper())

def env(name: str, default: str = "") -> str:
    return os.environ.get(name, default)

provider_ids = [p for p in env("DEEP_RESEARCH_PROVIDER_IDS").split() if p]
if not provider_ids:
    raise SystemExit("No providers found in DEEP_RESEARCH_PROVIDER_IDS")

try:
    with open(path, "r", encoding="utf-8") as f:
        config = json.load(f)
except FileNotFoundError:
    config = {"$schema": "https://opencode.ai/config.json"}

config.setdefault("$schema", "https://opencode.ai/config.json")
providers = config.setdefault("provider", {})

agent_models = [
    env("DEEP_RESEARCH_MODEL_PLANNER_AGENT"),
    env("DEEP_RESEARCH_MODEL_SOURCE_AGENT"),
    env("DEEP_RESEARCH_MODEL_LONG_CONTEXT_AGENT"),
    env("DEEP_RESEARCH_MODEL_ANALYST_AGENT"),
    env("DEEP_RESEARCH_MODEL_SCENARIO_AGENT"),
    env("DEEP_RESEARCH_MODEL_WRITER_AGENT"),
    env("DEEP_RESEARCH_MODEL_REVIEWER_AGENT"),
]

for provider_id in provider_ids:
    if provider_id in ("opencode", "opencode-go"):
        continue
    prefix = safe(provider_id)
    name = env(f"DEEP_RESEARCH_PROVIDER_{prefix}_NAME", provider_id)
    base_url = env(f"DEEP_RESEARCH_PROVIDER_{prefix}_BASE_URL")
    auth_env = env(f"DEEP_RESEARCH_PROVIDER_{prefix}_AUTH_ENV")
    models = set()
    for key in ("PRO_MODEL", "FAST_MODEL", "LONG_CONTEXT_MODEL"):
        value = env(f"DEEP_RESEARCH_PROVIDER_{prefix}_{key}")
        if value:
            models.add(value)
    for route in agent_models:
        if route.startswith(provider_id + "/"):
            models.add(route.split("/", 1)[1])

    entry = providers.setdefault(provider_id, {})
    entry["name"] = name
    entry["npm"] = "@ai-sdk/openai-compatible"
    if auth_env:
        entry["env"] = [auth_env]
    options = entry.setdefault("options", {})
    if base_url:
        options["baseURL"] = base_url
    entry["models"] = {model: {"name": model} for model in sorted(models)}

if dry_run:
    print(json.dumps(config, indent=2, ensure_ascii=False))
else:
    if os.path.exists(path):
        backup = f"{path}.backup-deep-research-{datetime.now().strftime('%Y%m%d-%H%M%S')}"
        shutil.copy2(path, backup)
        print(f"Backup: {backup}")
    with open(path, "w", encoding="utf-8") as f:
        json.dump(config, f, indent=2, ensure_ascii=False)
        f.write("\n")
    print(f"Updated OpenCode provider metadata: {path}")
    print("No API keys were written to the OpenCode config.")
PY
