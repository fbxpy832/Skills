# Hermes Dev-Collab Skill — Design Spec

**Date**: 2026-06-14
**Status**: Draft (awaiting user review)
**Author**: Brainstorming session with user
**Target location**: `~/Documents/RichardHub/Git/hermes-dev-skill/`

---

## 1. Background & Goals

The user operates a Hermes agent that is already bound to a Feishu (飞书) bot, with a 1:1 DM as the primary interaction surface. They want a Skill, invokable from Hermes, that automates the full "idea → code in a repo" loop without forcing them to babysit Codex or Claude Code sessions.

The loop has four user-facing phases and one internal phase:

1. **Requirements Clarification** — Hermes drives a multi-turn dialogue until the user confirms the spec is complete.
2. **Spec & Plan Generation** — Codex (GPT-5.5) produces `spec.md` + `plan.md` and self-checks them.
3. **Implementation** — Claude Code (Opus 4.8) writes code on a dedicated git branch inside the target repo.
4. **Review Loop** — Codex reviews the diff; Claude Code fixes; repeat until APPROVED or cap.
5. **Handoff** — Hermes summarises result, branch info, and merge instructions back to the user.

### Hard requirements (from the user)

- **End-to-end automation**: from a free-form dev idea to working code on a branch, with no manual hand-off between phases.
- **State transparency**: every phase's inputs/outputs are persisted; job state is observable.
- **Crash & interruption recovery**: if Hermes dies mid-job, the job can be resumed from a checkpoint.
- **Feishu progress push**: each phase's start, key result, and final outcome is pushed to the user's DM through `hermes send`.
- **Review bounded**: 5 rounds hard cap, `VERDICT: APPROVED` soft cap, user can extend via `@bot 继续`.

### Non-goals (explicit)

- **Not a CI/CD pipeline**: the skill does not push to remote, does not open PRs, does not trigger CI.
- **Not a multi-user system**: the Feishu bot is single-user; no ACL, no per-user job isolation.
- **Not a replacement for the user's editor**: code review comments go to the user, not to a hosted UI.
- **Not a generic agent framework**: it is opinionated about Codex for spec/review and Claude Code for implementation; no plugin system for alternate agents in v1.

---

## 2. Architecture

### 2.1 Orchestration model: Hybrid

The skill is driven by **two complementary actors** in the same Hermes process:

- **Hermes (LLM judgment)** drives: Feishu message I/O, the multi-turn clarification dialogue, the "is this spec complete" call, the final handoff message, and any user clarification during the implementation phase.
- **Bash + Python (deterministic logic)** drive: `codex` and `claude` CLI invocations, `git` operations, `state.json` transitions, review verdict parsing, retry/backoff, checkpoint save/restore, and the `reconcile` scan for orphaned jobs.

The split principle: anything that is **fuzzy / semantic** goes to Hermes; anything that is **mechanical / parseable** goes to a script. This keeps the LLM prompt small (only the judgement it actually has to make) and keeps the deterministic parts unit-testable.

### 2.2 Claude Code integration: CLI headless (not GUI)

The user explicitly requested a comparison of two integration modes for Claude Code:

| Dimension | CLI (`claude -p` headless) | Desktop App (GUI) |
|---|---|---|
| Automation | Full unattended; runs inside Bash | Requires foreground window, clicks, clipboard sync |
| Context transfer | Prompt piped via stdin / `-p`; full context in one shot | Must "copy → paste" into the GUI; GUI has no view of `job_id` |
| Skill integration | Subprocess of the Skill; trivially composable with `codex` | Requires AppleScript / Accessibility API; out-of-process state |
| Recovery | Restart the subprocess; resume from checkpoint | GUI state loss is hard to recover |
| Output parseability | `--output-format json` returns structured result | Free-form chat history; not machine-parseable |

**Decision: CLI headless.** It wins on all three of the dimensions the user named (automation, context transfer, integration complexity), plus error recovery and output structure as free bonuses. GUI integration is rejected for v1; it would only be justified by a feature exclusive to the desktop app that the skill actually needs (none identified).

### 2.3 Job model: async background job inside the Hermes process

A "job" is the unit of work from "user said `build me X`" to "user acks the handoff". Each job:

- Has a unique `job_id` (format `YYYYMMDD-HHMM-<6char>`; collision fallback uses microsecond suffix).
- Lives in its own directory `~/.hermes/runs/<job_id>/` (Section 4).
- Has its own `state.json` updated atomically on every transition.
- Pushes events to the user's Feishu DM as it progresses.

Jobs are **asynchronous from the Feishu conversation's perspective**: when the user says "build me X", Hermes replies once ("Job #abc started, I'll keep you posted"), then continues the job in the background while the user is free to send other messages or go offline. The user can later say "show me the spec" or "where's my job" to query state.

---

## 3. Directory layout

The skill lives at `~/Documents/RichardHub/Git/hermes-dev-skill/`. Layout:

```
hermes-dev-skill/
├── SKILL.md                              # Read by Hermes on first invocation
├── README.md                             # Human-facing overview
├── config.example.yaml                   # Template for ~/.hermes/hermes-dev/config.yaml
├── scripts/
│   ├── hermes-dev                        # Main CLI entry point (Python)
│   ├── phases/
│   │   ├── 01_clarify.sh                 # Bootstraps Phase 1; mostly a marker
│   │   ├── 02_spec_plan.sh               # Phase 2: invoke Codex for spec/plan
│   │   ├── 03_implement.sh               # Phase 3: invoke Claude Code
│   │   ├── 03_implement_iter.sh          # Phase 3 follow-up rounds (post-review fixes)
│   │   ├── 04_review.sh                  # Phase 4: review loop driver
│   │   ├── 04_review_one.sh              # Single review-round driver
│   │   └── 05_handoff.sh                 # Phase 5: generate handoff message
│   ├── lib/
│   │   ├── state.py                      # Atomic state.json read/write
│   │   ├── feishu.py                     # hermes send wrapper (text + card)
│   │   ├── review_parser.py              # Verdict + P0/P1 extraction
│   │   ├── git_ops.py                    # Branch / commit / diff helpers
│   │   ├── checkpoint.py                 # Per-phase checkpoint save/restore
│   │   ├── reconcile.py                  # Scan for orphaned jobs
│   │   └── project_registry.py           # Read/write ~/.hermes/projects.json
│   ├── handlers/
│   │   └── on_continue.sh                # Invoked when user says "@bot 继续"
│   ├── claude_contract.md                # Strict work contract for Claude Code
│   └── codex_prompts/
│       ├── spec_plan.md                  # Prompt template: spec + plan
│       ├── self_check.md                 # Prompt template: spec/plan self-audit
│       └── review.md                     # Prompt template: code review
├── references/
│   ├── state-schema.md                   # Full state.json reference
│   ├── feishu-message-format.md          # Card / text templates
│   └── troubleshooting.md                # Common errors + fixes
├── tests/
│   ├── test_state.py
│   ├── test_review_parser.py
│   ├── test_checkpoint.py
│   ├── test_project_registry.py
│   ├── fixtures/
│   │   ├── sample-review-approved.md
│   │   ├── sample-review-rejected-p0.md
│   │   ├── sample-review-rejected-p1.md
│   │   └── sample-state.json
│   ├── e2e/
│   │   └── sandbox-project/              # 50-line throwaway git repo for e2e
│   └── manual/
│       └── smoke.sh                      # End-to-end smoke against a real project
└── docs/superpowers/
    ├── specs/2026-06-14-hermes-dev-collab-skill-design.md   # This file
    └── plans/                            # Implementation plan (written by writing-plans)
```

`hermes-dev` is a single Python CLI with subcommands:

```bash
hermes-dev new            <intent>         # Create a new job; prints job_id
hermes-dev status         [job_id]         # Show state.json summary
hermes-dev continue       <job_id>         # Resume from last checkpoint
hermes-dev cancel         <job_id>         # Mark halted, archive runs dir
hermes-dev reconcile      [--age 5m]       # Scan for orphaned jobs
hermes-dev tail           <job_id>         # Stream events.jsonl
hermes-dev register       <name> <path>    # Add to projects.json
hermes-dev unregister     <name>
hermes-dev list                          # List known jobs / projects
```

---

## 4. State machine

### 4.1 `state.json` schema

```json
{
  "job_id": "20260614-1030-a1b2c3",
  "version": "1.0",
  "created_at": "2026-06-14T10:30:00Z",
  "updated_at": "2026-06-14T10:35:22Z",
  "status": "running",
  "phase": "review",
  "phase_round": 2,
  "project": {
    "name": "stocks",
    "path": "/Users/xpy/projects/stocks",
    "branch": "hermes-dev/20260614-1030-a1b2c3",
    "base_branch": "main",
    "is_git": true
  },
  "artifacts": {
    "requirements": "requirements.md",
    "spec": "spec.md",
    "plan": "plan.md",
    "self_check": "self-check.md",
    "review_rounds": [
      "review-rounds/round-1.md",
      "review-rounds/round-2.md"
    ]
  },
  "checkpoints": {
    "phase1": "checkpoints/phase1.json",
    "phase2": "checkpoints/phase2.json"
  },
  "feishu_message_ids": ["om_abc123", "om_def456"],
  "events_log": "events.jsonl",
  "errors": [],
  "user_overrides": {
    "codex_model": null,
    "max_review_rounds": 5,
    "extra_review_rounds_added": 0
  }
}
```

Field notes:
- `status` and `phase` are orthogonal (Section 4.2).
- `artifacts.*` are paths **relative to the runs dir** for portability.
- `feishu_message_ids` allows later updates to edit prior messages (cards support edits).
- `errors` is an array of `{at, phase, kind, message, traceback?}` — capped at 50 entries.

### 4.2 Status vs phase

`phase` answers "where in the workflow is this job?"; `status` answers "is anything actually happening right now?".

| `phase` | Description |
|---|---|
| `bootstrap` | Creating runs dir, generating job_id, first Feishu message |
| `clarify` | Multi-turn requirements dialogue |
| `spec_plan` | Codex generating spec.md, plan.md, self-check.md |
| `implement` | Claude Code writing code on the branch |
| `review` | Codex reviewing + Claude Code fixing |
| `handoff` | Summary message sent; awaiting user ack |
| `done` | User acked (or 24h timeout) |
| `halted` | Unrecoverable; needs human intervention |

| `status` | Description |
|---|---|
| `running` | Active work happening (script or Hermes LLM) |
| `awaiting_user` | Hermes asked the user a question; paused until reply |
| `awaiting_tool` | Waiting on Codex or Claude Code subprocess |
| `halted` | Hard error or cap reached; see `errors[]` |
| `orphaned` | Hermes process died mid-job; reconcile can resume |
| `done` | Terminal success state |

### 4.3 Phase transitions

```
[0] bootstrap
    └─→ [1] clarify
         ├─→ [1] clarify    (more user questions)
         └─→ [2] spec_plan
              ├─→ [2] spec_plan    (self-check failed, retry)
              └─→ [3] implement
                   └─→ [4] review
                        ├─→ [4] review    (round+1, not yet APPROVED)
                        ├─→ [4] review    (user said "继续", round+5)
                        └─→ [5] handoff → done
                                     ↘ halted    (5 rounds exceeded)
```

### 4.4 Checkpointing

At the **end of each phase**, `lib/checkpoint.py` writes `checkpoints/phase<N>.json` containing:

- The full `state.json` snapshot
- The hash of every artifact file produced by the phase (`requirements.md`, `spec.md`, etc.)

Checkpoint is **not** taken during the implement/review loop rounds (it would be too frequent). A single per-phase checkpoint is enough for resume; intra-phase recovery is best-effort (the script can re-run from the start of the current phase).

### 4.5 Crash recovery

Three resume paths exist; the spec is explicit about which one applies when:

| Trigger | Path | When |
|---|---|---|
| User sends `@bot 继续` (or taps card `action=continue`) | `scripts/handlers/on_continue.sh <job_id>` (Section 8.4) | Job is `halted` because the 5-round review cap was hit |
| Hermes host cron/launchd detects a dead job | `hermes-dev reconcile --age 5m --auto-resume` | `status=running\|awaiting_tool` with no live PID and `updated_at` older than threshold |
| User (or operator) explicitly resumes | `hermes-dev continue <job_id>` | Manual intervention; user can run this from terminal |

All three eventually call into the same orchestrator entry point: `state.json.phase` determines which phase's `phases/0X_*.sh` to invoke, and the phase's own script handles intra-phase re-runs (e.g., re-invoking Codex with its prior input).

`hermes-dev continue <job_id>` flow:

1. Load `state.json`. If `status == done`, refuse.
2. If `status == orphaned` (set by `reconcile`), jump to last successful checkpoint.
3. If `status == halted`, require explicit `--force` to attempt resume.
4. Re-enter the orchestrator at `phase` = last checkpoint's phase + 1 (or resume the current phase from its beginning).

The `reconcile` command is invoked by a launchd/cron job in the Hermes host (not part of this skill's install). It runs `hermes-dev reconcile --age 5m --auto-resume` periodically.

---

## 5. Phase 1 — Requirements Clarification

### 5.1 Trigger

User messages Hermes in the Feishu DM with a dev intent. Hermes detects the intent (e.g., contains verbs like "build / 做一个 / 加一个 / implement" or matches a configured keyword set) and loads this skill.

### 5.2 Flow

1. `hermes-dev new "<user intent>"` runs:
   - Generates `job_id`.
   - Creates `~/.hermes/runs/<job_id>/`.
   - Writes initial `state.json` (phase=clarify, status=running).
   - Sends Feishu card: "Job #<id> 启动，需求澄清中".
2. Hermes enters clarification loop. Each round:
   - Hermes asks 1–3 questions per turn, prioritised by impact (functional scope → behaviour → edge cases → acceptance criteria).
   - User replies in the same DM thread.
   - Hermes updates `requirements.md` in the runs dir after every turn.
3. Termination: when Hermes's checklist reports all of:
   - [ ] Functional scope: what features, in/out of scope
   - [ ] User-facing behaviour: key flows described step by step
   - [ ] Edge cases: error paths, empty states, auth/authz
   - [ ] Non-functional: performance, compatibility, deployment context
   - [ ] Acceptance criteria: how the user will judge "done"
   - [ ] Project context: which repo to work in (Section 5.3)
4. Hermes posts: "需求已确认，进入规划" and transitions to Phase 2.

### 5.3 Project resolution

The user wants the project context asked interactively rather than pre-registered. Flow:

1. After functional/edge case questions but before final confirmation, Hermes asks:
   > "请告诉我项目路径，或从已注册项目里选：[<names from projects.json>]。如果你没有想好路径，可以发一个 `look` 让我扫一下 `~/projects/ ~/code/ ~/Documents/`。"
2. User can:
   - Send an absolute path → resolved and stored.
   - Send a project name → looked up in `~/.hermes/projects.json`.
   - Send `look` → Hermes runs `lib/project_registry.scan()` and presents found repos.
   - Send `new <path>` → creates a new project entry.
3. Resolved path is written to `state.json.project.path` and `.hermes-dev.yaml` is initialised in the project root (if missing) with default test/lint commands guessed from the project type.

---

## 6. Phase 2 — Spec & Plan Generation

### 6.1 Invocation

```bash
# Construct prompt
PROMPT="$(cat scripts/codex_prompts/spec_plan.md)

=== REQUIREMENTS ===
$(cat runs/$JOB_ID/requirements.md)

=== PROJECT CONTEXT ===
- Path: $PROJECT_PATH
- Default branch: $BASE_BRANCH
- Detected stack: $DETECTED_STACK    # e.g. 'node + typescript' or 'python + fastapi'
- Existing .hermes-dev.yaml: $(test -f $PROJECT_PATH/.hermes-dev.yaml && echo yes || echo no)

=== OUTPUT INSTRUCTIONS ===
Write two files into the runs directory:
- $RUNS_DIR/spec.md
- $RUNS_DIR/plan.md

Both files must follow the schema in codex_prompts/spec_plan.md."

# Run Codex
codex --model "${CODEX_MODEL:-gpt-5.5}" \
      --sandbox danger-full-access \
      -p "$PROMPT" \
      --output-format json \
      > "$RUNS_DIR/codex-spec-plan.raw.json"
```

The `--sandbox danger-full-access` is required because Codex must write into the runs dir, which lives outside the project.

### 6.2 Codex output expectations

The prompt instructs Codex to emit both files in the runs dir, and the script then:

- Reads `spec.md` / `plan.md` from the runs dir (not from the JSON wrapper).
- Validates that both files are non-empty and contain required sections:
  - `spec.md` must include `# Specification`, `## Goals`, `## Non-goals`, `## Behaviour`, `## Edge cases`, `## Acceptance criteria`.
  - `plan.md` must include `# Plan`, `## Phases` (ordered list), `## Files to create/modify`, `## Test strategy`.

### 6.3 Self-check

A second Codex call audits the spec/plan for internal consistency and gaps:

```bash
PROMPT="$(cat scripts/codex_prompts/self_check.md)

=== SPEC ===
$(cat spec.md)

=== PLAN ===
$(cat plan.md)"
codex --model "$CODEX_MODEL" --sandbox danger-full-access -p "$PROMPT" \
      --output-format json > self-check.raw.json
```

Output expectations: a markdown file with sections `## Issues found` and `## Verdict` (either `VERDICT: PASS` or `VERDICT: FAIL` with N issues).

If `FAIL`, the phase retries (max 2 retries) with the self-check issues appended to the spec_plan prompt. After 2 retries with persistent `FAIL`, escalate to user via Feishu with a "self-check keeps failing, please review spec/plan" message and a halt.

### 6.4 Transition

On `PASS`, send Feishu: "Spec/Plan 已生成并自审通过，进入开发" with a card linking to `spec.md` and `plan.md`. Move to Phase 3.

---

## 7. Phase 3 — Implementation

### 7.1 Pre-flight

```python
# In scripts/phases/03_implement.sh
# 1. Confirm project is a git repo
if ! is_git_repo "$PROJECT_PATH"; then
    log "Project is not a git repo; will use directory-tree review (Section 9.2)"
    state_set project.is_git false
else
    # 2. Create branch if not exists
    BRANCH="hermes-dev/$JOB_ID"
    git -C "$PROJECT_PATH" checkout "$BASE_BRANCH"
    git -C "$PROJECT_PATH" checkout -b "$BRANCH" 2>/dev/null || \
        git -C "$PROJECT_PATH" checkout "$BRANCH"
    state_set project.branch "$BRANCH"
fi
```

### 7.2 Claude Code invocation

```bash
PROMPT="$(cat scripts/claude_contract.md)

=== JOB CONTEXT ===
- Job ID: $JOB_ID
- Project: $PROJECT_PATH
- Branch: $(state_get project.branch)
- Run dir: $RUNS_DIR

=== SPEC ===
$(cat $RUNS_DIR/spec.md)

=== PLAN ===
$(cat $RUNS_DIR/plan.md)

=== LAST REVIEW FEEDBACK ===
$(cat $RUNS_DIR/review-rounds/round-$((ROUND-1)).md 2>/dev/null || echo 'NONE — first implementation round')"

claude --model claude-opus-4-8 \
       --cwd "$PROJECT_PATH" \
       -p "$PROMPT" \
       --output-format json \
       > "$RUNS_DIR/claude-impl-round-$ROUND.json"
```

The `--cwd` flag is critical: it makes Claude Code operate inside the project repo with the right git branch already checked out.

### 7.3 Claude Code work contract (`scripts/claude_contract.md`)

```markdown
# Claude Code Work Contract — hermes-dev

You are Claude Code, invoked by the hermes-dev skill to implement a specification.

## ABSOLUTE RULES (do not violate under any circumstance)

1. **Stay on the assigned branch.** The branch `hermes-dev/<job_id>` is already checked out. Do not run `git checkout` to any other branch, including `main` or `master`.
2. **Never push.** Do not run `git push`, regardless of remote configuration.
3. **Never modify state outside the project.** Do not touch:
   - `~/.hermes/` (the runs dir, hermes config)
   - `runs/<job_id>/` (your supervisor's data)
   - Any file outside `$PROJECT_PATH` (the project working tree)
4. **Commit incrementally.** After each logically complete change, commit with message format:
   `hermes-dev(<job_id>): <imperative summary, ≤72 chars>`
   Then add a blank line and a paragraph explaining the change.
5. **If the spec is silent on a behaviour, STOP and ask.** Do not invent. Do not extend scope.
   - When you stop, write the question to `$RUNS_DIR/claude-questions.txt` and exit.
   - The orchestrator will surface the question to the user via Feishu.
6. **Before declaring done**, run the project's checks if configured:
   - Read `.hermes-dev.yaml` in the project root.
   - If it defines `lint_cmd` or `test_cmd`, run them.
   - If they fail, fix the failures; do not declare done.
7. **Output format**: when you finish, write a summary of what you did to
   `$RUNS_DIR/claude-summary.md` and exit. Do not write to stdout.

## GIT USAGE

- `git status` to see current state
- `git log -1` to see the last commit
- `git diff HEAD~1` to see your last change
- `git add -A && git commit -m "..."` for each logical change
- Do not use `git commit --amend` (would rewrite history the orchestrator depends on)
- Do not use `git rebase -i` for the same reason

## INCREMENTAL STYLE

- Small commits > large commits. The reviewer (Codex) sees the diff; small diffs are easier to review.
- Each commit should compile / type-check on its own if the project supports it.
```

The `claude_contract.md` is **inlined into the prompt** at invocation time so the model sees the rules every call, not as a separate file to discover.

### 7.4 Output handling

After Claude Code returns:

1. Check exit code. If non-zero, increment retry counter; on 3rd failure, set `status=halted`.
2. Read `$RUNS_DIR/claude-questions.txt` (if exists); for each question, send Feishu to user; set `status=awaiting_user`; resume on reply.
3. Read `$RUNS_DIR/claude-summary.md`; store the summary in `state.json`; send Feishu "开发完成" card.
4. Move to Phase 4.

---

## 8. Phase 4 — Review Loop

### 8.1 Loop driver

`scripts/phases/04_review.sh`:

```bash
#!/bin/bash
set -euo pipefail
JOB_ID="$1"
MAX=$(state_get user_overrides.max_review_rounds)
ROUND=$(state_get phase_round 1)
RUNS_DIR=~/.hermes/runs/$JOB_ID

while [ "$ROUND" -le "$MAX" ]; do
    # 1. If not the first round, re-invoke Claude Code with last review
    if [ "$ROUND" -gt 1 ]; then
        bash phases/03_implement_iter.sh "$JOB_ID" "$ROUND"
    fi

    # 2. Run Codex review
    bash phases/04_review_one.sh "$JOB_ID" "$ROUND"

    # 3. Parse verdict
    VERDICT=$(python -m lib.review_parser get-verdict \
        "$RUNS_DIR/review-rounds/round-$ROUND.md")
    P0=$(python -m lib.review_parser get-p0 \
        "$RUNS_DIR/review-rounds/round-$ROUND.md")
    P1=$(python -m lib.review_parser get-p1 \
        "$RUNS_DIR/review-rounds/round-$ROUND.md")

    # 4. Notify user
    python -m lib.feishu notify-review-round \
        "$JOB_ID" "$ROUND" "$VERDICT" "$P0" "$P1"

    # 5. Termination
    if [ "$VERDICT" = "APPROVED" ] && [ "$P0" -eq 0 ] && [ "$P1" -eq 0 ]; then
        state_set status running
        state_set phase handoff
        exit 0
    fi

    ROUND=$((ROUND + 1))
    state_set phase_round "$ROUND"
done

# Cap exceeded
python -m lib.feishu escalate-cap-exceeded "$JOB_ID" "$MAX"
state_set status halted
state_set phase handoff
```

### 8.2 Single review round (`04_review_one.sh`)

```bash
#!/bin/bash
set -euo pipefail
JOB_ID="$1"
ROUND="$2"
RUNS_DIR=~/.hermes/runs/$JOB_ID
PROJECT_PATH=$(state_get project.path)
IS_GIT=$(state_get project.is_git)
CODEX_MODEL=$(state_get user_overrides.codex_model)
CODEX_MODEL=${CODEX_MODEL:-gpt-5.5}

if [ "$IS_GIT" = "true" ]; then
    DIFF=$(cd "$PROJECT_PATH" && git diff "$BASE_BRANCH"..HEAD)
    DIFF_FILE="$RUNS_DIR/review-rounds/diff-round-$ROUND.txt"
    echo "$DIFF" > "$DIFF_FILE"
    REVIEW_INPUT_KIND="diff"
else
    # Non-git fallback: give Codex the project path and let it navigate
    # the tree itself. We do NOT dump the tree as a text blob — that would
    # either miss important files (head -N) or blow the context window
    # (full dump). Codex with workspace-write can read the project directly.
    DIFF_FILE=""
    REVIEW_INPUT_KIND="directory"
fi

PROMPT="$(cat scripts/codex_prompts/review.md)

=== SPEC ===
$(cat $RUNS_DIR/spec.md)

=== PLAN ===
$(cat $RUNS_DIR/plan.md)

=== REVIEW INPUT ===
$(if [ "$REVIEW_INPUT_KIND" = "diff" ]; then
    echo 'Kind: cumulative git diff against base branch'
    echo "Diff file: $DIFF_FILE (read this file directly)"
    cat "$DIFF_FILE"
else
    echo "Kind: directory tree (project is not a git repo)"
    echo "Project path: $PROJECT_PATH"
    echo "Read files from disk under that path as needed."
    echo "Do not require a diff blob; explore the tree."
fi)

=== OUTPUT INSTRUCTIONS ===
Write your review to $RUNS_DIR/review-rounds/round-$ROUND.md.
End the file with a single line: VERDICT: APPROVED  or  VERDICT: REJECTED
Use the format - [P0] / - [P1] / - [P2] for issue entries."

# Sandbox choice depends on input kind
if [ "$REVIEW_INPUT_KIND" = "diff" ]; then
    SANDBOX_FLAGS="--sandbox danger-full-access"
else
    SANDBOX_FLAGS="--sandbox workspace-write --add-dir $PROJECT_PATH"
fi

codex --model "$CODEX_MODEL" $SANDBOX_FLAGS -p "$PROMPT" \
      --output-format json > "$RUNS_DIR/review-rounds/round-$ROUND.raw.json"
```

### 8.3 Verdict parser (`lib/review_parser.py`)

```python
import re

VERDICT_RE = re.compile(r"^VERDICT:\s*(APPROVED|REJECTED)\s*$", re.MULTILINE)
P0_RE = re.compile(r"\bP0\b")
P1_RE = re.compile(r"\bP1\b")
P2_RE = re.compile(r"\bP2\b")


def parse(review_md: str) -> dict:
    """Returns:
        {
          'verdict': 'APPROVED' | 'REJECTED',
          'p0': int, 'p1': int, 'p2': int,
          'summary': str  # first 200 chars of the Issues section
        }
    """
    verdict_m = VERDICT_RE.search(review_md)
    verdict = verdict_m.group(1) if verdict_m else "REJECTED"
    # The skill treats absence of VERDICT line as REJECTED (safer default)
    return {
        "verdict": verdict,
        "p0": len(P0_RE.findall(review_md)),
        "p1": len(P1_RE.findall(review_md)),
        "p2": len(P2_RE.findall(review_md)),
        "summary": _extract_summary(review_md),
    }


def is_pass(parsed: dict) -> bool:
    return parsed["verdict"] == "APPROVED" and parsed["p0"] == 0 and parsed["p1"] == 0


def _extract_summary(review_md: str) -> str:
    m = re.search(r"##\s*Issues found\s*\n(.*?)(?=\n##|\Z)", review_md, re.DOTALL)
    if not m:
        return review_md[:200]
    return m.group(1).strip()[:300]
```

Note: the P0/P1/P2 counters count **mentions** in the markdown, not unique issues. That is intentional: a single P0 with three "P0" mentions (e.g., "see P0 above") still counts as 3 mentions; the soft-cap check `p0 == 0` is the strict gate.

### 8.4 User-extendable cap

When the user sends `@bot 继续` (or taps a card button with `action=continue`), `hermes-dev` parses the message and runs a single Bash command that:

1. Atomically increments `user_overrides.max_review_rounds` by 5 and
   `user_overrides.extra_review_rounds_added` by 5 in `state.json`.
2. If the job is currently `halted`, re-invokes `phases/04_review.sh` to resume
   the loop with the new cap.
3. Sends a Feishu confirmation: "已增加 5 轮 review 上限，现在最多 N 轮".

The implementation lives in `scripts/handlers/on_continue.sh`:

```bash
#!/bin/bash
set -euo pipefail
JOB_ID="$1"
RUNS_DIR=~/.hermes/runs/$JOB_ID

python -m lib.state atomic_update "$RUNS_DIR/state.json" '
{
  "user_overrides": {
    "max_review_rounds": (
      current["user_overrides"]["max_review_rounds"] + 5
    ),
    "extra_review_rounds_added": (
      current["user_overrides"]["extra_review_rounds_added"] + 5
    )
  }
}
'

NEW_MAX=$(python -m lib.state get "$RUNS_DIR/state.json" \
    user_overrides.max_review_rounds)
python -m lib.feishu send_text \
    "Job #${JOB_ID:0:6} 已增加 5 轮 review 上限，现在最多 $NEW_MAX 轮"

if [ "$(python -m lib.state get $RUNS_DIR/state.json status)" = "halted" ]; then
    bash phases/04_review.sh "$JOB_ID"
fi
```

The Feishu message handler in Hermes (in `SKILL.md` instructions) is responsible for matching `@bot 继续` patterns and invoking `on_continue.sh <job_id>`. The skill itself does not implement the message parser — that is Hermes's responsibility, per the Hybrid model.

---

## 9. Phase 5 — Handoff

### 9.1 Contents

A handoff message (Feishu card) includes:

- Job summary (one-line from `claude-summary.md`)
- Branch name and base branch
- Commit count and total diffstat
- Link to `spec.md` / `plan.md` (via card button → `file://` URL on the local machine)
- Instructions for the user:
  - How to inspect locally (`git fetch && git checkout hermes-dev/<job_id>`)
  - How to run tests if not already
  - Suggested commit message for the merge
- Question: "需要继续迭代吗？需要合并到 main 吗？"

### 9.2 Status finalisation

- On user reply "done" or "ok" or 24h timeout: set `status=done`, `phase=done`.
- On user reply "merge": instruct user to run the merge themselves (out of scope for v1).
- On user reply "more": re-enter Phase 3 with updated requirements.

---

## 10. External integrations

### 10.1 Feishu via `hermes send`

The skill **only** uses the following interface:

```bash
hermes send --text "<plain text>"
hermes send --card-json '<JSON string>'
```

**Contract assumption (must be verified at install time):** `hermes send` is expected to print a line of the form `message_id: om_xxx` to stdout on success, so the skill can capture it for later edits. If the user's Hermes implementation does not emit this line, the skill falls back to "no message_id tracking" (acceptable degradation): cards are sent but not edited, and `state.json.feishu_message_ids` is left empty. The `lib/feishu.py` wrapper **must not raise** on a missing message_id; it logs a warning and returns `""`.

The Python wrapper `lib/feishu.py` is a thin abstraction:

```python
import json, subprocess, uuid
from datetime import datetime

def _run(args: list) -> str:
    """Returns the Feishu message_id (om_xxx) parsed from hermes send's stdout."""
    result = subprocess.run(["hermes", "send", *args],
                            capture_output=True, text=True, check=True)
    # Convention: hermes send prints "message_id: om_xxx" on stdout
    for line in result.stdout.splitlines():
        if line.startswith("message_id:"):
            return line.split(":", 1)[1].strip()
    return ""  # best-effort; failure is non-fatal

def send_text(text: str) -> str:
    return _run(["--text", text])

def send_card(title: str, fields: list, buttons: list = None) -> str:
    card = {
        "header": {"title": {"tag": "plain_text", "content": title}},
        "elements": [
            *[{"tag": "div", "fields": [
                {"tag": "text", "text": f"{k}: {v}"} for k, v in f.items()
            ]} for f in fields],
        ],
    }
    if buttons:
        card["elements"].append({"tag": "action", "actions": [
            {"tag": "button",
             "text": {"tag": "plain_text", "content": b["text"]},
             "type": b.get("type", "default"),
             "value": b.get("value", {})}
            for b in buttons
        ]})
    return _run(["--card-json", json.dumps(card, ensure_ascii=False)])

def notify_progress(job_id: str, phase: str, message: str):
    """Sends a card with the current phase, optionally editing the prior progress card."""
    # Implementation: store the prior progress message_id; on next progress,
    # call hermes with --edit-message <om_xxx> to update. This requires the
    # hermes send command to support --edit-message; if not, fall back to
    # sending a new card.
    ...
```

If `hermes send` does not return a parseable `message_id`, the skill sends successfully but cannot edit prior messages. This is acceptable degradation; the wrapper must not crash on missing message_id.

### 10.2 Codex CLI

Model selection precedence (highest first):

1. `state.json.user_overrides.codex_model` (set per-job in Feishu)
2. `~/.hermes/hermes-dev/config.yaml` → `codex.model`
3. `~/.codex/config.toml` → `model` (the user's global default)

Reasoning effort follows the same precedence with key `codex.reasoning_effort`.

Invocation flags (locked):

```
codex --model <name> --sandbox danger-full-access -p <prompt> --output-format json
```

Why `danger-full-access`: Codex must write `spec.md` and `plan.md` to the runs dir, which is outside any project. With `read-only` or `workspace-write` sandboxes it would not be able to. The user is already in a trusted shell; the Codex invocation is bounded by the explicit prompt (no internet by default unless the prompt asks for it).

### 10.3 Claude Code CLI

Model selection precedence (highest first):

1. `state.json.user_overrides.claude_model`
2. `~/.hermes/hermes-dev/config.yaml` → `claude.model`
3. Default: `claude-opus-4-8` (per system prompt's "latest/most capable" guidance)

Invocation flags (locked):

```
claude --model <name> --cwd <project> -p <prompt> --output-format json
```

The `--cwd` is mandatory; it puts Claude Code inside the project with the correct git branch context.

### 10.4 Git

| Operation | Command |
|---|---|
| Is git repo? | `git -C <p> rev-parse --git-dir` exits 0 |
| Create branch | `git -C <p> checkout <base> && git -C <p> checkout -b hermes-dev/<job_id>` |
| Commit | `git -C <p> add -A && git -C <p> commit -m <msg>` |
| Cumulative diff | `git -C <p> diff <base>..HEAD` |
| Per-round diff | `git -C <p> diff HEAD~<n>..HEAD~<n-1>` |
| Last commit | `git -C <p> log -1 --pretty=format:"%H %s"` |
| Diffstat | `git -C <p> diff --shortstat <base>..HEAD` |

All git operations are performed in `lib/git_ops.py`; bash never calls `git` directly. This is a deliberate boundary: any future change to git behaviour (e.g., adding `--no-verify` for hooks) goes in one place.

---

## 11. Configuration

### 11.1 `~/.hermes/hermes-dev/config.yaml`

```yaml
version: 1

codex:
  model: gpt-5.5
  reasoning_effort: medium

claude:
  model: claude-opus-4-8

phases:
  requirements:
    max_questions_per_turn: 3
    completeness_checklist:
      - functional_scope
      - behaviour
      - edge_cases
      - non_functional
      - acceptance_criteria
  spec_plan:
    max_self_check_retries: 2
  review:
    max_rounds_default: 5
    extra_rounds_per_continue: 5

feishu:
  # Mapped to the user-DM chat implicitly by hermes send; no chat_id here.
  # prefer_card_over_text_threshold is consulted by lib/feishu.py to decide
  # whether to send a long message as a card (with title + elements) or as
  # plain text. This is a heuristic; callers can force a card by using
  # send_card() directly.
  prefer_card_over_text_threshold: 120  # chars; longer messages become cards
  progress_card_refresh: true           # edit-prior-card vs new-card (requires hermes send to support --edit-message)

reconcile:
  orphan_threshold_seconds: 300         # 5 min
```

### 11.2 `~/.hermes/projects.json` (optional, lazily created)

```json
{
  "stocks":  { "path": "/Users/xpy/projects/stocks",  "default_branch": "main" },
  "blog":    { "path": "/Users/xpy/code/blog",        "default_branch": "master" }
}
```

### 11.3 Project-local `.hermes-dev.yaml` (optional, in project root)

```yaml
test_cmd: pnpm test
lint_cmd: pnpm lint
typecheck_cmd: pnpm tsc --noEmit
```

If absent, the skill does not run tests/lint before declaring done (Section 7.3 rule 6).

---

## 12. Error handling & recovery

### 12.1 Error categories

| Category | Example | Recovery |
|---|---|---|
| Transient | Codex 5xx, network blip | Retry with exponential backoff (3 attempts) |
| User input | Ambiguous requirement | `status=awaiting_user`, Feishu question |
| Tool failure | `claude` non-zero exit | Retry 3x, then `halted` |
| Process death | Hermes killed mid-job | `reconcile` → `orphaned` → resume from checkpoint |
| Conflict | `git` merge conflict during review iteration | Inject conflict into next Claude Code prompt; 2 retries → `halted` |
| Verdict unparseable | Codex output has no `VERDICT:` line | Treat as `REJECTED`; still count round |
| Cap exceeded | 5 rounds no APPROVE | `halted` + Feishu escalation |

### 12.2 Retry backoff

```python
# lib/state.py helper

class TransientError(Exception):
    """Raised when an external call (codex / claude / network) fails in a way
    that retrying with backoff might succeed. Non-transient errors should
    not be wrapped in this; they propagate up to halt the job."""

def retry_with_backoff(fn, max_attempts: int = 3, base: float = 2.0):
    """Runs `fn` (a no-arg callable) up to `max_attempts` times.
    Returns the value of the first successful call.
    Raises the last TransientError if all attempts fail.
    Non-transient errors propagate immediately."""
    last_error = None
    for attempt in range(1, max_attempts + 1):
        try:
            return fn()
        except TransientError as e:
            last_error = e
            if attempt < max_attempts:
                time.sleep(base ** attempt)
    raise last_error
```

`TransientError` is defined in `lib/state.py` (it is the one place that knows what counts as transient for the skill). `lib/review_parser.py`, `lib/git_ops.py`, and `lib/feishu.py` import it from there.

### 12.3 Reconcile command

`hermes-dev reconcile [--age 5m] [--auto-resume]`:

1. List `~/.hermes/runs/*/state.json`.
2. For each with `status in (running, awaiting_tool)`:
   - If `state.json.updated_at` is older than `--age`, AND no live PID in `state.json.pid` (when set), mark `orphaned`.
3. For each `orphaned`:
   - Without `--auto-resume`: send Feishu "Job #X 已离线，请发 `@bot 继续` 恢复".
   - With `--auto-resume`: invoke `hermes-dev continue <job_id>` for each.

The launchd plist / cron entry to invoke `reconcile` is **outside this skill's install scope** (it belongs to the Hermes host setup). The skill's `install.sh` (Section 14) only registers the CLI, not the periodic job.

### 12.4 Event log

Every state transition writes a JSON line to `runs/<job_id>/events.jsonl`:

```json
{"ts":"2026-06-14T10:35:22Z","event":"phase_enter","phase":"review","round":1}
{"ts":"2026-06-14T10:42:11Z","event":"review_done","round":1,"verdict":"REJECTED","p0":1,"p1":2}
{"ts":"2026-06-14T10:42:15Z","event":"feishu_send","message_id":"om_xyz","kind":"card"}
```

`hermes-dev tail <job_id>` follows this file (similar to `tail -f`).

---

## 13. Testing strategy

### 13.1 Unit tests (pytest)

| File | Covers |
|---|---|
| `test_state.py` | Atomic read/write; schema validation; checkpoint round-trip |
| `test_review_parser.py` | Verdict extraction, P0/P1/P2 counts, malformed inputs |
| `test_checkpoint.py` | Save/restore, hash verification, multi-phase |
| `test_project_registry.py` | Add/list/remove projects; lazy creation of `projects.json` |

### 13.2 Fixtures

Real Codex review outputs saved as test fixtures, with a small markdown frontmatter marker for which scenario they represent:

- `sample-review-approved.md` — `VERDICT: APPROVED`, no P0/P1
- `sample-review-rejected-p0.md` — `VERDICT: REJECTED`, 2 P0s
- `sample-review-rejected-p1.md` — `VERDICT: REJECTED`, no P0, 3 P1s
- `sample-review-malformed.md` — no `VERDICT:` line; parser must default to REJECTED

### 13.3 E2E dry-run

`tests/e2e/sandbox-project/` is a 50-line throwaway git repo (e.g., a Python CLI that adds two numbers). The skill's `hermes-dev` accepts a `--dry-run` flag that:

- Skips real `codex` and `claude` invocations
- Uses canned responses from `tests/e2e/canned/`
- Asserts the state machine transitions match the expected sequence

Run with `pytest tests/e2e/`. CI runs this on every PR.

### 13.4 Manual smoke

`tests/manual/smoke.sh` is a shell script for the user to run by hand:

```bash
bash tests/manual/smoke.sh ~/projects/stocks
```

It creates a real job against a real project, lets Codex and Claude Code do their work, and asserts that the branch and review verdict are produced. Output is a clear PASS/FAIL per assertion. Intended to be run before each release.

### 13.5 Hermes-side observability

The skill does not log to stdout in production (Hermes's transcript is the primary log). The skill writes to `runs/<job_id>/events.jsonl` (Section 12.4) and surfaces only user-relevant events to Hermes for inclusion in its reply.

---

## 14. Installation

### 14.1 Files installed

```bash
# Skill files
~/Documents/RichardHub/Git/hermes-dev-skill/   # source-of-truth

# Hermes-visible (sync via Skill Hub)
~/.hermes/skills/hermes-dev-skill/             # SKILL.md is what Hermes reads

# Per-user state
~/.hermes/hermes-dev/config.yaml               # from config.example.yaml
~/.hermes/runs/                                # created on first job
~/.hermes/projects.json                        # created on first register
```

### 14.2 `install.sh` (Bash)

The install script:

1. Creates `~/.hermes/hermes-dev/` if absent; copies `config.example.yaml` → `config.yaml` if absent.
2. Creates `~/.hermes/runs/` if absent.
3. Symlinks `scripts/hermes-dev` into `~/.local/bin/hermes-dev`.
4. (Optional) Calls `Skill Hub`'s sync to install under `~/.hermes/skills/`.

The install script does **not**:

- Configure launchd / cron for `reconcile` (Hermes host concern).
- Modify `~/.codex/config.toml` (user controls their Codex defaults).
- Set up `lark-cli` or any Feishu credentials (Hermes already has them).

### 14.3 Updating

Updates flow through `Skill Hub` like other skills in the user's repo. The `~/.hermes/runs/` directory is preserved across updates (it is user data, not skill code).

---

## 15. Open questions / future work

These are **deliberately out of scope for v1** but flagged for the v1.1 design:

1. **Multi-user / multi-project workspaces**: today the bot is single-user. v1.1 could scope jobs to a project name and route to a project-specific Feishu group.
2. **Spec human review before implementation**: today, the user sees spec/plan only at the "Spec/Plan 已生成" message; v1.1 could pause Phase 2 for user approval.
3. **Auto-PR**: v1 stops at the local branch. v1.1 could push and open a PR via `gh` if the user wants.
4. **Codex prompt caching**: with multi-job usage, prompt caching for the spec/review templates would save cost. Tracked in v1.1.
5. **Test/lint auto-iteration**: today, if tests fail, Claude Code fixes; v1.1 could add a separate "tests green" gate before review.
6. **GitLab / non-GitHub remotes**: the design is git-agnostic, but the `gh` PR step (v1.1) is GitHub-specific.

---

## 16. Appendix A — Codex prompt templates

### `codex_prompts/spec_plan.md`

```markdown
You are Codex, invoked by the hermes-dev skill to convert a requirements document
into a Specification and a Plan for implementation.

## INPUTS

A requirements document written by the user via dialogue. It describes:
- The feature the user wants
- The project it should be implemented in
- Edge cases and acceptance criteria gathered through Q&A

## YOUR TASK

Produce TWO files in the runs directory (paths provided in the prompt):

### 1. `spec.md`

Schema (use these exact section headings):

```
# Specification

## Goals
<bullet list>

## Non-goals
<bullet list>

## Behaviour
<numbered list, step by step>

## Edge cases
<bullet list, each with: trigger + expected behaviour>

## Acceptance criteria
<numbered list, each verifiable: "Given X, when Y, then Z">

## Out-of-scope (deferred)
<bullet list — anything that came up in requirements but is for a later iteration>
```

### 2. `plan.md`

Schema:

```
# Plan

## Phases
<ordered list; each phase is a self-contained unit of work>

## Files to create / modify
<grouped by phase; for each file, list purpose>

## Test strategy
<how to verify each acceptance criterion>

## Risks
<anything that could go wrong, with mitigations>
```

## RULES

- Do not invent behaviour not in the requirements. If a behaviour is implied but not
  stated, write a question to `claude-questions.txt` and stop.
- Prefer smallest-viable spec. If 5 lines solve the user's problem, do not write 50.
- Be specific. "Add a button" is bad. "Add a `Submit` button to the bottom of the
  `<form id=checkout>` that POSTs to `/api/orders`" is good.

## OUTPUT

When done, print a one-line summary to stdout. Do not return the full spec/plan in
the assistant message — it lives in the files.
```

### `codex_prompts/self_check.md`

```markdown
You are Codex, auditing a spec/plan pair for internal consistency, gaps, and risks.

## INPUTS

The full content of `spec.md` and `plan.md`.

## YOUR TASK

Produce a single file `self-check.md` in the runs dir with this schema:

```
# Self-Check

## Coverage
<does the plan cover every acceptance criterion in the spec? yes/no per item>

## Internal consistency
<do the spec and plan contradict each other? list contradictions>

## Gaps
<behaviours described in the spec that the plan does not implement>

## Risks
<plan steps that are technically risky; e.g., large refactor without tests>

## Verdict
VERDICT: PASS    # if there are no P0 gaps and the plan is sound
# OR
VERDICT: FAIL    # if there are P0 gaps or contradictions
```

A P0 gap is one of:
- An acceptance criterion with no plan coverage
- A contradiction between spec and plan
- A plan step that cannot actually achieve its stated goal

## OUTPUT

One-line summary to stdout. Full report in the file.
```

### `codex_prompts/review.md`

```markdown
You are Codex, performing a code review of an implementation.

## INPUTS

- The original `spec.md` (what should be built)
- The original `plan.md` (how it should be built)
- A `git diff <base>..HEAD` of the implementation, OR a directory tree of the
  project if it is not a git repo

## YOUR TASK

Produce `review-rounds/round-N.md` with this schema:

```
# Review — round N

## Summary
<one paragraph: what does this implementation do>

## Spec compliance
<per acceptance criterion: met / not met / partial — with file:line evidence>

## Issues found

### P0 — must fix (blocks acceptance)
- [P0] <file:line> — <problem> — <suggested fix>

### P1 — should fix (correctness, missing tests, security)
- [P1] <file:line> — <problem> — <suggested fix>

### P2 — nice to have
- [P2] <file:line> — <problem> — <suggested fix>

## Praise
<things done well; useful for the user to see>

VERDICT: APPROVED
# OR
VERDICT: REJECTED
```

## RULES

- Every P0 and P1 must include a `file:line` reference. If you cannot cite
  file:line, the issue is not actionable — demote to P2 or drop.
- P0 = blocks spec compliance. P1 = doesn't block spec but is a real bug.
- If the spec is satisfied, output `VERDICT: APPROVED` even if P2s remain.
- The diff / tree can be very long. Skim the spec first, then read the relevant
  files end-to-end; do not rely on grep.
```

---

## 17. Appendix B — Example Feishu card

```json
{
  "header": {
    "title": {"tag": "plain_text", "content": "Job #a1b2c3 — Phase 4/5"}
  },
  "elements": [
    {
      "tag": "div",
      "text": {
        "tag": "lark_md",
        "content": "**Status**: Review round 2 of 5\n**Verdict**: REJECTED (1 P0, 2 P1)\n**Last commit**: `hermes-dev(a1b2c3): fix race in cache invalidation`"
      }
    },
    {
      "tag": "action",
      "actions": [
        {
          "tag": "button",
          "text": {"tag": "plain_text", "content": "查看 Review"},
          "type": "primary",
          "url": "file:///Users/xpy/.hermes/runs/20260614-1030-a1b2c3/review-rounds/round-2.md"
        },
        {
          "tag": "button",
          "text": {"tag": "plain_text", "content": "查看 Diff"},
          "type": "default",
          "url": "file:///Users/xpy/.hermes/runs/20260614-1030-a1b2c3/review-rounds/diff-round-2.txt"
        },
        {
          "tag": "button",
          "text": {"tag": "plain_text", "content": "继续 (5 轮)"},
          "type": "default",
          "value": {"action": "continue"}
        }
      ]
    }
  ]
}
```

---

## 18. Appendix C — Decision log (locked)

| # | Decision | Rationale | Date |
|---|---|---|---|
| 1 | Async background job model | Long Codex/Claude Code calls; user can stay online; recovery semantics make sense | 2026-06-14 |
| 2 | `hermes send --text\|--card-json` for Feishu | Hermes already has bot/DM binding; no need to bundle lark-cli | 2026-06-14 |
| 3 | `~/.hermes/runs/<job_id>/` for state | Survives project wipes; inspectable | 2026-06-14 |
| 4 | Project path on-demand | Don't force pre-registration; ask during Phase 1 | 2026-06-14 |
| 5 | Codex default `gpt-5.5` | Matches `~/.codex/config.toml` | 2026-06-14 |
| 6 | 5-round hard cap + APPROVED soft cap + user-extendable | Bounded cost, escape hatch exists | 2026-06-14 |
| 7 | Git diff review, directory-tree fallback | Precise review when possible; usable without git | 2026-06-14 |
| 8 | Bash thin + Python thick | Natural fit for Skill ecosystem; Python for parseable logic | 2026-06-14 |
| 9 | `reconcile` command, launchd out of scope | Skill is self-contained; deployment is host's job | 2026-06-14 |
| 10 | Claude Code CLI (not GUI) headless | Wins on automation, context, integration, recovery, parseability | 2026-06-14 |
| 11 | Claude Code work contract via inline prompt | Rules visible every call; no separate file to discover | 2026-06-14 |
| 12 | Hybrid orchestration (Hermes = judgement, scripts = mechanics) | LLMs do fuzzy work, scripts do mechanical work | 2026-06-14 |
