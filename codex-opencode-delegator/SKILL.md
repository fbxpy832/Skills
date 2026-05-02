---
name: codex-opencode-delegator
description: Use when the user wants Codex to plan, supervise, and review development work while delegating scoped coding, testing, documentation, or low-cost review tasks to OpenCode CLI with DeepSeek V4 Pro, DeepSeek V4 Flash, Kimi K2.6, or Qwen 3.6 Plus. This skill preserves Codex App and OpenAI provider configuration and only invokes OpenCode through local scripts.
---

# codex-opencode-delegator

## Purpose

This skill allows Codex to act as the architect, planner, supervisor, and reviewer, while delegating implementation work to OpenCode CLI.

Codex must not directly change global model provider settings. Codex must not modify `~/.codex/config.toml`, OpenAI credentials, Codex App settings, system proxy settings, or global environment variables unless the user explicitly asks.

This skill must only call OpenCode CLI through local scripts.

## Codex App Runtime Stability

When Codex calls OpenCode from inside the Codex App sandbox, OpenCode may fail even if it works in the user's normal terminal. Do not assume OpenCode is broken. First check the Codex runtime environment.

Before delegating, the local script should:

1. Resolve the OpenCode binary with `command -v opencode`.
2. If that fails, try `/opt/homebrew/bin/opencode`.
3. If that fails, try `$HOME/.opencode/bin/opencode`.
4. Use the resolved absolute path for all OpenCode calls.
5. Preserve `HOME=/Users/xpy` when that is the active user home.
6. Set `XDG_DATA_HOME=$HOME/.local/share` and `XDG_STATE_HOME=$HOME/.local/state` unless already provided.
7. Ensure `$XDG_DATA_HOME/opencode` and `$XDG_STATE_HOME/opencode` exist and are writable.
8. If they are not writable, report the issue and do not use `sudo`.
9. If proxy variables are absent and network calls fail, retry only with temporary per-process proxy variables:
   - `HTTP_PROXY=http://127.0.0.1:7890`
   - `HTTPS_PROXY=http://127.0.0.1:7890`
   - `ALL_PROXY=socks5://127.0.0.1:7890`
   - `NO_PROXY=localhost,127.0.0.1,::1`

Never fix OpenCode runtime failures by changing provider configuration, API keys, shell profile files, global proxy settings, or Codex configuration. The stable pattern is: absolute OpenCode path + per-process `HOME`/`XDG_*`/proxy variables + explicit filesystem permissions for OpenCode's data and state directories.

Common failure interpretation:

- `PRAGMA wal_checkpoint(PASSIVE)` or `readonly database`: Codex likely lacks write permission to `$XDG_DATA_HOME/opencode` or `$XDG_STATE_HOME/opencode`.
- `ProviderModelNotFoundError` after changing `XDG_DATA_HOME`: the temporary data directory probably lacks the user's normal auth/provider state. Use the real user data directory instead.
- `FailedToOpenSocket` or `ConnectionRefused` to `opencode.ai`: check Codex network permission and per-process proxy variables before judging the model or provider.

## Trigger Policy

This skill uses a semi-automatic trigger policy.

Codex may recommend this skill when it detects an implementation task, but Codex must not call OpenCode CLI before the user confirms the execution mode, unless the user has already explicitly specified the mode.

### When to trigger this skill

Trigger or recommend this skill when one or more of the following conditions are met, and the task is suitable for delegation to OpenCode CLI:

1. The user explicitly mentions `codex-opencode-delegator`.
2. The user asks Codex to perform actual file changes in the current codebase and wants or accepts OpenCode CLI delegation.
3. The user asks for implementation, bug fixing, refactoring, editing, testing, documentation, or batch code modification that is suitable for delegated execution.
4. The user wants Codex to plan or review while OpenCode CLI performs the execution.
5. The task is suitable for delegating implementation work to OpenCode CLI.

Typical trigger phrases include:

English:

- implement
- fix
- bugfix
- debug
- refactor
- edit
- update
- modify
- test
- add tests
- document
- docs
- batch modify
- execute this change
- apply this change

Chinese:

- 实现
- 修复
- 调试
- 重构
- 修改
- 编辑
- 更新
- 补测试
- 增加测试
- 改文档
- 写文档
- 批量修改
- 执行修改
- 应用修改
- 让 OpenCode 执行
- 交给 OpenCode
- 用 DeepSeek 执行

### When not to trigger this skill

Do not trigger this skill when the user only asks for:

1. Concept explanation.
2. Architecture discussion without file modification.
3. Technical analysis without implementation.
4. Code review only, especially when the user says not to modify files.
5. Command-line suggestions.
6. Configuration explanation.
7. General advice.
8. Planning only.
9. Prompt writing only.
10. Comparison of tools, models, libraries, or workflows.

Typical non-trigger phrases include:

- 分析一下
- 解释一下
- 这个架构合理吗
- 只 review 不修改
- 先不要改代码
- 给我一个方案
- 给我一个提示词
- 这个命令是什么意思
- 这个报错可能是什么原因
- 比较一下
- 推荐一下

### High-risk tasks

If the task involves any of the following, Codex must not directly execute without explicit user confirmation:

1. Codex App configuration.
2. `~/.codex/config.toml`.
3. OpenAI provider settings.
4. API keys or credentials.
5. Authentication tokens.
6. System proxy settings.
7. Global environment variables.
8. `.zshrc`, `.bashrc`, `.profile`, `.env`.
9. Production configuration.
10. Database migration.
11. Payment logic.
12. Authentication or authorization logic.
13. Security-sensitive code.
14. Destructive commands.
15. Use of `sudo`.

For high-risk tasks, Codex must explain the risk, recommend `quality_mode`, and wait for explicit confirmation.

### Mode confirmation rule

Before calling `scripts/opencode-delegate.sh`, Codex must determine whether the user has selected an execution mode.

If the user already specified one of the following, do not ask again.

Bare `A` or `B` only count as mode confirmation when they are a direct response to the mode-selection prompt. In other contexts, require an explicit mode phrase such as `quality_mode`, `高质量模式`, `economy_mode`, or `省成本模式`.

Quality mode indicators:

- A
- quality
- quality_mode
- 高质量模式
- 复杂任务
- 稳妥模式
- 高质量
- Codex Review
- Codex 5.5 Review

Economy mode indicators:

- B
- economy
- economy_mode
- 省成本模式
- 简单任务
- 快速处理
- 省额度
- 低成本
- OpenCode Review
- V4 Pro Review

If the user has not selected a mode, Codex must show the following prompt and wait for the user to choose A or B:

```text
请选择执行模式：

A. 高质量模式
适合复杂功能、核心逻辑、多文件修改、架构相关任务。
执行：OpenCode DeepSeek V4 Pro
Review：Codex 5.5
特点：质量更高，但 Codex 消耗更多。

B. 省成本模式
适合简单编辑、文档、注释、小范围低风险修改。
执行：OpenCode DeepSeek V4 Flash
Review：OpenCode DeepSeek V4 Pro
特点：更省 Codex 额度，但最终把关弱于 Codex 5.5。

推荐选择：{{RECOMMENDED_MODE}}
推荐理由：{{REASON}}

请回复 A 或 B。
```

## Use Cases

Use this skill when the user explicitly asks to use `codex-opencode-delegator`, delegate work to OpenCode CLI, use OpenCode Go models for implementation, or split responsibilities between Codex and OpenCode.

Good fit:

- Feature implementation after Codex planning
- Bug fixes with clear scope
- Test additions
- Documentation edits
- Local refactoring
- Low-cost review of simple changes
- Mode-based execution using quality or economy workflow

## Non-Use Cases

Do not use this skill for:

- Changing Codex App settings
- Changing `~/.codex/config.toml`
- Changing OpenAI provider settings
- Managing OpenCode login or credentials
- Installing OpenCode
- Setting global environment variables or proxy settings
- Running broad, unscoped rewrites
- Tasks where the user wants Codex to implement directly without delegation

## Core Roles

Codex is responsible for:

- Requirement understanding
- Architecture design
- Scope control
- Task decomposition
- Risk identification
- Creating execution instructions
- Choosing execution mode
- Reviewing OpenCode results when required
- Deciding whether another pass is needed
- Final merge recommendation

OpenCode CLI is responsible for:

- Executing clearly scoped coding tasks
- Implementing features
- Fixing bugs
- Adding tests
- Performing local refactoring
- Editing documentation
- Reviewing simple low-risk changes in economy mode

OpenCode must not:

- Expand task scope without permission
- Rewrite the whole project
- Introduce new frameworks without permission
- Modify architecture without permission
- Modify Codex configuration
- Modify OpenAI provider settings
- Modify credentials
- Modify system proxy
- Modify global environment variables
- Modify unrelated files

## Execution Modes

### A. quality_mode

Use this mode for high-quality, high-confidence development.

Workflow:

Codex 5.5 planning -> OpenCode DeepSeek V4 Pro execution -> Codex 5.5 review

Use quality_mode for:

- New feature development
- Complex business logic
- Multi-file changes
- Agent workflow changes
- API integration
- Authentication
- Authorization
- Credential handling
- State management
- Data processing
- Database migration
- Production configuration
- Trading strategy logic
- Calendar synchronization
- Obsidian automation
- Architecture-sensitive refactoring
- Security-sensitive changes
- User explicitly asks for high quality, safety, reliability, or careful review

Model responsibility:

- Planning: Codex 5.5
- Execution: OpenCode CLI + opencode-go/deepseek-v4-pro
- Review: Codex 5.5

### B. economy_mode

Use this mode for low-cost, low-risk development.

Workflow:

Codex short planning -> OpenCode DeepSeek V4 Flash execution -> OpenCode DeepSeek V4 Pro review -> Codex summary

Use economy_mode for:

- Simple editing
- Documentation changes
- Comment updates
- Formatting
- Small UI text changes
- Simple bug fixes
- Small tests
- Low-risk single-file changes
- Batch string replacement
- User explicitly asks to save Codex usage or use low-cost mode

Model responsibility:

- Planning: Codex short planning
- Execution: OpenCode CLI + opencode-go/deepseek-v4-flash
- Review: OpenCode CLI + opencode-go/deepseek-v4-pro
- Final summary: Codex

If OpenCode V4 Pro review finds significant risks, architecture concerns, unexpected changes, or scope expansion, Codex must recommend escalation to quality_mode.

## Mode Selection Rule

Before executing a delegated task, Codex should ask the user to choose a mode unless the user has already clearly specified a mode.

Prompt format:

```text
请选择执行模式：

A. 高质量模式
适合复杂功能、核心逻辑、多文件修改、架构相关任务。
执行：OpenCode DeepSeek V4 Pro
Review：Codex 5.5
特点：质量更高，但 Codex 消耗更多。

B. 省成本模式
适合简单编辑、文档、注释、小范围低风险修改。
执行：OpenCode DeepSeek V4 Flash
Review：OpenCode DeepSeek V4 Pro
特点：更省 Codex 额度，但最终把关弱于 Codex 5.5。

推荐选择：{{RECOMMENDED_MODE}}
推荐理由：{{REASON}}

请回复 A 或 B。
```

If the user says A, quality, high quality, 稳妥, 高质量, 复杂任务, then use quality_mode.

If the user says B, economy, 省成本, 简单任务, 快速处理, then use economy_mode.

If the task is obviously simple, recommend economy_mode.

If the task is risky, architectural, security-related, authentication-related, state-related, data-related, multi-file, or production-related, recommend quality_mode.

## Model Routing

Use three-level routing:

MODE + STAGE + TASK_TYPE

quality_mode:

- plan: Codex 5.5, do not delegate
- execute: opencode-go/deepseek-v4-pro
- review: Codex 5.5, do not delegate

economy_mode:

- plan: Codex short planning
- execute: opencode-go/deepseek-v4-flash
- review: opencode-go/deepseek-v4-pro

Default recommendations:

- docs/comment/format/simple/batch: recommend economy_mode
- implement/feature/backend/agent/api/state/refactor/test: recommend quality_mode
- auth/credential/payment/database/security/production config/architecture: must recommend quality_mode
- If user explicitly asks for economy mode on a risky task, warn about the risk first.
- If economy_mode review says escalation is needed, recommend quality_mode.

The routing script also includes optional defaults for Kimi K2.6 and Qwen 3.6 Plus:

- `chinese-doc`, `cn-doc`, or `report`: opencode-go/kimi-k2.6
- `architecture`, `plan`, or `planning` in auto routing: opencode-go/qwen3.6-plus

Known OpenCode Go model IDs:

- `opencode-go/deepseek-v4-flash`
- `opencode-go/deepseek-v4-pro`
- `opencode-go/glm-5`
- `opencode-go/glm-5.1`
- `opencode-go/kimi-k2.5`
- `opencode-go/kimi-k2.6`
- `opencode-go/mimo-v2-omni`
- `opencode-go/mimo-v2-pro`
- `opencode-go/mimo-v2.5`
- `opencode-go/mimo-v2.5-pro`
- `opencode-go/minimax-m2.5`
- `opencode-go/minimax-m2.7`
- `opencode-go/qwen3.5-plus`
- `opencode-go/qwen3.6-plus`

Model names in scripts are defaults. If local OpenCode model names differ, the user should run OpenCode and check `/models`, then update `scripts/model-router.sh`.

## Delegation Process

For quality_mode:

1. Codex understands the requirement.
2. Codex produces a short execution plan.
3. Codex generates an execution prompt file.
4. Codex calls `scripts/opencode-delegate.sh quality execute TASK_TYPE PROMPT_FILE PROJECT_DIR`.
5. OpenCode executes with opencode-go/deepseek-v4-pro.
6. Codex reads execution output and git diff.
7. Codex performs review using `templates/review-return.md`.
8. Codex outputs final result: Pass / Conditional Pass / Fail.

For economy_mode:

1. Codex understands the requirement.
2. Codex creates a short scoped instruction.
3. Codex calls `scripts/opencode-delegate.sh economy execute TASK_TYPE PROMPT_FILE PROJECT_DIR`.
4. OpenCode executes with opencode-go/deepseek-v4-flash.
5. Codex creates a review prompt using the result and diff.
6. Codex calls `scripts/opencode-delegate.sh economy review TASK_TYPE REVIEW_PROMPT_FILE PROJECT_DIR`.
7. OpenCode reviews with opencode-go/deepseek-v4-pro.
8. Codex summarizes the execution result and OpenCode review result.
9. If the review requests escalation, Codex recommends quality_mode.

## Template Selection

Choose the template that matches the delegated task:

- `templates/execute.md`: feature or implementation work
- `templates/fix.md`: bug fixing
- `templates/refactor.md`: refactoring
- `templates/test.md`: tests
- `templates/docs.md`: documentation
- `templates/opencode-review.md`: economy mode OpenCode review prompt
- `templates/review-return.md`: Codex final review structure
- `templates/mode-selection.md`: A/B mode selection prompt

Replace placeholders such as `{{TASK}}`, `{{FILES}}`, `{{RECOMMENDED_MODE}}`, and `{{REASON}}` before calling scripts.

## Safety Boundaries

This skill must never:

- Modify Codex App settings
- Modify `~/.codex/config.toml`
- Modify official OpenAI provider configuration
- Modify global shell configuration
- Modify `.zshrc`, `.bashrc`, `.profile`, `.env`, or proxy config unless explicitly requested
- Export global OPENAI_BASE_URL
- Export global OPENAI_API_KEY
- Export global proxy variables
- Change Codex authentication
- Change OpenAI authentication
- Store secrets in Skill files
- Print secrets
- Use sudo
- Install packages without explicit permission
- Run destructive commands

## Output Specification

When this skill completes delegated work, Codex should report:

1. Selected mode
2. Model route used
3. Files changed
4. Execution summary
5. Tests run
6. Review result
7. Risks or blockers
8. Merge recommendation

For quality_mode, final status must be one of:

- Pass
- Conditional Pass
- Fail

For economy_mode, include the OpenCode review status and whether Codex recommends escalation.

## Review Specification

Codex review should check:

- Whether the implementation followed the original plan
- Whether unexpected files changed
- Whether scope expanded
- Whether public APIs changed
- Whether configurations, credentials, proxies, or provider settings were modified
- Whether hidden side effects exist
- Whether error handling and edge cases are covered
- Whether tests were added or run
- Whether the change is safe to merge

OpenCode economy review should check:

- Whether the task was completed correctly
- Whether unrelated files changed
- Whether obvious bugs exist
- Whether tests are needed
- Whether the change should escalate to Codex 5.5 review

## Usage Examples

Example 1:

User:
使用 codex-opencode-delegator skill，帮我实现一个新的日程同步模块。

Codex:
推荐高质量模式。原因：涉及核心功能、多文件修改和数据同步。请选择 A 或 B。

Example 2:

User:
使用 codex-opencode-delegator skill，帮我改一下 README 的安装说明。

Codex:
推荐省成本模式。原因：这是文档类低风险任务。请选择 A 或 B。

Example 3:

User:
使用 codex-opencode-delegator skill，省成本模式，帮我修复这个按钮文案。

Codex:
直接使用 economy_mode，V4 Flash 执行，V4 Pro Review。

Example 4:

User:
使用 codex-opencode-delegator skill，高质量模式，帮我重构 Agent 调度逻辑。

Codex:
直接使用 quality_mode，V4 Pro 执行，Codex 5.5 Review。

## Troubleshooting

- If `opencode CLI not found` appears, install and log in to OpenCode first.
- If model selection fails or OpenCode rejects the model name, run OpenCode and check `/models`, then update `scripts/model-router.sh`.
- If a prompt file error appears, confirm the generated prompt file path exists.
- If the review stage in quality_mode prints `Review should be handled by Codex.`, this is expected.
- If economy_mode review says `Escalate to Codex`, rerun or continue the task in quality_mode.
- If OpenCode edits unrelated files, stop and review the git diff before any further delegation.
- If any credentials, provider settings, proxy settings, or global shell files were touched, treat the run as failed and require manual review.

## Important Notes

Model names in scripts are defaults. If local OpenCode model names differ, the user should run OpenCode and check `/models`, then update `scripts/model-router.sh`.
