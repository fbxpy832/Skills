# Search Adapter Contract

This document defines the backend contract for `scripts/search.sh` and external/MCP/native host search tools used by the Deep Research protocol.

---

## 1. Primary Search Entry Point

`scripts/search.sh` is the canonical search entry point for all Deep Research runs.

```bash
scripts/search.sh "query" [--backend bocha|brave|exa|auto] [--lang zh|en|auto] [opts...]
```

### 1.1 Roadmap for Custom / MCP / Native Host Search Tools

If you implement a **custom search adapter** (e.g., via MCP, host-native browser search, or an internal enterprise search API), it MUST conform to this contract. In that case, you may either:

- **Option A (recommended)**: wrap your search tool as a new backend inside `scripts/search.sh` following the existing `search_brave`/`search_bocha`/`search_exa` patterns.
- **Option B**: replace `scripts/search.sh` with a drop-in script that accepts the same CLI flags and outputs the same format.
- **Option C**: set `DEEP_RESEARCH_SEARCH_CMD` to point to a custom script that implements this contract.

---

## 2. Required Output Format

Every search backend MUST produce either:

### 2.1 Human-Readable Format (default)

```
[{lang}] {title}
  {url}
  {metadata_line}
  {snippet}
```

Example:
```
[zh] 智慧停车行业政策汇总
  https://example.gov.cn/policy/2025
  site: 住建部  date: 2025-03-15
  关于推进城市停车设施建设的指导意见，提出到2025年...
```

### 2.2 Raw JSON Format (`--json` flag)

When `--json` is passed, backends should output raw JSON from the search API:

```json
{
  "code": 200,
  "data": {
    "webPages": {
      "value": [
        {
          "title": "...",
          "url": "...",
          "snippet": "...",
          "siteName": "...",
          "dateLastCrawled": "..."
        }
      ]
    }
  }
}
```

The exact schema may vary by backend (Brave, Bocha, Exa each have their own). The runner/agent is responsible for parsing backend-specific JSON.

### 2.3 Error Output

Errors go to stderr in the format:

```
ERROR: {message}
```

Or for structured errors:

```
BOCHA_ERROR|{code}|{message}
```

---

## 3. Required CLI Flags

Every backend wrapper or drop-in replacement MUST support these flags:

| Flag | Type | Default | Description |
|------|------|---------|-------------|
| `--backend` | string | `auto` | Backend selection: `bocha`, `brave`, `exa`, `auto` |
| `--lang` | string | `auto` | Language hint: `zh`, `en`, `auto` |
| `--count` | int | `8` | Number of results to return |
| `--freshness` | string | `noLimit` | Time filter: `noLimit`, `oneDay`, `oneWeek`, `oneMonth`, `oneYear` |
| `--no-cache` | flag | off | Skip session cache |
| `--parallel` | flag | off | Multi-engine parallel search |
| `--json` | flag | off | Output raw JSON instead of formatted text |
| `--timeout` | int | `15` | Timeout in seconds |
| `--dry-run` | flag | off | Print what would be done, don't execute |
| `--help` / `-h` | flag | — | Show usage |

---

## 4. Health Check

All search backends MUST support a quick health check. The recommended pattern:

```bash
scripts/search.sh "health_check_test" --dry-run
# Expected exit code: 0
# Expected output: DRY RUN: backend=... lang=... query="health_check_test" count=...
```

For live health checks (API reachability):

```bash
# Each backend should return quickly with valid JSON or formatted output
scripts/search.sh "test" --backend brave --count 1 --timeout 5
scripts/search.sh "测试" --backend bocha --count 1 --timeout 5
scripts/search.sh "test" --backend exa --count 1 --timeout 5
```

The runner SHOULD NOT block indefinitely on health checks. Use `--timeout` to cap.

---

## 5. Fallback Order

### 5.1 Automatic Routing (default)

When `--backend auto` is used, the router follows this priority:

**Chinese queries (`--lang zh` or auto-detected Chinese):**
1. `bocha` (if `BOCHA_API_KEY` is set)
2. `brave` (fallback if Bocha unavailable)
3. `exa` (last resort, warns about Chinese query limitation)

**English queries (`--lang en` or auto-detected English):**
1. `exa` (if `EXA_API_KEY` is set)
2. `brave` (fallback if Exa unavailable)
3. `bocha` (last resort, warns about English query limitation)

### 5.2 Per-Backend Fallback

Each backend has its own internal fallback chain:

- **Bocha fails** → try Brave (with `search_lang=zh`)
- **Exa fails** → try Brave
- **Brave fails** → try Bocha (if key available) → try Exa (if key available)
- **All fail** → return error, trigger `source_failure_log`

### 5.3 Parallel Mode

When `--parallel` is used, two engines run concurrently:
- Chinese: Bocha + Brave
- English: Exa + Brave

Results are merged if both succeed. If only one succeeds, its results are used alone. If both fail, the search is marked as failed.

---

## 6. Failure Logging

Every search failure MUST be recorded with:

| Field | Example |
|-------|---------|
| `failed_task` | "市场规模数据检索" |
| `failed_source_type` | `external_media` |
| `failed_source_detail` | "Brave search returned empty results for '智慧停车 市场规模'" |
| `failure_type` | `web_search_failed` / `api_timeout` / `source_insufficient` |
| `failure_stage` | `Phase_2_资料搜索` |

See `references/source-failure-log.md` for full schema.

### 6.1 Search Status Reporting

After each search operation, the runner MUST record one of:

| Status | Condition |
|--------|-----------|
| `success` | Search completed, results returned, at least S/A/B sources found |
| `partial_success` | Search completed but results are incomplete or low quality |
| `failed` | Search could not complete (API error, timeout, no results) |

---

## 7. Caching

`scripts/search.sh` includes a session-level cache at `~/.cache/deep-research-skill/search-cache.json`.

### 7.1 Cache Behavior

- Cache key: `{backend}:{md5(query)[:16]}`
- Cache hit: skips API call, returns cached result
- `--no-cache` bypasses cache entirely
- Cache is write-through: every successful search updates the cache

### 7.2 Cache for Custom Backends

Custom backends SHOULD implement equivalent caching. Minimum:
- Cache key includes backend name + normalized query
- `--no-cache` flag respected
- Cache invalidation on freshness-sensitive queries

---

## 8. Rate Limiting

`scripts/search.sh` maintains a search counter at `~/.local/state/deep-research-skill/search-count`.

- Default budget: 15 searches per session (Brave only; Bocha/Exa are unlimited)
- When budget exceeded: warn but do not block
- Custom backends MAY implement their own rate limiting

---

## 9. Adding a New Backend

To add a new search backend to `scripts/search.sh`:

1. Add the API key variable (e.g., `CUSTOM_API_KEY`)
2. Implement `search_custom()` function following the existing pattern
3. Implement `format_custom_results()` for human-readable output
4. Add the backend to `resolve_backend()` routing logic
5. Add fallback chains in `search_sequential()` and `search_parallel()`
6. Update `scripts/setup.sh` to prompt for the new API key
7. Document in `references/search-tools.md`

### 9.1 Backend Function Contract

```bash
search_custom() {
  local query="$1"
  local count="${2:-8}"
  # ...
  # Output raw JSON to stdout
  # Output errors to stderr
  # Return 0 on success, non-zero on failure
}
```

### 9.2 Formatter Function Contract

```bash
format_custom_results() {
  # Read raw JSON from stdin
  # Output formatted text to stdout
  # Return 0 on success, non-zero on failure
}
```

---

## 10. Environment Variables

| Variable | Purpose | Required |
|----------|---------|:--------:|
| `BRAVE_API_KEY` | Brave Search API key | For Brave backend |
| `BOCHA_API_KEY` | Bocha AI search API key | For Bocha backend |
| `EXA_API_KEY` | Exa search API key | For Exa backend |
| `DEEP_RESEARCH_PROXY_PORT` | Proxy port for API calls | No (default: 7890) |
| `DEEP_RESEARCH_TIMEOUT` | Default timeout in seconds | No (default: 15) |
| `DEEP_RESEARCH_MAX_RETRIES` | Max retry attempts | No (default: 3) |
| `DEEP_RESEARCH_CACHE_DIR` | Cache directory override | No |
| `DEEP_RESEARCH_SEARCH_CMD` | Override search command | No (for custom backends) |

---

## 11. MCP Search Adapter

For hosts that use Model Context Protocol (MCP) for search:

- The MCP search tool MUST accept query + count parameters
- Output should be parsable JSON with at least: `title`, `url`, `snippet` fields
- The MCP adapter wrapper should translate MCP output to the format expected by agents
- If the MCP tool supports multiple backends, expose `--backend` equivalent

---

## 12. Native Host Search

For hosts with built-in browser search (GUI, CloudCode):

- The search tool call should produce structured results (not raw HTML)
- Results should include source URL, title, snippet, and date when available
- The native search wrapper should normalize output to the same format as `scripts/search.sh`

---

## 13. Compliance Checklist

Before claiming search adapter compliance, verify:

- [ ] Accepts `--backend`, `--lang`, `--count`, `--freshness`, `--timeout` flags
- [ ] Supports `--dry-run` mode
- [ ] Supports `--json` raw output mode
- [ ] Implements health check (dry-run exit 0)
- [ ] Uses appropriate API keys from `config.env` (never hardcoded)
- [ ] Respects `--timeout` and does not hang indefinitely
- [ ] Records failures per `source-failure-log.md` schema
- [ ] Never logs API keys in output or error messages
- [ ] Falls back to alternative backends when primary fails
- [ ] Exit code 0 on success, non-zero on failure
- [ ] Supports `DEEP_RESEARCH_SEARCH_CMD` override
