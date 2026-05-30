# Plan Round 1

Task:
# Task: Improve deep-research-skill as a multi-host enterprise Deep Research protocol

## Delegation rule

Codex is only dispatcher/reviewer. All implementation changes to `deep-research-skill/` must be performed by OpenCode/OMA. Keep changes scoped to `deep-research-skill/`.

## Goal

Upgrade `deep-research-skill` from a useful skill package into a more scalable, multi-host Deep Research protocol layer inspired by mainstream systems such as LangChain Open Deep Research and GPT Researcher, while preserving the current enterprise source-audit/reporting strengths.

## Required implementation

1. Add a host adapter contract:
   - Create `deep-research-skill/references/host-adapter-contract.md`.
   - Define how Codex, OpenCode, Claude Code, CloudCode, GUI, TU/terminal runners, and other hosts should read `config.env`, call `model-router.sh MODE AGENT`, invoke agents, record requested/detected model, record search status, and produce evidence.
   - Define required artifacts: `run-summary.md`, `execution-context.md`, `source_failure_log.md`, `events.ndjson`.
   - Define standard statuses, error codes, and fallback behavior.

2. Add progress events support:
   - Update `opencode-research-runner.sh` to write `events.ndjson`.
   - Each event should be compact JSONL with at least: timestamp, run_id or output_dir, phase, agent, status, requested_model, detected_model_status, message, error.
   - Emit events for run_started, agent_started, agent_completed, agent_failed, stage_started, stage_completed, run_completed.
   - Do not log API keys or secrets.

3. Add a generic host-neutral runner:
   - Create `deep-research-skill/scripts/generic-research-runner.sh`.
   - It should not call OpenCode directly.
   - It should read setup config, generate prompts/outputs/logs using the same agent/stage structure, support `--dry-run`, `--parallel|--sequential`, and write `run-summary.md`, `execution-context.md`, `source_failure_log.md`, `events.ndjson`.
   - It should be suitable for Codex, CloudCode, GUI, TU/terminal, or external orchestrators to use as a prompt/artifact generator.

4. Add search adapter contract:
   - Create `deep-research-skill/references/search-adapter-contract.md`.
   - Document backend contract for `scripts/search.sh` and external/MCP/native host search tools.
   - Include health check expectations, required output fields, fallback order, and failure logging.

5. Add lightweight eval harness:
   - Create `deep-research-skill/eval/`.
   - Include a small set of example task YAML/JSON files covering: business_decision, government_report, technical_route, investment_analysis, general_research.
   - Add `eval/rubric.yaml` and `eval/run-eval.sh`.
   - `run-eval.sh` may be dry-run oriented; it should validate that runner artifacts exist and contain model/source/search/audit fields.

6. Update documentation:
   - Update `SKILL.md` progressive loading and Host Integration sections to point to the new contracts and generic runner.
   - Update `references/opencode-runner.md` to clarify OpenCode is only one adapter.
   - Update output/completion summary docs if needed to mention `events.ndjson`.

## Constraints

- Do not edit files outside `deep-research-skill/` except `.codex-opencode/` runtime artifacts.
- Do not modify secrets, `.env`, SSH keys, cookies, or private host configs.
- Do not make OpenCode mandatory for generic runner.
- Preserve existing setup behavior: provider/model selection, search API key prompts, output directory selection, host-agnostic config.
- Keep shell scripts compatible with macOS Bash 3.2; avoid `mapfile` and associative arrays.
- Avoid hardcoded user paths.

## Verification required

Run and report:

- `/bin/bash -n deep-research-skill/scripts/*.sh`
- `git diff --check -- deep-research-skill`
- `deep-research-skill/scripts/generic-research-runner.sh high_quality <temp-task> <temp-output> <repo-root> --dry-run --sequential`
- `deep-research-skill/scripts/opencode-research-runner.sh high_quality <temp-task> <temp-output> <repo-root> --dry-run --sequential`
- Verify both runners write `run-summary.md`, `execution-context.md`, `source_failure_log.md`, `events.ndjson`.
- `deep-research-skill/eval/run-eval.sh --dry-run` or equivalent.

## Compact summary required

OpenCode/OMA final summary must include:

- files_changed
- tests_run
- errors
- next_action
- risk_level

Mode:
auto

Guidance:
- Keep changes minimal and inside project scope.
- Do not modify secrets, tokens, cookies, .env files, SSH keys, certificates, or system configuration.
- Do not install dependencies unless explicitly allowed by .codex-opencode/config.json.
- Do not claim tests passed unless they actually ran.
