# Knowledge Retrieval Adapter Contract

本文档定义知识库检索适配器的后端合约，适用于 `scripts/knowledge-<source>.sh` 系列脚本以及外部/MCP/宿主原生知识库检索工具。

所有知识库检索适配器（Obsidian Vault、Lark/Feishu Wiki、NotebookLM 等）必须遵循本合约，确保与 Deep Research 工作流的检索路由、来源分级、失败降级等机制兼容。

---

## 1. 适配器接口

每个知识库检索适配器 (`scripts/knowledge-<source>.sh`) 必须支持以下 CLI 标志：

| 标志 | 类型 | 默认值 | 描述 |
|------|------|--------|------|
| `--count N` | int | `5` | 最大返回结果数 |
| `--json` | flag | off | 输出 JSON 格式（默认：人类可读格式） |
| `--dry-run` | flag | off | 仅显示将要执行的操作，不实际执行 |
| `--timeout N` | int | `15` | 超时时间（秒） |
| `--query` | string | (必填) | 搜索查询字符串 |
| `--help` / `-h` | flag | — | 显示帮助信息 |

### 1.1 调用示例

```bash
# 基础搜索
scripts/knowledge-obsidian.sh --query "智慧停车 市场规模"

# 指定返回数量 + JSON 输出
scripts/knowledge-lark.sh --query "产品路线图 2026" --count 10 --json

# Dry-run 模式
scripts/knowledge-notebooklm.sh --query "竞品分析" --dry-run

# 超时控制
scripts/knowledge-obsidian.sh --query "深度学习 Transformer" --timeout 30
```

### 1.2 路由入口

`scripts/knowledge-retrieval.sh` 是知识库检索的规范入口，负责根据查询上下文路由到对应的适配器：

```bash
scripts/knowledge-retrieval.sh --query "..." --sources obsidian,lark,notebooklm [opts...]
```

`--sources` 使用逗号分隔的源列表（如 `--sources lark,obsidian`）。不指定 `--sources` 时自动检测所有已配置的适配器。

### 1.3 自定义适配器接入

如果你实现**自定义知识库检索适配器**（例如通过 MCP、宿主原生文件搜索、企业内部知识库 API），它必须遵循本合约。接入方式：

- **方式 A（推荐）**：将你的检索工具包装为新的适配器，放在 `scripts/knowledge-<source>.sh`，遵循本合约的 CLI 接口和输出格式。
- **方式 B**：直接替换 `scripts/knowledge-retrieval.sh`，保持相同的 CLI 标志和输出格式。

---

## 2. 输出格式

### 2.1 人类可读格式（默认）

每条结果输出格式：

```
[{source_type}] {title}
  {path/url}
  {content_preview（最多 200 字符）}
  {metadata: date / level / subtype}
```

示例（Obsidian Vault）：

```
[obsidian] 智慧停车行业市场分析报告 2025
  /Users/xxx/Notes/Projects/智慧停车/市场分析.md
  根据住建部和各地方政府公开数据，2025 年中国智慧停车市场规模预计达到 450 亿元...
  create_time: 2025-06-15  level: B  subtype: local_vault
```

示例（Lark Wiki）：

```
[lark_wiki] 郑好停产品架构设计文档
  https://bytedance.feishu.cn/wiki/xxx
  本文档描述郑好停产品的整体架构设计，包括后端服务拆分、数据...
  create_time: 2026-01-20  level: A  subtype: wiki_doc
```

示例（NotebookLM）：

```
[notebooklm] 智慧停车竞品对比分析（AI 总结）
  https://notebooklm.google.com/notebook/xxx
  根据上传的 5 份竞品分析报告，智慧停车市场主要参与者包括...
  create_time: 2026-03-10  level: C  subtype: model_reasoning
```

### 2.2 JSON 格式（`--json` 标志）

当使用 `--json` 标志时，适配器必须输出以下标准 JSON 结构：

```json
{
  "source_type": "lark_wiki",
  "query": "搜索关键词",
  "success": true,
  "error": "",
  "results": [
    {
      "title": "文档标题",
      "path": "https://...",
      "content_preview": "前 200 个字符的内容预览...",
      "source_level": "A",
      "metadata": {
        "create_time": "2026-01-15",
        "update_time": "2026-03-20",
        "source_subtype": "wiki_doc"
      }
    }
  ]
}
```

#### 顶级字段

| 字段 | 类型 | 必填 | 描述 |
|------|------|:----:|------|
| `source_type` | string | 是 | 来源类型标识：`obsidian` / `lark_wiki` / `notebooklm` |
| `query` | string | 是 | 本次搜索使用的查询字符串 |
| `success` | boolean | 是 | 检索是否成功完成 |
| `error` | string | 否 | 失败时的错误描述，成功时为空字符串 |
| `results` | array | 是 | 检索结果列表，无结果时为空数组 |

#### results 条目字段

| 字段 | 类型 | 必填 | 描述 |
|------|------|:----:|------|
| `title` | string | 是 | 文档或条目标题 |
| `path` | string | 是 | 文档路径（本地路径或 URL） |
| `content_preview` | string | 是 | 内容预览，最长 200 字符 |
| `source_level` | string | 是 | 来源级别：`S` / `A` / `B` / `C` / `D` |
| `metadata` | object | 是 | 元数据对象 |

#### metadata 对象字段

| 字段 | 类型 | 必填 | 描述 |
|------|------|:----:|------|
| `create_time` | string | 是 | 文档创建时间，格式 `YYYY-MM-DD` |
| `update_time` | string | 否 | 最后更新时间，格式 `YYYY-MM-DD` |
| `source_subtype` | string | 是 | 来源子类型（见下方说明） |

`source_subtype` 取值：

| 适配器 | 子类型 | 说明 |
|--------|--------|------|
| lark_wiki | `wiki_doc` | 正式知识库文档 |
| lark_wiki | `wiki_draft` | 个人笔记/草稿 |
| notebooklm | `model_reasoning` | AI 分析回答 |
| notebooklm | `uploaded_files` | 用户上传的原始来源 |
| obsidian | `local_vault` | 工作笔记/开发文档 |
| obsidian | `local_wiki` | 技术知识库（如 llm-wiki 目录） |

### 2.3 错误输出

错误信息通过 stderr 输出，格式为：

```
ERROR: {描述信息}
```

结构化错误格式：

```
{SOURCE}_ERROR|{code}|{message}
```

示例：

```
OBSIDIAN_ERROR|404|Vault 路径不存在: /Users/xxx/Notes
LARK_ERROR|401|飞书 API 鉴权失败，请检查 LARK_APP_ID 和 LARK_APP_SECRET
NOTEBOOKLM_ERROR|TIMEOUT|NotebookLM API 超时（15s）
```

---

## 3. 错误处理

### 3.1 错误输出规范

- 所有错误信息必须写入 **stderr**
- 错误格式：`ERROR: {描述信息}`
- 成功时 stdout 包含结果数据，stderr 应为空
- 部分成功时，stdout 输出可用的结果，stderr 输出错误描述

### 3.2 退出码

| 退出码 | 含义 | 说明 |
|:------:|------|------|
| `0` | 成功 | 检索正常完成，返回结果（可能为空） |
| `1` | 部分成功 | 检索完成但部分结果不可用（如部分文档无法访问） |
| `2` | 失败 | 检索无法完成（API 错误、超时、配置错误、路径不存在） |

### 3.3 失败日志

当检索失败时，适配器应触发 `source_failure_log` 记录。失败日志的 YAML 格式遵循 `references/source-failure-log.md` 规范。

关键字段映射：

| 字段 | 取值示例 |
|------|---------|
| `failed_task` | "Obsidian Vault 知识检索" |
| `failed_source_type` | `local_vault` / `local_wiki` / `lark_wiki` / `notebooklm` |
| `failed_source_detail` | "Vault 路径不存在" / "飞书 API 限流" / "NotebookLM 无匹配结果" |
| `failure_type` | `local_source_unavailable` / `api_timeout` / `source_insufficient` |
| `failure_stage` | `Phase_2_资料搜索` |

### 3.4 已知边界情况

| 场景 | 处理方式 | 退出码 |
|------|---------|:------:|
| 知识库路径/空间不存在 | stderr 输出 `ERROR: ...`，`success: false` | 2 |
| 鉴权失败（API key/token 无效） | stderr 输出 `ERROR: ...`，`success: false` | 2 |
| 搜索无匹配结果 | stdout 输出 `{"results": []}`，`success: true` | 0 |
| 部分文档不可访问（权限不足） | 返回可访问的结果，stderr 列出不可访问的文档 | 1 |
| 超时（超过 `--timeout`） | stderr 输出 `ERROR: timeout`，`success: false` | 2 |
| 并发限制/API 限流 | stderr 输出 `ERROR: rate_limit`，建议等待后重试 | 2 |

---

## 4. 可用性检查

每个适配器必须提供可用性检查功能：

```bash
scripts/knowledge-<source>.sh --check
```

### 4.1 检查规则

| 退出码 | 含义 | stdout | stderr |
|:------:|------|--------|--------|
| `0` | 可用 | "OK" 或版本信息 | （空） |
| `1` | 不可用 | — | 具体的不可用原因说明 |

### 4.2 检查内容

适配器的 `--check` 应验证以下内容：

- **Obsidian Vault**：`DEEP_RESEARCH_OBSIDIAN_VAULT_DIR` 环境变量是否已设置、路径是否存在。
- **Lark/Feishu Wiki**：`lark-cli` 是否已安装、`$HOME/.lark-cli/config.json` 是否存在（是否已登录）。
- **NotebookLM**：`notebooklm` CLI 是否已安装。

### 4.3 检查示例

```bash
# Obsidian Vault 可用性检查
scripts/knowledge-obsidian.sh --check
# 可用时: exit 0, stdout: "AVAILABLE: Obsidian Vault at <path>"
# 不可用时: exit 1, stderr: "ERROR: DEEP_RESEARCH_OBSIDIAN_VAULT_DIR 未设置或路径不存在"

# Lark Wiki 可用性检查
scripts/knowledge-lark.sh --check
# 可用时: exit 0, stdout: "AVAILABLE: lark-cli ready"
# 不可用时: exit 1, stderr: "ERROR: lark-cli 未安装或未配置"

# NotebookLM 可用性检查
scripts/knowledge-notebooklm.sh --check
# 可用时: exit 0, stdout: "AVAILABLE: notebooklm CLI ready"
# 不可用时: exit 1, stderr: "ERROR: notebooklm CLI 未安装"
```

---

## 5. 添加新的知识源

要新增一个知识库适配器，按以下步骤操作：

### 5.1 创建适配器脚本

在 `scripts/` 目录下创建 `knowledge-<source>.sh`，实现合约定义的 CLI 接口。

### 5.2 实现格式化函数

每个适配器需要包含两个输出模式：

- **JSON 格式化器**：输出第 2.2 节定义的标准 JSON 结构。
- **人类可读格式化器**：输出第 2.1 节定义的格式化文本。

格式化器函数命名约定：

```bash
# JSON 输出函数
format_<source>_json() {
  local results="$1"
  # 输出标准 JSON 到 stdout
}

# 人类可读输出函数
format_<source>_readable() {
  local results="$1"
  # 输出格式化文本到 stdout
}
```

### 5.3 注册路由

在 `scripts/knowledge-retrieval.sh` 的路由逻辑中注册新的适配器：

- 在 `resolve_source()` 函数中添加新来源类型的选择逻辑
- 在 `retrieve_knowledge()` 主函数中添加新适配器的调用分支
- 更新 `--source auto` 的自动选择逻辑

### 5.4 添加来源类型

在 `references/source-policy.yaml`（或等效配置文件）中添加新的来源类型定义，包含：

- 来源类型标识（如 `notebooklm`）
- 对应的 `source_type`（如 `model_reasoning`、`uploaded_files`）
- 默认来源等级
- 适用场景
- 使用限制

### 5.5 文档边界

在 `references/source-boundaries.md` 中为新增的知识源添加边界定义，说明：

- 适用范围
- 使用限制
- 误用风险
- 示例路径

### 5.6 添加审计规则

在 `references/source-audit.md` 中为新增的知识源添加审计规则：

- 来源类型定义
- 允许用于核心结论的判断规则
- 默认等级范围
- 引用规则

### 5.7 注册步骤总结

| 步骤 | 文件 | 操作 |
|:----:|------|------|
| 1 | `scripts/knowledge-<source>.sh` | 创建适配器脚本 |
| 2 | `scripts/knowledge-<source>.sh` | 实现 JSON 和人类可读格式化器 |
| 3 | `scripts/knowledge-retrieval.sh` | 注册路由逻辑 |
| 4 | `source-policy.yaml` | 添加来源类型 |
| 5 | `references/source-boundaries.md` | 文档边界 |
| 6 | `references/source-audit.md` | 添加审计规则 |

---

## 6. 来源等级映射

知识库检索结果必须根据来源类型和条件映射到 S/A/B/C/D 等级体系。

### 6.1 等级映射表

| 适配器 | 条件 | 等级 | source_type |
|--------|------|:----:|-------------|
| lark_wiki | 正式知识库文档（已发布） | A | external_media |
| lark_wiki | 个人笔记/草稿（未发布） | B | local_vault |
| notebooklm | AI 分析回答（模型推理） | C | model_reasoning |
| notebooklm | 用户上传的原始来源（文档/PDF 等） | 按原类型定级 | uploaded_files 或对应类型 |
| obsidian | `llm-wiki/` 目录或技术知识库内容 | C | local_wiki |
| obsidian | 工作笔记/开发文档/项目资料 | B | local_vault |
| obsidian | 已发布的内部正式报告/文档 | B (可提升至 A 需人工审核) | local_vault |

### 6.2 等级说明

**A 级 — 强支撑**：

- 飞书知识库中已发布的正式文档（经过审核的知识库文章）
- 可支撑重要结论，重大数据建议交叉验证

**B 级 — 辅助论据**：

- Obsidian Vault 中的工作笔记、项目文档、开发资料
- 飞书知识库中的个人笔记或未发布的草稿
- 可作为事实线索或辅助论据，不可单独支撑核心结论
- 经营数据必须标注"内部口径，需核验"

**C 级 — 观点参考**：

- Obsidian 技术知识库（`llm-wiki/`）中的技术介绍
- NotebookLM 的 AI 分析回答（模型推理结果）
- 可作为技术原理解释，不可用于判断最新事实

**D 级 — 假设/推理**：

- NotebookLM 中标注为 AI 生成但涉及具体数据的分析
- 无明确日期的历史笔记
- 仅作为假设，不得支撑任何事实性结论

### 6.3 等级覆盖规则

适配器返回的 `source_level` 是**建议等级**，source_agent 或主 Agent 可根据以下规则调整：

- **上调**：如果笔记/文档内容来自权威外部来源且有完整引用，可上调一级（如从 B 到 A）。
- **下调**：如果文档明显过时（超过有效期）、来源不可追溯、或内容质量存疑，应下调一级。
- **标注要求**：任何等级调整必须在 `source_failure_log` 或来源标注中说明调整理由。

---

## 7. 环境变量

| 变量 | 用途 | 必需 |
|------|------|:----:|
| `DEEP_RESEARCH_OBSIDIAN_VAULT_DIR` | Obsidian Vault 根目录路径 | Obsidian 适配器必需 |
| `LARK_CLI_CONFIG` | lark-cli 配置文件路径（默认 `$HOME/.lark-cli/config.json`） | Lark 适配器可选 |
| `LARK_WIKI_SPACE_ID` | 飞书知识空间 ID（可选，不指定则搜索所有可访问空间） | Lark 适配器可选 |
| `DEEP_RESEARCH_NOTEBOOKLM_NOTEBOOK_ID` | NotebookLM 笔记本 ID（未设置时自动检测） | NotebookLM 适配器可选 |
| `DEEP_RESEARCH_TIMEOUT` | 默认超时时间（秒） | 否（默认 15） |
| `DEEP_RESEARCH_CACHE_DIR` | 缓存目录覆盖 | 否 |

---

## 8. 合规检查清单

在宣称知识库适配器合规之前，请逐项验证：

- [ ] 支持 `--query`、`--count`、`--json`、`--dry-run`、`--timeout` 标志
- [ ] `--dry-run` 模式仅显示将要执行的操作，不实际执行
- [ ] `--json` 模式输出符合第 2.2 节定义的标准 JSON 结构
- [ ] 默认模式输出符合第 2.1 节定义的人类可读格式
- [ ] `--check` 可用性检查正确返回 0/1
- [ ] 错误信息写入 stderr，格式为 `ERROR: {描述}`
- [ ] 退出码符合规范：0 成功、1 部分成功、2 失败
- [ ] 搜索无结果时返回空 results 数组（不视为失败）
- [ ] 超时受 `--timeout` 值约束，不无限等待
- [ ] 使用对应的环境变量配置（不硬编码凭据或路径）
- [ ] 结果中的 `source_level` 符合第 6 节的映射规则
- [ ] 失败的检索触发 `source_failure_log` 记录
- [ ] 不在输出或错误信息中泄露 API 密钥或访问令牌
- [ ] 支持通过 `DEEP_RESEARCH_KNOWLEDGE_CMD` 环境变量覆盖

---

> **引用说明**：本文档与 `references/search-adapter-contract.md`（搜索适配器合约）、`references/source-boundaries.md`（来源边界）、`references/source-audit.md`（来源审计）、`references/source-failure-log.md`（失败日志）配套使用。知识库检索适配器的实现必须同时满足上述文件的相关要求。