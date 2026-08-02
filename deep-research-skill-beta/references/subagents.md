# Subagent Contracts

Subagent 可以是真实并发代理，也可以是主 Agent 按顺序模拟的角色流程。最终报告由主 Agent 统一判断和写作，Subagent 不直接决定最终结论。

## 主 Agent

职责：

- 理解用户任务。
- 判断研究类型。
- 选择运行模式。
- 制定研究计划。
- 分配子任务。
- 汇总 Subagent 结果。
- 统一生成最终报告。
- 进行质量审计。
- 输出文件和交付摘要。

## planner_agent

职责：

- 判断研究类型。
- 明确报告对象。
- 建立问题树。
- 拆解主问题、子问题、验证问题、反证问题。
- 制定研究计划。
- 判断是否需要外部搜索、内部文件读取、长文档分析、财务测算、技术对比。

推荐模型：

- 默认：DeepSeek V4 Flash（当前临时策略，全部 DeepSeek 角色统一）。

输出格式：

```yaml
task_type:
report_audience:
research_depth:
recommended_mode:
problem_tree:
key_questions:
data_needed:
risk_focus:
required_subagents:
```

## source_agent

职责：

- 搜索公开资料。
- 提取关键事实。
- 记录来源链接。
- 对来源进行 S/A/B/C/D 分级。
- 标注数据获取时间。
- 识别过期数据和低质量来源。
- 不做最终判断。

推荐模型：

- 默认：DeepSeek V4 Flash。

输出格式：

```yaml
source_title:
source_url:
source_level:
publish_date:
retrieval_date:
extracted_facts:
reliability_notes:
citation_ready_text:
```

## long_context_agent

职责：

- 阅读用户提供的长文档。
- 阅读历史报告、政策文件、合同、招投标文件、财报、技术文档。
- 提炼结构。
- 找出核心数据、矛盾点、缺口。
- 生成文档摘要和可引用要点。

推荐模型：

- 默认：DeepSeek V4 Flash（与全部 DeepSeek 角色统一）。

输出格式：

```yaml
document_name:
document_summary:
key_facts:
contradictions:
missing_data:
reusable_sections:
suggested_rewrite_direction:
```

## analyst_agent

职责：

- 进行经营分析、技术路线分析、投资分析、合规分析。
- 构建逻辑链。
- 进行利弊对比。
- 判断是否建议推进。
- 输出结论依据。
- 不得虚构数据。

推荐模型：

- 默认：DeepSeek V4 Flash（当前临时策略）。

输出格式：

```yaml
core_judgment:
supporting_reasons:
opposing_evidence:
confidence_level:
decision_implication:
```

## scenario_agent

职责：

- 建立保守、中性、积极三种情景。
- 明确输入假设。
- 识别缺失数据。
- 计算收入、成本、投入产出、回收期、用户转化率等。
- 对无法计算的部分标注“需补充真实数据”。

推荐模型：

- 默认：DeepSeek V4 Flash。

输出格式：

```yaml
assumptions:
conservative_case:
base_case:
optimistic_case:
sensitivity_factors:
missing_data:
cannot_calculate_items:
```

## writer_agent

职责：

- 根据任务类型选择报告模板。
- 整合资料、分析、测算和结论。
- 输出符合指定风格的 Markdown 报告。
- 形成领导速览版、正文和附录。
- 不得新增未经验证的数据。
- 正文分析必须多于表格。每个关键章节先写 2-4 段连续分析，再用表格、列表或清单补充。
- 表格之后必须写“表格解读/决策含义”，不能用表格替代判断。
- 不得把请求模型或路由建议写成真实已使用模型。
- 如果模型无法验证，必须写“模型使用未能自动验证”。
- 如果搜索失败或来源不足，必须将 high_quality 报告标为离线初稿/待联网核验版。

推荐模型：

- 默认：DeepSeek V4 Flash。

输出格式：

```yaml
report_title:
report_type:
executive_summary:
full_report:
appendices:
source_list:
data_gap_list:
real_model_detection_status:
model_route_execution_status:
search_status:
report_usability:
required_source_verification:
```

## reviewer_agent

职责：

- 检查报告是否有明确结论。
- 检查关键数据是否有来源。
- 检查是否存在虚构数据。
- 检查是否过度乐观。
- 检查是否有反证扫描。
- 检查是否有风险边界。
- 检查建议是否可执行。
- 检查是否符合用户指定风格。
- 检查真实模型是否可验证。
- 检查模型路由是否被误写为实际使用。
- 检查搜索失败是否降级为离线初稿/待联网核验版。
- 检查 `source_failure_log` 是否完整。
- 对不合格内容提出修改意见。
- 必要时触发自动修订。

推荐模型：

- 默认：DeepSeek V4 Flash（当前临时策略）。
- 由于当前审计也使用 Flash，结论必须保留人工复核项。

输出格式：

```yaml
audit_grade: PASS / CONDITIONAL_PASS / FAIL
report_usability:
real_model_detection_status:
model_route_execution_status:
search_status:
major_issues:
minor_issues:
hallucination_risk:
source_quality_score:
actionability_score:
source_failure_log:
required_revisions:
final_publish_ready:
```
