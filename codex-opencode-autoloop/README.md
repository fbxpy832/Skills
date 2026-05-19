# codex-opencode-autoloop

`codex-opencode-autoloop` is a root-level Skill plus local Codex App workflow scaffold for:

Codex -> OpenCode -> Oh My OpenAgent / OMA -> agents -> tests -> security check -> Codex Review -> repair loop.

This directory is the reusable Skill source. It keeps working state inside each target project's `.codex-opencode/` runtime directory so Codex App can inspect compact status, run summaries, evidence, and reports.

## Files In This Skill

- `SKILL.md`: trigger and operating instructions for Codex.
- `config.example.json`: default runtime configuration template.
- `scripts/`: runtime scripts to place under `.codex-opencode/scripts/` in a target project.
- `prompts/`: role prompt templates for planner, coder, tester, reviewer, and repair.
- `reports/troubleshooting.md`: troubleshooting reference.

## Good Fits

- Local development tasks where Codex should plan, review, and validate while OpenCode performs edits.
- Projects that already use OpenCode CLI.
- OMA setups where planner / coder / tester / reviewer / repair roles may be available.
- Repeatable repair loops with clear audit files.

## Poor Fits

- Tasks that require bypassing Codex App, OpenCode, OMA, operating system, network, or filesystem security.
- Work that needs automatic editing of OMA private configuration.
- Secret rotation, credential handling, or `.env` modification.
- Large refactors without explicit user approval.

## Architecture

Codex App is the controller. It reads compact status and summaries by default. OpenCode does implementation work. If OMA is detectable and usable, prompts prefer OMA-style roles. If OMA cannot be confirmed and fallback is enabled, the tool can use plain OpenCode.

Agent selection is never hard-coded unless the installed CLI exposes a compatible method. If no agent-selection flag can be confirmed, role selection is prompt-based and recorded as such.

## Preflight

```bash
bash .codex-opencode/scripts/codex-opencode-preflight.sh
```

This writes:

- `.codex-opencode/status/preflight.md`
- `.codex-opencode/status/preflight.json`
- `.codex-opencode/status/oma-preflight.md`
- `.codex-opencode/status/oma-preflight.json`
- `.codex-opencode/status/oma-trigger-test.md`

## Start A Task

```bash
bash .codex-opencode/scripts/codex-opencode-autoloop.sh --task "实现某功能"
```

From a task file:

```bash
bash .codex-opencode/scripts/codex-opencode-autoloop.sh --task-file .codex-opencode/tasks/20260101-120000-task.md
```

With max rounds:

```bash
bash .codex-opencode/scripts/codex-opencode-autoloop.sh --task "..." --max-rounds 5
```

With an explicit test command:

```bash
bash .codex-opencode/scripts/codex-opencode-autoloop.sh --task "..." --test "npm test"
```

Dry run:

```bash
bash .codex-opencode/scripts/codex-opencode-autoloop.sh --task "..." --dry-run
```

OMA mode:

```bash
bash .codex-opencode/scripts/codex-opencode-autoloop.sh --task "..." --oma-mode auto
bash .codex-opencode/scripts/codex-opencode-autoloop.sh --task "..." --oma-mode forced_oma
bash .codex-opencode/scripts/codex-opencode-autoloop.sh --task "..." --oma-mode plain_opencode
bash .codex-opencode/scripts/codex-opencode-autoloop.sh --task "..." --oma-mode manual_agent
```

## Status

```bash
bash .codex-opencode/scripts/codex-opencode-status.sh
```

Realtime status file:

```bash
cat .codex-opencode/status/live.md
```

Final report:

```bash
cat .codex-opencode/reports/final-report.md
```

Compact run summary:

```bash
cat .codex-opencode/runs/<run>/summary.md
```

OMA model audit:

```bash
cat .codex-opencode/reports/oma-model-audit.md
```

## Reset

Reset status only:

```bash
bash .codex-opencode/scripts/codex-opencode-reset.sh
```

Reset logs too:

```bash
bash .codex-opencode/scripts/codex-opencode-reset.sh --logs
```

Delete run history only with explicit double confirmation:

```bash
bash .codex-opencode/scripts/codex-opencode-reset.sh --runs --confirm-runs-delete
```

## Common Errors

- `opencode not found`: OpenCode is not installed or not visible in the Codex App PATH.
- `opencode auth missing`: OpenCode is installed but cannot authenticate under this environment.
- `OpenCode data directory not writable`: Use normal user-level OpenCode configuration or update app permissions.
- `Codex sandbox denied`: Do not bypass. Adjust allowed workspace/app permissions.
- `OMA not detected`: OMA may not be installed, or may only load through OpenCode configuration.
- `OMA trigger test failed`: Check `.codex-opencode/status/oma-trigger-test.md`.
- `model list unavailable`: The tool will not invent model names.
- `test command failed`: Inspect `.codex-opencode/logs/test.log`.
- `max rounds reached`: Inspect the latest `repair-round-N.prompt.md`.
- `high risk change detected`: Inspect `.codex-opencode/logs/security.log` before continuing.

## Manual Continuation

Use the latest repair prompt in `.codex-opencode/runs/<run>/repair-round-N.prompt.md`, give it to OpenCode manually, then rerun autoloop or ask Codex to review the resulting diff.

## Safety

- Does not bypass permissions or approvals.
- Does not automatically modify OMA source configuration.
- Does not delete run history by default.
- Does not intentionally log secrets; logs are passed through basic redaction.
- Does not mark skipped tests as passed.
