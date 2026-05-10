# CLI Runner

Use `scripts/research-runner.sh` when Deep Research should be run directly through a CLI with capability-based routing.

## Command

```bash
Skills/deep-research/scripts/research-runner.sh MODE TASK_FILE [OUTPUT_DIR] [PROJECT_DIR] [--parallel|--sequential]
```

Example:

```bash
Skills/deep-research/scripts/research-runner.sh high_quality /tmp/research-task.md /tmp/deep-research-run /path/to/project
```

Dry run without calling CLI:

```bash
Skills/deep-research/scripts/research-runner.sh high_quality /tmp/research-task.md /tmp/deep-research-run /path/to/project --dry-run
```

Force sequential fallback:

```bash
Skills/deep-research/scripts/research-runner.sh high_quality /tmp/research-task.md /tmp/deep-research-run /path/to/project --sequential
```

## Inputs

- `MODE`: `balanced`, `cost_saving`, `high_quality`, `long_context`, or `draft_fast`.
- `TASK_FILE`: Markdown or text file containing the user research request.
- `OUTPUT_DIR`: optional run directory. Defaults to `.deep-research-runs/YYYYMMDD-HHMMSS`.
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
  Skills/deep-research/scripts/research-runner.sh balanced /tmp/research-task.md
```

## Capability Routing

The runner calls `scripts/model-router.sh MODE AGENT` for each agent.

Important: capability routing is auditable only as a requested capability unless CLI command output, logs, or UI state verifies the actual model. Do not claim a specific model was actually used only because `model-routing.yaml` recommended it.

Default mapping:

- `balanced`: high capability for planning/analysis/scenario/writing/review, fast for sources, long_context for long context.
- `cost_saving`: fast for most work, long_context for long context, high for final review.
- `high_quality`: high for all critical work, fast for source collection, long_context for long context.
- `long_context`: long_context for long context, high for synthesis and review.
- `draft_fast`: fast for draft work, high for final review.

## Outputs

The runner creates:

- `run-summary.md`: mode, task path, capability mapping, output files.
- `execution-context.md`: requested capability routes and actual model detection status.
- `source_failure_log.md`: source/search/fetch failure log template for failed or insufficient source collection.
- `prompts/`: per-agent prompts sent to CLI.
- `outputs/`: per-agent Markdown outputs.
- `logs/`: per-agent timing and file metadata.

The final usable report should normally be in the `writer_agent` output, with final readiness and required revisions in the `reviewer_agent` output.

## Fallback Behavior

- If CLI is unavailable, the runner stops with a clear error.
- If `--dry-run` is passed, it writes prompts and placeholder outputs without calling CLI.
- If parallel execution causes provider rate limits, database locks, or network pressure, rerun with `--sequential`.

## Quality Downgrade Behavior

For `high_quality` mode:

- If actual model use cannot be verified, the report cannot be `PASS`.
- If web search, source collection, or source validation fails, the report must be marked `离线初稿` or `待联网核验版`.
- If source collection fails but structure is complete, use `CONDITIONAL_PASS`.
- If core conclusions lack S/A/B sources and no反证扫描 exists, use `FAIL`.
- Final summaries must include `real_model_detection_status`, `capability_route_execution_status`, `search_status`, `audit_grade`, `report_usability`, and required manual source verification.
