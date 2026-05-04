# Source Failure Log

当 web 搜索、资料抓取、API 调用、文件读取、本地资料检索或来源验证失败时，必须记录 `source_failure_log`。本日志是质量审计和报告可用性降级的依据。

---

## 1. Trigger Conditions

以下任一情况触发 `source_failure_log` 记录：

### 1.1 外部搜索失败

- **web 搜索失败**：搜索引擎返回空结果、超时、被限流，或无法完成检索。
- **外部检索不可用**：搜索 API 不可达、鉴权失败、服务降级。
- **外部抓取失败**：目标页面返回 403、404、500，或连接超时。
- **API 超时或返回错误**：接口响应超过阈值，或返回非预期状态码。
- **web 页面不可达**：域名解析失败、TLS 握手失败、网络隔离导致无法访问。

### 1.2 来源质量不足

- **来源质量不足（仅 C/D 级可用）**：核心结论需要 S/A/B 级来源，但搜索仅返回 C/D 级来源。
- **关键来源只有 C/D 级**：某项关键事实的所有外部来源均为自媒体、博客、论坛或未核验传闻。
- **公开来源不足**：所有可用来源信息量不足以支撑报告分析深度。
- **关键数据缺少发布时间**：引用的事实来源没有可识别的发布日期。
- **关键数据缺少统计口径**：数据未标注统计方法、样本范围、计算方式。
- **关键数据缺少获取时间**：无法确认数据的时间上下文。
- **来源冲突未解决**：同一事实在多个来源中数据矛盾，且无法通过口径分析或进一步检索解决。

### 1.3 本地来源失败

- **local_vault 未找到或为空**：指定的 Obsidian Vault 路径不存在，或无匹配文件。
- **local_wiki 未找到或为空**：本地技术知识库路径不存在，或无匹配文件。
- **uploaded_files 缺失**：用户明确提及应上传附件但未提供，或预期的附件不存在。

### 1.4 来源冲突与解析失败

- **来源冲突未解决**：同一事实在同一级别（S/A/B）的来源中数据矛盾，无法通过口径、时效、统计方法分辨。
- **来源解析失败**：已抓取的内容无法提取有效事实（PDF 扫描件 OCR 失败、页面乱码、结构化数据不可读）。
- **语言/地区限制**：目标信息来源仅存在于无法检索的语言区域，且无翻译或替代来源。

---

## 2. Required Fields

每次失败事件必须输出为一条 YAML 记录。参数说明如下：

```yaml
source_failure_log:
  - failure_time: "YYYY-MM-DD HH:MM"               # 失败发生时间
    failed_task: ""                                  # 触发失败的研究子任务（如 "市场规模检索"、"政策条文核验"）
    failed_source_type: "external_authoritative | external_media | local_vault | local_wiki | uploaded_files"
    failed_source_detail: ""                         # 具体失败的来源名称、URL 或文件路径
    failure_type: "web_search_failed | fetch_failed | api_timeout | source_insufficient | source_quality_low | local_source_unavailable | timestamp_missing | caliber_missing | source_conflict_unresolved | source_parse_failed"
    failure_stage: "Phase_2_资料搜索 | Phase_3_事实核验 | Phase_5_情景测算 | 全文"
    affected_scope: ""                               # 受影响的研究章节或结论（如 "第3章市场规模估算"、"核心技术结论"）
    affected_conclusions: []                         # 受影响的具体结论列表
    fallback_handling: ""                            # 已采用的替代方案（使用了什么代替）
    fallback_source_level: "S | A | B | C | D | none" # 替代来源的质量等级，无可替代来源时写 "none"
    confidence_impact: "none | reduced | high"      # 对该部分结论置信度的影响程度
    required_manual_sources: []                      # 需要人工补充的来源清单
    suggested_databases_or_keywords: []              # 建议后续检索的数据库和关键词
    report_usability_marking: "离线初稿 | 内部初稿 | 正式版"  # 此失败对报告可用性的影响
    audit_grade_cap: "CONDITIONAL_PASS | FAIL"       # 此失败导致的审计等级上限
```

### 2.1 failure_type 枚举说明

| failure_type | 含义 | 典型场景 |
|---|---|---|
| `web_search_failed` | 搜索引擎无法完成检索 | 无网络、限流、无结果 |
| `fetch_failed` | 目标页面/API 返回错误 | 403、404、500、连接拒绝 |
| `api_timeout` | 外部 API 超时 | 响应超过阈值、上游服务不可用 |
| `source_insufficient` | 可用来源总量不足 | 搜索结果数量过少或无匹配 |
| `source_quality_low` | 可用来源质量过低 | 仅有 C/D 级来源，无法验证关键事实 |
| `local_source_unavailable` | 本地来源不可用 | Vault/Wiki/附件路径不存在或为空 |
| `timestamp_missing` | 数据缺少发布时间 | 来源未标注日期，无法判断时效 |
| `caliber_missing` | 数据缺少统计口径 | 无样本量、计算方法、统计范围 |
| `source_conflict_unresolved` | 来源数据冲突且无法化解 | 同级别来源数据矛盾 |
| `source_parse_failed` | 来源内容无法解析 | OCR 失败、乱码、格式损坏 |

### 2.2 confidence_impact 含义

| 值 | 含义 | 后续处理 |
|---|---|---|
| `none` | 替代方案等效，置信度不受影响 | 正常交付 |
| `reduced` | 该部分结论置信度降低，存在不确定性 | 标注"需进一步核验"，列入手动核验清单 |
| `high` | 该部分结论无法依赖当前来源，置信度严重受损 | 标注"当前结论不可作为决策依据" |

---

## 3. High Quality Downgrade

`high_quality` 模式（或其他模式下要求高质量报告时），任一外部搜索、抓取或来源核验失败，必须执行以下降级：

### 3.1 硬性规则

- **禁止标记为"正式高质量报告"**：凡是外部搜索失败的报告，不得在审计等级中标记为 `PASS`，最高 `CONDITIONAL_PASS`。
- **文件名必须加降级后缀**：`-离线初稿` 或 `-待联网核验版`。
- **报告开头必须包含警告声明**：在报告标题下方或首段后，以醒目方式标注当前来源状态和报告可用性等级。
- **审计等级最高 `CONDITIONAL_PASS`**：reviewer_agent 不得对此类报告给出 `PASS` 评定。
- **交付摘要必须写明搜索状态**：`search_status` 必须为 `failed` 或 `partial_success`，不得写 `success`。

### 3.2 警告声明模板

当报告为离线初稿时，报告开头必须包含以下声明：

```text
---
⚠️ 本报告为离线初稿 / 待联网核验版
搜索状态: failed / partial_success
报告可用性: 离线初稿 / 内部初稿
版次说明: 本稿基于当前可用的 (本地资料 / 部分外部资料 / AI 推理) 生成，部分核心数据未得到权威来源核验。
下一版次: 联网核验版需补充 [具体来源] 后重新生成。
---
```

### 3.3 报告可用性判定矩阵

| 搜索状态 | 可用来源情况 | 报告可用性 | 文件名后缀 | 审计等级上限 |
|---|---|---|---|---|
| 完全失败 | 外部搜索全部失败，仅有本地资料和 AI 推理 | **离线初稿** | `-离线初稿` | CONDITIONAL_PASS |
| 部分成功 | 外部搜索部分成功，但核心结论来源不足 | **离线初稿** | `-离线初稿` | CONDITIONAL_PASS |
| 部分成功 | 外部搜索部分成功，本地 Vault/Wiki 用于补强 | **内部初稿** | `-待联网核验版` | CONDITIONAL_PASS |
| 来源不足 | 外部搜索成功但关键数据仅有 C/D 级来源 | **离线初稿** | `-离线初稿` | CONDITIONAL_PASS |
| 时间缺失 | 数据可用但缺少发布时间或统计口径 | **内部初稿** | 不加后缀（在正文内标注） | CONDITIONAL_PASS |
| 完全成功 | 所有核心结论有 S/A 级来源支撑 | **正式版** | 不加后缀 | PASS |

### 3.4 离线初稿标志说明

**"离线初稿"**（文件名加 `-离线初稿`）适用的严格条件：

- 外部搜索完全失败（所有搜索 API 不可达或全部超时）。
- 外部搜索成功但返回结果不足以支撑核心结论（关键数据缺失、来源质量过低）。
- 关键数据缺少 S/A/B 级来源，仅能依赖 C/D 级来源或 AI 推理。
- 多个核心章节的数据依赖用户上传文件或本地资料，但无外部交叉验证。

**"内部初稿"**（文件名加 `-待联网核验版` 或标注为 `内部初稿`）适用的条件：

- 外部搜索部分成功，部分维度已核验，但仍有重要缺口。
- 本地 Vault/Wiki 数据已用于补充核心数据，且明确标注了来源类型。
- 部分数据来自爬取但未完成权威性核验。
- 来源冲突已记录但尚未人工裁决。

---

## 4. Offline Draft Labels

如果报告为离线初稿，文件名必须自动加后缀：

- `-离线初稿`：外部搜索完全失败或关键数据无 S/A/B 级来源时使用。
- `-待联网核验版`：外部搜索部分成功，本地资料已用于补强时使用。

不添加后缀的情况：

- 搜索完全成功且所有核心结论有 S/A/B 级来源支撑。
- 仅个别次要数据存在缺口，且已在正文中标注。

---

## 5. Source-Specific Fallback Strategies

每种来源类型失败时，执行对应的降级策略。

### 5.1 external_authoritative 失败

**表现**：S/A 级外部权威来源不可达、无结果、返回错误。

**降级策略**：

1. 使用 `external_media`（B 级媒体和行业资料）作为补充来源。
2. 在报告中标记该部分数据"缺少权威来源核验，当前数据来自媒体/行业资料，需补充权威验证"。
3. 如果媒体来源也失败，继续降至 C 级或本地来源，标记"外部来源严重不足"。
4. 将受影响的数据点全部列入 `required_manual_sources`。
5. `confidence_impact` 至少标记为 `reduced`；核心结论涉及该数据时标记为 `high`。

**报告标注**：

```text
⚠️ 本章数据缺少权威来源（S/A 级）核验，当前数据基于媒体/行业资料。
需补充: [具体权威来源建议]。
```

### 5.2 external_media 失败

**表现**：B 级媒体和行业资料不可达或无匹配。

**降级策略**：

1. 使用更广泛的 web 搜索（放宽检索条件、切换搜索引擎、调整关键词）。
2. 标记"媒体覆盖有限，信息完整性受限"。
3. 如果扩展搜索仍失败，降为 C 级来源（如行业博客、企业新闻稿）并标注"信息来源单一"。
4. `confidence_impact` 标记为 `reduced`。

**报告标注**：

```text
⚠️ 本章信息基于有限媒体覆盖，可能存在遗漏。建议补充检索: [替代关键词/数据库]。
```

### 5.3 local_vault 不可用

**表现**：本地 Obsidian Vault 路径不存在、无匹配文件、搜索结果为空。

**降级策略**：

1. 记录缺失的上下文类型（如"缺少郑好停项目历史资料"、"缺少内部经营数据"）。
2. 在报告中注明"本报告未引用内部资料（本地 Vault 不可用），所有结论仅基于外部来源和 AI 推理"。
3. 如果任务依赖内部资料（如公司经营决策），标记 `confidence_impact` 为 `high`。
4. 继续以外部来源为主生成报告，但明确列出缺失的本地上下文。
5. 建议用户提供或恢复 Vault 访问后重新生成 `-内参版`。

**报告标注**：

```text
⚠️ 本报告未引用本地内部资料：
- Vault 路径不可用: [路径]
- 缺失上下文: [具体说明缺少哪些内部业务背景]
- 当前结论仅基于外部公开信息和 AI 推理，内部自评维度待补充。
```

### 5.4 local_wiki 不可用

**表现**：本地技术知识库路径不存在、无匹配文件、搜索结果为空。

**降级策略**：

1. 技术原理解释切换为 AI 模型内训知识。
2. 在报告中明确标注"技术解释基于 AI 模型记忆，非最新版本文档库，可能存在过时或错误，需人工核验"。
3. 技术对比和选型建议以外部搜索来源为主，标注 AI 推理为辅。
4. 严禁以 AI 知识替代外部文献引用 — 涉及具体论文、版本号、Benchmark 数据时标记为"AI 估算，需核验"。
5. `confidence_impact`：技术原理说明部分标记为 `reduced`；技术选型核心结论涉及本地 Wiki 数据时标记为 `high`。

**报告标注**：

```text
⚠️ 本地技术知识库（local_wiki）不可用。
当前技术解释基于 AI 模型记忆，可能存在版本滞后或事实错误。
涉及具体版本号、Benchmark、论文结论的技术判断请以外部核验为准。
```

### 5.5 uploaded_files 缺失

**表现**：用户预期应上传附件但未提供，或任务描述中引用的文件不存在。

**降级策略**：

1. **暂停并询问用户**：明确告知缺少的附件，询问是否继续（基于公开资料和 AI 推理生成）、或等待附件上传。
2. 如果用户选择继续，基于可用来源生成报告，标注"缺少用户上传附件，分析基于公开资料"。
3. `confidence_impact` 标记为 `high`（如果附件是核心分析素材）。
4. 在 `required_manual_sources` 中列出缺失附件的预期内容。

**询问模板**：

```text
检测到以下预期附件缺失：[文件名列表]。
是否继续基于公开资料和 AI 推理生成报告？（报告将标注"缺少用户附件"）
或请上传附件后重新启动研究。
```

### 5.6 所有外部来源均失败

**表现**：外部搜索完全失败，无法获取任何外部资料。

**降级策略**：

1. 报告标记为 `离线初稿`，文件名加 `-离线初稿`。
2. 所有分析基于 `local_vault`、`local_wiki`（如可用）和 `AI 推理`。
3. 报告开头使用完整的离线初稿警告声明。
4. `source_failure_log` 中列出**所有维度**需要人工补充的外部来源。
5. `required_manual_sources` 清单需要覆盖每个研究章节。
6. 审计等级上限 `CONDITIONAL_PASS`，实际可能更低。
7. 每个核心结论必须标注"基于 AI 推理/内部资料，缺外部核验"。

**报告标注**：

```text
---
⚠️ 本报告为离线初稿 — 外部搜索完全失败
生成来源: AI 模型记忆 + (本地 Vault / 本地 Wiki，如可用)
核验状态: 所有核心数据和结论待联网核验
使用限制: 不得用于正式决策，仅供内部初判参考
---
```

### 5.7 所有来源均失败（含本地）

**表现**：外部搜索失败，本地 Vault 和 Wiki 也均不可用。

**降级策略**：

1. 报告标记为 `离线初稿 — 仅 AI 推理`。
2. 报告完全基于 AI 模型记忆生成。
3. 每个事实性断言必须标注"AI 训练数据，时效和准确性待核验"。
4. 报告尾部添加"完全未核验声明"。
5. `report_usability` 标记为"仅供参考"。
6. 强烈建议用户在网络和本地资料恢复后重新生成。

---

## 6. Source Conflict Resolution

当同一事实在多个来源中出现数据冲突时，按以下流程处理。

### 6.1 冲突排查优先级

1. **口径差异**：检查来源的统计口径、样本范围、计算方法是否一致。
2. **时效差异**：检查来源的发布时间，较旧数据可能已更新。
3. **机构偏差**：检查来源机构是否有已知偏好或利益关系。
4. **信息层级**：S 级优先于 A 级，A 级优先于 B 级 — 但需说明为何采信。
5. **交叉验证**：寻找第三方独立来源裁决。

### 6.2 冲突记录格式

```yaml
source_conflict:
  - fact_description: ""                        # 冲突的事实描述
    conflicting_sources:
      - source_name: ""
        source_level: "S/A/B/C/D"
        data_claim: ""
        publish_date: ""
        caliber: ""                              # 统计口径说明
      - source_name: ""
        source_level: "S/A/B/C/D"
        data_claim: ""
        publish_date: ""
        caliber: ""
    resolution_attempt: ""                       # 尝试如何处理
    resolution_result: "resolved | unresolved"   # 是否已解决
    adopted_source: ""                           # 如已解决，采信哪个来源及理由
    unresolved_handling: ""                      # 如未解决，标注"存在数据冲突，需人工核实"
```

### 6.3 冲突未解决规则

- 不得只选对结论有利的数据。
- 必须在报告正文中列出所有冲突来源和数据。
- 必须说明可能的原因（口径差异、时间差异、统计方法差异）。
- 如果冲突涉及核心结论，`confidence_impact` 标记为 `high`。
- 触发 `source_failure_log`，`failure_type` 为 `source_conflict_unresolved`。

---

## 7. Recovery Steps

任何来源失败事件发生后，执行以下恢复流程：

### 7.1 即时记录

1. **记录失败日志**：按第 2 节格式写入 `source_failure_log`，包含全部必填字段。
2. **标记失败发生阶段**：`failure_stage` 精确到研究 Phase 2/3/5。
3. **关联受影响结论**：每个失败事件必须列出 `affected_conclusions` 列表。

### 7.2 应用降级标签

1. 根据第 3.3 节的判定矩阵，确定 `report_usability_marking`。
2. 更新文件名，添加 `-离线初稿` 或 `-待联网核验版` 后缀。
3. 在报告开头插入第 3.2 节的警告声明。
4. 在报告 footer 中更新 `搜索状态` 为 `failed` 或 `partial_success`。
5. 在报告 footer 中更新 `审计等级` 上限为 `CONDITIONAL_PASS`。
6. 在报告 footer 中更新 `报告可用性` 为 `离线初稿` 或 `内部初稿`。

### 7.3 列出人工核验需求

1. 填充 `required_manual_sources`：按研究章节和数据类型列出需要人工补充的来源。
2. 填充 `suggested_databases_or_keywords`：建议的数据库名称和检索关键词。
3. 在报告正文中，每个受影响的章节末尾添加核验提示。

### 7.4 标记受影响结论

1. 对每个受影响的结论，在报告正文中添加标记：
   - `[待核验]`：结论基于降级来源，需联网核验。
   - `[AI 估算]`：结论基于 AI 推理，需人工核实。
   - `[内部口径]`：结论基于本地 Vault 数据，需与外部数据交叉验证。
   - `[来源冲突]`：结论涉及来源冲突，尚未解决，需人工裁决。
2. 在报告的"数据局限性"部分汇总所有标记项。

### 7.5 生成恢复清单

报告完成后，如果存在失败记录，必须在报告末尾或交付摘要中输出恢复清单：

```text
## 联网核验恢复清单

本次研究存在以下来源缺口，联网核验版生成前需补充：

| 序号 | 研究维度 | 缺失来源类型 | 建议检索关键词 | 建议检索数据库 | 核验优先级 |
|------|---------|-------------|---------------|---------------|-----------|
| 1    | [维度]  | [类型]      | [关键词]      | [数据库]      | 高/中/低  |

待完成后，重新运行研究任务生成 -联网核验版 报告。
```

---

## 8. Integration with Other Agents

### 8.1 source_agent 集成

- source_agent 在每次搜索任务结束后必须返回搜索状态（`success` / `partial_success` / `failed`）。
- 搜索状态为 `failed` 或 `partial_success` 时，source_agent 必须同时返回 `source_failure_log` 条目。
- source_agent 不可在搜索失败时返回空结果并标注 `success`。
- 搜索失败时 source_agent 仍须输出：`来源缺口清单`、`建议补充检索的数据库`、`建议补充检索的关键词`。

### 8.2 writer_agent 集成

- writer_agent 在生成报告时必须检查 `source_failure_log` 是否存在。
- 如果存在失败记录且报告为 `high_quality` 模式，writer_agent 必须执行第 3 节的降级规则。
- writer_agent 必须将警告声明写入报告开头。
- writer_agent 必须根据 `report_usability_marking` 决定文件名后缀。

### 8.3 reviewer_agent 集成

- reviewer_agent 必须检查 `source_failure_log` 的完整性：
  - 缺失必填字段 → 标记为审计问题，触发修订。
  - 搜索失败但未记录日志 → 标记为审计问题，`audit_grade` 不可为 `PASS`。
  - 搜索失败但报告标注为"正式版" → 强制降级，触发修订。
  - 搜索失败但文件名未加降级后缀 → 强制添加，触发修订。
  - `required_manual_sources` 为空 → 标记为审计问题，要求补充。
- reviewer_agent 最终输出的 `source_failure_log` 必须与 source_agent 和主 Agent 的记录交叉核对。

### 8.4 主 Agent 集成

- 主 Agent 在 Phase 2（资料搜索与来源分级）结束和 Phase 6（质量审计）结束后各检查一次 `source_failure_log`。
- 主 Agent 负责汇总所有 source_agent 返回的失败记录，合并去重后写入最终报告 footer。
- 主 Agent 在交付摘要中必须说明整体搜索状态、失败项数、以及是否需要人工补充来源。

---

## 9. Example: Complete Failure Log

以下为一次典型的部分搜索失败场景的完整日志示例：

```yaml
source_failure_log:
  # 失败事件 1：权威政策来源搜索失败
  - failure_time: "2026-05-05 14:30"
    failed_task: "中国智慧停车行业政策检索"
    failed_source_type: "external_authoritative"
    failed_source_detail: "住建部/交通部官网政策文件搜索"
    failure_type: "source_insufficient"
    failure_stage: "Phase_2_资料搜索"
    affected_scope: "第2章 政策环境分析"
    affected_conclusions:
      - "最新国家标准发布时间"
      - "中央财政补贴政策细节"
      - "各省市试点政策清单"
    fallback_handling: "使用本地 Vault 中的 2024 年政策整理文件作为替代来源"
    fallback_source_level: "D"
    confidence_impact: "high"
    required_manual_sources:
      - "住建部 2025-2026 年智慧停车相关政策文件"
      - "交通部 2025 年停车管理指导意见"
      - "各省市 2025-2026 年试点政策"
    suggested_databases_or_keywords:
      - "住建部官网: 智慧停车 政策 2025 2026"
      - "中国政府网: 城市停车 指导意见"
      - "北大法宝: 停车管理 地方条例"
    report_usability_marking: "内部初稿"
    audit_grade_cap: "CONDITIONAL_PASS"

  # 失败事件 2：市场规模数据不足
  - failure_time: "2026-05-05 14:45"
    failed_task: "中国智慧停车市场规模检索"
    failed_source_type: "external_media"
    failed_source_detail: "行业研究报告、券商研报搜索"
    failure_type: "source_quality_low"
    failure_stage: "Phase_2_资料搜索"
    affected_scope: "第3章 市场规模与增长估算"
    affected_conclusions:
      - "2025 年中国智慧停车市场规模"
      - "2025-2030 年复合增长率"
      - "细分市场份额分布"
    fallback_handling: "使用 2024 年发布的咨询机构报告和 AI 推理估算"
    fallback_source_level: "C"
    confidence_impact: "high"
    required_manual_sources:
      - "2025 年智慧停车行业年度报告"
      - "券商 2025 年智慧停车深度研报"
      - "上市公司 2025 年报停车场业务数据"
    suggested_databases_or_keywords:
      - "东方财富/同花顺: 智慧停车 2025 年报"
      - "艾瑞/易观: 智慧停车 市场报告 2025"
      - "Wind/彭博: 智能停车 市场规模"
    report_usability_marking: "离线初稿"
    audit_grade_cap: "CONDITIONAL_PASS"

  # 失败事件 3：本地技术 Wiki 缺失
  - failure_time: "2026-05-05 15:00"
    failed_task: "计算机视觉/车牌识别技术原理解释"
    failed_source_type: "local_wiki"
    failed_source_detail: "~/Documents/llm-wiki 路径不存在"
    failure_type: "local_source_unavailable"
    failure_stage: "Phase_2_资料搜索"
    affected_scope: "第4章 核心技术分析"
    affected_conclusions:
      - "车牌识别算法技术路线对比"
      - "边缘计算与云端处理技术权衡"
    fallback_handling: "技术解释基于 AI 模型记忆，标注'AI 估算，需核验'"
    fallback_source_level: "D"
    confidence_impact: "reduced"
    required_manual_sources:
      - "最新车牌识别算法综述 2025+"
      - "边缘计算工业部署技术文档"
    suggested_databases_or_keywords:
      - "arXiv: license plate recognition 2025"
      - "IEEE: edge computing parking management"
    report_usability_marking: "内部初稿"
    audit_grade_cap: "CONDITIONAL_PASS"
```

---

## 10. Quick Reference Card

| 场景 | 文件名后缀 | 报告可用性 | 审计上限 | confidence_impact |
|---|---|---|---|---|
| 外部搜索完全失败 | `-离线初稿` | 离线初稿 | CONDITIONAL_PASS | 全部 high |
| 外部搜索部分成功 | `-离线初稿` | 离线初稿 | CONDITIONAL_PASS | 受影响章 reduced/high |
| 外部搜索成功 + 本地 Vault 补强 | `-待联网核验版` | 内部初稿 | CONDITIONAL_PASS | reduced |
| 关键数据仅 C/D 级 | `-离线初稿` | 离线初稿 | CONDITIONAL_PASS | high |
| 数据缺时间/口径 | `-待联网核验版`或正文标注 | 内部初稿 | CONDITIONAL_PASS | reduced |
| local_vault 不可用 | 无后缀（正文标注） | 内部分析 | PASS（如外部来源充足） | reduced |
| local_wiki 不可用 | 无后缀（正文标注） | 正式版/内部初稿 | PASS（如外部来源充足） | reduced（非技术任务 none） |
| uploaded_files 缺失 | 无后缀（暂停询问） | 内部初稿 | 取决于外部来源 | high（如果附件是核心素材） |
| 来源冲突未解决 | `-离线初稿` | 离线初稿 | CONDITIONAL_PASS | high |
| 全部来源均失败 | `-离线初稿` | 仅供参考 | FAIL（建议不交付） | 全部 high |
| 全部成功 | 无后缀 | 正式版 | PASS | none |

---

> **引用说明**: 本文件与 `source-audit.md`（来源分级 S/A/B/C/D）、`source-boundaries.md`（六类来源边界）、`output-rules.md`（输出规则与报告 footer）、`subagents.md`（source_agent/writer_agent/reviewer_agent 合约）配套使用。任何来源失败场景的处理必须同时满足上述文件的要求。
