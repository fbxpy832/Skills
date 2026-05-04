---
name: opencode-deep-research
description: 深度研究决策工作流。用于企业经营决策、技术路线研究、政府/国企汇报、投资/公司分析、竞品对标、政策研究、产业趋势、需求分析和通用知识深度研究。先识别任务类型与运行模式，再调度 Subagent、模型路由、来源审计、反证扫描、情景测算、质量审计，并输出领导速览版、完整研究版或执行建议版报告。
---

# Deep Research

Deep Research 是一套“研究决策型”工作流，不只是资料汇总。每次运行都必须先判断任务类型、选择运行模式和研究框架，再执行资料、分析、测算、写作与审计。

## Core Contract

1. 先分类，再研究：不要收到题目就直接搜索或写报告。
2. 先判断决策问题：明确用户真正要回答的是“是否做、怎么做、投入多少、风险在哪、下一步是什么”。
3. 先规划，再分工：建立问题树，决定是否需要公开搜索、内部文件读取、长文档分析、财务测算、技术对比、质量审计。
4. 先证据，再结论：关键事实必须有来源等级；缺数据时列为数据缺口，不虚构。
5. 先反证，再建议：重大结论必须做反证扫描和风险边界说明。
6. 先审计，再交付：最终报告必须经过 reviewer_agent 质量审计；不通过时自动修订一次。
7. 保持落地：建议必须包含动作主体、动作、资源、时间、指标、风险条件。

## Progressive Loading

只加载当前任务需要的文件：

- 模型路由与模式：读 [model-routing.yaml](model-routing.yaml)。
- OpenCode 直接调用：读 [references/opencode-runner.md](references/opencode-runner.md)，使用 `scripts/opencode-research-runner.sh`。
- 完整阶段流程：读 [references/workflow.md](references/workflow.md)。
- 任务分类与研究框架：读 [references/task-classification.md](references/task-classification.md)。
- Subagent 职责和输出契约：读 [references/subagents.md](references/subagents.md)。
- 来源分级和审计：读 [references/source-audit.md](references/source-audit.md)。
- 来源失败日志：读 [references/source-failure-log.md](references/source-failure-log.md)。
- 最终质量审计：读 [references/quality-review.md](references/quality-review.md)。
- 实际执行一致性检查：读 [references/execution-consistency.md](references/execution-consistency.md)。
- 输出文件与交付汇报：读 [references/output-rules.md](references/output-rules.md)。
- 用户业务上下文适配：涉及郑好停、阿顺数智、智慧停车、国企、城市治理、停车业务时读 [references/user-context.md](references/user-context.md)。
- 报告模板：按任务类型读取 `templates/` 下对应模板。

## Phase 0 Quick Start

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

## Model Routing Rules

模型路由以 [model-routing.yaml](model-routing.yaml) 为准，但默认只是“指令级路由建议”。只有 runner 或 OpenCode 命令输出能验证 `--model <model_id>` 调用成功时，才可写“已请求/已切换到该模型”；只有 OpenCode 状态栏、日志或命令输出能检测真实模型时，才可写“实际使用该模型”。无法检测时必须写“模型使用未能自动验证”。

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

## OpenCode Direct Runner

需要从 OpenCode 直接运行 Deep Research 时，使用：

```bash
Skills/deep-research/scripts/opencode-research-runner.sh MODE TASK_FILE [OUTPUT_DIR] [PROJECT_DIR]
```

示例：

```bash
Skills/deep-research/scripts/opencode-research-runner.sh high_quality /tmp/research-task.md /tmp/deep-research-run /Users/xpy/Documents/RichardHub/Git
```

该 runner 会按 `mode + agent` 调用 `scripts/model-router.sh`，默认采用分阶段并发：planner 先跑，source 与 long_context 并发，analyst 与 scenario 并发，writer 汇总，reviewer 最后审计。受限环境可用 `--sequential` 回退。详见 [references/opencode-runner.md](references/opencode-runner.md)。

## Source And Data Rules

凡涉及政策、市场数据、公司动态、价格、投融资、财务、论文、开源活跃度、新闻和最新进展，必须检索或读取可靠来源并标注来源等级。

来源等级简表：

- S：政府官网、监管机构、交易所/上市公司公告、法规原文、统计年鉴、标准、招股书/年报/季报、权威论文。
- A：主流财经媒体、行业协会、券商研报、咨询机构、专利/标准数据库、公开招投标。
- B：企业新闻稿、地方媒体、行业媒体、产品官网、会议材料。
- C：自媒体、博客、论坛、未经核验观点。
- D：经验估算、AI 推理、用户未核验口径、无法确认来源的数据。

关键事实尽量使用 S/A/B 来源。C/D 只能做参考，不得支撑核心结论。缺少可靠来源时必须写：“缺少可靠公开数据，需进一步核验。”

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

默认保存到：

`~/Library/Mobile Documents/iCloud~md~obsidian/Documents/RichardHub/收件箱/`

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

完成后不能只说“完成了”。必须汇报：

1. 输出文件路径。
2. 报告类型。
3. 自动选择的运行模式。
4. 使用的研究框架。
5. 启用的 Subagent。
6. 每个 Subagent 的请求模型；无法验证真实模型时写“模型使用未能自动验证”。
7. 真实模型检测状态。
8. 模型路由执行状态：真实切换 / 指令级建议 / 无法验证。
9. 搜索状态：成功 / 部分成功 / 失败。
10. 审计等级：PASS / CONDITIONAL_PASS / FAIL。
11. 报告可用性：正式版 / 内部初稿 / 离线初稿 / 仅供参考。
12. 是否触发模型升级。
13. 是否触发 fallback。
14. 主要结论。
15. 主要修改/优化点。
16. 仍缺哪些真实数据。
17. 必须补充核验的来源。
18. 是否建议进入下一步。
19. 是否需要人工复核的高风险部分。

## Backward Compatibility

原有能力继续保留：问题树、分层搜索、证据分级、反证扫描、交叉验证、置信度标注、多格式输出、禁止空话、技术路线主推/备选/不建议结构、报告保存到 Obsidian 收件箱。
