# Deep Research Plugin 安装手册

## 适用宿主

| 宿主 | 安装方式 | 功能 |
|------|---------|------|
| **OpenCode CLI / TUI** | 本地插件安装 | 完整工作流、斜杠命令触发 |
| **Codex** | 通用 Runner 调用 | 自动编排、多轮执行 |
| **Claude Code** | 通用 Runner 调用 | 对话中触发研究任务 |
| **终端 / CI / 脚本** | 直接执行 Runner | 自动化研究流水线 |

---

## 方式一：OpenCode 用户（推荐）

### 1. 获取插件

```bash
# 从内部仓库克隆（替换为实际地址）
git clone <内部仓库地址> /tmp/deep-research-plugin

# 或通过内部文件共享接收压缩包
# 解压到任意目录，例如 ~/.opencode/plugins/deep-research-plugin/
```

### 2. 安装

```bash
opencode plugin install /path/to/deep-research-plugin
```

验证成功：

```bash
opencode plugin list   # 应显示 deep-research-plugin
```

### 3. 首次配置

```bash
# 运行 setup 配置搜索 API key 和模型来源
/path/to/deep-research-plugin/scripts/setup.sh
```

配置项：
- **搜索 API Key**：Brave Search（英文搜索主力）、博查（中文主力）、Exa（英文语义搜索），至少配置一个
- **模型来源**：选择各 agent 使用哪个 provider/model
- **输出目录**：研究报告保存位置（支持相对路径，默认为 `~/Documents/DeepResearch`）

setup 是交互式的，会生成 `config.env` 到插件目录下。（不要提交到 git，已在 .gitignore 中）

### 4. 使用

在 OpenCode 对话中触发：

```
/opencode-deep-research 郑州停车充电需求分析
```

或直接描述研究需求，OpenCode 会自动加载 skill。

---

## 方式二：Codex 用户（通用 Runner）

无需安装插件，直接调用通用 Runner：

```bash
# 1. 创建任务文件
cat > /tmp/task.md << 'EOF'
# 研究任务

分析郑州郑东新区白沙组团的停车和充电需求，坐标 34.752, 113.793。
生成决策分析报告。
EOF

# 2. 执行研究
./deep-research-plugin/scripts/generic-research-runner.sh \
  high_quality \
  /tmp/task.md \
  /tmp/deep-research-output \
  /path/to/your/project \
  --sequential

# 3. 查看结果
cat /tmp/deep-research-output/run-summary.md
```

产出文件：
| 文件 | 用途 |
|------|------|
| `run-summary.md` | 运行摘要（整体状态） |
| `execution-context.md` | 执行上下文（配置、参数） |
| `source_failure_log.md` | 来源失败日志 |
| `events.ndjson` | 事件流（机器可读） |

---

## 方式三：终端直接使用

```bash
# 设置环境变量
export BRAVE_API_KEY="你的key"
export BOCHA_API_KEY="你的key"     # 可选
export DEEP_RESEARCH_OUTPUT_DIR="/tmp/research-out"

# 执行研究（dry-run 模式预览，不实际调用 agent）
./deep-research-plugin/scripts/generic-research-runner.sh \
  high_quality /tmp/task.md /tmp/out . --dry-run --sequential
```

去掉 `--dry-run` 即实际调用 agent 执行研究（需要对应宿主的 agent 调用命令配置）。

---

## 环境要求

- **Shell**：bash 3.2+（macOS 默认版本兼容）
- **Python**：3.7+（用于 JSON 转义和 Brave API 结果解析）
- **curl**：用于搜索 API 调用
- **网络**：能访问 Brave Search API 或博查 AI Search API（至少一个）

---

## 故障排查

### `search.sh` 报错：Brave API 不可用

检查代理配置（若需要）：

```bash
export https_proxy=http://127.0.0.1:7897
./deep-research-plugin/scripts/search.sh "测试搜索"
```

### `generic-research-runner.sh` 报错：HOST_RUN_CMD not set

通用 Runner 默认在 dry-run 模式运行。实际执行需要设置 `HOST_RUN_CMD` 环境变量，指向宿主的 agent 调用命令：

```bash
# OpenCode 宿主
export HOST_RUN_CMD="opencode run --model"

# Codex 宿主
export HOST_RUN_CMD="codex run"
```

### setup.sh 权限问题

```bash
chmod +x /path/to/deep-research-plugin/scripts/*.sh
```

---

## 更新插件

```bash
cd /path/to/deep-research-plugin
git pull
opencode plugin install . --force
```
