# Troubleshooting

## "hermes send" doesn't print a message_id

Some `hermes send` implementations don't emit the `message_id: om_xxx`
line. The skill falls back to returning `""` and does not raise. Card
edits will not work; new cards are sent each time. To fix: ensure your
`hermes send` outputs `message_id: om_xxx` on stdout on success.

## "state.json is missing required keys"

This means a script wrote a partial state. Check the most recent
`events.jsonl` for the last successful operation. You can re-write the
state with `python -c "from scripts.lib import state; state.write(
'<runs_dir>', { ... full state ... })"`.

## "Review keeps failing self-check"

`02_spec_plan.sh` retries self-check up to 2 times, then halts. Read
`self-check.md` to see what Codex thinks is missing. Common causes:
- The spec references behaviour the user did not state (over-spec)
- The plan skips an acceptance criterion (under-plan)
- The plan uses a technology the project does not have

You can re-run Phase 2 after editing the spec/plan manually:
`bash scripts/phases/02_spec_plan.sh <job_id>`.

## "Job is orphaned"

Run `hermes-dev reconcile --auto-resume`. Or manually:
`hermes-dev continue <job_id> --force`.

## "git diff is empty for a non-trivial change"

This means Claude Code committed on a different branch. Check
`state.json.project.branch`; if it does not match
`hermes-dev/<job_id>`, manually re-checkout and re-commit:
`cd $PROJECT && git checkout hermes-dev/<job_id> && git cherry-pick <sha>`.

## "Codex 5xx error"

Transient. The skill retries 3 times with exponential backoff. If it
still fails, the job is halted. Re-run `bash scripts/phases/02_spec_plan.sh`
or `04_review.sh` after Codex is back up.
