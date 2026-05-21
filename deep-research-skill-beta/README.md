# Deep Research Skill — Beta 版

深度研究决策工作流，用于企业经营决策、技术路线研究、政府/国企汇报、投资/公司分析、竞品对标、政策研究、产业趋势、需求分析和通用知识深度研究。

## 核心特性

- **7 Agent 流水线**：planner → source → long-context → analyst → scenario → writer → reviewer
- **5 级来源体系**：S/A/B/C/D 严格分级，交叉验证规则
- **3 种搜索后端**：博查（中文）、Exa（英文语义）、Brave（通用 fallback）
- **5 种运行模式**：balanced / high_quality / cost_saving / long_context / draft_fast
- **3 级质量审计**：PASS / CONDITIONAL_PASS / FAIL，含自动修订
- **反幻觉机制**：模型声明必须可验证、来源降级强制记录

## 快速开始

```bash
# 1. 运行配置
scripts/setup.sh

# 2. 运行研究（通用模式）
scripts/generic-research-runner.sh high_quality task.md ./output

# 3. 直接搜索测试
scripts/search.sh "研究关键词" --parallel
```

## 文档

- [SKILL.md](SKILL.md) — 触发入口
- [references/workflow.md](references/workflow.md) — 完整工作流
- [references/task-classification.md](references/task-classification.md) — 任务分类
- [references/subagents.md](references/subagents.md) — Agent 职责
- [references/quality-review.md](references/quality-review.md) — 质量审计
- [references/search-tools.md](references/search-tools.md) — 搜索工具

## 许可

Beta 版 — 内部使用