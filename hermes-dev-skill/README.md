# hermes-dev-skill

A Hermes-invocable skill that turns a free-form dev idea in Feishu into
working code on a git branch, using Codex (for spec / plan / review) and
Claude Code (for implementation). Includes a 5-round bounded review
loop and checkpoint-based crash recovery.

## Install

```bash
cd ~/Documents/RichardHub/Git/hermes-dev-skill
pip install -e ".[dev]"
bash install.sh
```

`install.sh` (run separately after `pip install`):
- Creates `~/.hermes/hermes-dev/` and copies `config.example.yaml` →
  `config.yaml`
- Creates `~/.hermes/runs/`
- Symlinks `scripts/hermes-dev` into `~/.local/bin/hermes-dev`

## Use

From a Feishu chat with your Hermes bot, say something like:

> 帮我做一个股票价格预警功能，触发条件是价格跌破 5 日均线 5%

Hermes will:
1. Create a new job and reply with the job ID
2. Ask 1–3 clarifying questions per turn
3. Invoke Codex to write `spec.md` and `plan.md`, then self-check
4. Invoke Claude Code to implement on `hermes-dev/<job_id>` branch
5. Run up to 5 rounds of Codex review + Claude Code fix
6. Send a summary card with the diff and branch info

Reply `@bot 继续` to extend the review cap by 5 rounds if the first 5
don't pass.

## Architecture

Hybrid orchestrator:
- **Hermes (LLM)** drives: Feishu I/O, multi-turn clarification, the
  "is the spec complete" judgement, the handoff message
- **Bash + Python scripts** drive: `codex` and `claude` CLI invocations,
  `git` operations, `state.json` transitions, review-verdict parsing,
  retry logic

State lives at `~/.hermes/runs/<job_id>/` and is updated atomically.

## Tests

```bash
cd ~/Documents/RichardHub/Git/hermes-dev-skill
python -m pytest                  # unit + integration (no real Codex/Claude Code)
python -m pytest -m e2e           # e2e dry-run with canned responses
```

Manual smoke: see `tests/manual/smoke.sh`.

## Spec / design

See `design-specs/2026-06-14-hermes-dev-collab-skill-design.md` for the
full design rationale and `plans/2026-06-14-hermes-dev-collab-skill.md`
for the implementation plan.
