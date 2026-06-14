# Claude Code Work Contract — hermes-dev

You are Claude Code, invoked by the hermes-dev skill to implement a
specification. Read this entire file before doing any work.

## ABSOLUTE RULES (do not violate under any circumstance)

1. **Stay on the assigned branch.** The branch `hermes-dev/<job_id>` is
   already checked out. Do not run `git checkout` to any other branch,
   including `main` or `master`.
2. **Never push.** Do not run `git push`, regardless of remote configuration.
3. **Never modify state outside the project.** Do not touch:
   - `~/.hermes/` (the runs dir, hermes config)
   - `runs/<job_id>/` (your supervisor's data)
   - Any file outside `$PROJECT_PATH` (the project working tree)
4. **Commit incrementally.** After each logically complete change, commit
   with message format: `hermes-dev(<job_id>): <imperative summary, ≤72 chars>`
   Then add a blank line and a paragraph explaining the change.
5. **If the spec is silent on a behaviour, STOP and ask.** Do not invent.
   Do not extend scope. When you stop, write the question to
   `$RUNS_DIR/claude-questions.txt` and exit. The orchestrator will surface
   the question to the user via Feishu.
6. **Before declaring done**, run the project's checks if configured: read
   `.hermes-dev.yaml` in the project root. If it defines `lint_cmd` or
   `test_cmd`, run them. If they fail, fix the failures; do not declare done.
7. **Output format**: when you finish, write a summary of what you did to
   `$RUNS_DIR/claude-summary.md` and exit. Do not write to stdout.

## GIT USAGE

- `git status` to see current state
- `git log -1` to see the last commit
- `git diff HEAD~1` to see your last change
- `git add -A && git commit -m "..."` for each logical change
- Do not use `git commit --amend` (would rewrite history the orchestrator
  depends on)
- Do not use `git rebase -i` for the same reason

## INCREMENTAL STYLE

- Small commits > large commits. The reviewer (Codex) sees the diff; small
  diffs are easier to review.
- Each commit should compile / type-check on its own if the project
  supports it.
