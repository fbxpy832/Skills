#!/usr/bin/env bash

# Resolve Deep Research config in host-neutral and Cowork-safe order.
# Caller should set SCRIPT_DIR and optionally SKILL_DIR/PROJECT_DIR first.

# Optional: load platform.sh for cygpath normalization and workbuddy paths
# (caller may not have platform.sh if this file is used standalone)
if [ -z "${PLATFORM_SH_LOADED:-}" ]; then
  PLATFORM_SH_DIR="${SCRIPT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}"
  if [ -f "$PLATFORM_SH_DIR/platform.sh" ]; then
    # shellcheck disable=SC1090
    source "$PLATFORM_SH_DIR/platform.sh"
    PLATFORM_SH_LOADED=yes
  elif [ -f "${PLATFORM_SH_DIR%/lib}/lib/platform.sh" ]; then
    # shellcheck disable=SC1090
    source "${PLATFORM_SH_DIR%/lib}/lib/platform.sh"
    PLATFORM_SH_LOADED=yes
  fi
fi

deep_research_resolve_config() {
  local skill_dir="${SKILL_DIR:-}"
  local project_dir="${PROJECT_DIR:-}"
  local candidate
  local resolved

  if [ -n "${DEEP_RESEARCH_CONFIG_ENV:-}" ] && [ -f "$DEEP_RESEARCH_CONFIG_ENV" ]; then
    echo "$DEEP_RESEARCH_CONFIG_ENV"
    return 0
  fi

  for candidate in \
    "$PWD/config.env" \
    "${skill_dir:+$skill_dir/config.env}" \
    "${project_dir:+$project_dir/config.env}" \
    "${DEEP_RESEARCH_SKILL_CONFIG_DIR:-$HOME/.config/deep-research-skill}/config.env" \
    "$HOME/.config/deep-research-skill/config.env" \
    "${APPDATA:-$HOME/AppData/Roaming}/deep-research-skill/config.env" \
    "${WORKBUDDY_WORKSPACE:-$HOME/WorkBuddy/Claw}/.deep-research.env"
  do
    [ -n "$candidate" ] || continue
    # Normalize paths on Git Bash (mingw → cygwin/msys format)
    if type cygpath >/dev/null 2>&1; then
      candidate="$(cygpath -u "$candidate" 2>/dev/null || echo "$candidate")"
    fi
    if [ -f "$candidate" ]; then
      resolved="$candidate"
      break
    fi
  done

  if [ -n "${resolved:-}" ]; then
    echo "$resolved"
    return 0
  fi

  echo "${DEEP_RESEARCH_CONFIG_ENV:-${DEEP_RESEARCH_SKILL_CONFIG_DIR:-$HOME/.config/deep-research-skill}/config.env}"
  return 1
}

deep_research_source_config() {
  CONFIG_ENV="$(deep_research_resolve_config)" || true
  if [ -f "$CONFIG_ENV" ]; then
    # shellcheck disable=SC1090
    source "$CONFIG_ENV"
    export DEEP_RESEARCH_CONFIG_ENV="$CONFIG_ENV"
    return 0
  fi
  return 1
}
