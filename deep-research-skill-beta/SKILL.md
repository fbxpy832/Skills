---
name: deep-research
description: 深度研究决策工作流。用于企业经营决策、技术路线研究、政府/国企汇报、投资/公司分析、竞品对标、政策研究、产业趋势、需求分析和通用知识深度研究。先识别任务类型与运行模式，再调度 Subagent、来源规划与审计、反证扫描、情景测算、质量审计，并输出领导速览版、完整研究版或执行建议版报告。
---

# Deep Research Skill — Beta 版

深度研究工作流，支持 7 Agent 流水线、5 级来源体系（S/A/B/C/D）、多搜索引擎路由、质量审计和反幻觉机制。

## 安装方式

### 方式一：Claude Code 本地技能

```bash
# 1. 将本 skill 复制到 Claude Code skills 目录（排除 git/ 等无关文件）
mkdir -p ~/.claude/skills/deep-research
cp scripts/ references/ templates/ source-policy.yaml model-routing.yaml SKILL.md ~/.claude/skills/deep-research/
cp -r scripts/ references/ templates/ ~/.claude/skills/deep-research/
# 注意：如果以上命令报错，请逐个目录复制：
# cp -r scripts references templates source-policy.yaml model-routing.yaml SKILL.md ~/.claude/skills/deep-research/

# 2. 运行配置脚本（首次使用必须运行）
cd ~/.claude/skills/deep-research && bash scripts/setup.sh

# 3. 激活配置
source ~/.config/deep-research-skill/config.env
```

### 方式二：放在项目中直接使用

```bash
git clone <仓库地址>
cd deep-research-skill-beta
bash scripts/setup.sh
source ~/.config/deep-research-skill/config.env
```

### 方式三：OpenCode 集成

```bash
bash scripts/install-opencode-providers.sh
bash scripts/setup.sh
source ~/.config/deep-research-skill/config.env
```

## 前置条件

- **bash 3.2+**（macOS 自带，Linux 需确认）
- **python3**（用于 JSON 处理和搜索结果解析）
- **curl**（用于搜索 API 调用）
- 至少一个搜索 API Key（通过 setup.sh 配置）：Brave / Bocha / Exa
- 可选工具：
  - **ripgrep** (`brew install ripgrep`) — 用于 Obsidian Vault 全文搜索
  - **lark-cli** — 用于飞书知识库搜索
  - **notebooklm CLI** — 用于 NotebookLM 搜索

## 使用方式

本 Skill 在支持的宿主中按以下方式触发：

- **Claude Code**：直接对话中提及研究需求（如「深度研究一下 XXX 行业」、「分析 XXX 公司的投资价值」），Skill 自动匹配。
- **OpenCode**：`/opencode-deep-research 研究主题描述`
- **通用模式**：`scripts/generic-research-runner.sh high_quality task.md`（宿主无关）

配置项包括：各 agent 模型来源、搜索 API key（Brave/Bocha/Exa）、知识库路径（Obsidian Vault / NotebookLM）、输出目录。
安装后还需将 `scripts/` 目录添加到 $PATH 或使用绝对路径调用 search.sh、model-router.sh 等脚本。
激活配置：`source ~/.config/deep-research-skill/config.env`

## 技能结构

```
deep-research-skill-beta/
├── SKILL.md                  # 触发入口
├── model-routing.yaml        # 模型路由配置
├── source-policy.yaml        # 来源策略配置
├── scripts/                  # 10 个脚本
│   ├── setup.sh
│   ├── search.sh
│   ├── knowledge-retrieval.sh    # 知识库检索统一入口 ← 新增
│   ├── knowledge-obsidian.sh     # Obsidian Vault 适配器 ← 新增
│   ├── knowledge-lark.sh         # 飞书知识库适配器 ← 新增
│   ├── knowledge-notebooklm.sh   # NotebookLM 适配器 ← 新增
│   ├── model-router.sh
│   ├── generic-research-runner.sh
│   ├── opencode-research-runner.sh
│   └── install-opencode-providers.sh
├── references/               # 16 份参考文档
│   ├── workflow.md
│   ├── task-classification.md
│   ├── subagents.md
│   ├── source-audit.md
│   ├── source-boundaries.md
│   ├── source-failure-log.md
│   ├── quality-review.md
│   ├── output-rules.md
│   ├── knowledge-retrieval.md    # 知识库适配器协议 ← 新增
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
