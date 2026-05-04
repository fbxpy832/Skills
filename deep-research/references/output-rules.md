# Output Rules

## File Output

默认输出 Markdown 文件。

默认保存目录：

```text
~/Library/Mobile Documents/iCloud~md~obsidian/Documents/RichardHub/收件箱/
```

文件名格式：

```text
YYYY-MM-DD-研究主题-报告类型.md
```

规则：

- 不覆盖原文件，除非用户明确要求。
- 如果目标文件已存在，追加 `-v2`、`-v3`。
- 二次优化加入“优化版”“立项版”“审校版”等后缀。
- 外部搜索失败、来源抓取失败或来源不足时，文件名必须加入 `-离线初稿` 或 `-待联网核验版`。
- 文件名去除 `/\:*?"<>|` 等不安全字符。

## Report Footer

报告末尾必须保留：

```text
---
生成日期: YYYY-MM-DD
研究方法: ...
运行模式: balanced/cost_saving/high_quality/long_context/draft_fast
任务类型: ...
Subagent 分工: ...
模型使用说明: ...
真实模型检测状态: verified / partially_verified / not_verified
模型路由执行状态: real_switch / instruction_level_recommendation / unable_to_verify
搜索状态: success / partial_success / failed
审计等级: PASS / CONDITIONAL_PASS / FAIL
报告可用性: 正式版 / 内部初稿 / 离线初稿 / 仅供参考
是否触发模型升级: 是/否，原因
是否触发 fallback: 是/否，原因
来源等级说明: S/A/B/C/D
source_failure_log: ...
数据局限性: ...
必须补充核验的来源: ...
下一步建议: ...
作者: AI Deep Research Skill
```

## Narrative Density

报告不得以表格为主体。表格只用于对比、清单、测算和附录，不能替代分析正文。

默认写作密度：

- 领导速览版可以使用要点，但每个核心判断必须配 1 段解释。
- 正文章节必须先写 2-4 段连续分析，再使用表格或列表补充。
- 每个关键章节至少回答“为什么重要、证据是什么、对决策有什么影响、下一步怎么验证”。
- 技术路线、经营决策、投资分析、政府汇报类报告中，表格内容之后必须有一段“表格解读/决策含义”。
- 除来源清单、数据缺口、行动计划、情景测算外，不得连续输出多个表格。
- 如果信息不足，也要用文字说明“不足在哪里、为何影响判断、需要补什么数据”，不要只给空表。

建议比例：

- 标准版和深度版：正文分析文字应占主要篇幅，表格和列表仅作辅助。
- 快速初稿：可多用要点，但仍需在每个大章节保留解释段落。

## Completion Summary

完成任务后必须汇报：

- 输出文件路径。
- 报告类型。
- 自动选择的运行模式。
- 使用的研究框架。
- 启用的 Subagent。
- 每个 Subagent 的请求模型与真实模型检测状态。
- 真实模型检测状态。
- 模型路由执行状态：真实切换 / 指令级建议 / 无法验证。
- 搜索状态：成功 / 部分成功 / 失败。
- 审计等级：PASS / CONDITIONAL_PASS / FAIL。
- 报告可用性：正式版 / 内部初稿 / 离线初稿 / 仅供参考。
- 是否触发模型升级。
- 是否触发 fallback。
- 主要结论。
- 主要修改/优化点。
- 仍缺哪些真实数据。
- 是否建议进入下一步。
- 是否需要人工复核的高风险部分。
- 必须补充核验的来源。

## Model Statement Rule

模型使用说明只能写真实可检测状态：

- runner 日志中有 `requested_model`：写“请求模型为 ...”。
- OpenCode 状态栏或命令输出可检测实际模型：写“检测到实际模型为 ...”。
- 无法检测：写“模型使用未能自动验证”。
- 不得把 `model-routing.yaml` 的建议模型写成“已使用模型”。

## No File Mode

如果用户只要求在聊天中回答，仍按工作流执行，但可不写文件。最终必须说明“本次未生成文件”。
