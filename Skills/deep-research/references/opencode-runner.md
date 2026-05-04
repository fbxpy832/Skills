# OpenCode Runner

Use `scripts/opencode-research-runner.sh` when Deep Research should be run directly through OpenCode with model routing.

## Command

```bash
Skills/deep-research/scripts/opencode-research-runner.sh MODE TASK_FILE [OUTPUT_DIR] [PROJECT_DIR]
```

Example:

```bash
Skills/deep-research/scripts/opencode-research-runner.sh high_quality /tmp/research-task.md /tmp/deep-research-run /Users/xpy/Documents/RichardHub/Git
```

Dry run without calling OpenCode:

```bash
Skills/deep-research/scripts/opencode-research-runner.sh high_quality /tmp/research-task.md /tmp/deep-research-run /Users/xpy/Documents/RichardHub/Git --dry-run
```

## Inputs

- `MODE`: `balanced`, `cost_saving`, `high_quality`, `long_context`, or `draft_fast`.
- `TASK_FILE`: Markdown or text file containing the user research request.
- `OUTPUT_DIR`: optional run directory. Defaults to `.deep-research-runs/YYYYMMDD-HHMMSS`.
- `PROJECT_DIR`: optional working directory. Defaults to current directory.

## Agent Selection

By default, the runner executes all seven agents sequentially:

```text
planner_agent,source_agent,long_context_agent,analyst_agent,scenario_agent,writer_agent,reviewer_agent
```

To run a subset:

```bash
DEEP_RESEARCH_AGENTS="planner_agent,source_agent,analyst_agent,writer_agent,reviewer_agent" \
  Skills/deep-research/scripts/opencode-research-runner.sh balanced /tmp/research-task.md
```

## Model Routing

The runner calls `scripts/model-router.sh MODE AGENT` for each agent.

Default mapping:

- `balanced`: Pro for planning/analysis/scenario/writing/review, Flash for sources, Kimi 2.6 for long context.
- `cost_saving`: Flash for most work, Kimi 2.6 for long context, Pro for final review.
- `high_quality`: Pro for all critical work, Flash for source collection, Kimi 2.6 for long context.
- `long_context`: Kimi 2.6 for long context, Pro for synthesis and review.
- `draft_fast`: Flash for draft work, Pro for final review.

## Outputs

The runner creates:

- `run-summary.md`: mode, task path, model mapping, output files.
- `prompts/`: per-agent prompts sent to OpenCode.
- `outputs/`: per-agent Markdown outputs.

The final usable report should normally be in the `writer_agent` output, with final readiness and required revisions in the `reviewer_agent` output.

## Fallback Behavior

- If OpenCode is unavailable, the runner stops with a clear error.
- If `--dry-run` is passed, it writes prompts and placeholder outputs without calling OpenCode.
- If true parallel Subagents are unavailable, this runner uses sequential Subagent execution and requires the final report metadata to state that sequential mode was used.
