# Deep Research Multi-host Distribution Package

**不是单一 OpenCode 插件。** 本包是面向多宿主的 Deep Research 分发包——同一套配置、runner、搜索和输出协议，供 OpenCode、Codex、Claude Code、CloudCode、GUI、TU/terminal 和 CI 通过各自 host adapter 接入。

## 快速验证

```bash
# 1. 配置
./scripts/setup.sh

# 2. 验证
./scripts/generic-research-runner.sh cost_saving /tmp/test.md /tmp/test-out . --dry-run --sequential

# 3. Eval
./eval/run-eval.sh --dry-run --runner generic
```

## 宿主支持矩阵

| 宿主 | 安装方式 | 真实 agent 调用 | Runner |
|------|---------|:---:|------|
| OpenCode | `opencode plugin /path/... --force` | ✓ | opencode-research-runner.sh |
| Codex | SKILL.md 链接 + autoloop | ✓（通过 Codex） | generic-research-runner.sh |
| Claude Code | 直接调用 runner | 宿主负责 | generic-research-runner.sh |
| CloudCode | 直接调用 runner | 宿主负责 | generic-research-runner.sh |
| GUI / TU | 直接调用 runner | 宿主负责 | generic-research-runner.sh |
| Terminal / CI | 直接执行脚本 | dry-run 或宿主提供 | 两个 runner 均可 |

## 核心组件

| 组件 | 文件 | 职责 |
|------|------|------|
| **配置层** | `~/.config/deep-research-skill/config.env` | 模型路由、搜索 key、输出目录 |
| **搜索层** | `scripts/search.sh` | Brave/Bocha/Exa 多引擎搜索 |
| **模型路由** | `scripts/model-router.sh` | 按 mode+agent 路由到 provider/model |
| **通用 Runner** | `scripts/generic-research-runner.sh` | 宿主无关的 prompt/artifact 生成器 |
| **OpenCode Runner** | `scripts/opencode-research-runner.sh` | OpenCode 宿主适配 runner |
| **Eval** | `eval/run-eval.sh` | 5 种任务类型 dry-run 验证 |
| **协议文档** | `references/` | 宿主适配器契约、来源体系、审计规则 |

## 目录

```
deep-research-plugin/
├── index.js              ← OpenCode plugin 入口
├── package.json          ← npm 包清单（main → index.js）
├── plugin.yaml           ← 多宿主 metadata
├── SKILL.md              ← 工作流文档
├── README.md             ← 本文件
├── INSTALL.md            ← 安装手册
├── SECURITY.md           ← 安全策略
├── scripts/              ← 6 个脚本
├── references/           ← 协议契约和文档
├── eval/                 ← 评测框架
├── templates/            ← 报告模板
├── source-policy.yaml    ← 来源策略
└── model-routing.yaml    ← 模型路由
```

## 许可

MIT
