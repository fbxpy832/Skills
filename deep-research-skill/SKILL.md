---
name: deep-research
description: 深度研究决策工作流。用于企业经营决策、技术路线研究、政府/国企汇报、投资/公司分析、竞品对标、政策研究、产业趋势、需求分析和通用知识深度研究。先识别任务类型与运行模式，再调度 Subagent、来源规划与审计、反证扫描、情景测算、质量审计，并输出领导速览版、完整研究版或执行建议版报告。
---

# Deep Research — 轻量触发入口

本 skill 是 `deep-research-plugin` 的触发包装。所有脚本、配置、模板和评测框架均由插件提供。

## 前置条件

安装插件（本地开发版）：

```bash
opencode plugin install ./deep-research-plugin
```

## 首次配置

```bash
deep-research-plugin/scripts/setup.sh
```

配置项包括：各 agent 模型来源、搜索 API key（Brave/Bocha/Exa）、输出目录。

## 使用

```
/opencode-deep-research 研究主题描述
```

或直接对话中提及研究需求。

## 插件结构

核心逻辑位于 `deep-research-plugin/`：
- `scripts/` — 6 个脚本（setup、search、model-router、generic-runner、opencode-runner、install-providers）
- `references/` — 协议契约、来源体系、审计规则、搜索后端文档
- `eval/` — 评测框架（5 种任务类型 × rubric + run-eval.sh）
- `templates/` — 报告模板（business/government/technical/investment/general）
- `source-policy.yaml`、`model-routing.yaml` — 来源策略和模型路由配置
