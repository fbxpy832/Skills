# OpenCode Runner

> **Note**: OpenCode is ONE host adapter for the Deep Research protocol. For a complete overview of how different hosts (Codex, Claude Code, CloudCode, GUI, TU/terminal) integrate with the protocol, see `references/host-adapter-contract.md`. For host-neutral execution without OpenCode dependencies, use `scripts/generic-research-runner.sh`.

Use `scripts/opencode-research-runner.sh` when Deep Research should be run directly through OpenCode with model routing.

## Command

```bash
./scripts/opencode-research-runner.sh MODE TASK_FILE [OUTPUT_DIR] [PROJECT_DIR] [--parallel|--sequential]
```

Example:

```bash
./scripts/opencode-research-runner.sh high_quality /tmp/research-task.md /tmp/deep-research-run /Users/xpy/Documents/RichardHub/Git
```

Dry run without calling OpenCode:

```bash
./scripts/opencode-research-runner.sh high_quality /tmp/research-task.md /tmp/deep-research-run /Users/xpy/Documents/RichardHub/Git --dry-run
```

Force sequential fallback:

```bash
./scripts/opencode-research-runner.sh high_quality /tmp/research-task.md /tmp/deep-research-run /Users/xpy/Documents/RichardHub/Git --sequential
```

## Inputs

- `MODE`: `balanced`, `cost_saving`, `high_quality`, `long_context`, or `draft_fast`.
- `TASK_FILE`: Markdown or text file containing the user research request.
- `OUTPUT_DIR`: optional run directory. Defaults to `${DEEP_RESEARCH_OUTPUT_DIR:-.deep-research-runs}/YYYYMMDD-HHMMSS`.
- `PROJECT_DIR`: optional working directory. Defaults to current directory.
- `--parallel`: staged parallel execution. This is the default.
- `--sequential`: run the same agents one by one for debugging or constrained environments.

## Agent Selection

By default, the runner executes all seven agents with staged parallelism:

```text
planner_agent,source_agent,long_context_agent,analyst_agent,scenario_agent,writer_agent,reviewer_agent
```

Default stage plan:

```text
1. planner_agent
2. source_agent + long_context_agent in parallel
3. analyst_agent + scenario_agent in parallel
4. writer_agent
5. reviewer_agent
```

To run a subset:

```bash
DEEP_RESEARCH_AGENTS="planner_agent,source_agent,analyst_agent,writer_agent,reviewer_agent" \
  ./scripts/opencode-research-runner.sh balanced /tmp/research-task.md
```

## Model Routing

The runner calls `scripts/model-router.sh MODE AGENT` for each agent.

Important: model routing is auditable only as a requested route unless OpenCode command output, logs, or UI state verifies the actual model. Do not claim a model was actually used only because `model-routing.yaml` recommended it.

Default mapping:

- `balanced`: Pro for planning/analysis/scenario/writing/review, Flash for sources, Kimi 2.6 for long context.
- `cost_saving`: Flash for most work, Kimi 2.6 for long context, Pro for final review.
- `high_quality`: Pro for all critical work, Flash for source collection, Kimi 2.6 for long context.
- `long_context`: Kimi 2.6 for long context, Pro for synthesis and review.
- `draft_fast`: Flash for draft work, Pro for final review.

## Outputs

The runner creates:

- `run-summary.md`: mode, task path, model mapping, output files.
- `execution-context.md`: requested model routes and actual model detection status.
- `source_failure_log.md`: source/search/fetch failure log template for failed or insufficient source collection.
- `events.ndjson`: structured event stream (one JSON object per line) with run_started, agent_started, agent_completed, agent_failed, stage_started, stage_completed, run_completed events.
- `prompts/`: per-agent prompts sent to OpenCode.
- `outputs/`: per-agent Markdown outputs.
- `logs/`: per-agent timing and file metadata.

The final usable report should normally be in the `writer_agent` output, with final readiness and required revisions in the `reviewer_agent` output.

## Fallback Behavior

- If OpenCode is unavailable, the runner stops with a clear error.
- If `--dry-run` is passed, it writes prompts and placeholder outputs without calling OpenCode.
- If parallel execution causes provider rate limits, database locks, or network pressure, rerun with `--sequential`.

## Quality Downgrade Behavior

For `high_quality` mode:

- If actual model use cannot be verified, the report cannot be `PASS`.
- If web search, source collection, or source validation fails, the report must be marked `离线初稿` or `待联网核验版`.
- If source collection fails but structure is complete, use `CONDITIONAL_PASS`.
- If core conclusions lack S/A/B sources and no反证扫描 exists, use `FAIL`.
- Final summaries must include `real_model_detection_status`, `model_route_execution_status`, `search_status`, `audit_grade`, `report_usability`, and required manual source verification.
