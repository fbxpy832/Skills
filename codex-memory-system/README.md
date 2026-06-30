# Codex Memory Automation

Codex 记忆自动化系统 —— 从 rollout summaries 自动抽取候选记忆，
写入 Obsidian vault 的记忆管线，同步到 Codex native mirror 的完整框架。

## 架构

```text
Codex rollout summaries
        ↓
extract_candidates.py    ← 每日自动抽取候选记忆
        ↓
Obsidian: Codex-Input/pending/   ← 待人工审核
        ↓ (人工确认)
Codex-Memory/Ground-Truth.md    ← 权威记忆
        ↓
sync_memory.sh → ~/.codex/memories/  ← Codex 运行时记忆
```

## 安装

```bash
cd codex-memory-system
./bootstrap.sh
```

### 前置依赖

- macOS (测试于 Apple Silicon / 15.x)
- Obsidian vault (iCloud 同步，含 Codex-Memory/ 和 Codex-Input/)
- `brew install ripgrep`
- Python 3.10+ (macOS 自带)

### 安装后

```bash
source ~/.zshrc
codex-mem status
sync_memory.sh --status-only
```

安装器会同时配置两类自动同步：

- `launchd`: 登录/加载时同步一次，之后每 15 分钟同步一次。
- shell 启动钩子: 新开交互式 `zsh` 会话时后台补一次同步，300 秒冷却，避免频繁重复执行。

## 文件结构

| 路径 | 说明 |
|------|------|
| `cli/codex-mem` | Obsidian 记忆检索/写入 CLI |
| `scripts/*.sh` | 自动化调度脚本 |
| `scripts/extract_candidates.py` | 候选记忆抽取器 |
| `launchd/*.plist` | launchd 定时任务模板 |
| `bootstrap.sh` | 一键安装器 |

## 日常使用

| 命令 | 用途 |
|------|------|
| `memory_search.sh "关键词"` | 统一检索（Obsidian + native + rollout） |
| `memory_search.sh --rsearch "中文"` | 中文专用搜索 |
| `sync_memory.sh` | 手动同步到 Codex native mirror |
| `review_memory.sh` | 生成记忆健康审计报告 |
| `run_all.sh` | 完整每日管线（抽取 + 同步 + 审计） |
| `codex-mem search "关键词"` | Obsidian 全文搜索 |
| `codex-mem ground-truth` | 查看 Ground-Truth.md |

## 记忆管线工作流

1. 每天 9:00 launchd 自动执行 `run_all.sh`：
   - 抽取候选记忆 → `Codex-Input/pending/`
   - 同步到 `~/.codex/memories/memory_summary.md`
   - 生成审计报告 → `Codex-Input/review/memory-audit-*.md`
2. `com.richard.codex-memory-sync` 在登录/加载时自动同步一次，并每 15 分钟同步一次。
3. 新开交互式 `zsh` 会话时，`~/.zshrc` 启动钩子会在后台补一次同步（300 秒冷却）。
4. 你打开 Obsidian，审查 `pending/` 中的候选：
   - 有效记忆 → 移入 `approved/` 或直接合入 `Ground-Truth.md`
   - 无用内容 → 删除
5. 审查 `review/` 中的审计报告，处理冲突和过期项
6. 手动 sync: `sync_memory.sh`

## 迁移到新 Mac

1. 拷贝整个 `codex-memory-system/` 目录到新机器
2. 新机器上确保 iCloud Obsidian vault 已同步
3. 运行 `./bootstrap.sh`
4. 检查 `codex-mem status` 输出

## 文件说明

### Codex-Input 元数据规范

所有手动写入的记忆文件应包含 frontmatter:

```yaml
---
type: preference | knowledge | decision | project_note | procedure | pitfall
scope: global | project | repo | tool
project:
confidence: high | medium | low
status: active | stale | deprecated | pending
source: manual | session_extract | rollout_summary
created_at: YYYY-MM-DD
last_verified:
---
```

### 日志

所有脚本的输出写入 `~/.codex/memory-automation/logs/`。
launchd 日志: `sync-launchd.log`, `daily-launchd.log`。
shell 启动同步节流文件: `~/.codex/memory-automation/.startup-sync-stamp`。

## 注意事项

- 自动生成内容仅进入 `pending/`，不会静默修改 `Ground-Truth.md`
- `codex-mem` 只读 Obsidian vault，不写
- launchd 定时器加载后可通过 `launchctl list | grep codex-memory` 检查状态
- shell 启动同步只在交互式 `zsh` 中生效，后台执行，不阻塞终端启动
- 中文搜索用 `memory_search.sh --rsearch` 以获得更高命中率
