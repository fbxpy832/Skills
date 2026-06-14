# state.json schema reference

`state.json` lives at the root of each job's runs directory:
`~/.hermes/runs/<job_id>/state.json`. It is the single source of truth
for job state; everything else in the runs dir is an artifact.

## Top-level fields

```json
{
  "job_id": "20260614-1030-a1b2c3",
  "version": "1.0",
  "created_at": "2026-06-14T10:30:00Z",
  "updated_at": "2026-06-14T10:35:22Z",
  "status": "running",
  "phase": "review",
  "phase_round": 2,
  "intent": "build me a stock alerter",
  "project": { ... },
  "artifacts": { ... },
  "checkpoints": { ... },
  "feishu_message_ids": ["om_abc123"],
  "events_log": "events.jsonl",
  "errors": [],
  "user_overrides": { ... }
}
```

### Required keys (validated on read)

`job_id`, `status`, `phase`, `phase_round`. See
`scripts/lib/state.py:REQUIRED_KEYS`.

### Allowed values

- `status` ∈ {`running`, `awaiting_user`, `awaiting_tool`, `halted`,
  `orphaned`, `done`}
- `phase` ∈ {`bootstrap`, `clarify`, `spec_plan`, `implement`, `review`,
  `handoff`, `done`, `halted`}

## `project` sub-object

```json
{
  "name": "stocks",
  "path": "/Users/xpy/projects/stocks",
  "branch": "hermes-dev/20260614-1030-a1b2c3",
  "base_branch": "main",
  "is_git": true
}
```

Set by Phase 1 (clarify) when the user confirms the project path.

## `artifacts` sub-object

Paths are **relative to the runs dir**:

```json
{
  "requirements": "requirements.md",
  "spec": "spec.md",
  "plan": "plan.md",
  "self_check": "self-check.md",
  "review_rounds": [
    "review-rounds/round-1.md",
    "review-rounds/round-2.md"
  ]
}
```

## `user_overrides` sub-object

```json
{
  "codex_model": null,
  "claude_model": null,
  "max_review_rounds": 5,
  "extra_review_rounds_added": 0
}
```

`null` for a model means "use config.yaml default".

## `errors` array (capped at 50)

```json
[
  {
    "at": "2026-06-14T10:35:22Z",
    "phase": "review",
    "kind": "codex_5xx",
    "message": "Codex returned 503",
    "traceback": "..."
  }
]
```

## Atomic update API

```python
from scripts.lib import state

# Shorthand: replace/add these fields
state.atomic_update(runs_dir, {"phase": "implement", "phase_round": 1})

# Full Python expression
state.atomic_update(runs_dir, '''
{
  "user_overrides": {
    "max_review_rounds": current["user_overrides"]["max_review_rounds"] + 5
  }
}
''')
```

`atomic_update` takes a file lock so concurrent calls are safe.
