# Deep Research Multi-host Distribution Package — 安装手册

本包不是单一 OpenCode 插件。**多宿主分发包**意味着同一套配置、runner、搜索和输出协议，通过不同 host adapter 供多个宿主使用。

## 支持的宿主

| 宿主 | 安装方式 | 入口 |
|------|---------|------|
| **OpenCode** | 官方 plugin 安装 | `index.js` → `scripts/opencode-research-runner.sh` |
| **Codex** | SKILL.md + 通用 Runner | `scripts/generic-research-runner.sh` |
| **Claude Code** | 通用 Runner | `scripts/generic-research-runner.sh` |
| **CloudCode / GUI / TU** | 通用 Runner | `scripts/generic-research-runner.sh` |
| **终端 / CI** | 直接执行脚本 | `scripts/*.sh` |

---

## Quick Start（所有宿主通用）

### 一、安装

```bash
opencode plugin /path/to/deep-research-plugin --force
```

### 二、配置（必须）

```bash
/path/to/deep-research-plugin/scripts/setup.sh
```

> **这一步不是可选的。** 不运行 setup 就不会有模型供应商、搜索 API key 和输出目录配置。安装后首次使用 `deep_research_run` tool 时也会提示运行。

setup 会生成本机私有配置：`~/.config/deep-research-skill/config.env`

配置内容包括：
- 各 agent 模型来源（provider/model 路由）
- 搜索 API key（Brave/Bocha/Exa，至少一个）
- 输出目录（DEEP_RESEARCH_OUTPUT_DIR）

### 三、验证

```bash
./scripts/generic-research-runner.sh cost_saving /tmp/test-task.md /tmp/test-out . --dry-run --sequential
./eval/run-eval.sh --dry-run --runner generic
```

---

## OpenCode Adapter

### 安装（官方 plugin 方式）

```bash
opencode plugin /path/to/deep-research-plugin --force
```

全局安装：

```bash
opencode plugin /path/to/deep-research-plugin --global --force
```

或手动编辑项目级 `.opencode/opencode.json` 或全局 `~/.config/opencode/opencode.json`：

```json
{
  "plugin": ["/path/to/deep-research-plugin"]
}
```

OpenCode 官方 loader 通过 `package.json` → `main` → `index.js` 加载插件。`index.js` 提供 `deep_research_run` tool 和 runner 封装。

### 使用

安装后 `deep_research_run` tool 即可在 OpenCode 对话中使用。也可直接调用 runner：

```bash
./scripts/opencode-research-runner.sh high_quality /tmp/task.md /tmp/out . --sequential
```

如需斜杠命令，在 `opencode.json` 中添加 command 定义（参见 https://opencode.ai/docs/commands/）。

---

## Codex Adapter

作为 skill 使用：复制或链接 SKILL.md 到 Codex skills 目录。Codex 通过 autoloop 调用通用 Runner：

```bash
./scripts/generic-research-runner.sh high_quality /tmp/task.md /tmp/out /path/to/repo --sequential
```

Codex 只读取 compact summary（`run-summary.md`），不直接执行 agent。

---

## Claude Code / CloudCode / GUI / TU

统一通过通用 Runner 接入，宿主负责真实 agent 调用，遵守 `references/host-adapter-contract.md`。

```bash
./scripts/generic-research-runner.sh high_quality /tmp/task.md /tmp/out . --sequential
```

---

## Terminal / CI

```bash
# Dry-run 验证配置
./scripts/generic-research-runner.sh high_quality /tmp/task.md /tmp/out . --dry-run --sequential

# Eval 质量检查
./eval/run-eval.sh --dry-run --runner generic
```

每个 runner 运行后必须产出：

| 文件 | 说明 |
|------|------|
| `run-summary.md` | 运行摘要 |
| `execution-context.md` | 执行上下文 |
| `source_failure_log.md` | 来源失败记录 |
| `events.ndjson` | 事件流（每行合法 JSON） |

---

## 更新

```bash
cd deep-research-plugin
git pull
opencode plugin /path/to/deep-research-plugin --force
```

---

## 故障排查

| 问题 | 解决 |
|------|------|
| 搜索 API 不可用 | 检查代理：`export https_proxy=http://127.0.0.1:7897` |
| `HOST_RUN_CMD not set` | 通用 Runner 默认 dry-run，实际执行需设置宿主命令 |
| setup.sh 权限问题 | `chmod +x ./scripts/*.sh` |
| config.env 未找到 | 运行 `./scripts/setup.sh` 生成配置 |

## 环境要求

- **Shell**：bash 3.2+
- **Python**：3.7+
- **Node**：18+（仅 OpenCode plugin 安装需要）
- **curl**：用于搜索 API
