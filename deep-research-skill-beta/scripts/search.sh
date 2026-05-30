#!/usr/bin/env bash
# ============================================================================
# search.sh — Deep Research 统一搜索入口
# ============================================================================
# 功能：
#   1. 自动检测查询语言（中文/英文/混合）
#   2. 按语言路由到最佳搜索后端
#   3. 支持手动指定后端（--backend bocha|brave|exa|auto）
#   4. 集成会话级缓存（默认写入 ~/.cache/deep-research-skill/search-cache.json）
#   5. 集成搜索计数器（默认写入 ~/.local/state/deep-research-skill/search-count）
#   6. 重试逻辑（指数退避，最多3次）
#   7. 超时控制
#   8. 统一 JSON 输出格式
#
# 用法：
#   search.sh "查询关键词"                           # 自动路由
#   search.sh "查询关键词" --lang zh --backend bocha  # 强制中文走博查
#   search.sh "查询关键词" --lang en --count 5         # 英文，5条结果
#   search.sh "查询关键词" --freshness oneWeek         # 时效性过滤（仅博查）
#   search.sh "查询关键词" --no-cache                  # 跳过缓存
#   search.sh "查询关键词" --parallel                     # 多引擎并发搜索
#   search.sh "查询关键词" --json                          # 输出原始 JSON（用于管道）
#
# 输出格式（默认人类可读）：
#   [zh] 结果标题
#     https://example.com/article
#     摘要内容...
# ============================================================================

set -euo pipefail

# ─── 配置 ────────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
CONFIG_ENV="${DEEP_RESEARCH_CONFIG_ENV:-${DEEP_RESEARCH_SKILL_CONFIG_DIR:-$HOME/.config/deep-research-skill}/config.env}"

if [ -f "$CONFIG_ENV" ]; then
  # shellcheck disable=SC1090
  source "$CONFIG_ENV"
fi

# 代理配置（统一使用 7890 端口，与 runner 保持一致）
PROXY_PORT="${DEEP_RESEARCH_PROXY_PORT:-7890}"
PROXY_HOST="127.0.0.1"
CACHE_DIR="${DEEP_RESEARCH_CACHE_DIR:-${XDG_CACHE_HOME:-$HOME/.cache}/deep-research-skill}"
STATE_DIR="${DEEP_RESEARCH_STATE_DIR:-${XDG_STATE_HOME:-$HOME/.local/state}/deep-research-skill}"
CACHE_FILE="${DEEP_RESEARCH_CACHE_FILE:-$CACHE_DIR/search-cache.json}"
COUNT_FILE="${DEEP_RESEARCH_COUNT_FILE:-$STATE_DIR/search-count}"
MAX_RETRIES="${DEEP_RESEARCH_MAX_RETRIES:-3}"
TIMEOUT="${DEEP_RESEARCH_TIMEOUT:-15}"
DEFAULT_COUNT=8

mkdir -p "$CACHE_DIR" "$STATE_DIR"
chmod 700 "$CACHE_DIR" "$STATE_DIR" 2>/dev/null || true

# Brave API. Users must provide their own key via setup.sh or environment.
BRAVE_API_KEY="${BRAVE_API_KEY:-}"
BRAVE_API_URL="https://api.search.brave.com/res/v1/web/search"

# 博查 API
BOCHA_API_KEY="${BOCHA_API_KEY:-}"
BOCHA_API_URL="https://api.bochaai.com/v1/web-search"

# Exa API
EXA_API_KEY="${EXA_API_KEY:-}"
EXA_API_URL="https://api.exa.ai/search"

# 自动从配置文件加载 API Key
if [ -f "$HOME/.bocha-config" ]; then
  source "$HOME/.bocha-config" 2>/dev/null || true
fi
BOCHA_API_KEY="${BOCHA_API_KEY:-}"
EXA_API_KEY="${EXA_API_KEY:-}"

# ─── 参数解析 ────────────────────────────────────────────────────
QUERY=""
BACKEND="auto"
LANG="auto"
COUNT=$DEFAULT_COUNT
FRESHNESS="noLimit"
NO_CACHE=false
RAW_JSON=false
DRY_RUN=false
PARALLEL=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --backend)   BACKEND="$2"; shift 2 ;;
    --lang)      LANG="$2"; shift 2 ;;
    --count)     COUNT="$2"; shift 2 ;;
    --freshness) FRESHNESS="$2"; shift 2 ;;
    --no-cache)  NO_CACHE=true; shift ;;
    --parallel)  PARALLEL=true; shift ;;
    --json)      RAW_JSON=true; shift ;;
    --dry-run)   DRY_RUN=true; shift ;;
    --timeout)   TIMEOUT="$2"; shift 2 ;;
    --help|-h)
      echo "Usage: search.sh QUERY [OPTIONS]"
      echo ""
      echo "Options:"
      echo "  --backend bocha|brave|exa|auto  搜索后端（默认 auto）"
      echo "  --parallel                    多引擎并发搜索"
      echo "  --lang zh|en|auto           查询语言（默认 auto）"
      echo "  --count N                   返回结果数（默认 8）"
      echo "  --freshness noLimit|oneDay|oneWeek|oneMonth|oneYear  时效性过滤（仅博查）"
      echo "  --no-cache                  跳过缓存"
      echo "  --json                      输出原始 JSON"
      echo "  --timeout N                 超时秒数（默认 15）"
      echo "  --dry-run                   仅显示即将执行的搜索，不实际搜索"
      echo "  --help, -h                  显示此帮助"
      exit 0
      ;;
    -*)
      echo "ERROR: Unknown option: $1" >&2
      exit 1
      ;;
    *)
      QUERY="$1"
      shift
      ;;
  esac
done

if [ -z "$QUERY" ]; then
  echo "ERROR: Missing search query." >&2
  echo "Usage: search.sh \"your query\" [--backend bocha|brave|exa|auto]" >&2
  exit 1
fi

# ─── 辅助函数 ────────────────────────────────────────────────────

proxy_setup() {
  if nc -z -w 1 "$PROXY_HOST" "$PROXY_PORT" 2>/dev/null; then
    export https_proxy="http://${PROXY_HOST}:${PROXY_PORT}"
    export http_proxy="http://${PROXY_HOST}:${PROXY_PORT}"
    return 0
  else
    return 1
  fi
}

detect_language() {
  local q="$1"
  local zh_count=0
  local total=0

  # Count CJK characters (force UTF-8 locale for perl)
  zh_count=$(printf '%s' "$q" | LC_ALL=en_US.UTF-8 perl -CS -ne 'print scalar(() = m/[\x{4e00}-\x{9fff}\x{3400}-\x{4dbf}\x{20000}-\x{2a6df}\x{2a700}-\x{2b73f}\x{2b740}-\x{2b81f}\x{2b820}-\x{2ceaf}\x{2ceb0}-\x{2ebe0}\x{3000}-\x{303f}\x{ff00}-\x{ffef}]/g)' 2>/dev/null)
  total=$(printf '%s' "$q" | LC_ALL=en_US.UTF-8 perl -CS -ne 'print length($_)' 2>/dev/null)

  if [ -z "$zh_count" ]; then
    zh_count=0
  fi
  if [ -z "$total" ]; then
    total=0
  fi

  # If >15% of characters are Chinese, consider it a Chinese query
  if [ "$total" -gt 0 ] && [ "$(( zh_count * 100 / total ))" -ge 15 ]; then
    echo "zh"
  else
    echo "en"
  fi
}

cache_key() {
  local backend="$1"
  local query="$2"
  local extra="$3"  # e.g. ":parallel" or ":json"
  echo "${backend}:$(echo "$query" | md5 | head -c 16):c${COUNT}:f${FRESHNESS:0:2}:l${LANG}${extra}"
}

cache_get() {
  local key="$1"
  if [ "$NO_CACHE" = true ]; then
    return 1
  fi
  if [ ! -f "$CACHE_FILE" ]; then
    return 1
  fi
  python3 -c "
import json, sys
try:
    with open('$CACHE_FILE') as f:
        cache = json.load(f)
    val = cache.get('$key', '')
    if val:
        print(val)
        sys.exit(0)
    else:
        sys.exit(1)
except:
    sys.exit(1)
" 2>/dev/null
}

cache_set() {
  local key="$1"
  local value="$2"
  python3 -c "
import json, sys
cache = {}
try:
    with open('$CACHE_FILE') as f:
        cache = json.load(f)
except:
    pass
cache['$key'] = sys.stdin.read().rstrip('\n')
with open('$CACHE_FILE', 'w') as f:
    json.dump(cache, f)
" <<< "$value" 2>/dev/null
  chmod 600 "$CACHE_FILE" 2>/dev/null || true
}

counter_check() {
  local budget="${1:-15}"
  if [ ! -f "$COUNT_FILE" ]; then
    echo "0" > "$COUNT_FILE"
    chmod 600 "$COUNT_FILE" 2>/dev/null || true
    return 0
  fi
  local count
  count=$(cat "$COUNT_FILE" 2>/dev/null || echo "0")
  if [ "$count" -ge "$budget" ]; then
    echo "WARNING: Search count ($count) >= budget ($budget). Consider using fallback." >&2
    return 1
  fi
  return 0
}

counter_inc() {
  if [ ! -f "$COUNT_FILE" ]; then
    echo "1" > "$COUNT_FILE"
  else
    local count
    count=$(cat "$COUNT_FILE" 2>/dev/null || echo "0")
    echo $((count + 1)) > "$COUNT_FILE"
  fi
  chmod 600 "$COUNT_FILE" 2>/dev/null || true
}

retry() {
  local max_attempts="$1"
  shift
  local cmd=("$@")
  local attempt=1
  local delay=1

  while [ "$attempt" -le "$max_attempts" ]; do
    if "${cmd[@]}" 2>/dev/null; then
      return 0
    fi
    if [ "$attempt" -lt "$max_attempts" ]; then
      echo "WARNING: Attempt $attempt failed, retrying in ${delay}s..." >&2
      sleep "$delay"
      delay=$((delay * 2))
    fi
    attempt=$((attempt + 1))
  done
  return 1
}

# ─── 搜索后端实现 ────────────────────────────────────────────────

search_brave() {
  local query="$1"
  local count="${2:-$DEFAULT_COUNT}"
  local search_lang="${3:-}"

  if [ -z "$BRAVE_API_KEY" ]; then
    echo "BRAVE_API_KEY not set. Run $SCRIPT_DIR/setup.sh or export BRAVE_API_KEY." >&2
    return 1
  fi

  proxy_setup || {
    echo "ERROR: Proxy not available at ${PROXY_HOST}:${PROXY_PORT}" >&2
    return 1
  }

  local encoded_q
  encoded_q=$(echo "$query" | python3 -c "import sys,urllib.parse; print(urllib.parse.quote(sys.stdin.read().strip()))")
  local url="${BRAVE_API_URL}?q=${encoded_q}&count=${count}"
  if [ -n "$search_lang" ] && [ "$search_lang" != "auto" ]; then
    url="${url}&search_lang=${search_lang}"
  fi

  curl -s --connect-timeout "$TIMEOUT" \
    -H "X-Subscription-Token: $BRAVE_API_KEY" \
    "$url"
}

search_bocha() {
  local query="$1"
  local count="${2:-$DEFAULT_COUNT}"

  if [ -z "$BOCHA_API_KEY" ]; then
    echo '{"code":401,"message":"BOCHA_API_KEY not set"}' >&2
    return 1
  fi

  local payload
  payload=$(python3 -c "
import json, sys
q = sys.stdin.read().strip()
print(json.dumps({
    'query': q,
    'count': $count,
    'freshness': '$FRESHNESS'
}))
" <<< "$query")

  local raw
  raw=$(curl -s --connect-timeout "$TIMEOUT" \
    -H "Authorization: Bearer $BOCHA_API_KEY" \
    -H "Content-Type: application/json" \
    -d "$payload" \
    "$BOCHA_API_URL")

  local code
  code=$(echo "$raw" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('code',-1))" 2>/dev/null || echo "-1")
  if [ "$code" != "200" ]; then
    local msg
    msg=$(echo "$raw" | python3 -c "import json,sys; print(json.load(sys.stdin).get('message',''))" 2>/dev/null || echo "unknown")
    echo "BOCHA_ERROR|$code|$msg" >&2
    return 1
  fi

  echo "$raw"
}

search_exa() {
  local query="$1"
  local count="${2:-$DEFAULT_COUNT}"

  if [ -z "$EXA_API_KEY" ]; then
    echo "EXA_API_KEY not set. Get a key at https://dashboard.exa.ai/api-keys" >&2
    return 1
  fi

  local payload
  payload=$(python3 -c "
import json, sys
q = sys.stdin.read().strip()
print(json.dumps({
    'query': q,
    'numResults': $count,
    'type': 'auto',
    'contents': {'highlights': True}
}))
" <<< "$query")

  curl -s --connect-timeout "$TIMEOUT" \
    -H "x-api-key: $EXA_API_KEY" \
    -H "Content-Type: application/json" \
    -d "$payload" \
    "$EXA_API_URL"
}

# ─── 结果格式化 ──────────────────────────────────────────────────

format_brave_results() {
  python3 -c "
import json, sys
data = json.load(sys.stdin)
results = data.get('web', {}).get('results', [])
if not results:
    print('search_status=no_results')
    sys.exit(1)
for r in results:
    lang = r.get('language', '?')
    title = r.get('title', '')
    url = r.get('url', '')
    desc = r.get('description', '')[:200]
    print(f'[{lang}] {title}')
    print(f'  {url}')
    print(f'  {desc}')
    ex = r.get('extra_snippets', [])
    if ex:
        print(f'  [+] {ex[0][:200]}')
    print()
" 2>/dev/null
}

format_exa_results() {
  python3 -c "
import json, sys
data = json.load(sys.stdin)
results = data.get('results', [])
if not results:
    print('search_status=no_results')
    sys.exit(1)
search_type = data.get('requestId', '')[:8] if data.get('requestId') else ''
cost = data.get('costDollars', {}).get('total', 0)
for r in results:
    title = r.get('title', '')
    url = r.get('url', '')
    date = (r.get('publishedDate') or '')[:10]
    author = r.get('author', '')
    score = r.get('score') or 0
    highlights = r.get('highlights') or []
    print(f'[exa:{score:.4f}] {title}')
    print(f'  {url}')
    if date or author:
        print(f'  date: {date or \"-\"}  author: {str(author)[:60] if author else \"-\"}')
    for h in highlights[:2]:
        print(f'  [+] {h[:200]}')
    print()
if cost:
    print(f'(cost: \${cost:.4f})')
"
}

format_bocha_results() {
  python3 -c "
import json, sys
data = json.load(sys.stdin)
code = data.get('code', -1)
if code != 200:
    msg = data.get('message', 'Unknown error')
    print(f'BOCHA_ERROR|{code}|{msg}', file=sys.stderr)
    sys.exit(1)
pages = data.get('data', {}).get('webPages', {}).get('value', [])
if not pages:
    print('search_status=no_results')
    sys.exit(1)
for p in pages:
    title = p.get('title', '')
    url = p.get('url', '')
    snippet = (p.get('snippet') or '')[:250]
    site = p.get('siteName', '')
    date = (p.get('dateLastCrawled') or '')[:10]
    print(f'[zh] {title}')
    print(f'  {url}')
    print(f'  site: {site}  date: {date}')
    print(f'  {snippet}')
    print()
"
}

# ─── 路由逻辑 ────────────────────────────────────────────────────

resolve_backend() {
  local detected_lang="$1"
  local requested="$2"

  if [ "$requested" != "auto" ]; then
    echo "$requested"
    return
  fi

  if [ "$detected_lang" = "zh" ]; then
    if [ -n "$BOCHA_API_KEY" ]; then
      echo "bocha"
    elif [ -n "$BRAVE_API_KEY" ]; then
      echo "brave"
    elif [ -n "$EXA_API_KEY" ]; then
      echo "WARNING: Chinese query detected but BOCHA_API_KEY and BRAVE_API_KEY are not set. Falling back to Exa." >&2
      echo "exa"
    else
      echo "WARNING: No search API keys configured. Defaulting to bocha so the missing key error is explicit." >&2
      echo "bocha"
    fi
  else
    if [ -n "$EXA_API_KEY" ]; then
      echo "exa"
    elif [ -n "$BRAVE_API_KEY" ]; then
      echo "brave"
    elif [ -n "$BOCHA_API_KEY" ]; then
      echo "WARNING: English query detected but EXA_API_KEY and BRAVE_API_KEY are not set. Falling back to Bocha." >&2
      echo "bocha"
    else
      echo "WARNING: No search API keys configured. Defaulting to exa so the missing key error is explicit." >&2
      echo "exa"
    fi
  fi
}

# ─── 主流程 ──────────────────────────────────────────────────────

# API Key 可用性检查（跳过 help / dry-run / 单个后端检查）
api_key_check_ok() {
  [ "$DRY_RUN" = true ] && return 0
  [ -n "${BRAVE_API_KEY:-}" ] && return 0
  [ -n "${BOCHA_API_KEY:-}" ] && return 0
  [ -n "${EXA_API_KEY:-}" ] && return 0
  return 1
}

if ! api_key_check_ok; then
  echo "ERROR: 至少需要配置一个搜索 API Key 才能联网搜索。" >&2
  echo "  请运行 scripts/setup.sh 配置 Bocha / Brave / Exa API Key。" >&2
  echo "  或在环境变量中设置 BRAVE_API_KEY / BOCHA_API_KEY / EXA_API_KEY。" >&2
  exit 1
fi

main() {
  local detected_lang
  if [ "$LANG" = "auto" ]; then
    detected_lang=$(detect_language "$QUERY")
  else
    detected_lang="$LANG"
  fi

  local backend
  backend=$(resolve_backend "$detected_lang" "$BACKEND")

  if [ "$DRY_RUN" = true ]; then
    echo "DRY RUN: backend=$backend lang=$detected_lang query=\"$QUERY\" count=$COUNT freshness=$FRESHNESS parallel=$PARALLEL"
    return 0
  fi

  # ─── Parallel mode ──────────────────────────────────────────────────
  if [ "$PARALLEL" = true ] && [ "$BACKEND" = "auto" ]; then
    search_parallel "$detected_lang"
    return $?
  fi

  # ─── Single-backend mode ────────────────────────────────────────────
  local ckey
  ckey=$(cache_key "$backend" "$QUERY" "")
  if [ "$NO_CACHE" != true ]; then
    local cached
    if cached=$(cache_get "$ckey"); then
      echo "[CACHE HIT] $backend: $QUERY" >&2
      echo "$cached"
      return 0
    fi
  fi

  search_sequential "$backend" "$detected_lang"
}

search_parallel() {
  local detected_lang="$1"
  local primary secondary

  if [ "$detected_lang" = "zh" ]; then
    primary="bocha"
    secondary="brave"
  else
    primary="exa"
    secondary="brave"
  fi

  local tmp1 tmp2 pid1 pid2 r1 r2
  tmp1=$(mktemp /tmp/search_parallel_XXXXXX)
  tmp2=$(mktemp /tmp/search_parallel_XXXXXX)
  local raw1 raw2
  raw1=$(mktemp /tmp/search_parallel_raw_XXXXXX)
  raw2=$(mktemp /tmp/search_parallel_raw_XXXXXX)

  echo "[PARALLEL] $primary + $secondary: $QUERY" >&2

  # Run both backends concurrently; capture exit code, raw output, formatted output
  (
    local p_result=""
    local p_ckey
    p_ckey=$(cache_key "$primary" "$QUERY" ":parallel")
    # Check cache first
    if [ "$NO_CACHE" != true ]; then
      p_result=$(cache_get "$p_ckey") || true
    fi
    if [ -n "$p_result" ]; then
      echo "[CACHE HIT] $primary: $QUERY" >&2
      echo "$p_result" > "$raw1"
      echo "$p_result" | format_bocha_results > "$tmp1" 2>/dev/null; echo "${PIPESTATUS[1]}" > "${tmp1}.exit"
      echo "0" > "${tmp1}.status"
    else
      search_bocha "$QUERY" "$COUNT" > "$raw1" 2>/dev/null; r1=$?
      echo "$r1" > "${tmp1}.status"
      if [ "$r1" = "0" ]; then
        cache_set "$p_ckey" "$(cat "$raw1")"
        # Try to format, capture exit code
        cat "$raw1" | format_bocha_results > "$tmp1" 2>/dev/null; echo "${PIPESTATUS[1]}" > "${tmp1}.exit"
      fi
    fi
  ) &
  pid1=$!

  (
    local s_result=""
    local s_ckey
    s_ckey=$(cache_key "$secondary" "$QUERY" ":parallel")
    if [ "$NO_CACHE" != true ]; then
      s_result=$(cache_get "$s_ckey") || true
    fi
    if [ -n "$s_result" ]; then
      echo "[CACHE HIT] $secondary: $QUERY" >&2
      echo "$s_result" > "$raw2"
      echo "$s_result" | format_brave_results > "$tmp2" 2>/dev/null; echo "${PIPESTATUS[1]}" > "${tmp2}.exit"
      echo "0" > "${tmp2}.status"
    else
      search_brave "$QUERY" "$COUNT" > "$raw2" 2>/dev/null; r2=$?
      echo "$r2" > "${tmp2}.status"
      if [ "$r2" = "0" ]; then
        cache_set "$s_ckey" "$(cat "$raw2")"
        # Count Brave success
        counter_inc
        local count_after
        count_after=$(cat "$COUNT_FILE" 2>/dev/null || echo "0")
        echo "[COUNT] Brave count: $count_after" >&2
        cat "$raw2" | format_brave_results > "$tmp2" 2>/dev/null; echo "${PIPESTATUS[1]}" > "${tmp2}.exit"
      fi
    fi
  ) &
  pid2=$!

  wait $pid1 $pid2 2>/dev/null || true

  local e1=1 e2=1
  local s1=1 s2=1
  local fmt_exit1=1 fmt_exit2=1
  [ -f "${tmp1}.exit" ] && fmt_exit1=$(cat "${tmp1}.exit")
  [ -f "${tmp2}.exit" ] && fmt_exit2=$(cat "${tmp2}.exit")
  [ -f "${tmp1}.status" ] && s1=$(cat "${tmp1}.status")
  [ -f "${tmp2}.status" ] && s2=$(cat "${tmp2}.status")

  # Determine per-backend status
  # sN=0 means API call succeeded; fmt_exit=0 means results were non-empty
  local p_status="failed" s_status="failed"
  local p_count=0 s_count=0
  local p_error="" s_error=""

  if [ "$s1" = "0" ]; then
    if [ "$fmt_exit1" = "0" ]; then
      p_status="success"
      p_count=$(grep -c "^\[" "$tmp1" 2>/dev/null || echo "0")
    else
      p_status="no_results"
      p_error="API returned success but no results"
    fi
  else
    p_status="failed"
    p_error="API call failed"
  fi

  if [ "$s2" = "0" ]; then
    if [ "$fmt_exit2" = "0" ]; then
      s_status="success"
      s_count=$(grep -c "^\[" "$tmp2" 2>/dev/null || echo "0")
    else
      s_status="no_results"
      s_error="API returned success but no results"
    fi
  else
    s_status="failed"
    s_error="API call failed"
  fi

  echo "[PARALLEL] $primary: $p_status, $secondary: $s_status" >&2

  # Determine overall status
  local overall_status
  if [ "$p_status" = "success" ] && [ "$s_status" = "success" ]; then
    overall_status="success"
    e1=0
  elif [ "$p_status" = "success" ] || [ "$s_status" = "success" ]; then
    overall_status="partial_success"
    e1=0
  elif [ "$p_status" = "no_results" ] || [ "$s_status" = "no_results" ]; then
    overall_status="no_results"
    e1=1
  else
    overall_status="failed"
    e1=1
  fi

  # Output failure info to stderr
  if [ "$e1" != "0" ]; then
    echo "SEARCH_STATUS: $overall_status" >&2
    echo "FAILURE_TYPE: web_search_failed" >&2
    echo "ATTEMPTED_BACKENDS: $primary:$p_status,$secondary:$s_status" >&2
  fi

  # Output results
  if [ "$RAW_JSON" = true ]; then
    # Structured JSON output
    local merged_text=""
    merged_text=$(merge_results "$tmp1" "$tmp2" "$primary" "$secondary" 2>/dev/null || true)

    python3 -c "
import json, sys
output = {
    'query': '$(echo "$QUERY" | sed "s/['\\\"]//g")',
    'lang': '$detected_lang',
    'mode': 'parallel',
    'overall_status': '$overall_status',
    'backends': [
        {'name': '$primary', 'status': '$p_status', 'result_count': $p_count, 'error': '$(echo "$p_error" | sed "s/['\\\"]//g")'},
        {'name': '$secondary', 'status': '$s_status', 'result_count': $s_count, 'error': '$(echo "$s_error" | sed "s/['\\\"]//g")'}
    ],
    'results': '''$(printf '%s' "$merged_text" | sed "s/['\\\"]//g")''',
    'errors': []
}
json.dump(output, sys.stdout, ensure_ascii=False, indent=2)
print()
"
  else
    merge_results "$tmp1" "$tmp2" "$primary" "$secondary"
  fi

  rm -f "$tmp1" "$tmp2" "${tmp1}.exit" "${tmp2}.exit" "$raw1" "$raw2"

  return $e1
}

search_with_fallback() {
  local backend="$1"
  local detected_lang="$2"
  local result
  local last_error=""

  if [ "$backend" = "bocha" ]; then
    if result=$(retry "$MAX_RETRIES" search_bocha "$QUERY" "$COUNT"); then
      echo "$result" | format_bocha_results && return 0
      # No results — fall through to Brave
      echo "WARNING: Bocha returned no results, trying Brave..." >&2
      last_error="bocha:no_results"
    else
      echo "WARNING: Bocha failed, trying Brave..." >&2
      last_error="bocha:api_failed"
    fi
    if result=$(retry "$MAX_RETRIES" search_brave "$QUERY" "$COUNT" "zh"); then
      echo "$result" | format_brave_results && return 0
      echo "WARNING: Brave also returned no results after Bocha failure." >&2
      last_error="${last_error}:brave:no_results"
    else
      last_error="${last_error}:brave:api_failed"
    fi
  elif [ "$backend" = "exa" ]; then
    if result=$(retry "$MAX_RETRIES" search_exa "$QUERY" "$COUNT"); then
      echo "$result" | format_exa_results && return 0
      echo "WARNING: Exa returned no results, trying Brave..." >&2
      last_error="exa:no_results"
    else
      echo "WARNING: Exa failed, trying Brave..." >&2
      last_error="exa:api_failed"
    fi
    if result=$(retry "$MAX_RETRIES" search_brave "$QUERY" "$COUNT"); then
      echo "$result" | format_brave_results && return 0
      echo "WARNING: Brave also returned no results after Exa failure." >&2
      last_error="${last_error}:brave:no_results"
    else
      last_error="${last_error}:brave:api_failed"
    fi
  else
    if result=$(retry "$MAX_RETRIES" search_brave "$QUERY" "$COUNT"); then
      echo "$result" | format_brave_results && return 0
      echo "WARNING: Brave returned no results." >&2
      last_error="brave:no_results"
    else
      last_error="brave:api_failed"
    fi
  fi

  # All backends exhausted with no usable results
  echo "SEARCH_STATUS: no_results" >&2
  echo "FAILURE_TYPE: web_search_failed" >&2
  echo "ATTEMPTED_BACKENDS: $last_error" >&2
  return 1
}

merge_results() {
  local f1="$1" f2="$2" label1="$3" label2="$4"
  (
    echo "=== $label1 ==="
    cat "$f1"
    echo ""
    echo "=== $label2 ==="
    cat "$f2"
  )
}

search_sequential() {
  local backend="$1"
  local detected_lang="$2"

  local count_before=0
  if [ "$backend" = "brave" ]; then
    counter_check 15 || true
    count_before=$(cat "$COUNT_FILE" 2>/dev/null || echo "0")
  fi

  echo "[SEARCH] $backend: $QUERY" >&2
  local result
  local search_lang=""
  if [ "$detected_lang" = "zh" ]; then
    search_lang="zh"
  fi

  # Try primary backend
  local search_ok=false
  local final_backend="$backend"

  if [ "$backend" = "bocha" ]; then
    if result=$(retry "$MAX_RETRIES" search_bocha "$QUERY" "$COUNT"); then
      if echo "$result" | format_bocha_results > /dev/null 2>&1; then
        search_ok=true
      else
        echo "WARNING: Bocha returned no results, falling back to Brave..." >&2
        final_backend="brave"
      fi
    else
      echo "WARNING: Bocha search failed, falling back to Brave..." >&2
      final_backend="brave"
    fi
  elif [ "$backend" = "exa" ]; then
    if result=$(retry "$MAX_RETRIES" search_exa "$QUERY" "$COUNT"); then
      if echo "$result" | format_exa_results > /dev/null 2>&1; then
        search_ok=true
      else
        echo "WARNING: Exa returned no results, falling back to Brave..." >&2
        final_backend="brave"
      fi
    else
      echo "WARNING: Exa search failed, falling back to Brave..." >&2
      final_backend="brave"
    fi
  else
    if result=$(retry "$MAX_RETRIES" search_brave "$QUERY" "$COUNT" "$search_lang"); then
      if echo "$result" | format_brave_results > /dev/null 2>&1; then
        search_ok=true
      else
        echo "WARNING: Brave returned no results." >&2
        # Try fallback backends
        if [ -n "$BOCHA_API_KEY" ]; then
          echo "Falling back to Bocha..." >&2
          if result=$(retry "$MAX_RETRIES" search_bocha "$QUERY" "$COUNT"); then
            if echo "$result" | format_bocha_results > /dev/null 2>&1; then
              final_backend="bocha"
              search_ok=true
            fi
          fi
        fi
        if [ "$search_ok" != true ] && [ -n "$EXA_API_KEY" ]; then
          echo "Falling back to Exa..." >&2
          if result=$(retry "$MAX_RETRIES" search_exa "$QUERY" "$COUNT"); then
            if echo "$result" | format_exa_results > /dev/null 2>&1; then
              final_backend="exa"
              search_ok=true
            fi
          fi
        fi
      fi
    else
      echo "ERROR: Brave search failed after $MAX_RETRIES attempts." >&2
      if [ -n "$BOCHA_API_KEY" ]; then
        echo "Falling back to Bocha..." >&2
        if result=$(retry "$MAX_RETRIES" search_bocha "$QUERY" "$COUNT"); then
          final_backend="bocha"
          search_ok=true
        fi
      fi
      if [ "$search_ok" != true ] && [ -n "$EXA_API_KEY" ]; then
        echo "Falling back to Exa..." >&2
        if result=$(retry "$MAX_RETRIES" search_exa "$QUERY" "$COUNT"); then
          final_backend="exa"
          search_ok=true
        fi
      fi
    fi
  fi

  if [ "$search_ok" != true ]; then
    echo "SEARCH_STATUS: no_results" >&2
    echo "FAILURE_TYPE: web_search_failed" >&2
    echo "ATTEMPTED_BACKENDS: $backend,$final_backend" >&2
    return 1
  fi

  # Count Brave success
  if [ "$final_backend" = "brave" ]; then
    counter_inc
    local count_after
    count_after=$(cat "$COUNT_FILE" 2>/dev/null || echo "0")
    echo "[COUNT] ${count_before} → ${count_after}" >&2
  fi

  # Cache the raw result
  local ckey_actual
  ckey_actual=$(cache_key "$final_backend" "$QUERY" "")
  if [ "$NO_CACHE" != true ] && [ -n "$result" ]; then
    cache_set "$ckey_actual" "$result"
  fi

  # Output
  if [ "$RAW_JSON" = true ]; then
    echo "$result"
  elif [ "$final_backend" = "bocha" ]; then
    echo "$result" | format_bocha_results
  elif [ "$final_backend" = "exa" ]; then
    echo "$result" | format_exa_results
  else
    echo "$result" | format_brave_results
  fi
}

main
