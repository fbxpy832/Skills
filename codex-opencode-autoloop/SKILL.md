---
name: codex-opencode-autoloop
description: Use when coordinating Codex App with OpenCode or Oh My OpenAgent for local development, automated review, test evidence collection, and repair loops.
---

# codex-opencode-autoloop

Use this root-level skill when a user wants Codex to act only as dispatcher, status reader, reviewer, and final acceptor for a local OpenCode / OMA development loop.

This skill directory is the reusable source. Runtime state, logs, reports, and per-project configuration should be created in the target project's `.codex-opencode/` directory.

## Delegation Contract

- For development, bug fixing, refactoring, testing, or code generation, Codex MUST NOT directly edit business source code.
- Codex MAY only create or edit files under `.codex-opencode/`.
- All business code changes MUST be performed by OpenCode CLI or OMA agents.
- If OpenCode / OMA availability cannot be confirmed, Codex must stop automatic development, report the blocker, and give only the minimum recovery suggestion.
- Codex must not take over coding because OpenCode is unavailable, slow, failing, or inconvenient.

## Mandatory CLI Invocation

Every development task must follow this order:

1. Run preflight:
   `bash .codex-opencode/scripts/codex-opencode-preflight.sh`
2. Write the user requirement to:
   `.codex-opencode/tasks/<timestamp>-task.md`
3. Start execution through the configured OpenCode / OMA command.
4. Before each Codex reply, record:
   - `command`
   - `exit_code`
   - `run_id`
   - `status_file`
   - `summary_file`
   - `test_result`
   Destination: `.codex-opencode/status/last-codex-reply.json`.

## Workflow

1. Initialize the runtime directory under `.codex-opencode/`.
2. Run preflight:
   `bash .codex-opencode/scripts/codex-opencode-preflight.sh`
3. Write the task file under `.codex-opencode/tasks/`.
4. Invoke OpenCode / OMA CLI.
5. Read compact status and summary only.
6. If needed, request an OpenCode / OMA repair loop.
7. Codex performs final review only after tests and security evidence exist.

## Token Budget Rules

- By default, Codex may read only:
  - `.codex-opencode/status/state.json`
  - `.codex-opencode/status/live.md`
  - `.codex-opencode/reports/final-report.md`
  - `.codex-opencode/runs/<run>/summary.md`
- Do not default to reading full source, full logs, or full diffs.
- Only if summary shows failure, test failure, or security anomaly may Codex read more context.
- Per round, read at most:
  - 3 source files
  - 200 log lines
  - 1 diff summary
- OpenCode / OMA output must provide a compact summary with:
  - `files_changed`
  - `tests_run`
  - `errors`
  - `next_action`
  - `risk_level`
- If `.codex-opencode/runs/<run>/summary.md` is missing, treat the run as incomplete.

## Codex Self-Check

Before any code modification, Codex must ask:

- Am I editing business source directly? Expected: No.
- Have I invoked OpenCode / OMA? Expected: Yes.
- Do I have a `run_id` and test evidence? Expected: Yes.
- Am I reading only compact summaries? Expected: Yes.

If any answer differs from the expected value or is unsafe, stop and switch back to OpenCode / OMA invocation.

## Violation Handling

- If Codex has already edited business source directly, stop further development.
- State that the delegation protocol was violated.
- Hand all remaining implementation work back to OpenCode / OMA.
- Do not bypass CLI to save steps.
- Do not treat "OpenCode unavailable" as permission for Codex to code directly.

## Safety Rules

- Keep artifacts under `.codex-opencode/`.
- Do not edit secrets, `.env` files, SSH keys, cookies, or OMA private config.
- Do not bypass Codex App, OpenCode, OMA, OS, network, or filesystem security.
- If OMA cannot be confirmed, follow `config.json` fallback behavior and report uncertainty.
- If security check reports `needs_user_action`, stop the automatic loop.

## Recommended User Prompt

使用 codex-opencode-autoloop skill。你只能作为调度与审查者，不得直接修改业务源码。所有开发、修复、测试必须通过 OpenCode/OMA CLI 完成。每轮只读取 compact summary，不读取完整日志或全量源码，除非测试失败且必须最小化定位。

## Key Files

- `.codex-opencode/config.json`
- `.codex-opencode/tasks/<timestamp>-task.md`
- `.codex-opencode/status/live.md`
- `.codex-opencode/status/state.json`
- `.codex-opencode/status/last-codex-reply.json`
- `.codex-opencode/reports/final-report.md`
- `.codex-opencode/reports/oma-model-audit.md`
- `.codex-opencode/runs/<run>/summary.md`
- `.codex-opencode/runs/<run>/`
