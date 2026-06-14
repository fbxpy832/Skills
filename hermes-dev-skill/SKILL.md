---
name: hermes-dev-skill
description: |
  End-to-end dev collaboration skill. Drives the loop from a free-form dev
  idea in Feishu to working code on a git branch, using Codex for spec /
  plan / review and Claude Code for implementation. Includes a 5-round
  bounded review loop and checkpoint-based crash recovery.
---

# Hermes Dev-Collab Skill

You are Hermes, with this skill loaded. When the user sends a dev intent
in Feishu ("build me X", "在 stocks 加一个价格预警", etc.), you orchestrate
the following phases. Each phase has a state machine entry point; you
drive the LLM-judgment parts and call out to scripts for the mechanical
parts.

## Phase 0: bootstrap (per `hermes-dev new`)

When you detect a dev intent, run:

```bash
hermes-dev new "<user's intent, verbatim>"
```

The CLI prints a `job_id` to stdout. Capture it; all subsequent commands
take that `job_id` as their first argument.

Send a Feishu card to the user:

> Job #<short-id> 启动，需求澄清中。

## Phase 1: requirements clarification (you drive this)

The phase script `scripts/phases/01_clarify.sh` is a no-op marker. You
handle the multi-turn dialogue yourself, asking 1–3 questions per turn
and updating `requirements.md` (in `~/.hermes/runs/<job_id>/`) after
every turn. Completeness checklist:

- [ ] functional_scope
- [ ] behaviour
- [ ] edge_cases
- [ ] non_functional
- [ ] acceptance_criteria

When all are checked AND the user has confirmed the project path (see
below), write the final `requirements.md`, then run:

```bash
python -m scripts.lib.state atomic_update $HOME/.hermes/runs/$JOB_ID/state.json \
  '{"phase": "spec_plan"}'
python -m scripts.lib.feishu send_text "需求已确认，进入规划"
bash scripts/phases/02_spec_plan.sh $JOB_ID
```

### Project path resolution

Ask the user once, near the end of the dialogue:

> 请告诉我项目路径，或从已注册项目里选：[<names from ~/.hermes/projects.json>]。
> 如果没有想好路径，可以发 `look` 让我扫一下 `~/projects/ ~/code/ ~/Documents/`。

Then run the appropriate script:

```bash
# If user gave a name
python -m scripts.lib.project_registry register "$NAME" "$PATH"   # first time only
PROJECT=$(python -m scripts.lib.project_registry lookup "$NAME" | python -c "import sys,json; print(json.load(sys.stdin)['path'])")
# Or scan if user said "look"
python -m scripts.lib.project_registry scan_common_dirs
# Then save
python -m scripts.lib.state atomic_update $HOME/.hermes/runs/$JOB_ID/state.json "
{
  'project': {
    'name': '$NAME',
    'path': '$PROJECT',
    'base_branch': 'main',
    'is_git': true
  }
}
"
```

## Phase 2: spec & plan generation (script-driven)

`scripts/phases/02_spec_plan.sh` invokes Codex twice (spec/plan, then
self-check). It writes `spec.md`, `plan.md`, and `self-check.md` in the
runs dir. On `VERDICT: PASS`, it transitions state to `phase=implement`
and posts a Feishu card. On failure it halts and surfaces the issue.

You do not need to drive this phase — just call the script and wait for
the next user message (which will be a Feishu push, not a user reply).

## Phase 3: implementation (script-driven, Claude Code under the hood)

`scripts/phases/03_implement.sh` invokes Claude Code with the work
contract + spec + plan. Claude Code writes code on `hermes-dev/<job_id>`
branch and commits. You do not drive this phase either.

If Claude Code writes questions to `claude-questions.txt`, surface them
to the user via Feishu and set `status=awaiting_user`.

## Phase 4: review loop (script-driven)

`scripts/phases/04_review.sh` runs up to 5 rounds of Codex review +
Claude Code fix. On APPROVED, transitions to handoff. On cap, halts and
escalates to the user.

## Phase 5: handoff (script-driven)

`scripts/phases/05_handoff.sh` sends the summary card. After the user
acks ("ok" / "done") or after 24h, mark the job `status=done`.

## Message handlers (you parse Feishu messages)

| User says | You do |
|---|---|
| "在 <repo> 加一个功能..." | Phase 0 (new) → Phase 1 |
| "@bot 继续" | `bash scripts/handlers/on_continue.sh <job_id>` |
| "@bot 状态" | `hermes-dev status <job_id>` |
| "@bot 取消" | `hermes-dev cancel <job_id>` |
| "ok" / "done" (after handoff) | `hermes-dev continue <job_id>` (no-op) → state `done` |
| "merge" (after handoff) | Tell user the merge is theirs to do (out of scope) |

## Error escalation

If any phase script exits non-zero, read the `state.json.errors` array
and the most recent `events.jsonl` line, then send a Feishu card
explaining the failure and asking the user how to proceed.

## State introspection

```bash
hermes-dev status $JOB_ID       # pretty print key state fields
hermes-dev tail $JOB_ID         # stream events.jsonl
hermes-dev list                 # all jobs
```
