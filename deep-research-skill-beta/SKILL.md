---
name: deep-research-skill-beta
description: 深度研究决策工作流 Beta。用于企业经营决策、技术路线研究、政府/国企汇报、投资/公司分析、竞品对标、政策研究、产业趋势、需求分析和通用知识深度研究。首次使用先运行 setup 选择不同 agent 的模型来源、接入点地址、API key 或 token plan key，并配置搜索工具 API key；之后先识别任务类型与运行模式，再调度 Subagent、来源规划与审计、反证扫描、情景测算、质量审计，并输出领导速览版、完整研究版或执行建议版报告。
---

# Deep Research Skill — Beta 版

深度研究工作流，支持 7 Agent 流水线、5 级来源体系（S/A/B/C/D）、多搜索引擎路由、质量审计和反幻觉机制。

## Claude Desktop / Cowork 强制规则

首次触发本 Skill 时，必须先运行配置检查脚本：

```bash
bash scripts/check-config.sh
```

- 如果配置文件不存在，或没有任何 `BOCHA_API_KEY` / `BRAVE_API_KEY` / `EXA_API_KEY`，必须停止研究并提示用户运行 `bash scripts/setup.sh` 或 `bash setup-config.sh` 完成配置。不得继续生成“深度研究报告”。
- Claude Desktop / Cowork 不会自动执行交互式安装，也不保证宿主机 `~/.config` 会映射进沙箱。配置解析顺序为：`DEEP_RESEARCH_CONFIG_ENV`、当前工作目录 `config.env`、Skill 目录 `config.env`、`~/.config/deep-research-skill/config.env`。
- 在 Cowork 中，如果 `~/.config` 不可见，但当前工作目录或 Skill 目录已有 `config.env`，以 `scripts/check-config.sh` 的结果为准，不得误报“未配置”。
- 执行搜索前必须通过脚本自动解析配置，不要手写 `test -f ~/.config/...` 检查。
- 默认必须联网搜索。除非用户明确说“不联网 / 离线 / 不用搜索”，否则 source_agent 必须调用 `scripts/search.sh "查询词" --parallel` 或宿主等价搜索工具。
- `scripts/generic-research-runner.sh` 在没有 `HOST_RUN_CMD` 时只会进入 dry-run，生成提示文件和占位输出；这不等于完成研究。Claude Desktop / Cowork 中不得把 dry-run 输出宣称为“7 个 Agent 已执行完成”。
- 如果宿主无法真实切换或验证模型，报告必须写“模型使用未能自动验证”，不得宣称已使用某个推荐模型。
- 最终报告必须通过 `bash scripts/finalize-report.sh --writer <writer输出> --task <任务文件> --run-dir <运行目录> --mode <模式> --source-log <source_failure_log>` 保存并校验。只有脚本返回 `final_report_path=...` 且该文件真实存在时，才能对用户说“报告已保存”。
- 最终回复必须读取 `finalize-report.sh` 返回的 `final_audit_grade=...`。只有 `PASS` 才能写“质量审计通过”；`FAIL` / `CONDITIONAL_PASS` 必须明确降级，不得用“数据可追溯、结论有支撑”等泛化话术掩盖来源缺口。
- `DEEP_RESEARCH_OUTPUT_DIR` 是首选输出目录；如果 Claude Desktop / Cowork 沙箱无法访问该目录（例如宿主 iCloud/Obsidian 路径），必须明确告知“配置输出目录不可见或不可写”，并报告脚本返回的真实 fallback 路径。不得把聊天附件、工作目录文件或沙箱文件说成已经保存到配置目录。
- 如果用户要求必须保存到配置目录，设置 `DEEP_RESEARCH_STRICT_OUTPUT_DIR=1`；此时目标目录不可写必须停止并报错，不得 fallback。

## 安装方式

### Claude Desktop / Cowork 员工安装要点

给员工安装到 Claude Desktop / Cowork 时，必须同时完成两处本机私有配置：

1. `~/.config/deep-research-skill/config.env` — 宿主机终端、Claude Code、OpenCode 使用。
2. `~/.claude/skills/deep-research-skill-beta/config.env` — Claude Desktop / Cowork 沙箱随 Skill 目录读取，用于避免沙箱内 `~/.config` 不可见时误报未配置。

推荐让员工在 Mac 终端运行：

```bash
cd <deep-research-skill-beta 目录>
bash setup-config.sh
```

安装脚本必须在生成 `~/.config/deep-research-skill/config.env` 后，把同一份配置复制到 `~/.claude/skills/deep-research-skill-beta/config.env`，并设置 `chmod 600`。`config.env` 含 API key，禁止提交到 Git、打进公共 zip 包或共享给其他员工。

安装完成后，用以下命令验证，而不是手写 `~/.config` 检查：

```bash
cd ~/.claude/skills/deep-research-skill-beta
bash scripts/check-config.sh
```

### 方式一：Claude Code 本地技能

```bash
# 1. 将本 skill 复制到 Claude/Claude Code skills 目录（排除 git、本地配置、运行产物）
mkdir -p ~/.claude/skills/deep-research
rsync -a \
  --exclude='.git' \
  --exclude='.deep-research-runs' \
  --exclude='config.env' \
  --exclude='*.env' \
  ./ ~/.claude/skills/deep-research/
chmod +x ~/.claude/skills/deep-research/scripts/*.sh

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

### 方式四：Windows Git Bash + WorkBuddy

用于公司分发场景，员工主要使用 WorkBuddy（CodeBuddy 桌面 IDE）调用本 skill。

```bash
# 1. 前提：安装 Git for Windows（自带 bash 5+ 和 curl）
#    https://gitforwindows.org/

# 2. 在 Git Bash 中运行一键配置脚本
cd <deep-research-skill-beta 目录>
bash setup-config.sh

# 3. 脚本检测到 WorkBuddy 后，按提示选择「1) WorkBuddy」
#    配置自动写入三个位置：
#    - ~/.config/deep-research-skill/config.env（宿主机终端）
#    - ~/.claude/skills/deep-research-skill-beta/config.env（skill 目录）
#    - ~/WorkBuddy/Claw/.deep-research.env（WorkBuddy 沙箱可见）

# 4. 重启 WorkBuddy，验证配置
bash scripts/check-config.sh
```

> **注意**：WorkBuddy 模式采用指令级路由（`workbuddy/opus`、`workbuddy/sonnet`、`workbuddy/haiku`），实际模型由 WorkBuddy gateway 调度，本 skill **不会自动验证**真实后端模型。报告将固定注明"模型使用未能自动验证"。

### 平台兼容矩阵

| 平台 | Claude Code | WorkBuddy | OpenCode | Claude Desktop |
|---|---|---|---|---|
| macOS | ✅ 推荐 | ✅ | ✅ | ✅ |
| Linux | ✅ | ❌ | ✅ | ✅ |
| Windows Git Bash | ✅ 可选部署 | ✅ **主要部署路径** | ⚠️ 路径探测 | ⚠️ 路径探测 |
| WSL | ⚪ 暂不支持 | ⚪ 暂不支持 | ⚪ 暂不支持 | ⚪ 暂不支持 |

## 前置条件

- **bash 3.2+**（macOS 自带；Windows 需要 [Git for Windows](https://gitforwindows.org/)，自带 bash 5.2+）
- **python3** 或 **py -3**（Windows 需安装 [Python Launcher](https://www.python.org/downloads/windows/)，脚本自动检测 `py -3`）
- **curl**（用于搜索 API 调用；Git for Windows 自带，macOS/Linux 自带）
- 至少一个搜索 API Key（通过 setup.sh 配置）：百度智能云 / Brave / Bocha / Exa
- 可选工具：
  - **ripgrep** — Obsidian Vault 全文搜索。macOS: `brew install ripgrep` / Linux: `apt install ripgrep` / Windows: `winget install BurntSushi.ripgrep`
  - **lark-cli** — 用于飞书知识库搜索
  - **notebooklm CLI** — 用于 NotebookLM 搜索

## 使用方式

本 Skill 在支持的宿主中按以下方式触发：

- **Claude Desktop / Cowork**：先确认配置和搜索 key，然后按本文件的强制规则直接执行研究流程；不要用 dry-run runner 代替真实研究。
- **WorkBuddy**：采用指令级路由 `workbuddy/opus|sonnet|haiku`。实际模型由 WorkBuddy gateway 调度，报告必须标注"模型使用未能自动验证"。首次使用需在 setup 中选择 WorkBuddy 选项。
- **Claude Code**：直接对话中提及研究需求（如「深度研究一下 XXX 行业」、「分析 XXX 公司的投资价值」），Skill 自动匹配。
- **OpenCode**：`/opencode-deep-research 研究主题描述`
- **通用模式**：`HOST_RUN_CMD` 已配置时才可用 `scripts/generic-research-runner.sh high_quality task.md` 执行 live agent；未配置时只是 dry-run。

配置项包括：各 agent 模型来源、搜索 API key（百度智能云 / Brave / Bocha / Exa）、知识库路径（Obsidian Vault / NotebookLM）、输出目录。
安装后还需将 `scripts/` 目录添加到 $PATH 或使用绝对路径调用 search.sh、model-router.sh 等脚本。
激活配置：`source ~/.config/deep-research-skill/config.env`
Claude Desktop / Cowork 中必须优先以 `bash scripts/check-config.sh` 验证配置可见性；如果该脚本返回 `status=ok`，即使沙箱内 `~/.config` 不可见，也应继续执行研究。

## 技能结构

```
deep-research-skill-beta/
├── SKILL.md                  # 触发入口
├── model-routing.yaml        # 模型路由配置
├── source-policy.yaml        # 来源策略配置
├── scripts/                  # 10 个脚本
│   ├── setup.sh
│   ├── search.sh
│   ├── check-config.sh
│   ├── finalize-report.sh
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
