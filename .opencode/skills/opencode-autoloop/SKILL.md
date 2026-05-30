---
name: opencode-autoloop
description: Use when the user wants to run a local automated development loop (plan, develop, test, review, fix). Triggers include "start autoloop", "run the autoloop", "auto develop with review", "autoloop this task". This is a local orchestrator that uses OpenCode for planning/development/fixing and Codex only for diff review. Use ONLY when the user explicitly requests automated loop development.
---

# OpenCodeAutoLoop v2

Local automated development orchestrator. OpenCode is the main developer; a
local Python script handles flow control; Codex only does diff review.

## What OpenCode Should Do

When the user triggers autoloop for a task, OpenCode should:

1. Read the project (`opencode-autoloop/autoloop.py`, `opencode-autoloop/.autoloop/config.json`) to understand the current configuration.
2. Invoke the orchestrator:
   ```bash
   python opencode-autoloop/autoloop.py --task "user's requirement"
   ```
3. The orchestrator will then call OpenCode back at each phase (planning, development, fixing) with structured prompts. OpenCode's role in each phase:
   - **Planning**: Read project structure, generate `docs/SPEC.md` and `docs/TASKS.md`. Do NOT modify business code.
   - **Development**: Execute tasks per `docs/SPEC.md` and `docs/TASKS.md`. Update `docs/CHANGELOG_AUTOLOOP.md`.
   - **Fixing**: Fix only Must Fix items from the Codex review. Do NOT expand scope.
4. OpenCode must NOT call Codex during its phases. The orchestrator handles Codex review separately.

## Available Commands

```bash
# Start a new task
python opencode-autoloop/autoloop.py --task "requirement"

# Resume from last incomplete run
python opencode-autoloop/autoloop.py --resume

# Show current status
python opencode-autoloop/autoloop.py --status

# Override config
python opencode-autoloop/autoloop.py --task "..." --max-rounds 3 --allow-dirty

# Dry run (verify config without executing)
python opencode-autoloop/autoloop.py --task "..." --dry-run

# Run smoke tests
python opencode-autoloop/test_smoke.py
```

## Key Files

- `opencode-autoloop/autoloop.py` — Main orchestrator script
- `opencode-autoloop/.autoloop/config.json` — Runtime configuration
- `opencode-autoloop/.autoloop/state.json` — Current run state
- `opencode-autoloop/README.md` — Full documentation
- `opencode-autoloop/test_smoke.py` — Git path function smoke test
- `.autoloop/config.json` — Project-level config (at project root)
- `docs/SPEC.md`, `docs/TASKS.md` — Generated planning docs (at project root)
- `docs/REVIEW_PACKET.md` — Review packet sent to Codex
- `docs/FINAL_REPORT.md` — Final delivery report

## Phases

```
init → planning → developing → testing → review_packet → codex_review → [fix → test → review] → final_report
```

The loop (test → review → fix) repeats up to 2-3 rounds. Blocked on repeated
timeouts/failures or Codex BLOCKED verdict.

## Safety

- OpenCode is the main developer. Do not delegate coding to Codex.
- The orchestrator handles all Codex calls for review only.
- All output goes to the project root's `docs/` and `logs/` directories.
- `state.json` supports resume via `--resume`.
- Maximum 2-3 review rounds; no infinite loops.
