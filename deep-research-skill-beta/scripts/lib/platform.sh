#!/usr/bin/env bash
# ============================================================================
# platform.sh — Deep Research Skill 跨平台检测库
# ============================================================================
# 此文件不含 `set -euo pipefail`，允许 source 时不改变调用者的 shell 选项。
# 所有函数用 `local`，需 bash 3.2+（macOS 自带）兼容。
# 不依赖 `declare -A` / `mapfile` / `coproc` 等 bash 4+ 特性。
# ============================================================================

# 确保 $HOME 有值（极罕见情况，但路径函数依赖它）
: "${HOME:=/tmp}"

# ─── OS 检测 ────────────────────────────────────────────────────────────
# 输出：darwin | linux | windows-gitbash | windows-wsl | unknown
dr_detect_os() {
  local uname_s
  uname_s="$(uname -s 2>/dev/null || echo Unknown)"
  case "$uname_s" in
    Darwin) echo "darwin" ;;
    Linux)
      if [ -n "${WSL_DISTRO_NAME:-}" ] || [ -n "${WSLENV:-}" ]; then
        echo "windows-wsl"
      else
        echo "linux"
      fi
      ;;
    MINGW*|MSYS*|CYGWIN*) echo "windows-gitbash" ;;
    *) echo "unknown" ;;
  esac
}

# ─── Python 命令探测 ────────────────────────────────────────────────────
# 输出（按优先级）：python3 | python | py -3
# 返回：0 找到，1 未找到
dr_detect_python() {
  if command -v python3 >/dev/null 2>&1; then
    echo "python3"; return 0
  fi
  if command -v python >/dev/null 2>&1; then
    local pyver
    pyver="$(python --version 2>&1 || true)"
    case "$pyver" in "Python 3"*) echo "python"; return 0 ;; esac
  fi
  if command -v py >/dev/null 2>&1 && py -3 --version >/dev/null 2>&1; then
    echo "py -3"; return 0
  fi
  return 1
}

# ─── Python 执行（兼容 py -3 带空格） ─────────────────────────────────
# 用法：dr_python_exec "$PYTHON_BIN" -c 'code' [args...]
dr_python_exec() {
  [ $# -ge 2 ] || { echo "dr_python_exec: need py_cmd and -c code" >&2; return 1; }
  local py_cmd="$1"
  shift
  case "$py_cmd" in
    *\ *)
      local cmd="${py_cmd%% *}"
      local arg="${py_cmd#* }"
      "$cmd" "$arg" "$@"
      ;;
    ?*)
      "$py_cmd" "$@"
      ;;
    *)
      echo "dr_python_exec: empty py_cmd" >&2
      return 1
      ;;
  esac
}

# ─── 路径归一化（Git Bash mingw 风格） ────────────────────────────────
# 对已经是 mingw 风格的路径无副作用
dr_path_normalize() {
  local path="$1"
  if command -v cygpath >/dev/null 2>&1; then
    cygpath -u "$path" 2>/dev/null || echo "$path"
  else
    echo "$path"
  fi
}

# ─── Claude Desktop 配置路径 ────────────────────────────────────────────
dr_claude_desktop_config_path() {
  local os="$1"
  case "$os" in
    darwin) echo "$HOME/Library/Application Support/Claude/claude_desktop_config.json" ;;
    linux)  echo "${XDG_CONFIG_HOME:-$HOME/.config}/Claude/claude_desktop_config.json" ;;
    windows-gitbash) echo "${APPDATA:-$HOME/AppData/Roaming}/Claude/claude_desktop_config.json" ;;
    *) return 1 ;;
  esac
}

# ─── Claude Code settings 路径（三平台一致） ──────────────────────────
dr_claude_code_settings_path() {
  echo "$HOME/.claude/settings.json"
}

# ─── WorkBuddy settings 候选路径 ───────────────────────────────────────
# 输出多行，每行一个候选
dr_workbuddy_settings_paths() {
  local os="$1"
  case "$os" in
    darwin)
      echo "$HOME/.workbuddy/settings.json"
      echo "$HOME/Library/Application Support/WorkBuddy/User/settings.json"
      ;;
    windows-gitbash)
      echo "${APPDATA:-$HOME/AppData/Roaming}/WorkBuddy/User/settings.json"
      echo "$HOME/.workbuddy/settings.json"
      ;;
    linux)
      echo "${XDG_CONFIG_HOME:-$HOME/.config}/WorkBuddy/User/settings.json"
      echo "$HOME/.workbuddy/settings.json"
      ;;
    *) return 1 ;;
  esac
}

# ─── WorkBuddy 沙箱工作目录 ──────────────────────────────────────────
dr_workbuddy_workspace_dir() {
  local os="$1"
  case "$os" in
    darwin|linux) echo "$HOME/WorkBuddy/Claw" ;;
    windows-gitbash) echo "${USERPROFILE:-$HOME}/WorkBuddy/Claw" ;;
    *) return 1 ;;
  esac
}

# ─── WorkBuddy skills-marketplace 目录 ────────────────────────────────
dr_workbuddy_skills_dir() {
  local os="$1"
  case "$os" in
    darwin|linux) echo "$HOME/.workbuddy/skills-marketplace/skills" ;;
    windows-gitbash) echo "${APPDATA:-$HOME/AppData/Roaming}/WorkBuddy/skills-marketplace/skills" ;;
    *) return 1 ;;
  esac
}

# ─── cc-switch SQLite 数据库路径 ──────────────────────────────────────
dr_ccswitch_db() {
  echo "$HOME/.cc-switch/cc-switch.db"
}

# ─── 默认研究报告输出目录 ──────────────────────────────────────────────
dr_default_output_dir() {
  local os="$1"
  case "$os" in
    darwin) echo "$HOME/Deep-Research-Outputs" ;;
    linux)  echo "$HOME/Deep-Research-Outputs" ;;
    windows-gitbash) echo "${USERPROFILE:-$HOME}/Deep-Research-Outputs" ;;
    *) echo "$HOME/Deep-Research-Outputs" ;;
  esac
}

# ─── Shell rc 文件路径 ──────────────────────────────────────────────────
dr_shell_rc_path() {
  local os="$1"
  case "$os" in
    darwin) echo "$HOME/.zshrc" ;;
    linux)  echo "$HOME/.bashrc" ;;
    *) echo "$HOME/.bashrc" ;;
  esac
}

# ─── 安全 chmod（接受 NTFS/FAT 上的模拟失败） ────────────────────────
dr_chmod_safe() {
  chmod "$@" 2>/dev/null || true
}

# ─── 编码类型判断（用于搜索路由） ────────────────────────────────────
# 简单启发式：检测字符串中是否包含 CJK/非 ASCII。返回 zh / en / mixed
dr_detect_search_lang() {
  local text="$1"
  case "$text" in
    *[一-龥]*)   echo "zh" ;;
    *[あ-ん]*)   echo "ja" ;;
    *[가-힣]*)   echo "ko" ;;
    *)
      # 检查是否有非 ASCII 字符
      local ascii_only
      ascii_only="$(printf "%s" "$text" | LC_ALL=C tr -d '[\x00-\x7F]')"
      if [ -n "$ascii_only" ]; then
        echo "zh"  # 以中文处理
      else
        echo "en"
      fi
      ;;
  esac
}
