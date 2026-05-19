---
name: deep-research-skill
description: 可推广部署的深度研究决策工作流。首次使用先运行 setup 选择不同 agent 的模型来源、接入点地址、API key 或 token plan key，并配置搜索工具 API key；用于企业经营决策、技术路线研究、政府/国企汇报、投资/公司分析、竞品对标、政策研究、产业趋势、需求分析和通用知识深度研究。
---

# Deep Research Skill

Deep Research 是一套“研究决策型”工作流，不只是资料汇总。每次运行都必须先判断任务类型、选择运行模式和研究框架，再执行资料、分析、测算、写作与审计。

## First Use Setup

首次使用或换团队环境时，先运行：

```bash
scripts/setup.sh
```

setup 会在 `~/.config/deep-research-skill/` 下生成本机私有配置。该配置是宿主无关的，可被 OpenCode、Codex、Claude Code、CloudCode、Deep Research GUI、TU/terminal 工具或其他 agent runner 读取，包含：

- 多个模型来源：宿主 token plan、DeepSeek、Moonshot/Kimi、OpenAI、OpenRouter、SiliconFlow 或自定义 OpenAI-compatible endpoint；可一次配置多个 provider。
- 各 agent 的 provider/model 路由：`planner_agent`、`source_agent`、`long_context_agent`、`analyst_agent`、`scenario_agent`、`writer_agent`、`reviewer_agent`。
- 接入点地址：每个来源可配置 `base_url`。
- 凭证：支持 API key 或 token plan key。本 skill 不要求把凭证写入仓库。
- 搜索工具 key：提示配置 `BRAVE_API_KEY`、`BOCHA_API_KEY`、`EXA_API_KEY`，用于 `scripts/search.sh`。
- 默认输出目录：提示配置 `DEEP_RESEARCH_OUTPUT_DIR`，报告和 runner 产物默认写入该目录。

生成的 `config.env` 会被 `scripts/model-router.sh`、`scripts/opencode-research-runner.sh`、`scripts/search.sh` 以及其他宿主适配器读取。setup 可选调用 `scripts/install-opencode-providers.sh`，把 provider 元数据和模型列表合并进 OpenCode 配置；默认不写任何宿主配置。API key 仍只保存在本机私有 `config.env`，runner 或宿主适配器在调用对应 agent 前临时导出。若未配置，仍按内置默认模型路由运行，但搜索工具必须使用用户自己的 API key；不得依赖他人或示例 key。

## Host Integration

本 skill 的核心协议与具体宿主解耦：

- **通用配置层**：`~/.config/deep-research-skill/config.env`、`providers.env`、`model-routing.yaml`。
- **通用搜索层**：`scripts/search.sh`，由 `BRAVE_API_KEY`、`BOCHA_API_KEY`、`EXA_API_KEY` 驱动。
- **通用模型路由层**：`scripts/model-router.sh MODE AGENT`，返回 `provider/model`。
- **通用输出层**：`DEEP_RESEARCH_OUTPUT_DIR`，由 setup 初始化，所有宿主默认写入该目录。
- **宿主适配层**：OpenCode、Codex、Claude Code、CloudCode、GUI、TU/terminal runner 可各自读取同一配置，并负责真实模型调用与日志证据。

宿主只能把 `provider/model` 写成“请求模型”或“路由建议”。只有对应宿主日志、UI 状态、命令输出或 API 响应能证明真实模型时，才可写“实际使用模型”。

## Core Contract

1. 先分类，再研究：不要收到题目就直接搜索或写报告。
2. 先判断决策问题：明确用户真正要回答的是“是否做、怎么做、投入多少、风险在哪、下一步是什么”。
3. 先规划，再分工：建立问题树，默认必须发起公开搜索（除非用户明确指示"不需要联网搜索""离线分析""不用搜索"），并确定内部文件读取、长文档分析、财务测算、技术对比、质量审计。
4. 先证据，再结论：关键事实必须有来源等级；缺数据时列为数据缺口，不虚构。
5. 先反证，再建议：重大结论必须做反证扫描和风险边界说明。
6. 先审计，再交付：最终报告必须经过 reviewer_agent 质量审计；不通过时自动修订一次。
7. 保持落地：建议必须包含动作主体、动作、资源、时间、指标、风险条件。

## Progressive Loading

只加载当前任务需要的文件：

- 来源策略与配置：读 [source-policy.yaml](source-policy.yaml)。
- 来源类型与边界：读 [references/source-boundaries.md](references/source-boundaries.md)。
- 来源分级和审计：读 [references/source-audit.md](references/source-audit.md)。
- 来源失败日志：读 [references/source-failure-log.md](references/source-failure-log.md)。
- 搜索工具方案（工具矩阵、搜索引擎选择、降级策略）：读 [references/search-tools.md](references/search-tools.md)。
- 模型路由与模式：读 [model-routing.yaml](model-routing.yaml)。
- 首次配置与本机私有凭证：运行 `scripts/setup.sh`；配置文件位于 `~/.config/deep-research-skill/config.env`。
- 宿主集成：默认读本节 `Host Integration`；OpenCode 直接调用时再读 [references/opencode-runner.md](references/opencode-runner.md)，使用 `scripts/opencode-research-runner.sh`。
- 完整阶段流程：读 [references/workflow.md](references/workflow.md)。
- 任务分类与研究框架：读 [references/task-classification.md](references/task-classification.md)。
- Subagent 职责和输出契约：读 [references/subagents.md](references/subagents.md)。
- 最终质量审计：读 [references/quality-review.md](references/quality-review.md)。
- 实际执行一致性检查：读 [references/execution-consistency.md](references/execution-consistency.md)。
- 输出文件与交付汇报：读 [references/output-rules.md](references/output-rules.md)。
- 用户业务上下文适配：涉及郑好停、阿顺数智、智慧停车、国企、城市治理、停车业务时读 [references/user-context.md](references/user-context.md)。
- 报告模板：按任务类型读取 `templates/` 下对应模板；生成附录时再读 [references/template-appendix.md](references/template-appendix.md)。

## Phase 0 Quick Start

### 强制前置加载

执行任何操作前，**必须先确认本机配置和搜索工具配置**：

```yaml
必须确认:
  - ~/.config/deep-research-skill/config.env 是否存在
  - 如不存在，先提示并运行 scripts/setup.sh
  - references/search-tools.md 中的搜索后端和降级策略
  - BRAVE_API_KEY / BOCHA_API_KEY / EXA_API_KEY 至少配置一个
```

未确认搜索 key 和 search-tools.md 前，不得发起任何搜索或执行任何 Phase。中文优先 Bocha，英文优先 Exa，Brave 作为通用 fallback；若用户明确不需要联网搜索，可跳过搜索 key，但最终报告必须标注为离线分析。

收到研究任务后，先输出内部判断并执行，不要频繁追问；除非缺失信息会导致研究方向完全不同。

1. 识别 `task_type`：
   - `business_decision`：公司经营决策、立项、试点、预算、业务推进、商业模式。
   - `government_report`：政府汇报、国企材料、城市治理、公共服务。
   - `technical_route`：技术路线、架构选型、端侧 AI、算法、系统方案。
   - `investment_analysis`：上市公司、股票、估值、行业景气、财务分析。
   - `general_research`：概念解释、趋势、科普、背景研究。
2. 选择 `mode`：
   - 默认 `balanced`。
   - 决策、汇报、立项、投资、技术路线、风险评估、给领导看：`high_quality`。
   - 基于长文件、多份材料、审校、重写：`long_context`。
   - 简单整理、快速看、初步分析、不用太详细：`cost_saving`。
   - 快速初稿、后续人工修改：`draft_fast`。
3. 选择写作风格：
   - `government_formal`、`executive_brief`、`professional_direct`、`technical_deep`、`investment_research`。
   - 涉及郑好停、阿顺数智、城市治理、国企经营、停车业务时，默认 `professional_direct + government_formal`。
4. 确定 Subagent：
   - 默认启用 `planner_agent`、`analyst_agent`、`writer_agent`、`reviewer_agent`。
   - 涉及公开事实或最新资料时启用 `source_agent`。
   - 技术路线研究类任务必须启用 `source_agent`；即使搜索失败，也必须输出来源缺口和建议检索库/关键词。
   - 涉及长文档或已有材料时启用 `long_context_agent`。
   - 涉及市场规模、收入、利润、用户数、回收期、估值、成本节约、效率提升时启用 `scenario_agent`。
5. 如真实 Subagent 或多模型调用不可用，退化为主 Agent 顺序模拟，并在交付说明中写明。

## Phase 0.5 Source Planning（来源规划）

Phase 0 完成后、Phase 1 开始前，必须先形成内部 `source_plan`，明确本次研究需要哪些数据来源、各自适用边界以及失败降级策略。

### 来源类型定义

| 来源类型 | 定义 | 允许支撑核心结论 | 默认等级 |
|---------|------|:---:|:---:|
| **external_authoritative** | 政府官网、监管机构、交易所公告、上市公司公告、法规原文、标准、统计年鉴、招股书/年报/季报、学术论文、权威会议论文、行业协会报告、公开招投标 | ✓ | S/A |
| **external_media** | 主流财经媒体、行业媒体、券商研报、咨询机构报告、企业新闻稿、产品官网、技术博客、会议材料 | 需交叉验证 | B/C |
| **local_vault** | 本地 Obsidian Vault（建议通过 `DEEP_RESEARCH_VAULT_DIR` 配置）：公司历史报告、项目方案、用户笔记、会议纪要、业务材料 | 条件允许（标注"内部口径，需核验"） | 内部口径 |
| **local_wiki** | 本地 llm-wiki / karpathy wiki：AI/LLM/Agent 等技术原理知识库 | 条件允许（不用于最新事实） | 技术参考 |
| **uploaded_files** | 当前上传的 Markdown/PDF/Word/Excel/图片等 | 条件允许（区分"文件内声称"与"已核验事实"） | 当前上下文 |
| **model_reasoning** | AI 推理判断 | ✗ 不得写成事实 | D |

详见 [references/source-boundaries.md](references/source-boundaries.md)。

### 来源等级

| 等级 | 定义 | 支撑能力 |
|:---:|------|------|
| **S** | 政府官网、监管机构、法规原文、交易所公告、年报/招股书、权威论文 | 支撑核心结论 |
| **A** | 行业协会报告、咨询机构、券商研报、企业官网正式页、招投标、专利 | 支撑重要结论 |
| **B** | 主流财经媒体、行业媒体、企业新闻稿、会议演讲、技术博客 | 辅助论据，需交叉验证 |
| **C** | 自媒体、知乎、博客、论坛、未经核验传闻 | 仅观点参考 |
| **D** | AI 知识、经验估算、无出处数据、二手转述 | 仅假设，不写成事实 |

### 任务类型 × 数据源优先级

| 任务类型 | 优先来源（按顺序） | 特殊约束 |
|---------|------------------|---------|
| **business_decision** | uploaded_files → local_vault → external_authoritative → external_media → model_reasoning | 必须区分内部口径/外部事实/AI 推理/待核验数据 |
| **government_report** | external_authoritative → local_vault → uploaded_files → external_media → model_reasoning | 禁止用自媒体支撑核心结论；禁止营销话术 |
| **technical_route** | local_wiki(仅原理) → external_authoritative → external_media → uploaded_files → local_vault → model_reasoning | local_wiki 不用于最新事实，必须外部核验最新论文和产品进展 |
| **investment_analysis** | external_authoritative → external_media → uploaded_files → local_vault → model_reasoning | 禁止用论坛/自媒体作核心依据；禁止绝对化投资结论 |
| **general_research** | external_authoritative → local_wiki → external_media → model_reasoning | 概念可引用 local_wiki，最新状态需外部核验 |

### Source Plan 最小输出

每次研究必须在内部形成 `source_plan` 的 YAML-like 判断：

- `task_type`
- `required_sources`: 必须使用的来源
- `optional_sources`: 可选来源
- `forbidden_or_weak_sources`: 不应作为核心依据的来源
- `source_risk`: 来源风险点
- `verification_needs`: 需交叉核验的内容
- `freshness_requirement`: 是否需求最新信息
- `local_source_need`: 是否需要检索 Vault/Wiki
- `uploaded_file_need`: 是否需优先读取上传文件
- `fallback_policy`: 来源失败时的降级策略

source_plan 可作为内部过程，不强制写入报告正文。但最终交付摘要应简要说明"主要数据来源"。

### 来源使用红线

1. **核心结论**必须尽量由 S/A/B 级来源支撑。
2. **C 级来源**只能用于启发、补充、线索，不得单独支撑核心判断。
3. **D 级来源**只能作为假设或待核验项，不得写成事实。
4. 涉及**政策、法律、监管、资金、财务、上市公司、投资判断**，必须优先 S/A 级来源。
5. **不得把本地 Vault 笔记当作外部权威事实**。
6. **不得把本地 Wiki 当作最新产业事实**。
7. **不得把 AI 模型推理写成事实**。
8. 无可靠来源时不得虚构，应写"缺少可靠公开来源，需进一步核验"。
9. 关键事实尽量有 2+ 独立来源交叉验证。

### 外部搜索失败降级

当外部搜索失败、API 超时、网页无法访问或来源不足时：

1. 必须记录 `source_failure_log`（见 [references/source-failure-log.md](references/source-failure-log.md)）。
2. `high_quality` 模式不得标记为"正式高质量报告"。
3. 报告自动降级为 **离线初稿** 或 **待联网核验版**。
4. 文件名加后缀 `-离线初稿`。
5. 报告开头写："本报告因外部搜索/来源抓取失败，部分内容基于本地资料或模型知识生成，关键结论需联网核验后方可用于正式决策。"
6. 审计等级最高为 `CONDITIONAL_PASS`。

详见 [references/source-failure-log.md](references/source-failure-log.md) 和 [references/source-boundaries.md](references/source-boundaries.md)。

> **重要：** 在判定"外部搜索失败"前，必须按 [references/search-tools.md](references/search-tools.md) 定义的统一搜索入口与 fallback 顺序逐级尝试。跳过已配置的搜索后端直接降级是禁止行为。

## Model Routing Rules

模型路由以 [model-routing.yaml](model-routing.yaml) 和本机 `~/.config/deep-research-skill/config.env` 为准。本机配置优先级高于内置默认值，但仍只是“指令级路由建议”。只有 runner、宿主命令输出或 API 响应能验证模型调用成功时，才可写“已请求/已切换到该模型”；只有宿主状态栏、日志、命令输出或 API 响应能检测真实模型时，才可写“实际使用该模型”。无法检测时必须写“模型使用未能自动验证”。

关键底线：

- DeepSeek V4 Pro：复杂推理、经营决策、合规资金税务、技术路线、投资分析、最终报告、质量审计。
- DeepSeek V4 Flash：资料初筛、搜索结果整理、低成本批量搜索、初稿骨架、通用解释。
- Kimi 2.6：长文档阅读、多文件摘要、政策/合同/招投标/财报/技术文档归纳。

必须升级到 DeepSeek V4 Pro：

- 合规、法律、资金、二清、支付、税务。
- 公司立项、预算、投资决策。
- 财务测算、估值、收入预测。
- 最终结论和质量审计。
- Flash 输出出现明显不确定、逻辑跳跃或数据缺口。
- 用户要求认真分析、给领导看、用于汇报或用于决策。

禁止：

- Flash 作为最终经营判断模型。
- Kimi 2.6 单独承担最终结论。
- 为省成本跳过最终 Pro 审计。

## OpenCode Adapter

需要从 OpenCode 直接运行 Deep Research 时，使用：

```bash
Skills/deep-research-skill/scripts/opencode-research-runner.sh MODE TASK_FILE [OUTPUT_DIR] [PROJECT_DIR]
```

示例：

```bash
Skills/deep-research-skill/scripts/opencode-research-runner.sh high_quality /tmp/research-task.md /tmp/deep-research-run /path/to/project
```

该 runner 会按 `mode + agent` 调用 `scripts/model-router.sh`，默认采用分阶段并发：planner 先跑，source 与 long_context 并发，analyst 与 scenario 并发，writer 汇总，reviewer 最后审计。受限环境可用 `--sequential` 回退。详见 [references/opencode-runner.md](references/opencode-runner.md)。

## Source And Data Rules

来源体系的核心配置见 [source-policy.yaml](source-policy.yaml)，边界定义见 [references/source-boundaries.md](references/source-boundaries.md)。审计规则见 [references/source-audit.md](references/source-audit.md)。

**速查摘要**：

- 每次研究前必须形成内部 `source_plan`（任务类型 → 来源优先级 → 降级策略）。
- 来源分 **6 类**：external_authoritative / external_media / local_vault / local_wiki / uploaded_files / model_reasoning。
- 来源分 **5 级**：S（最高）→ A（高）→ B（中）→ C（低）→ D（不可作为事实）。
- **核心结论**必须由 S/A/B 级来源支撑。C 级只能补充。D 级只能作假设。
- 外部搜索失败时自动降级为"离线初稿"，不得标为"正式高质量报告"。缺少可靠来源时必须写：“缺少可靠公开数据，需进一步核验。”

## Scenario Rules

涉及市场规模、收入、利润、用户数、投资回收期、储值金额、估值、成本节约、运营效率提升时，禁止只给单点预测。至少输出：

- 保守情景。
- 中性情景。
- 积极情景。

缺少真实数据时必须写：“以下为情景假设，不作为最终决策依据，需结合公司真实经营数据复核。”

## Output Templates

按任务类型读取模板：

- `business_decision`：读 [templates/business-decision.md](templates/business-decision.md)。
- `technical_route`：读 [templates/technical-route.md](templates/technical-route.md)。
- `investment_analysis`：读 [templates/investment-analysis.md](templates/investment-analysis.md)。
- `government_report`：读 [templates/government-report.md](templates/government-report.md)。
- `general_research`：读 [templates/general-research.md](templates/general-research.md)。

默认输出 Markdown。根据用户要求可输出：

- 领导速览版：结论、建议、收益、风险、决策事项。
- 完整研究版：事实、分析、反证、情景、来源、数据缺口。
- 执行建议版：行动路径、资源、周期、指标、风险边界。

## File Output

默认保存到 setup 配置的目录：

`${DEEP_RESEARCH_OUTPUT_DIR:-~/Deep-Research-Outputs/}`

文件名：

`YYYY-MM-DD-研究主题-报告类型.md`

不要覆盖原文件，除非用户明确要求。二次优化应加“优化版”“立项版”“审校版”等后缀。

报告末尾必须保留：

- 生成日期。
- 研究方法。
- 运行模式。
- Subagent 分工。
- 模型使用说明。
- 来源等级说明。
- 数据局限性。
- 下一步建议。

## Final Delivery Summary

完成后不能说“完成了”。必须汇报：

1. 输出文件路径。
2. 报告类型。
3. 自动选择的运行模式。
4. 使用的研究框架。
5. 启用的 Subagent。
6. 每个 Subagent 的请求模型；无法验证真实模型时写“模型使用未能自动验证”。
7. 真实模型检测状态。
8. 模型路由执行状态：真实切换 / 指令级建议 / 无法验证。
9. 搜索状态：成功 / 部分成功 / 失败。
10. 使用的数据来源类型（按 external_authoritative / external_media / local_vault / local_wiki / uploaded_files / model_reasoning 列举）。
11. 来源审计等级：PASS / CONDITIONAL_PASS / FAIL。
12. 是否存在来源失败。
13. 哪些关键结论需要人工核验。
14. 报告可用性：正式版 / 内部初稿 / 离线初稿 / 仅供参考。
15. 是否触发模型升级。
16. 是否触发 fallback。
17. 主要结论。
18. 主要修改/优化点。
19. 仍缺哪些真实数据。
20. 必须补充核验的来源。
21. 是否建议进入下一步。
22. 是否需要人工复核的高风险部分。

## Backward Compatibility

原有能力继续保留：问题树、分层搜索、证据分级、反证扫描、交叉验证、置信度标注、多格式输出、禁止空话、技术路线主推/备选/不建议结构、报告保存到用户配置的输出目录。
