# Deep Research Skill — 知识库集成设计

日期: 2026-05-22
状态: Draft

## 背景

Deep Research Skill 目前仅支持网页搜索（Bocha/Brave/Exa）作为外部信息来源。用户在本地的 Obsidian Vault、飞书知识库和 NotebookLM 中积累了大量的业务资料、技术笔记和分析报告，但这些知识库尚未被研究工作流利用。

本设计为 Deep Research Skill 增加三层知识库检索能力，使研究工作流能同时利用网页搜索 + 内部知识库，覆盖更完整的信息维度。

## 目标

1. **飞书知识库** — 研究 agent 能自动搜索所有有权限的飞书知识空间，读取相关文档
2. **NotebookLM** — 研究 agent 能读取 NotebookLM 笔记本内容，并主动提问获取分析
3. **Obsidian Vault** — 研究 agent 能搜索整个 Obsidian Vault 中的 Markdown 文件，按目录分类

## 架构

### 系统层次

```
Phase 2: 资料搜索与来源分级
  │
  ├── search.sh (existing)              → 网页搜索
  │     ├── Bocha (中文主引擎)
  │     ├── Exa (英文语义搜索)
  │     └── Brave (通用 fallback)
  │
  └── knowledge-retrieval.sh (new)      → 知识库检索
        ├── knowledge-lark.sh           → 飞书知识库
        ├── knowledge-notebooklm.sh     → NotebookLM
        └── knowledge-obsidian.sh       → Obsidian Vault
```

### 工作流集成

在 Phase 2（资料搜索与来源分级）中，source_agent 同时执行：

1. **网页搜索**: 调用 `search.sh`（已有逻辑，不变）
2. **知识库检索**: 调用 `knowledge-retrieval.sh`（新增）
3. **来源合并**: 将两部分结果统一进入 S/A/B/C/D 分级体系
4. **失败处理**: 知识库检索失败不影响网页搜索，反之亦然，各自记录 `source_failure_log`

## 适配器协议

### 统一接口

```bash
scripts/knowledge-<source>.sh "查询词" [选项]
```

| 参数 | 默认值 | 说明 |
|------|--------|------|
| `--count N` | 5 | 返回结果数 |
| `--json` | off | 输出 JSON 格式 |
| `--dry-run` | off | 仅显示将要执行的查询，不实际执行 |

### 输出格式

人类可读格式（默认）：
```
[{source_type}] {标题}
  {路径/URL}
  {内容预览（≤200字符）}
  {元数据行：日期 / 等级 / 子类型}
```

JSON 格式（`--json`）：
```json
{
  "source_type": "lark_wiki",
  "query": "关键词",
  "success": true,
  "results": [
    {
      "title": "文档标题",
      "path": "https://feishu.cn/doc/...",
      "content_preview": "内容预览...",
      "source_level": "A",
      "metadata": {
        "create_time": "2026-03-15",
        "update_time": "2026-05-20",
        "source_subtype": "wiki_doc"
      }
    }
  ]
}
```

### 错误输出

错误信息写入 stderr，格式：
```
ERROR: {错误描述}
```

退出码：0 成功，1 部分成功，2 失败

## 适配器详细设计

### 1. knowledge-lark.sh — 飞书知识库

**功能**: 搜索飞书知识空间中的文档，读取匹配文档内容

**工作流**:
1. 检测 `lark-cli` 是否可用，不可用则直接返回空结果
2. `lark-cli docs +search "关键词"` → 获取匹配文档列表
3. 对每条结果：`lark-cli docs +fetch <doc_token>` → 获取文档内容
4. 输出结构化结果

**来源等级映射**:
- 正式文档（Wiki 空间中的正式文档）→ A 级
- 笔记类（个人空间、草稿）→ B 级
- 无法判断类型 → B 级

**配置**: 复用 lark-cli 已有认证，无需额外配置

**依赖**:
- `lark-cli` installed and authenticated
- `~/.lark-cli/config.json` 存在

### 2. knowledge-notebooklm.sh — NotebookLM

**功能**: 查询 NotebookLM 当前 notebook 的内容，并对研究问题提问

**工作流**:
1. 检测 `notebooklm` CLI 是否可用
2. 从 `~/.notebooklm/context.json` 读取当前 notebook_id
3. 执行两种查询：
   a. `notebooklm ask "关键词"` → 获取 AI 分析回答
   b. 列出 notebook 来源作为参考
4. 输出结构化结果

**来源等级映射**:
- NotebookLM 的分析回答 → C 级（AI 分析，标注 "NotebookLM 生成"）
- NotebookLM 中的原始来源文档 → 按原文档类型定级

**配置**:
- `DEEP_RESEARCH_NOTEBOOKLM_NOTEBOOK_ID` — 可选，自动从 context.json 读取
- `DEEP_RESEARCH_NOTEBOOKLM_ENABLED` — 可选，默认 true

**注意**: NotebookLM 的回答属于 AI 推理，在 source-policy.yaml 中映射到 model_reasoning 类型，需要在报告中与事实来源分开标注

### 3. knowledge-obsidian.sh — Obsidian Vault

**功能**: 在 Obsidian Vault 中搜索 Markdown 文件，返回匹配结果并按目录分类

**工作流**:
1. 读取 `DEEP_RESEARCH_OBSIDIAN_VAULT_DIR` 环境变量
2. 使用 `rg`（ripgrep）搜索 .md 文件内容，`-l` 列出匹配文件
3. 对匹配文件提取标题（第一个 # 行）和上下文预览
4. 按目录路径分类：
   - `llm-wiki/`、`karpathy-wiki/` → `local_wiki` 类型
   - `工作笔记/`、`开发文档/`、`技术研究/` → `local_vault` 类型
   - `投资研究/`、`收件箱/`、`阅读学习/` → `local_vault` 类型
5. 输出结构化结果

**来源等级映射**:
- `local_wiki` 类别 → B/C 级（技术原理参考）
- `local_vault` 类别 → B/C 级（内部资料，需核验）

**配置**:
- `DEEP_RESEARCH_OBSIDIAN_VAULT_DIR` — Obsidian Vault 根目录
- 自动检测：从 `~/.config/obsidian-article-extractor/vault-path` 读取

### 4. knowledge-retrieval.sh — 统一入口

**功能**: 调度所有已启用/已配置的知识库适配器，合并结果

**用法**:
```bash
scripts/knowledge-retrieval.sh "关键词"              # 所有已配置来源
scripts/knowledge-retrieval.sh "关键词" --sources lark,obsidian  # 指定来源
scripts/knowledge-retrieval.sh "关键词" --dry-run     # 预览模式
scripts/knowledge-retrieval.sh "关键词" --json        # JSON 输出
scripts/knowledge-retrieval.sh "关键词" --timeout 30  # 超时控制
```

**工作流**:
1. 检测每个知识源的可用性（CLI 是否存在、配置是否完整）
2. 并行执行可用的适配器
3. 收集各适配器的结果和错误
4. 合并所有结果输出
5. 返回整体退出码

## 来源类型定义

### source-policy.yaml 新增

```yaml
source_types:
  # ... 现有类型不变 ...

  lark_wiki:
    description: "飞书知识库文档：公司内部知识空间、项目文档、技术文档、管理制度"
    allowed_for_core_claims: conditional
    conditions:
      - "标注文档创建/更新时间，区分'当前有效'与'历史存档'"
      - "内部文档不自动等同于外部权威事实"
      - "涉及财务、合规、法律等正式内容需核实是否为最终批准版本"
    default_level: "A/B"
    note: "飞书知识库内部文档，需注意版本和时效性"

  notebooklm:
    description: "Google NotebookLM 笔记本分析输出"
    allowed_for_core_claims: conditional
    conditions:
      - "NotebookLM 的分析输出属于 AI 推理（model_reasoning），不是事实来源"
      - "NotebookLM 中的来源材料可视为用户上传文档级别"
      - "必须标注'NotebookLM 生成'以区分 AI 分析与原始材料"
    default_level: "C"
    note: "NotebookLM 内容含 AI 生成分析，需与原始来源区分"
```

### 现有 local_vault / local_wiki 路径更新

```yaml
  local_vault:
    path: "${DEEP_RESEARCH_OBSIDIAN_VAULT_DIR}"  # 指向 Obsidian Vault 根目录
    # 子目录映射: 工作笔记/ 开发文档/ 技术研究/ 投资研究/ 收件箱/ 阅读学习/

  local_wiki:
    paths:
      - "${DEEP_RESEARCH_OBSIDIAN_VAULT_DIR}/llm-wiki"  # 主路径
      - "~/Documents/karpathy-wiki"
      - "~/Documents/llm-wiki"
```

## 配置项

### setup.sh 新增配置

| 环境变量 | 说明 | 默认值 | 自动检测 |
|---------|------|--------|---------|
| `DEEP_RESEARCH_OBSIDIAN_VAULT_DIR` | Obsidian Vault 路径 | - | 从 `~/.config/obsidian-article-extractor/vault-path` 读取 |
| `DEEP_RESEARCH_NOTEBOOKLM_NOTEBOOK_ID` | NotebookLM notebook ID | - | 从 `~/.notebooklm/context.json` 读取 |
| `DEEP_RESEARCH_NOTEBOOKLM_ENABLED` | 是否启用 NotebookLM | true | - |
| `DEEP_RESEARCH_LARK_ENABLED` | 是否启用飞书知识库 | true | 检测 lark-cli 可用性 |

## 边界和限制

### 飞书知识库
- 搜索范围：用户有权限的所有知识空间（受 lark-cli 权限限制）
- 文档格式：飞书文档格式，适配器输出为 Markdown/纯文本
- 频率限制：受飞书 API 频率限制

### NotebookLM
- 仅支持当前选中的 notebook（`notebooklm use <id>` 可切换）
- NotebookLM 分析为 AI 生成，不可作为独立事实来源
- 需要 Google 账号认证

### Obsidian Vault
- 仅搜索 `.md` 文件（不包含图片、PDF 等附件）
- 二进制文件和大文件会被自动跳过
- 搜索性能受 vault 大小影响（预计 < 1000 文件秒级响应）

## 文件清单

### 新增文件 (7)

| 文件 | 说明 |
|------|------|
| `scripts/knowledge-retrieval.sh` | 知识库检索统一入口 |
| `scripts/knowledge-lark.sh` | 飞书知识库适配器 |
| `scripts/knowledge-notebooklm.sh` | NotebookLM 适配器 |
| `scripts/knowledge-obsidian.sh` | Obsidian Vault 适配器 |
| `references/knowledge-retrieval.md` | 知识库检索协议文档 |

### 修改文件 (7)

| 文件 | 修改内容 |
|------|---------|
| `source-policy.yaml` | 新增 `lark_wiki`、`notebooklm` 来源类型；更新 `local_vault`/`local_wiki` 路径 |
| `references/source-boundaries.md` | 新增两种来源的适用范围、边界和误用风险 |
| `references/source-audit.md` | 附录中补充新来源的审计规则和引用格式 |
| `references/workflow.md` | Phase 2 增加知识库检索步骤和检查清单 |
| `references/subagents.md` | source_agent 职责增加知识库检索说明 |
| `scripts/setup.sh` | 增加知识库路径配置和自动检测 |
| `SKILL.md` | 更新目录结构和描述 |

## 验证方式

1. **单元测试**: 每个适配器运行 `--dry-run` 模式，验证参数解析和输出格式
2. **集成测试**: 对每个实际存在的知识源执行一次真实查询，验证结果格式
3. **知识库检索**: `scripts/knowledge-retrieval.sh "测试" --dry-run` 显示启用的来源
4. **eval 框架**: 更新 `eval/` 中的测试任务，纳入知识库检索结果验证