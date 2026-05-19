# Troubleshooting

## Codex App cannot access OpenCode data directories

Run preflight and inspect `.codex-opencode/status/preflight.md`. Do not change permissions broadly. Prefer launching Codex from an environment where the normal user can read OpenCode's own config and state directories.

## OpenCode works but OMA does not trigger

Inspect `.codex-opencode/status/oma-trigger-test.md`. If it cannot confirm OMA, the autoloop will follow `config.json`: use plain OpenCode when fallback is enabled, or stop in `forced_oma` mode.

## OMA config exists but model list is unavailable

Check `.codex-opencode/status/oma-preflight.md`. The tool does not invent model names. Add or expose a supported OMA/OpenCode model-list command, then rerun preflight.

## OpenCode Go cannot specify a model

Keep role selection prompt-based. Codex remains final reviewer, and model recommendations remain advisory.

## `opencode run` arguments are incompatible

Edit `opencode_run_args` in `.codex-opencode/config.json`. The autoloop first tries stdin, then prompt-as-argument.

## Codex sandbox rejects commands

Do not bypass the sandbox. Run only allowed commands, keep artifacts under `.codex-opencode/`, and adjust the Codex App workspace permissions through normal app settings if needed.

## Test command detection fails

Set `"test_command"` in `.codex-opencode/config.json` or pass `--test "your command"`.

## Git diff is empty but OpenCode claims it changed code

Check the run output under `.codex-opencode/runs/<run>/`. OpenCode may have written outside the workspace, failed to write, or only suggested changes.

## All OMA agents use one model

This may be acceptable for small tasks, but larger or higher-risk work benefits from separating coder and reviewer models when OpenCode Go exposes multiple reliable choices.

## Coder and reviewer use the same model

It is workable for low-risk tasks because Codex performs final review. For important changes, prefer a distinct reviewer model if available.

## Move or map OpenCode/OMA working directories

Use OpenCode/OMA documented configuration options. Do not symlink or rewrite private config automatically from this tool.

## Avoid token overuse

Limit max rounds, keep task scope narrow, use tester/reviewer agents only for tasks that need them, and preserve run evidence instead of replaying long logs.

## Avoid infinite loops

`max_rounds` is enforced. Security failures and hard OpenCode/OMA failures stop the loop.

## Manually take over one repair round

Open the latest `repair-round-N.prompt.md`, give it to OpenCode manually, then rerun autoloop or ask Codex to review the resulting diff.
