---
name: codex-opencode-autoloop
description: Use when coordinating Codex App with OpenCode or Oh My OpenAgent for local development, automated review, test evidence collection, and repair loops.
---

# codex-opencode-autoloop

Use this project-local skill when a user wants Codex to control a local OpenCode / OMA development loop while preserving auditability and safety.

## Workflow

1. Run preflight:
   `bash .codex-opencode/scripts/codex-opencode-preflight.sh`
2. Start a task with `--task` or `--task-file`.
3. Watch `.codex-opencode/status/live.md` or run the status script.
4. Review each run under `.codex-opencode/runs/`.
5. Trust completion only after Codex Review, tests, and security check are recorded.

## Safety Rules

- Keep artifacts under `.codex-opencode/`.
- Do not edit secrets, `.env` files, SSH keys, cookies, or OMA private config.
- Do not bypass Codex App, OpenCode, OMA, OS, network, or filesystem security.
- If OMA cannot be confirmed, follow `config.json` fallback behavior and report uncertainty.
- If security check reports `needs_user_action`, stop the automatic loop.

## Key Files

- `.codex-opencode/config.json`
- `.codex-opencode/status/live.md`
- `.codex-opencode/status/state.json`
- `.codex-opencode/reports/final-report.md`
- `.codex-opencode/reports/oma-model-audit.md`
- `.codex-opencode/runs/<run>/`
