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
是否触发模型升级: 是/否，原因
是否触发 fallback: 是/否，原因
来源等级说明: S/A/B/C/D
数据局限性: ...
下一步建议: ...
作者: AI Deep Research Skill
```

## Completion Summary

完成任务后必须汇报：

- 输出文件路径。
- 报告类型。
- 自动选择的运行模式。
- 使用的研究框架。
- 启用的 Subagent。
- 每个 Subagent 使用的模型。
- 是否触发模型升级。
- 是否触发 fallback。
- 主要结论。
- 主要修改/优化点。
- 仍缺哪些真实数据。
- 是否建议进入下一步。
- 是否需要人工复核的高风险部分。

## No File Mode

如果用户只要求在聊天中回答，仍按工作流执行，但可不写文件。最终必须说明“本次未生成文件”。
