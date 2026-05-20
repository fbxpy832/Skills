# OpenCodeAutoLoop v2

Local automated development orchestrator.

```
OpenCode (main dev) → Orchestrator (flow control) → Codex (diff review only)
```

## Quick Start

```bash
# Show current status
python opencode-autoloop/autoloop.py --status

# Run a full auto-loop
python opencode-autoloop/autoloop.py --task "Your development requirement"

# Resume from last incomplete run
python opencode-autoloop/autoloop.py --resume

# Smoke test
python opencode-autoloop/test_smoke.py
```

## Configuration

Edit `opencode-autoloop/.autoloop/config.json` (auto-created on first run).

### Codex Review Model & Reasoning

Control which model Codex uses for review and reasoning effort via `codex_flags`:

```json
{
  "codex_flags": [
    "--dangerously-bypass-approvals-and-sandbox",
    "--model", "gpt-5-high",
    "--config", "model_reasoning_effort=high"
  ]
}
```

| Flag | Purpose |
|---|---|
| `--model <name>` | Override the default Codex model (e.g. `gpt-5-high`, `claude-sonnet-4-5`) |
| `--config model_reasoning_effort=<level>` | Set reasoning effort: `low`, `medium`, `high` |
| `--oss` | Use open-source provider (Ollama, LM Studio) |
| `--local-provider <name>` | Specify local provider: `ollama` or `lmstudio` |
| `--profile <name>` | Use a named config profile from `~/.codex/config.toml` |

**Recommended for review quality:**
```json
{
  "codex_flags": [
    "--dangerously-bypass-approvals-and-sandbox",
    "--config", "model_reasoning_effort=high"
  ]
}
```

### OpenCode Flags

```json
{
  "opencode_flags": [
    "--dangerously-skip-permissions",
    "--model", "deepseek-v4-pro"
  ]
}
```

| Flag | Purpose |
|---|---|
| `--model <provider/model>` | Override model (e.g. `deepseek-v4-pro`, `kimi-k2.6`) |
| `--variant <level>` | Reasoning effort: `high`, `max`, `minimal` |
| `--agent <name>` | Use a named agent from OpenCode config |

### Test / Lint / Build Commands

```json
{
  "test_commands": ["npm run test", "npm run typecheck"],
  "lint_commands": ["npm run lint"],
  "build_commands": ["npm run build"]
}
```

Auto-detected from `package.json`, `pyproject.toml`, `Makefile` on first run.

## CLI Reference

```
python opencode-autoloop/autoloop.py [OPTIONS]

  --task TEXT             Development requirement
  --task-file PATH        File containing the requirement
  --resume                Resume from last incomplete run
  --status                Show current state and exit
  --review-only           Only generate review packet and run Codex review
  --fix-only              Only fix Must Fix items from last Codex review
  --project-root PATH     Target project directory (default: cwd)
  --max-rounds N          Override max review rounds (1-3, default: 2)
  --opencode-timeout N    Override opencode timeout in seconds
  --codex-timeout N       Override codex timeout in seconds
  --config PATH           Path to config file
  --allow-dirty           Proceed even if git working tree is dirty
  --dry-run               Show configuration and exit
  --quiet, -q             Reduce output
  --no-color              Disable colored output
```

## Phases

```
planning   → OpenCode generates SPEC.md + TASKS.md
developing → OpenCode executes development tasks
testing    → Orchestrator runs lint/test/build commands
reviewing  → Codex review of REVIEW_PACKET.md (diff-only)
fixing     → OpenCode fixes Must Fix items from review
           → loop: test → review → fix (up to max-review-rounds)
completed  → PASS after review
blocked    → Manual intervention required
```

## Artifacts

All output goes to the project root (cwd or `--project-root`):

```
.autoloop/
  config.json          # Configuration (tracked in git)
  state.json           # Runtime state (gitignored)
  last_review.md       # Last Codex review output
  last_prompt.md        # Last OpenCode prompt

docs/
  SPEC.md, TASKS.md, CHANGELOG_AUTOLOOP.md
  TEST_RESULT.md, REVIEW_PACKET.md, FINAL_REPORT.md

logs/
  YYYYMMDD-HHMMSS/
    opencode-plan.log, opencode-dev.log, opencode-fix.log
    test-round-N.log, codex-review-round-N.log
    state.json (snapshot)
```

## Smoke Test

```bash
python opencode-autoloop/test_smoke.py
python opencode-autoloop/test_smoke.py --project-root /path/to/project
```

Verifies:
- `get_dirty_files()` / `get_changed_files()` / `get_untracked_files()` return project_root-relative paths
- `_rel_path()` normalizes repo-root-relative paths correctly
- `is_working_tree_clean_except_tool()` works

## Troubleshooting

| Problem | Check |
|---|---|
| `opencode not found` | Install OpenCode CLI: `brew install anomalyco/tap/opencode` |
| `codex not found` | Install Codex CLI: `brew install codex` |
| `Working tree is not clean` | Commit/stash changes or use `--allow-dirty` |
| `Max rounds reached` | Review FINAL_REPORT.md; increase `--max-rounds 3` |
| `Codex review timed out` | Check network; increase `--codex-timeout` |
| `Spec/plan not generated` | Check `opencode-plan.log` in logs directory |
