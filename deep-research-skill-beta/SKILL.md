---
name: deep-research
description: 深度研究决策工作流。用于企业经营决策、技术路线研究、政府/国企汇报、投资/公司分析、竞品对标、政策研究、产业趋势、需求分析和通用知识深度研究。先识别任务类型与运行模式，再调度 Subagent、来源规划与审计、反证扫描、情景测算、质量审计，并输出领导速览版、完整研究版或执行建议版报告。
---

# Deep Research Skill — Beta 版

深度研究工作流，支持 7 Agent 流水线、5 级来源体系（S/A/B/C/D）、多搜索引擎路由、质量审计和反幻觉机制。

## 前置条件

首次使用需要运行配置脚本：

```bash
scripts/setup.sh
```

配置项包括：各 agent 模型来源、搜索 API key（Brave/Bocha/Exa）、输出目录。

## 使用方式

本 Skill 在支持的宿主中按以下方式触发：

- **Claude Code**：直接对话中提及研究需求（如「深度研究一下 XXX 行业」、「分析 XXX 公司的投资价值」），Skill 自动匹配。
- **OpenCode**：`/opencode-deep-research 研究主题描述`
- **通用模式**：`scripts/generic-research-runner.sh high_quality task.md`（宿主无关）

## 首次配置

```bash
scripts/setup.sh
```

配置项包括：各 agent 模型来源、搜索 API key（Brave/Bocha/Exa）、输出目录。

安装后还需将 `scripts/` 目录添加到 $PATH 或使用绝对路径调用 search.sh、model-router.sh 等脚本。

## 技能结构

```
deep-research-skill-beta/
├── SKILL.md                  # 触发入口
├── model-routing.yaml        # 模型路由配置
├── source-policy.yaml        # 来源策略配置
├── scripts/                  # 6 个脚本
│   ├── setup.sh
│   ├── search.sh
│   ├── model-router.sh
│   ├── generic-research-runner.sh
│   ├── opencode-research-runner.sh
│   └── install-opencode-providers.sh
├── references/               # 15 份参考文档
│   ├── workflow.md
│   ├── task-classification.md
│   ├── subagents.md
│   ├── source-audit.md
│   ├── source-boundaries.md
│   ├── source-failure-log.md
│   ├── quality-review.md
│   ├── output-rules.md
│   ├── search-tools.md
│   ├── execution-consistency.md
│   ├── host-adapter-contract.md
│   ├── opencode-runner.md
│   ├── search-adapter-contract.md
│   ├── user-context.md
│   ├── template-appendix.md
│   └── search-backends/
│       ├── bocha.md
│       ├── exa.md
│       └── searxng-deploy.md
├── templates/                # 5 份报告模板
│   ├── business-decision.md
│   ├── government-report.md
│   ├── technical-route.md
│   ├── investment-analysis.md
│   └── general-research.md
└── eval/                     # 评测框架
    ├── rubric.yaml
    ├── run-eval.sh
    └── 5 个任务 YAML
```
