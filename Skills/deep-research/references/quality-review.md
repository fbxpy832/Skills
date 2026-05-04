# Quality Review

最终报告必须由 reviewer_agent 审计。审计等级为 `PASS`、`CONDITIONAL_PASS`、`FAIL`。审计不通过或仅条件通过时，必须按问题自动修订一次，并保留仍需人工核验的事项。

## Mandatory Checks

1. 是否有明确结论。
2. 是否有来源清单。
3. 关键数据是否标注来源。
4. 是否存在明显虚构数据。
5. 是否区分事实、推理、假设。
6. 是否有反证扫描。
7. 是否有风险分析。
8. 是否有行动建议。
9. 是否有数据缺口清单。
10. 是否符合用户指定风格。
11. 是否存在过度乐观表述。
12. 是否存在营销化、口号化语言。
13. 是否有无法落地的建议。
14. 是否有单点预测但没有情景分析。
15. 是否对公司决策没有帮助。
16. 是否说明本次使用的模式、Subagent 和模型分工。
17. 模型使用说明是否基于真实可检测执行上下文。
18. 是否把“模型路由建议”误写成“已使用模型”。
19. 搜索状态是否成功、部分成功或失败。
20. 是否存在 `source_failure_log`。
21. high_quality 模式是否因搜索失败、模型不可验证或来源不足降级。
22. 是否有关键数据时间戳。
23. 是否有人工复核项。

## Review Output

```yaml
audit_grade: PASS / CONDITIONAL_PASS / FAIL
report_usability: 正式版 / 内部初稿 / 离线初稿 / 仅供参考
real_model_detection_status: verified / partially_verified / not_verified
model_route_execution_status: real_switch / instruction_level_recommendation / unable_to_verify
search_status: success / partial_success / failed
major_issues:
minor_issues:
hallucination_risk:
source_quality_score: 1-5
actionability_score: 1-5
source_failure_log:
required_revisions:
final_publish_ready:
```

## Audit Grades

### PASS

可正式使用。必须同时满足：

- 运行模式与任务一致。
- 模型声明可验证，且不存在模型不一致。
- high_quality 的关键事实有 S/A/B 级来源。
- 外部搜索或来源读取成功。
- 有反证扫描。
- 关键数据有发布时间、统计口径或获取时间。
- 有人工复核项。

### CONDITIONAL_PASS

可作为内部初稿，但需补充核验。适用于：

- web 搜索失败但报告结构完整。
- 来源部分不足但已列出来源缺口和人工补充清单。
- 模型路由仅能验证为“指令级建议”。
- 模型使用无法自动验证，但未影响结构性分析。
- 内容适合内部讨论，不适合直接对外或上会。

### FAIL

不能交付为研究报告，只能作为研究提纲或草稿。适用于：

- 关键结论无来源且无明确假设。
- 没有反证扫描。
- high_quality 声称使用某模型但实际模型不一致或无法验证。
- 没有来源清单。
- 没有人工复核项。
- 技术路线任务未启用 source_agent。
- 投资、合规、财务或立项结论依赖 C/D 级来源。

## Failure Conditions

以下任一情况视为不通过：

- 重大结论没有 S/A/B 级来源或清晰假设。
- 涉及测算但只有单点预测。
- 涉及公司决策但没有“是否建议推进”。
- 涉及政府/国企材料但语言过度营销化。
- 涉及投资分析但没有风险提示和不构成投资建议声明。
- 没有数据缺口清单。
- 没有反证或失败案例扫描。
- Flash 或 Kimi 单独承担最终结论。
- 外部搜索失败但未标记为离线初稿/待联网核验版。
- 来源清单不足。
- 核心结论缺少 S/A/B 级来源。
- 实际模型与声明模型不一致。
- 模型使用无法验证但仍声明已使用某模型。
- 没有关键数据时间戳。
- 没有人工复核项。

## High Quality Downgrade Rules

`high_quality` 模式：

- 所有关键来源正常、模型可验证、审计通过：`PASS`。
- web 搜索失败但报告结构完整：`CONDITIONAL_PASS`，报告可用性为“离线初稿”或“内部初稿”。
- 关键结论无来源且无反证扫描：`FAIL`。
- 模型路由无法验证或与实际状态栏不一致：不得 `PASS`。
- 外部搜索失败、来源抓取失败或来源不足：文件名、报告开头、交付摘要必须标注 `离线初稿` 或 `待联网核验版`。

## Revision Rules

自动修订时优先处理：

1. 删除或标注无来源数据。
2. 补充反证和风险边界。
3. 将空泛建议改为动作、资源、时间、指标。
4. 将单点预测改为三情景。
5. 补充数据缺口清单。
6. 补充模式、Subagent、模型分工说明。
7. 把模型声明改为真实可验证状态；无法验证时写“模型使用未能自动验证”。
8. 补充 `source_failure_log`。
9. 将 high_quality 报告按条件降级为离线初稿/待联网核验版。

## Language Guardrails

避免：

- 加强、推动、赋能、构建生态、筑牢基础。
- 显著提升、全面领先、必然增长、确定受益。
- 无成本、低风险、快速复制、立即见效。

替换为：

- 谁在什么时间内做什么。
- 需要哪些资源。
- 验证什么指标。
- 达不到什么条件就暂停或退出。
