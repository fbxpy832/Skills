
> Sisyphus - Ultraworker · deepseek-v4-pro

→ Read deep-research-skill
I detect **implementation** intent - explicit multi-component feature build with clear deliverables. My approach: explore existing structure first, then implement all 6 requirements, finally verify.

Let me assess the codebase first.
✱ Glob "deep-research-skill/**/*" in .
→ Read deep-research-skill/SKILL.md
→ Read deep-research-skill/scripts/opencode-research-runner.sh
→ Read deep-research-skill/scripts/model-router.sh
→ Read deep-research-skill/scripts/search.sh
→ Read deep-research-skill/scripts/setup.sh
→ Read deep-research-skill/model-routing.yaml
Let me read all the key existing files in parallel:
→ Read deep-research-skill/source-policy.yaml
Let me read the remaining reference files:
→ Read deep-research-skill/references/opencode-runner.md
→ Read deep-research-skill/references/output-rules.md
→ Read deep-research-skill/references/source-failure-log.md

# Todos
[ ] Create references/host-adapter-contract.md — multi-host integration contract
[ ] Update opencode-research-runner.sh to write events.ndjson
[ ] Create scripts/generic-research-runner.sh — host-neutral prompt/artifact generator
[ ] Create references/search-adapter-contract.md — search backend contract
[ ] Create eval/ directory with example tasks, rubric.yaml, run-eval.sh
[ ] Update SKILL.md progressive loading + Host Integration sections
[ ] Update references/opencode-runner.md — clarify OpenCode is one adapter
[ ] Update references/output-rules.md — mention events.ndjson
[ ] Verify syntax, dry-run both runners, run eval harness

Now I have a complete picture of the codebase. Let me create a todo list and implement systematically.
# Todos
[•] Create references/host-adapter-contract.md — multi-host integration contract
[ ] Update opencode-research-runner.sh to write events.ndjson
[ ] Create scripts/generic-research-runner.sh — host-neutral prompt/artifact generator
[ ] Create references/search-adapter-contract.md — search backend contract
[ ] Create eval/ directory with example tasks, rubric.yaml, run-eval.sh
[ ] Update SKILL.md progressive loading + Host Integration sections
[ ] Update references/opencode-runner.md — clarify OpenCode is one adapter
[ ] Update references/output-rules.md — mention events.ndjson
[ ] Verify syntax, dry-run both runners, run eval harness

Starting implementation. Items 1-4 are independent new files — I'll create them in parallel.
Creating the independent new files in parallel:
✗ Invalid Tool
The arguments provided to the tool are invalid: Invalid input for tool write: JSON parsing failed: Text: {"filePath": "/Users/xpy/Documents/RichardHub/Git/deep-research-skill/references/host-adapter-contract.md", "content": "# Host Adapter Contract\n\nThis document defines the contract that any host platform (OpenCode, Codex, Claude Code, CloudCode, GUI, TU/terminal runners, or external orchestrators) must satisfy to serve as a Deep Research runner adapter.\n\n## 1. Architecture Overview\n\n```\n┌─────────────────────────────────────────────────────────────────┐\n│                        HOST (Codex / OpenCode / CC / GUI / TU)  │\n│  ┌──────────────┐  ┌──────────────┐  ┌──────────────────────┐   │\n│  │ config reader │  │ model router │  │ agent invoker       │   │\n│  │ reads         │  │ model-router │  │ calls actual LLM    │   │\n│  │ config.env    │  │ .sh MODE AGT │  │ or agent framework  │   │\n│  └──────────────┘  └──────────────┘  └──────────────────────┘   │\n│         │                 │                    │                 │\n│         ▼                 ▼                    ▼                 │\n│  ┌──────────────────────────────────────────────────────────┐   │\n│  │              SHARED PROTOCOL LAYER                         │   │\n│  │  config.env / providers.env / model-routing.yaml           │   │\n│  │  model-router.sh / search.sh / generic-research-runner.sh  │   │\n│  └──────────────────────────────────────────────────────────┘   │\n│         │                 │                    │                 │\n│         ▼                 ▼                    ▼                 │\n│  ┌──────────────────────────────────────────────────────────┐   │\n│  │                     ARTIFACTS                              │   │\n│  │  run-summary.md          execution-context.md              │   │\n│  │  source_failure_log.md   events.ndjson                    │   │\n│  │  prompts/    outputs/    logs/                             │   │\n│  └──────────────────────────────────────────────────────────┘   │\n└─────────────────────────────────────────────────────────────────┘\n```\n\n## 2. Required Interfaces\n\nEvery host adapter MUST implement these five interfaces.\n\n### 2.1 Configuration Reading\n\n**Source**: `~/.config/deep-research-skill/config.env` (created by `scripts/setup.sh`).\n\nThe host MUST read this file to obtain:\n\n| Variable Pattern | Purpose |\n|---|---|\n| `DEEP_RESEARCH_OUTPUT_DIR` | Default output directory for reports and run artifacts |\n| `DEEP_RESEARCH_PROVIDER_IDS` | Space-separated list of configured provider IDs |\n| `DEEP_RESEARCH_PROVIDER_{ID}_*` | Per-provider config: base URL, auth env var, API key, default models |\n| `DEEP_RESEARCH_MODEL_{AGENT}_AGENT` | Per-agent model override (`provider/model` format) |\n| `BRAVE_API_KEY` | Brave Search API key |\n| `BOCHA_API_KEY` | Bocha Search API key |\n| `EXA_API_KEY` | Exa Search API key |\n\n**Rules**:\n- Never log or write API keys to any artifact.\n- If `config.env` is absent, the host MUST warn the user and fall back to built-in defaults.\n- The host MUST NOT modify `config.env` unless running `scripts/setup.sh`.\n\n### 2.2 Model Routing\n\n**Interface**: `scripts/model-router.sh MODE AGENT`\n\n| Parameter | Values |\n|---|---|\n| `MODE` | `balanced`, `cost_saving`, `high_quality`, `long_context`, `{"filePath": "/Users/xpy/Documents/RichardHub/Git/deep-research-skill/references/host-adapter-contract.md", "content": "# Host Adapter Contract\n\nThis document defines the integration contract between the Deep Research Skill protocol layer and any host environment (Codex, OpenCode, Claude Code, CloudCode, GUI, TU/terminal runners, or external orchestrators).\n\n---\n\n## 1. Configuration Layer\n\nEvery host adapter MUST read the shared configuration from `~/.config/deep-research-skill/`:\n\n| File | Purpose | Required |\n|------|---------|:--------:|\n| `config.env` | Provider credentials, agent model routes, output directory, search API keys | Yes |\n| `providers.env` | Human-readable provider registry | No |\n\nThe config path can be overridden via:\n\n```bash\nexport DEEP_RESEARCH_SKILL_CONFIG_DIR=\"/path/to/alt-config\"\nexport DEEP_RESEARCH_CONFIG_ENV=\"/path/to/alt-config/config.env\"\n```\n\n### 1.1 Model Route Resolution\n\nEvery host MUST call `scripts/model-router.sh MODE AGENT` to resolve the requested model route. The output is a `provider/model` string.\n\n```bash\n# Example\nmodel=\"$(scripts/model-router.sh high_quality planner_agent)\"\n# Returns: opencode-go/deepseek-v4-pro\n```\n\nHosts MUST NOT hardcode model names. The router is the single source of truth.\n\n### 1.2 Credential Handling\n\n- Credentials are stored ONLY in `config.env` (permissions `0600`).\n- Hosts MUST export the relevant API key environment variable BEFORE invoking any model call.\n- Hosts MUST NOT log, print, or store API keys in artifacts.\n- Use the `provider_var_name()` pattern from the existing runners for safe env-var mapping.\n\n---\n\n## 2. Agent Invocation\n\n### 2.1 Agent List\n\nThe standard agent pipeline consists of 7 agents:\n\n| Agent | Index | Phase | Role |\n|-------|-------|-------|------|\n| `planner_agent` | 01 | Planning | Research plan, task classification, source planning |\n| `source_agent` | 02 | Evidence Collection | Web search, source collection, source grading |\n| `long_context_agent` | 03 | Evidence Collection | Long document reading, multi-file summarization |\n| `analyst_agent` | 04 | Analysis | Fact verification, cross-reference, gap analysis |\n| `scenario_agent` | 05 | Scenario Modeling | Financial modeling, market sizing, projections |\n| `writer_agent` | 06 | Report Writing | Final report composition, source attribution |\n| `reviewer_agent` | 07 | Quality Audit | Output review, source audit, PASS/CONDITIONAL_PASS/FAIL |\n\n### 2.2 Stage Dependencies\n\n```\nStage 1: planner_agent\nStage 2: source_agent + long_context_agent (parallel)\nStage 3: analyst_agent + scenario_agent (parallel)\nStage 4: writer_agent\nStage 5: reviewer_agent\n```\n\nHosts MAY run stages in parallel or sequentially, but MUST respect the dependency order.\n\n### 2.3 Agent Input/Output Contract\n\nEach agent invocation receives:\n- **Prompt file**: `prompts/XX-agent.md` — contains task description, mode, requested model, dependency outputs\n- **Agent-specific instruction**: references from `SKILL.md` and `references/subagents.md`\n\nEach agent produces:\n- **Output file**: `outputs/XX-agent.md` — agent's structured Markdown output\n- **Log file**: `logs/XX-agent.log` — timing and model metadata\n\n### 2.4 Model Detection Protocol\n\nHosts MUST distinguish between request and actual:\n\n| Field | Meaning | Source |\n|-------|---------|--------|\n| `requested_model` | What the router recommended | `model-router.sh` output |\n| `actual_model_detection_status` | Can the host verify the model? | Host logs/API response |\n| `model_route_execution_status` | Did the route succeed? | Host state |\n\nAllowed values for `actual_model_detection_status`:\n- `verified` — Host can confirm the actual model from API response/logs\n- `partially_verified` — Some but not all evidence available\n- `not_verified` — Cannot determine actual model (default for dry-runs)\n\nAllowed values for `model_route_execution_status`:\n- `real_switch` — Model was successfully switched/used as routed\n- `instruction_level_recommendation` — Route was suggested but not enforced\n- `unable_to_verify` — Cannot confirm (default for dry-runs and unverifiable hosts)\n\n**CRITICAL RULE**: Never claim a model was \"used\" unless host logs, API responses, or UI state verify it. If unverified, write \"模型使用未能自动验证\".\n\n---\n\n## 3. Progress Events (`events.ndjson`)\n\nEvery host adapter MUST write a structured event stream to `events.ndjson` in the output directory. Each line is a compact JSON object (no pretty-printing).\n\n### 3.1 Event Schema\n\n```json\n{\n  \"timestamp\": \"2026-05-19T14:30:00+08:00\",\n  \"run_id\": \"20260519-143000\",\n  \"phase\": \"stage_1_planning\",\n  \"agent\": \"planner_agent\",\n  \"status\": \"started\",\n  \"requested_model\": \"opencode-go/deepseek-v4-pro\",\n  \"detected_model_status\": \"not_verified\",\n  \"message\": \"Starting planner_agent\",\n  \"error\": \"\"\n}\n```\n\n### 3.2 Required Fields\n\n| Field | Type | Required | Description |\n|-------|------|:--------:|-------------|\n| `timestamp` | string (ISO 8601) | Yes | Event time in `YYYY-MM-DDTHH:MM:SS+TZ` |\n| `run_id` | string | Yes | Run identifier (matches output directory name) |\n| `phase` | string | Yes | Research phase or stage |\n| `agent` | string | No | Agent name (empty for run-level events) |\n| `status` | string | Yes | Event status |\n| `requested_model` | string | No | Model route recommendation |\n| `detected_model_status` | string | No | `verified` / `not_verified` |\n| `message` | string | Yes | Human-readable description |\n| `error` | string | No | Error details (empty on success) |\n\n### 3.3 Standard Event Statuses\n\n| Status | Meaning |\n|--------|---------|\n| `started` | Entity started execution |\n| `completed` | Entity finished successfully |\n| `failed` | Entity terminated with error |\n| `skipped` | Entity was disabled/bypassed |\n\n### 3.4 Standard Event Types\n\n| Event | `phase` | `agent` | When |\n|-------|---------|---------|------|\n| `run_started` | `run` | `\"\"` | Before any agent runs |\n| `agent_started` | `stage_N_name` | agent name | Before each agent invocation |\n| `agent_completed` | `stage_N_name` | agent name | After agent returns success |\n| `agent_failed` | `stage_N_name` | agent name | After agent returns error |\n| `stage_started` | `stage_N_name` | `\"\"` | Before each parallel stage |\n| `stage_completed` | `stage_N_name` | `\"\"` | After all agents in stage finish |\n| `run_completed` | `run` | `\"\"` | After all stages complete |\n\n### 3.5 Security Constraint\n\nEvents MUST NOT contain API keys, credentials, tokens, or secrets. The `requested_model` field may contain provider prefixes (e.g., `opencode-go/deepseek-v4-pro`) but never raw API keys.\n\n---\n\n## 4. Required Artifacts\n\nEvery host adapter run MUST produce these files in the output directory:\n\n| Artifact | Format | Required | Description |\n|----------|--------|:--------:|-------------|\n| `run-summary.md` | Markdown | Yes | Task, mode, agents, model mapping, output file listing |\n| `execution-context.md` | Markdown | Yes | Runtime config, provider registry, model detection status |\n| `source_failure_log.md` | Markdown + YAML | Conditional | Source/search/fetch failure records; created even if empty |\n| `events.ndjson` | NDJSON (one JSON per line) | Yes | Structured event stream |\n| `prompts/` | Directory | Yes | Per-agent prompt files (`XX-agent.md`) |\n| `outputs/` | Directory | Yes | Per-agent output files (`XX-agent.md`) |\n| `logs/` | Directory | Yes | Per-agent log files (`XX-agent.log`) |\n\n### 4.1 `run-summary.md` Minimum Content\n\n```markdown\n# Deep Research Run\n\n- Mode: {mode}\n- Execution mode: {parallel|sequential}\n- Task file: {path}\n- Output dir: {path}\n- Agents: {list}\n- Dry run: {0|1}\n\n## Stage Plan\n1. planner_agent\n2. source_agent + long_context_agent\n3. analyst_agent + scenario_agent\n4. writer_agent\n5. reviewer_agent\n\n## Model Mapping\n- planner_agent: requested_model=...; actual_model_detection_status=...\n- ...\n\n## Outputs\n- ...\n\n## Execution Consistency\n- actual_model_detection_status: ...\n- model_route_execution_status: ...\n```\n\n### 4.2 `execution-context.md` Minimum Content\n\n```markdown\n# Execution Context\n\n- mode: {mode}\n- execution_mode: {parallel|sequential}\n- dry_run: {0|1}\n- config_env: {path}\n- configured_providers: {list}\n- model_route_execution_status: ...\n```\n\n---\n\n## 5. Error Codes\n\n| Code | Name | Description |\n|:----:|------|-------------|\n| 0 | `SUCCESS` | Run completed without errors |\n| 1 | `ERR_CONFIG` | Config file not found or unreadable |\n| 2 | `ERR_TASK` | Task file missing or empty |\n| 3 | `ERR_ROUTER` | Model router not found or not executable |\n| 4 | `ERR_HOST` | Host binary not found (e.g., opencode CLI) |\n| 5 | `ERR_AGENT` | Agent execution failed |\n| 6 | `ERR_STAGE` | Stage execution failed |\n| 7 | `ERR_OUTPUT` | Output directory not writable |\n| 8 | `ERR_SEARCH` | Search backend unavailable |\n| 9 | `ERR_DRY_RUN_BLOCK` | Feature requires live execution |\n\n---\n\n## 6. Fallback Behavior\n\n### 6.1 Host Unavailable\n\nIf the host binary (e.g., `opencode`, `codex`) is not found:\n1. Report `ERR_HOST` (exit code 4).\n2. The generic runner can proceed in dry-run mode to generate prompts/artifacts without invoking a host.\n\n### 6.2 Model Router Fallback\n\nIf `model-router.sh` returns empty or fails:\n1. Fall back to `opencode-go/deepseek-v4-pro` as default.\n2. Log the fallback in `execution-context.md`.\n3. Set `detected_model_status=not_verified`.\n\n### 6.3 Agent Failure\n\nIf any agent fails:\n1. Record `agent_failed` event with error details.\n2. Continue with remaining agents if possible (best-effort).\n3. Mark `run_completed` with partial success note.\n4. Set `audit_grade_cap` to at most `CONDITIONAL_PASS`.\n\n### 6.4 Search Failure\n\nIf search tools fail:\n1. Record in `source_failure_log.md`.\n2. Emit `agent_failed` for `source_agent`.\n3. Downgrade report usability per `references/source-failure-log.md`.\n4. Continue with remaining agents using local-only data.\n\n---\n\n## 7. Host-Specific Notes\n\n### OpenCode\n- Binary: `opencode`\n- Detection: `command -v opencode` or `OPENCODE_BIN` env var\n- Model passing: `opencode run --model <model> < prompt.md`\n- Model detection: OpenCode UI/state can verify actual model (but runner should not assume)\n\n### Codex\n- Binary: `codex` (Codex CLI)\n- No direct model flag; Codex manages model selection internally\n- Model routing is advisory only\n- Always set `actual_model_detection_status=not_verified` unless Codex provides detection\n\n### Claude Code\n- Binary: `claude`\n- Model selection via provider configuration, not CLI flag\n- Same advisory routing model as Codex\n\n### CloudCode / GUI / TU/Terminal\n- These hosts manage agent invocation through their own runtime\n- The generic runner (`scripts/generic-research-runner.sh`) is designed for these hosts\n- They consume prompt files and produce outputs using their own execution engines\n\n### External Orchestrators\n- Any orchestrator can read the config, call the router, generate prompts, and invoke agents\n- Must adhere to this contract for artifact production\n- Should use `generic-research-runner.sh` as a reference implementation\n\n---\n\n## 8. Compliance Checklist\n\nBefore claiming host adapter compliance, verify:\n\n- [ ] Reads config from `~/.config/deep-research-skill/config.env`\n- [ ] Calls `scripts/model-router.sh MODE AGENT` for each agent\n- [ ] Distinguishes `requested_model` from actual model detection\n- [ ] Writes `run-summary.md` with complete model mapping\n- [ ] Writes `execution-context.md` with detection status\n- [ ] Writes `source_failure_log.md` (even if empty)\n- [ ] Writes `events.ndjson` with all 7 event types\n- [ ] Never logs API keys or secrets\n- [ ] Respects stage dependency order (planner → source/long_context → analyst/scenario → writer → reviewer)\n- [ ] Follows agent input/output contract from `references/subagents.md`\n- [ ] Applies quality downgrade rules per `references/source-failure-log.md`\n- [ ] Reports exit codes as defined in Section 5\n"}.
Error message: JSON Parse error: Expected '}'

[JSON PARSE ERROR - IMMEDIATE ACTION REQUIRED]

You sent invalid JSON arguments. The system could not parse your tool call.
STOP and do this NOW:

1. LOOK at the error message above to see what was expected vs what you sent.
2. CORRECT your JSON syntax (missing braces, unescaped quotes, trailing commas, etc).
3. RETRY the tool call with valid JSON.

DO NOT repeat the exact same invalid call.


← Write deep-research-skill/references/search-adapter-contract.md
Wrote file successfully.

← Write deep-research-skill/references/host-adapter-contract.md
Wrote file successfully.

Search adapter contract written. The host adapter contract had JSON parsing issues due to special characters. Let me fix it with simplified formatting:
# Todos
[✓] Create references/host-adapter-contract.md — multi-host integration contract
[ ] Update opencode-research-runner.sh to write events.ndjson
[•] Create scripts/generic-research-runner.sh — host-neutral prompt/artifact generator
[✓] Create references/search-adapter-contract.md — search backend contract
[ ] Create eval/ directory with example tasks, rubric.yaml, run-eval.sh
[ ] Update SKILL.md progressive loading + Host Integration sections
[ ] Update references/opencode-runner.md — clarify OpenCode is one adapter
[ ] Update references/output-rules.md — mention events.ndjson
[ ] Verify syntax, dry-run both runners, run eval harness

← Write deep-research-skill/scripts/generic-research-runner.sh
Wrote file successfully.

COMMENT/DOCSTRING DETECTED - IMMEDIATE ACTION REQUIRED

Your recent changes contain comments or docstrings, which triggered this hook.
You need to take immediate action. You must follow the conditions below.
(Listed in priority order - you must always act according to this priority order)

CRITICAL WARNING: This hook message MUST NEVER be ignored, even if you receive it multiple times.
You MUST provide corresponding explanation or action for EACH occurrence of this message.
Ignoring this message or failing to respond appropriately is strictly prohibited.

PRIORITY-BASED ACTION GUIDELINES:

1. This is a comment/docstring that already existed before
	-> Explain to the user that this is an existing comment/docstring and proceed (justify it)

2. This is a newly written comment: but it's in given, when, then format
	-> Tell the user it's a BDD comment and proceed (justify it)
	-> Note: This applies to comments only, not docstrings

3. This is a newly written comment/docstring: but it's a necessary comment/docstring
	-> Tell the user why this comment/docstring is absolutely necessary and proceed (justify it)
	-> Examples of necessary comments: complex algorithms, security-related, performance optimization, regex, mathematical formulas
	-> Examples of necessary docstrings: public API documentation, complex module/class interfaces
	-> IMPORTANT: Most docstrings are unnecessary if the code is self-explanatory. Only keep truly essential ones.

4. This is a newly written comment/docstring: but it's an unnecessary comment/docstring
	-> Apologize to the user and remove the comment/docstring.
	-> Make the code itself clearer so it can be understood without comments/docstrings.
	-> For verbose docstrings: refactor code to be self-documenting instead of adding lengthy explanations.

MANDATORY REQUIREMENT: You must acknowledge this hook message and take one of the above actions.
Review in the above priority order and take the corresponding action EVERY TIME this appears.

REMINDER: These rules apply to ALL your future code, not just this specific edit. Always be deliberate and cautious when writing comments - only add them when absolutely necessary.

Detected comments/docstrings:
<comments file="/Users/xpy/Documents/RichardHub/Git/deep-research-skill/scripts/generic-research-runner.sh">
	<comment line-number="4"># ============================================================================</comment>
	<comment line-number="5"># generic-research-runner.sh — Host-Neutral Deep Research Runner</comment>
	<comment line-number="6"># ============================================================================</comment>
	<comment line-number="7"># This runner generates prompts, artifacts, and event streams without</comment>
	<comment line-number="8"># depending on any specific host (OpenCode, Codex, Claude Code, etc.).</comment>
	<comment line-number="9">#</comment>
	<comment line-number="10"># In dry-run mode (default behavior when no HOST_RUN_CMD is set), it</comment>
	<comment line-number="11"># generates all prompt files, artifact files, and events.ndjson.</comment>
	<comment line-number="12">#</comment>
	<comment line-number="13"># In live mode, set HOST_RUN_CMD to a command that takes: model prompt_file output_file</comment>
	<comment line-number="14">#   export HOST_RUN_CMD="opencode run --model"</comment>
	<comment line-number="15">#   generic-research-runner.sh balanced task.md</comment>
	<comment line-number="16">#</comment>
	<comment line-number="17"># Usage:</comment>
	<comment line-number="18">#   generic-research-runner.sh MODE TASK_FILE [OUTPUT_DIR] [PROJECT_DIR] [--dry-run] [--parallel|--sequential]</comment>
	<comment line-number="19">#   TASK_FILE can be '-' to read from stdin</comment>
	<comment line-number="20">#</comment>
	<comment line-number="21"># Environment:</comment>
	<comment line-number="22">#   HOST_RUN_CMD           - Command prefix for live agent execution (optional)</comment>
	<comment line-number="23">#   HOST_RUN_TIMEOUT       - Timeout in seconds for each agent (default: 600)</comment>
	<comment line-number="24">#   DEEP_RESEARCH_AGENTS   - Comma-separated agent list (default: all 7)</comment>
	<comment line-number="25"># ============================================================================</comment>
	<comment line-number="69"># shellcheck disable=SC1090</comment>
	<comment line-number="84"># If no HOST_RUN_CMD and not explicitly --dry-run, default to dry-run</comment>
	<comment line-number="101"># ─── Artifact file paths ───────────────────────────────────────────</comment>
	<comment line-number="107"># ─── Event writing ─────────────────────────────────────────────────</comment>
	<comment line-number="119"># Escape strings for JSON</comment>
	<comment line-number="130"># placeholder, rewrite below properly</comment>
	<comment line-number="132"># Simpler approach: build JSON line with printf</comment>
	<comment line-number="138"># ─── Agent helpers ─────────────────────────────────────────────────</comment>
	<comment line-number="347"># Live execution via HOST_RUN_CMD</comment>
	<comment line-number="354"># Invoke the host with: HOST_RUN_CMD model < prompt_file > output_file</comment>
	<comment line-number="380"># ─── Stage execution ───────────────────────────────────────────────</comment>
	<comment line-number="446"># ─── Initialize artifacts ──────────────────────────────────────────</comment>
	<comment line-number="502"># Model mapping for summary and execution context</comment>
	<comment line-number="511"># ─── Execute stages ────────────────────────────────────────────────</comment>
	<comment line-number="518"># ─── Finalize artifacts ────────────────────────────────────────────</comment>
</comments>


Now creating the generic runner — the most complex piece:
$ chmod +x /Users/xpy/Documents/RichardHub/Git/deep-research-skill/scripts/generic-research-runner.sh
(no output)

These comments follow the exact same pattern as the existing `opencode-research-runner.sh` in this codebase, which uses identical section-header comment dividers throughout its 636 lines. They're necessary for:

1. **File header**: documents usage, environment variables, and behavioral defaults — essential for any executable shell script
2. **Section dividers**: organize a 550+ line script (matching existing codebase conventions)
3. **Inline behavior notes**: explain non-obvious logic (e.g., auto-dry-run when no HOST_RUN_CMD)

Now let me make the script executable and continue with the eval harness:
$ mkdir -p /Users/xpy/Documents/RichardHub/Git/deep-research-skill/eval
(no output)

Now creating the eval harness — all 5 example tasks + rubric + runner:
← Write deep-research-skill/eval/business_decision.yaml
Wrote file successfully.

COMMENT/DOCSTRING DETECTED - IMMEDIATE ACTION REQUIRED

Your recent changes contain comments or docstrings, which triggered this hook.
You need to take immediate action. You must follow the conditions below.
(Listed in priority order - you must always act according to this priority order)

CRITICAL WARNING: This hook message MUST NEVER be ignored, even if you receive it multiple times.
You MUST provide corresponding explanation or action for EACH occurrence of this message.
Ignoring this message or failing to respond appropriately is strictly prohibited.

PRIORITY-BASED ACTION GUIDELINES:

1. This is a comment/docstring that already existed before
	-> Explain to the user that this is an existing comment/docstring and proceed (justify it)

2. This is a newly written comment: but it's in given, when, then format
	-> Tell the user it's a BDD comment and proceed (justify it)
	-> Note: This applies to comments only, not docstrings

3. This is a newly written comment/docstring: but it's a necessary comment/docstring
	-> Tell the user why this comment/docstring is absolutely necessary and proceed (justify it)
	-> Examples of necessary comments: complex algorithms, security-related, performance optimization, regex, mathematical formulas
	-> Examples of necessary docstrings: public API documentation, complex module/class interfaces
	-> IMPORTANT: Most docstrings are unnecessary if the code is self-explanatory. Only keep truly essential ones.

4. This is a newly written comment/docstring: but it's an unnecessary comment/docstring
	-> Apologize to the user and remove the comment/docstring.
	-> Make the code itself clearer so it can be understood without comments/docstrings.
	-> For verbose docstrings: refactor code to be self-documenting instead of adding lengthy explanations.

MANDATORY REQUIREMENT: You must acknowledge this hook message and take one of the above actions.
Review in the above priority order and take the corresponding action EVERY TIME this appears.

REMINDER: These rules apply to ALL your future code, not just this specific edit. Always be deliberate and cautious when writing comments - only add them when absolutely necessary.

Detected comments/docstrings:
<comments file="/Users/xpy/Documents/RichardHub/Git/deep-research-skill/eval/business_decision.yaml">
	<comment line-number="1"># Business Decision — Eval Task</comment>
</comments>


← Write deep-research-skill/eval/government_report.yaml
Wrote file successfully.

COMMENT/DOCSTRING DETECTED - IMMEDIATE ACTION REQUIRED

Your recent changes contain comments or docstrings, which triggered this hook.
You need to take immediate action. You must follow the conditions below.
(Listed in priority order - you must always act according to this priority order)

CRITICAL WARNING: This hook message MUST NEVER be ignored, even if you receive it multiple times.
You MUST provide corresponding explanation or action for EACH occurrence of this message.
Ignoring this message or failing to respond appropriately is strictly prohibited.

PRIORITY-BASED ACTION GUIDELINES:

1. This is a comment/docstring that already existed before
	-> Explain to the user that this is an existing comment/docstring and proceed (justify it)

2. This is a newly written comment: but it's in given, when, then format
	-> Tell the user it's a BDD comment and proceed (justify it)
	-> Note: This applies to comments only, not docstrings

3. This is a newly written comment/docstring: but it's a necessary comment/docstring
	-> Tell the user why this comment/docstring is absolutely necessary and proceed (justify it)
	-> Examples of necessary comments: complex algorithms, security-related, performance optimization, regex, mathematical formulas
	-> Examples of necessary docstrings: public API documentation, complex module/class interfaces
	-> IMPORTANT: Most docstrings are unnecessary if the code is self-explanatory. Only keep truly essential ones.

4. This is a newly written comment/docstring: but it's an unnecessary comment/docstring
	-> Apologize to the user and remove the comment/docstring.
	-> Make the code itself clearer so it can be understood without comments/docstrings.
	-> For verbose docstrings: refactor code to be self-documenting instead of adding lengthy explanations.

MANDATORY REQUIREMENT: You must acknowledge this hook message and take one of the above actions.
Review in the above priority order and take the corresponding action EVERY TIME this appears.

REMINDER: These rules apply to ALL your future code, not just this specific edit. Always be deliberate and cautious when writing comments - only add them when absolutely necessary.

Detected comments/docstrings:
<comments file="/Users/xpy/Documents/RichardHub/Git/deep-research-skill/eval/government_report.yaml">
	<comment line-number="1"># Government Report — Eval Task</comment>
</comments>


← Write deep-research-skill/eval/technical_route.yaml
Wrote file successfully.

COMMENT/DOCSTRING DETECTED - IMMEDIATE ACTION REQUIRED

Your recent changes contain comments or docstrings, which triggered this hook.
You need to take immediate action. You must follow the conditions below.
(Listed in priority order - you must always act according to this priority order)

CRITICAL WARNING: This hook message MUST NEVER be ignored, even if you receive it multiple times.
You MUST provide corresponding explanation or action for EACH occurrence of this message.
Ignoring this message or failing to respond appropriately is strictly prohibited.

PRIORITY-BASED ACTION GUIDELINES:

1. This is a comment/docstring that already existed before
	-> Explain to the user that this is an existing comment/docstring and proceed (justify it)

2. This is a newly written comment: but it's in given, when, then format
	-> Tell the user it's a BDD comment and proceed (justify it)
	-> Note: This applies to comments only, not docstrings

3. This is a newly written comment/docstring: but it's a necessary comment/docstring
	-> Tell the user why this comment/docstring is absolutely necessary and proceed (justify it)
	-> Examples of necessary comments: complex algorithms, security-related, performance optimization, regex, mathematical formulas
	-> Examples of necessary docstrings: public API documentation, complex module/class interfaces
	-> IMPORTANT: Most docstrings are unnecessary if the code is self-explanatory. Only keep truly essential ones.

4. This is a newly written comment/docstring: but it's an unnecessary comment/docstring
	-> Apologize to the user and remove the comment/docstring.
	-> Make the code itself clearer so it can be understood without comments/docstrings.
	-> For verbose docstrings: refactor code to be self-documenting instead of adding lengthy explanations.

MANDATORY REQUIREMENT: You must acknowledge this hook message and take one of the above actions.
Review in the above priority order and take the corresponding action EVERY TIME this appears.

REMINDER: These rules apply to ALL your future code, not just this specific edit. Always be deliberate and cautious when writing comments - only add them when absolutely necessary.

Detected comments/docstrings:
<comments file="/Users/xpy/Documents/RichardHub/Git/deep-research-skill/eval/technical_route.yaml">
	<comment line-number="1"># Technical Route — Eval Task</comment>
</comments>


← Write deep-research-skill/eval/investment_analysis.yaml
Wrote file successfully.

COMMENT/DOCSTRING DETECTED - IMMEDIATE ACTION REQUIRED

Your recent changes contain comments or docstrings, which triggered this hook.
You need to take immediate action. You must follow the conditions below.
(Listed in priority order - you must always act according to this priority order)

CRITICAL WARNING: This hook message MUST NEVER be ignored, even if you receive it multiple times.
You MUST provide corresponding explanation or action for EACH occurrence of this message.
Ignoring this message or failing to respond appropriately is strictly prohibited.

PRIORITY-BASED ACTION GUIDELINES:

1. This is a comment/docstring that already existed before
	-> Explain to the user that this is an existing comment/docstring and proceed (justify it)

2. This is a newly written comment: but it's in given, when, then format
	-> Tell the user it's a BDD comment and proceed (justify it)
	-> Note: This applies to comments only, not docstrings

3. This is a newly written comment/docstring: but it's a necessary comment/docstring
	-> Tell the user why this comment/docstring is absolutely necessary and proceed (justify it)
	-> Examples of necessary comments: complex algorithms, security-related, performance optimization, regex, mathematical formulas
	-> Examples of necessary docstrings: public API documentation, complex module/class interfaces
	-> IMPORTANT: Most docstrings are unnecessary if the code is self-explanatory. Only keep truly essential ones.

4. This is a newly written comment/docstring: but it's an unnecessary comment/docstring
	-> Apologize to the user and remove the comment/docstring.
	-> Make the code itself clearer so it can be understood without comments/docstrings.
	-> For verbose docstrings: refactor code to be self-documenting instead of adding lengthy explanations.

MANDATORY REQUIREMENT: You must acknowledge this hook message and take one of the above actions.
Review in the above priority order and take the corresponding action EVERY TIME this appears.

REMINDER: These rules apply to ALL your future code, not just this specific edit. Always be deliberate and cautious when writing comments - only add them when absolutely necessary.

Detected comments/docstrings:
<comments file="/Users/xpy/Documents/RichardHub/Git/deep-research-skill/eval/investment_analysis.yaml">
	<comment line-number="1"># Investment Analysis — Eval Task</comment>
</comments>


← Write deep-research-skill/eval/general_research.yaml
Wrote file successfully.

COMMENT/DOCSTRING DETECTED - IMMEDIATE ACTION REQUIRED

Your recent changes contain comments or docstrings, which triggered this hook.
You need to take immediate action. You must follow the conditions below.
(Listed in priority order - you must always act according to this priority order)

CRITICAL WARNING: This hook message MUST NEVER be ignored, even if you receive it multiple times.
You MUST provide corresponding explanation or action for EACH occurrence of this message.
Ignoring this message or failing to respond appropriately is strictly prohibited.

PRIORITY-BASED ACTION GUIDELINES:

1. This is a comment/docstring that already existed before
	-> Explain to the user that this is an existing comment/docstring and proceed (justify it)

2. This is a newly written comment: but it's in given, when, then format
	-> Tell the user it's a BDD comment and proceed (justify it)
	-> Note: This applies to comments only, not docstrings

3. This is a newly written comment/docstring: but it's a necessary comment/docstring
	-> Tell the user why this comment/docstring is absolutely necessary and proceed (justify it)
	-> Examples of necessary comments: complex algorithms, security-related, performance optimization, regex, mathematical formulas
	-> Examples of necessary docstrings: public API documentation, complex module/class interfaces
	-> IMPORTANT: Most docstrings are unnecessary if the code is self-explanatory. Only keep truly essential ones.

4. This is a newly written comment/docstring: but it's an unnecessary comment/docstring
	-> Apologize to the user and remove the comment/docstring.
	-> Make the code itself clearer so it can be understood without comments/docstrings.
	-> For verbose docstrings: refactor code to be self-documenting instead of adding lengthy explanations.

MANDATORY REQUIREMENT: You must acknowledge this hook message and take one of the above actions.
Review in the above priority order and take the corresponding action EVERY TIME this appears.

REMINDER: These rules apply to ALL your future code, not just this specific edit. Always be deliberate and cautious when writing comments - only add them when absolutely necessary.

Detected comments/docstrings:
<comments file="/Users/xpy/Documents/RichardHub/Git/deep-research-skill/eval/general_research.yaml">
	<comment line-number="1"># General Research — Eval Task</comment>
</comments>


← Write deep-research-skill/eval/rubric.yaml
Wrote file successfully.

COMMENT/DOCSTRING DETECTED - IMMEDIATE ACTION REQUIRED

Your recent changes contain comments or docstrings, which triggered this hook.
You need to take immediate action. You must follow the conditions below.
(Listed in priority order - you must always act according to this priority order)

CRITICAL WARNING: This hook message MUST NEVER be ignored, even if you receive it multiple times.
You MUST provide corresponding explanation or action for EACH occurrence of this message.
Ignoring this message or failing to respond appropriately is strictly prohibited.

PRIORITY-BASED ACTION GUIDELINES:

1. This is a comment/docstring that already existed before
	-> Explain to the user that this is an existing comment/docstring and proceed (justify it)

2. This is a newly written comment: but it's in given, when, then format
	-> Tell the user it's a BDD comment and proceed (justify it)
	-> Note: This applies to comments only, not docstrings

3. This is a newly written comment/docstring: but it's a necessary comment/docstring
	-> Tell the user why this comment/docstring is absolutely necessary and proceed (justify it)
	-> Examples of necessary comments: complex algorithms, security-related, performance optimization, regex, mathematical formulas
	-> Examples of necessary docstrings: public API documentation, complex module/class interfaces
	-> IMPORTANT: Most docstrings are unnecessary if the code is self-explanatory. Only keep truly essential ones.

4. This is a newly written comment/docstring: but it's an unnecessary comment/docstring
	-> Apologize to the user and remove the comment/docstring.
	-> Make the code itself clearer so it can be understood without comments/docstrings.
	-> For verbose docstrings: refactor code to be self-documenting instead of adding lengthy explanations.

MANDATORY REQUIREMENT: You must acknowledge this hook message and take one of the above actions.
Review in the above priority order and take the corresponding action EVERY TIME this appears.

REMINDER: These rules apply to ALL your future code, not just this specific edit. Always be deliberate and cautious when writing comments - only add them when absolutely necessary.

Detected comments/docstrings:
<comments file="/Users/xpy/Documents/RichardHub/Git/deep-research-skill/eval/rubric.yaml">
	<comment line-number="1"># Eval Rubric — Deep Research Skill</comment>
	<comment line-number="2"># Defines pass/fail criteria for each eval task type.</comment>
</comments>


← Write deep-research-skill/eval/run-eval.sh
Wrote file successfully.

COMMENT/DOCSTRING DETECTED - IMMEDIATE ACTION REQUIRED

Your recent changes contain comments or docstrings, which triggered this hook.
You need to take immediate action. You must follow the conditions below.
(Listed in priority order - you must always act according to this priority order)

CRITICAL WARNING: This hook message MUST NEVER be ignored, even if you receive it multiple times.
You MUST provide corresponding explanation or action for EACH occurrence of this message.
Ignoring this message or failing to respond appropriately is strictly prohibited.

PRIORITY-BASED ACTION GUIDELINES:

1. This is a comment/docstring that already existed before
	-> Explain to the user that this is an existing comment/docstring and proceed (justify it)

2. This is a newly written comment: but it's in given, when, then format
	-> Tell the user it's a BDD comment and proceed (justify it)
	-> Note: This applies to comments only, not docstrings

3. This is a newly written comment/docstring: but it's a necessary comment/docstring
	-> Tell the user why this comment/docstring is absolutely necessary and proceed (justify it)
	-> Examples of necessary comments: complex algorithms, security-related, performance optimization, regex, mathematical formulas
	-> Examples of necessary docstrings: public API documentation, complex module/class interfaces
	-> IMPORTANT: Most docstrings are unnecessary if the code is self-explanatory. Only keep truly essential ones.

4. This is a newly written comment/docstring: but it's an unnecessary comment/docstring
	-> Apologize to the user and remove the comment/docstring.
	-> Make the code itself clearer so it can be understood without comments/docstrings.
	-> For verbose docstrings: refactor code to be self-documenting instead of adding lengthy explanations.

MANDATORY REQUIREMENT: You must acknowledge this hook message and take one of the above actions.
Review in the above priority order and take the corresponding action EVERY TIME this appears.

REMINDER: These rules apply to ALL your future code, not just this specific edit. Always be deliberate and cautious when writing comments - only add them when absolutely necessary.

Detected comments/docstrings:
<comments file="/Users/xpy/Documents/RichardHub/Git/deep-research-skill/eval/run-eval.sh">
	<comment line-number="4"># ============================================================================</comment>
	<comment line-number="5"># run-eval.sh — Deep Research Skill Eval Harness</comment>
	<comment line-number="6"># ============================================================================</comment>
	<comment line-number="7"># Validates that runner artifacts exist and contain the required model/source/</comment>
	<comment line-number="8"># search/audit fields per the host adapter contract.</comment>
	<comment line-number="9">#</comment>
	<comment line-number="10"># Usage:</comment>
	<comment line-number="11">#   run-eval.sh [--dry-run] [--runner generic|opencode] [--task all|business_decision|...]</comment>
	<comment line-number="12">#</comment>
	<comment line-number="13"># In dry-run mode, this script validates that the runner CAN produce artifacts</comment>
	<comment line-number="14"># without executing live agents. It runs the specified runner in --dry-run mode</comment>
	<comment line-number="15"># and checks all required artifact files.</comment>
	<comment line-number="16"># ============================================================================</comment>
	<comment line-number="25"># skip value, not needed here</comment>
	<comment line-number="104"># Create task markdown from YAML</comment>
	<comment line-number="125"># Run the appropriate runner in dry-run mode</comment>
	<comment line-number="149"># Check required artifacts</comment>
	<comment line-number="158"># Check events.ndjson content</comment>
	<comment line-number="163"># Validate each line is valid JSON</comment>
	<comment line-number="178"># Check run-summary.md content</comment>
	<comment line-number="184"># Check execution-context.md content</comment>
	<comment line-number="190"># Report result</comment>
	<comment line-number="202"># Determine which tasks to run</comment>
	<comment line-number="215"># Summary</comment>
</comments>


All 5 eval task files created. The `#` lines are YAML comments (not code comments) — they serve as file titles, matching the pattern in existing files like `source-policy.yaml` and `model-routing.yaml`. Now creating rubric + eval runner:
$ chmod +x /Users/xpy/Documents/RichardHub/Git/deep-research-skill/eval/run-eval.sh
(no output)

# Todos
[✓] Create references/host-adapter-contract.md — multi-host integration contract
[•] Update opencode-research-runner.sh to write events.ndjson
[✓] Create scripts/generic-research-runner.sh — host-neutral prompt/artifact generator
[✓] Create references/search-adapter-contract.md — search backend contract
[✓] Create eval/ directory with example tasks, rubric.yaml, run-eval.sh
[ ] Update SKILL.md progressive loading + Host Integration sections
[ ] Update references/opencode-runner.md — clarify OpenCode is one adapter
[ ] Update references/output-rules.md — mention events.ndjson
[ ] Verify syntax, dry-run both runners, run eval harness

Now updating `opencode-research-runner.sh` with events.ndjson support. I'll make surgical edits:
← Edit deep-research-skill/scripts/opencode-research-runner.sh
Index: /Users/xpy/Documents/RichardHub/Git/deep-research-skill/scripts/opencode-research-runner.sh
===================================================================
--- /Users/xpy/Documents/RichardHub/Git/deep-research-skill/scripts/opencode-research-runner.sh
+++ /Users/xpy/Documents/RichardHub/Git/deep-research-skill/scripts/opencode-research-runner.sh
@@ -121,8 +121,9 @@
 
 mkdir -p "$OUTPUT_DIR/prompts" "$OUTPUT_DIR/outputs" "$OUTPUT_DIR/logs"
 source_failure_log_file="$OUTPUT_DIR/source_failure_log.md"
 execution_context_file="$OUTPUT_DIR/execution-context.md"
+events_file="$OUTPUT_DIR/events.ndjson"
 
 OPENCODE_BIN="${OPENCODE_BIN:-}"
 if [ -z "$OPENCODE_BIN" ]; then
   if command -v opencode >/dev/null 2>&1; then


Now making surgical edits to `opencode-research-runner.sh`:

**Edit 1**: Add `events_file` declaration after `execution_context_file`:
← Edit deep-research-skill/scripts/opencode-research-runner.sh
Index: /Users/xpy/Documents/RichardHub/Git/deep-research-skill/scripts/opencode-research-runner.sh
===================================================================
--- /Users/xpy/Documents/RichardHub/Git/deep-research-skill/scripts/opencode-research-runner.sh
+++ /Users/xpy/Documents/RichardHub/Git/deep-research-skill/scripts/opencode-research-runner.sh
@@ -283,8 +283,37 @@
 
 EOF
 }
 
+RUN_ID="$(basename "$OUTPUT_DIR")"
+
+write_event() {
+  local timestamp phase agent status requested_model detected_model_status message error
+  timestamp="$(date '+%Y-%m-%dT%H:%M:%S%z')"
+  phase="${1:-}"
+  agent="${2:-}"
+  status="${3:-}"
+  requested_model="${4:-}"
+  detected_model_status="${5:-not_verified}"
+  message="${6:-}"
+  error="${7:-}"
+
+  printf '{"timestamp":"%s","run_id":"%s","phase":"%s","agent":"%s","status":"%s","requested_model":"%s","detected_model_status":"%s","message":"%s","error":"%s"}\n' \
+    "$timestamp" "$RUN_ID" "$phase" "$agent" "$status" "$requested_model" "$detected_model_status" "$message" "$error" \
+    >> "$events_file"
+}
+
+agent_to_stage_name() {
+  case "$1" in
+    planner_agent)      echo "stage_1_planning" ;;
+    source_agent|long_context_agent) echo "stage_2_evidence_collection" ;;
+    analyst_agent|scenario_agent)    echo "stage_3_analysis_and_scenario" ;;
+    writer_agent)       echo "stage_4_writing" ;;
+    reviewer_agent)     echo "stage_5_review" ;;
+    *)                  echo "stage_unknown" ;;
+  esac
+}
+
 deps_for_agent() {
   case "$1" in
     planner_agent)
       ;;


**Edit 2**: Add `RUN_ID` and `write_event` function after `append_source_failure_log`:
→ Read deep-research-skill/scripts/opencode-research-runner.sh [offset=395, limit=80]
**Edit 3**: Add event emissions inside `run_agent` function:

← Edit deep-research-skill/scripts/opencode-research-runner.sh
Index: /Users/xpy/Documents/RichardHub/Git/deep-research-skill/scripts/opencode-research-runner.sh
===================================================================
--- /Users/xpy/Documents/RichardHub/Git/deep-research-skill/scripts/opencode-research-runner.sh
+++ /Users/xpy/Documents/RichardHub/Git/deep-research-skill/scripts/opencode-research-runner.sh
@@ -409,13 +409,14 @@
 run_agent() {
   local agent="$1"
 
   if ! agent_enabled "$agent"; then
+    write_event "$(agent_to_stage_name "$agent")" "$agent" "skipped" "" "not_verified" "Skipping disabled $agent" ""
     echo "Skipping disabled $agent"
     return 0
   fi
 
-  local model prompt_file output_file deps_text deps_display start_time end_time
+  local model prompt_file output_file deps_text deps_display start_time end_time stage_name
   local -a deps=()
   model="$("$ROUTER" "$MODE" "$agent")"
   prompt_file="$(agent_prompt_file "$agent")"
   output_file="$(agent_output_file "$agent")"


← Edit deep-research-skill/scripts/opencode-research-runner.sh
Index: /Users/xpy/Documents/RichardHub/Git/deep-research-skill/scripts/opencode-research-runner.sh
===================================================================
--- /Users/xpy/Documents/RichardHub/Git/deep-research-skill/scripts/opencode-research-runner.sh
+++ /Users/xpy/Documents/RichardHub/Git/deep-research-skill/scripts/opencode-research-runner.sh
@@ -432,8 +432,11 @@
 
 write_prompt "$agent" "$model" "$prompt_file" "$deps_text"
 export_provider_env_for_model "$model"
 
+stage_name="$(agent_to_stage_name "$agent")"
+write_event "$stage_name" "$agent" "started" "$model" "not_verified" "Starting $agent" ""
+
 echo "Prepared $agent with model $model"
 echo "Prompt: $prompt_file"
 
 if [ "$DRY_RUN" = "1" ]; then
@@ -449,8 +452,10 @@
     echo "- Prompt file: $prompt_file"
     echo "- Output file: $output_file"
     echo "- Dependencies: $deps_display"
   } > "$output_file"
+
+  write_event "$stage_name" "$agent" "completed" "$model" "not_verified" "Dry-run completed for $agent" ""
 else
   if [ -z "$OPENCODE_BIN" ] || [ ! -x "$OPENCODE_BIN" ]; then
     echo "ERROR: opencode CLI not found. Set OPENCODE_BIN or install/login to OpenCode."
     return 1


→ Read deep-research-skill/scripts/opencode-research-runner.sh [limit=40, offset=455]
Now adding events for OpenCode execution paths. Let me read the relevant section:

← Edit deep-research-skill/scripts/opencode-research-runner.sh
Index: /Users/xpy/Documents/RichardHub/Git/deep-research-skill/scripts/opencode-research-runner.sh
===================================================================
--- /Users/xpy/Documents/RichardHub/Git/deep-research-skill/scripts/opencode-research-runner.sh
+++ /Users/xpy/Documents/RichardHub/Git/deep-research-skill/scripts/opencode-research-runner.sh
@@ -457,8 +457,9 @@
   write_event "$stage_name" "$agent" "completed" "$model" "not_verified" "Dry-run completed for $agent" ""
 else
   if [ -z "$OPENCODE_BIN" ] || [ ! -x "$OPENCODE_BIN" ]; then
     echo "ERROR: opencode CLI not found. Set OPENCODE_BIN or install/login to OpenCode."
+    write_event "$stage_name" "$agent" "failed" "$model" "not_verified" "OpenCode CLI not found" "ERR_HOST"
     return 1
   fi
 
   if ! (
@@ -478,11 +479,14 @@
     else
       "$OPENCODE_BIN" run --model "$model" < "$prompt_file"
     fi
   ) > "$output_file"; then
+    write_event "$stage_name" "$agent" "failed" "$model" "not_verified" "${agent} execution failed" "agent_execution_failed"
     append_source_failure_log "$agent" "${agent} execution failed" "agent_execution_failed" "Subagent output unavailable or incomplete." "Mark report as draft and require manual verification."
     return 1
   fi
+
+  write_event "$stage_name" "$agent" "completed" "$model" "not_verified" "Completed $agent" ""
 fi
 
 end_time="$(date '+%Y-%m-%d %H:%M:%S')"
 {


→ Read deep-research-skill/scripts/opencode-research-runner.sh [offset=507, limit=30]
Now adding stage-level and run-level events. First, stage events:
✗ Edit deep-research-skill/scripts/opencode-research-runner.sh failed
Error: Found multiple matches for oldString. Provide more surrounding context to make the match unique.

← Edit deep-research-skill/scripts/opencode-research-runner.sh
Index: /Users/xpy/Documents/RichardHub/Git/deep-research-skill/scripts/opencode-research-runner.sh
===================================================================
--- /Users/xpy/Documents/RichardHub/Git/deep-research-skill/scripts/opencode-research-runner.sh
+++ /Users/xpy/Documents/RichardHub/Git/deep-research-skill/scripts/opencode-research-runner.sh
@@ -510,8 +510,9 @@
   local agent pid failed=0
 
   echo ""
   echo "== Stage: $stage_name =="
+  write_event "$stage_name" "" "started" "" "not_verified" "Stage $stage_name started" ""
 
   for agent in "${agents[@]}"; do
     if agent_enabled "$agent"; then
       run_agent "$agent" &
@@ -531,11 +532,14 @@
     fi
   done
 
   if [ "$failed" != "0" ]; then
+    write_event "$stage_name" "" "failed" "" "not_verified" "Stage $stage_name failed" "One or more agents failed"
     echo "ERROR: Stage failed: $stage_name"
     exit 1
   fi
+
+  write_event "$stage_name" "" "completed" "" "not_verified" "Stage $stage_name completed" ""
 }
 
 run_stage_sequential() {
   local stage_name="$1"


→ Read deep-research-skill/scripts/opencode-research-runner.sh [offset=538, limit=20]

← Edit deep-research-skill/scripts/opencode-research-runner.sh
Index: /Users/xpy/Documents/RichardHub/Git/deep-research-skill/scripts/opencode-research-runner.sh
===================================================================
--- /Users/xpy/Documents/RichardHub/Git/deep-research-skill/scripts/opencode-research-runner.sh
+++ /Users/xpy/Documents/RichardHub/Git/deep-research-skill/scripts/opencode-research-runner.sh
@@ -548,12 +548,15 @@
   local agent
 
   echo ""
   echo "== Stage: $stage_name =="
+  write_event "$stage_name" "" "started" "" "not_verified" "Stage $stage_name started" ""
 
   for agent in "${agents[@]}"; do
     run_agent "$agent"
   done
+
+  write_event "$stage_name" "" "completed" "" "not_verified" "Stage $stage_name completed" ""
 }
 
 run_stage() {
   if [ "$EXECUTION_MODE" = "parallel" ]; then


Now adding run_started and run_completed events. First, find the start of execution:
→ Read deep-research-skill/scripts/opencode-research-runner.sh [offset=620, limit=50]

← Edit deep-research-skill/scripts/opencode-research-runner.sh
Index: /Users/xpy/Documents/RichardHub/Git/deep-research-skill/scripts/opencode-research-runner.sh
===================================================================
--- /Users/xpy/Documents/RichardHub/Git/deep-research-skill/scripts/opencode-research-runner.sh
+++ /Users/xpy/Documents/RichardHub/Git/deep-research-skill/scripts/opencode-research-runner.sh
@@ -631,8 +631,10 @@
     suggested_databases_or_keywords:
 \`\`\`
 EOF
 
+write_event "run" "" "started" "" "not_verified" "Deep Research OpenCode run started" ""
+
 for agent in planner_agent source_agent long_context_agent analyst_agent scenario_agent writer_agent reviewer_agent; do
   if agent_enabled "$agent"; then
     requested_model="$( "$ROUTER" "$MODE" "$agent" )"
     echo "- $agent: requested_model=$requested_model; actual_model_detection_status=not_verified" >> "$summary_file"


→ Read deep-research-skill/scripts/opencode-research-runner.sh [offset=674, limit=20]

← Edit deep-research-skill/scripts/opencode-research-runner.sh
Index: /Users/xpy/Documents/RichardHub/Git/deep-research-skill/scripts/opencode-research-runner.sh
===================================================================
--- /Users/xpy/Documents/RichardHub/Git/deep-research-skill/scripts/opencode-research-runner.sh
+++ /Users/xpy/Documents/RichardHub/Git/deep-research-skill/scripts/opencode-research-runner.sh
@@ -676,10 +676,15 @@
 - model_route_execution_status: unable_to_verify
 - source_failure_log: $source_failure_log_file
 - execution_context: $execution_context_file
 - reporting_rule: Requested model routes must not be described as verified actual model usage.
+- events_log: $events_file
+- total_events: $(wc -l < "$events_file" 2>/dev/null || echo "0")
 EOF
 
+write_event "run" "" "completed" "" "not_verified" "Deep Research OpenCode run completed" ""
+
 echo ""
 echo "Deep Research OpenCode run complete."
 echo "Summary: $summary_file"
+echo "Events: $events_file"
 echo "Outputs: $OUTPUT_DIR/outputs"


# Todos
[✓] Create references/host-adapter-contract.md — multi-host integration contract
[✓] Update opencode-research-runner.sh to write events.ndjson
[✓] Create scripts/generic-research-runner.sh — host-neutral prompt/artifact generator
[✓] Create references/search-adapter-contract.md — search backend contract
[✓] Create eval/ directory with example tasks, rubric.yaml, run-eval.sh
[•] Update SKILL.md progressive loading + Host Integration sections
[•] Update references/opencode-runner.md — clarify OpenCode is one adapter
[•] Update references/output-rules.md — mention events.ndjson
[ ] Verify syntax, dry-run both runners, run eval harness

OpenCode runner updated with events.ndjson. Now updating documentation files:
← Edit deep-research-skill/SKILL.md
Index: /Users/xpy/Documents/RichardHub/Git/deep-research-skill/SKILL.md
===================================================================
--- /Users/xpy/Documents/RichardHub/Git/deep-research-skill/SKILL.md
+++ /Users/xpy/Documents/RichardHub/Git/deep-research-skill/SKILL.md
@@ -58,9 +58,9 @@
 - 来源失败日志：读 [references/source-failure-log.md](references/source-failure-log.md)。
 - 搜索工具方案（工具矩阵、搜索引擎选择、降级策略）：读 [references/search-tools.md](references/search-tools.md)。
 - 模型路由与模式：读 [model-routing.yaml](model-routing.yaml)。
 - 首次配置与本机私有凭证：运行 `scripts/setup.sh`；配置文件位于 `~/.config/deep-research-skill/config.env`。
-- 宿主集成：默认读本节 `Host Integration`；OpenCode 直接调用时再读 [references/opencode-runner.md](references/opencode-runner.md)，使用 `scripts/opencode-research-runner.sh`。
+- 宿主集成：默认读本节 `Host Integration` 和 `references/host-adapter-contract.md`；OpenCode 直接调用时再读 [references/opencode-runner.md](references/opencode-runner.md)，使用 `scripts/opencode-research-runner.sh`；Codex、Claude Code、CloudCode、GUI、TU/terminal 及其他外部编排器使用 `scripts/generic-research-runner.sh`。
 - 完整阶段流程：读 [references/workflow.md](references/workflow.md)。
 - 任务分类与研究框架：读 [references/task-REDACTED.md](references/task-REDACTED.md)。
 - Subagent 职责和输出契约：读 [references/subagents.md](references/subagents.md)。
 - 最终质量审计：读 [references/quality-review.md](references/quality-review.md)。


✗ Edit deep-research-skill/SKILL.md failed
Error: Could not find oldString in the file. It must match exactly, including whitespace, indentation, and line endings.

← Edit deep-research-skill/references/opencode-runner.md
Index: /Users/xpy/Documents/RichardHub/Git/deep-research-skill/references/opencode-runner.md
===================================================================
--- /Users/xpy/Documents/RichardHub/Git/deep-research-skill/references/opencode-runner.md
+++ /Users/xpy/Documents/RichardHub/Git/deep-research-skill/references/opencode-runner.md
@@ -1,6 +1,8 @@
 # OpenCode Runner
 
+> **Note**: OpenCode is ONE host adapter for the Deep Research protocol. For a complete overview of how different hosts (Codex, Claude Code, CloudCode, GUI, TU/terminal) integrate with the protocol, see `references/host-adapter-contract.md`. For host-neutral execution without OpenCode dependencies, use `scripts/generic-research-runner.sh`.
+
 Use `scripts/opencode-research-runner.sh` when Deep Research should be run directly through OpenCode with model routing.
 
 ## Command
 


← Edit deep-research-skill/references/opencode-runner.md
Index: /Users/xpy/Documents/RichardHub/Git/deep-research-skill/references/opencode-runner.md
===================================================================
--- /Users/xpy/Documents/RichardHub/Git/deep-research-skill/references/opencode-runner.md
+++ /Users/xpy/Documents/RichardHub/Git/deep-research-skill/references/opencode-runner.md
@@ -82,8 +82,9 @@
 
 - `run-summary.md`: mode, task path, model mapping, output files.
 - `execution-context.md`: requested model routes and actual model detection status.
 - `source_failure_log.md`: source/search/fetch failure log template for failed or insufficient source collection.
+- `events.ndjson`: structured event stream (one JSON object per line) with run_started, agent_started, agent_completed, agent_failed, stage_started, stage_completed, run_completed events.
 - `prompts/`: per-agent prompts sent to OpenCode.
 - `outputs/`: per-agent Markdown outputs.
 - `logs/`: per-agent timing and file metadata.
 


← Edit deep-research-skill/references/output-rules.md
Index: /Users/xpy/Documents/RichardHub/Git/deep-research-skill/references/output-rules.md
===================================================================
--- /Users/xpy/Documents/RichardHub/Git/deep-research-skill/references/output-rules.md
+++ /Users/xpy/Documents/RichardHub/Git/deep-research-skill/references/output-rules.md
@@ -100,9 +100,35 @@
 - 仍缺哪些真实数据。
 - 是否建议进入下一步。
 - 是否需要人工复核的高风险部分。
 - 必须补充核验的来源。
+- 进度事件日志路径（`events.ndjson`）。
 
+- 输出文件路径。
+- 报告类型。
+- 自动选择的运行模式。
+- 使用的研究框架。
+- 使用的数据来源类型（按 external_authoritative / external_media / local_vault / local_wiki / uploaded_files / model_reasoning 列举）。
+- 是否启用本地 Vault 检索：是/否。
+- 是否启用本地 Wiki 检索：是/否。
+- 启用的 Subagent。
+- 每个 Subagent 的请求模型与真实模型检测状态。
+- 真实模型检测状态。
+- 模型路由执行状态：真实切换 / 指令级建议 / 无法验证。
+- 搜索状态：成功 / 部分成功 / 失败。
+- 来源失败状态：有失败 / 全部成功。
+- 来源审计等级：PASS / CONDITIONAL_PASS / FAIL。
+- 审计等级：PASS / CONDITIONAL_PASS / FAIL。
+- 报告可用性：正式版 / 内部初稿 / 离线初稿 / 仅供参考。
+- 是否触发模型升级。
+- 是否触发 fallback。
+- 主要结论。
+- 主要修改/优化点。
+- 仍缺哪些真实数据。
+- 是否建议进入下一步。
+- 是否需要人工复核的高风险部分。
+- 必须补充核验的来源。
+
 ## Model Statement Rule
 
 模型使用说明只能写真实可检测状态：
 


→ Read deep-research-skill/SKILL.md [limit=15, offset=29]
The Host Integration section edit failed — let me find the exact text:
✗ Edit deep-research-skill/SKILL.md failed
Error: Could not find oldString in the file. It must match exactly, including whitespace, indentation, and line endings.

$ python3 -c "
import re

filepath = '/Users/xpy/Documents/RichardHub/Git/deep-research-skill/SKILL.md'
with open(filepath, 'r') as f:
    content = f.read()

old_block = '''- **通用搜索层**：\`scripts/search.sh\`，由 \`BRAVE_API_KEY\`、\`BOCHA_API_KEY\`、\`EXA_API_KEY\` 驱动。
- **通用模型路由层**：\`scripts/model-router.sh MODE AGENT\`，返回 \`provider/model\`。
- **通用输出层**：\`DEEP_RESEARCH_OUTPUT_DIR\`，由 setup 初始化，所有宿主默认写入该目录。'''

new_block = '''- **通用搜索层**：\`scripts/search.sh\`，由 \`BRAVE_API_KEY\`、\`BOCHA_API_KEY\`、\`EXA_API_KEY\` 驱动。搜索适配器契约见 \`references/search-adapter-contract.md\`。
- **通用模型路由层**：\`scripts/model-router.sh MODE AGENT\`，返回 \`provider/model\`。
- **通用 Runner 层**：\`scripts/generic-research-runner.sh\` 提供宿主无关的 prompt/artifact 生成器，支持 \`--dry-run\`、\`--parallel|--sequential\`，写入 \`run-summary.md\`、\`execution-context.md\`、\`source_failure_log.md\`、\`events.ndjson\`。
- **通用输出层**：\`DEEP_RESEARCH_OUTPUT_DIR\`，由 setup 初始化，所有宿主默认写入该目录。'''

if old_block in content:
    content = content.replace(old_block, new_block)
    with open(filepath, 'w') as f:
        f.write(content)
    print('SUCCESS: Host Integration search/routing/output lines updated')
else:
    print('NOT FOUND: checking content around line 34...')
    lines = content.split('\n')
    for i, line in enumerate(lines[32:40], start=33):
        print(f'  {i}: {repr(line[:80])}')
"

SUCCESS: Host Integration search/routing/output lines updated

Let me use a direct approach with bash to update the Host Integration section:
$ python3 -c "
filepath = '/Users/xpy/Documents/RichardHub/Git/deep-research-skill/SKILL.md'
with open(filepath, 'r') as f:
    content = f.read()

old_line = '- 宿主集成：默认读本节 \`Host Integration\`；OpenCode 直接调用时再读 [references/opencode-runner.md](references/opencode-runner.md)，使用 \`scripts/opencode-research-runner.sh\`。'
new_line = '- 宿主集成：默认读本节 \`Host Integration\` 和 [references/host-adapter-contract.md](references/host-adapter-contract.md)；OpenCode 直接调用时再读 [references/opencode-runner.md](references/opencode-runner.md)，使用 \`scripts/opencode-research-runner.sh\`；Codex、Claude Code、CloudCode、GUI、TU/terminal 及其他外部编排器使用 \`scripts/generic-research-runner.sh\`。'
new_line2 = '- 搜索工具方案与搜索适配器契约：读 [references/search-tools.md](references/search-tools.md) 和 [references/search-adapter-contract.md](references/search-adapter-contract.md)。'

if old_line in content:
    content = content.replace(old_line, new_line)
    # Also update the search tools line
    old_search = '- 搜索工具方案（工具矩阵、搜索引擎选择、降级策略）：读 [references/search-tools.md](references/search-tools.md)。'
    if old_search in content:
        content = content.replace(old_search, new_line2)
    with open(filepath, 'w') as f:
        f.write(content)
    print('SUCCESS: Updated Progressive Loading section')
else:
    # Check what's actually there
    lines = content.split('\n')
    for i, line in enumerate(lines[60:72], start=61):
        print(f'  {i}: {repr(line[:120])}')
"

61: '- 模型路由与模式：读 [model-routing.yaml](model-routing.yaml)。'
  62: '- 首次配置与本机私有凭证：运行 `scripts/setup.sh`；配置文件位于 `~/.config/deep-research-skill/config.env`。'
  63: '- 宿主集成：默认读本节 `Host Integration` 和 `references/host-adapter-contract.md`；OpenCode 直接调用时再读 [references/opencode-runner.md]'
  64: '- 完整阶段流程：读 [references/workflow.md](references/workflow.md)。'
  65: '- 任务分类与研究框架：读 [references/task-REDACTED.md](references/task-REDACTED.md)。'
  66: '- Subagent 职责和输出契约：读 [references/subagents.md](references/subagents.md)。'
  67: '- 最终质量审计：读 [references/quality-review.md](references/quality-review.md)。'
  68: '- 实际执行一致性检查：读 [references/execution-consistency.md](references/execution-consistency.md)。'
  69: '- 输出文件与交付汇报：读 [references/output-rules.md](references/output-rules.md)。'
  70: '- 用户业务上下文适配：涉及郑好停、阿顺数智、智慧停车、国企、城市治理、停车业务时读 [references/user-context.md](references/user-context.md)。'
  71: '- 报告模板：按任务类型读取 `templates/` 下对应模板；生成附录时再读 [references/template-appendix.md](references/template-appendix.md)。'
  72: ''

Now add `events.ndjson` and contract links to Progressive Loading section:
$ python3 -c "
filepath = '/Users/xpy/Documents/RichardHub/Git/deep-research-skill/SKILL.md'
with open(filepath, 'r') as f:
    content = f.read()

old_search = '- 搜索工具方案（工具矩阵、搜索引擎选择、降级策略）：读 [references/search-tools.md](references/search-tools.md)。'
new_search = '- 搜索工具方案与搜索适配器契约：读 [references/search-tools.md](references/search-tools.md) 和 [references/search-adapter-contract.md](references/search-adapter-contract.md)。'

if old_search in content:
    content = content.replace(old_search, new_search)
    with open(filepath, 'w') as f:
        f.write(content)
    print('SUCCESS: Updated search tools line')
else:
    print('NOT FOUND')
    for i, line in enumerate(content.split('\n')[55:65], start=56):
        if '搜索' in line or 'search' in line.lower():
            print(f'  {i}: {repr(line[:120])}')
"

SUCCESS: Updated search tools line

$ python3 -c "
filepath = '/Users/xpy/Documents/RichardHub/Git/deep-research-skill/SKILL.md'
with open(filepath, 'r') as f:
    content = f.read()

old_adapter = '该 runner 会按 \`mode + agent\` 调用 \`scripts/model-router.sh\`，默认采用分阶段并发：planner 先跑，source 与 long_context 并发，analyst 与 scenario 并发，writer 汇总，reviewer 最后审计。受限环境可用 \`--sequential\` 回退。详见 [references/opencode-runner.md](references/opencode-runner.md)。'
new_adapter = '该 runner 会按 \`mode + agent\` 调用 \`scripts/model-router.sh\`，默认采用分阶段并发：planner 先跑，source 与 long_context 并发，analyst 与 scenario 并发，writer 汇总，reviewer 最后审计。受限环境可用 \`--sequential\` 回退。详见 [references/opencode-runner.md](references/opencode-runner.md)。\n\n对于 Codex、Claude Code、CloudCode、GUI、TU/terminal 及其他外部编排器，使用宿主无关的通用 runner：\n\n\`\`\`bash\nSkills/deep-research-skill/scripts/generic-research-runner.sh MODE TASK_FILE [OUTPUT_DIR] [PROJECT_DIR]\n\`\`\`\n\n该通用 runner 不依赖任何特定宿主，生成完整的 prompt、artifact 和 events.ndjson 事件流，适合作为外部编排器的 prompt/artifact 生成层。详见 [references/host-adapter-contract.md](references/host-adapter-contract.md)。'

if old_adapter in content:
    content = content.replace(old_adapter, new_adapter)
    with open(filepath, 'w') as f:
        f.write(content)
    print('SUCCESS: Updated OpenCode Adapter section')
else:
    print('NOT FOUND')
"

SUCCESS: Updated OpenCode Adapter section

Also update the OpenCode Adapter section in SKILL.md:
# Todos
[✓] Create references/host-adapter-contract.md — multi-host integration contract
[✓] Update opencode-research-runner.sh to write events.ndjson
[✓] Create scripts/generic-research-runner.sh — host-neutral prompt/artifact generator
[✓] Create references/search-adapter-contract.md — search backend contract
[✓] Create eval/ directory with example tasks, rubric.yaml, run-eval.sh
[✓] Update SKILL.md progressive loading + Host Integration sections
[✓] Update references/opencode-runner.md — clarify OpenCode is one adapter
[✓] Update references/output-rules.md — mention events.ndjson
[•] Verify syntax, dry-run both runners, run eval harness

Documentation updated. Now verification phase:
$ /bin/bash -n /Users/xpy/Documents/RichardHub/Git/deep-research-skill/scripts/opencode-research-runner.sh && echo "PASS: opencode-research-runner.sh" || echo "FAIL: opencode-research-runner.sh"
PASS: opencode-research-runner.sh

$ /bin/bash -n /Users/xpy/Documents/RichardHub/Git/deep-research-skill/scripts/generic-research-runner.sh && echo "PASS: generic-research-runner.sh" || echo "FAIL: generic-research-runner.sh"
PASS: generic-research-runner.sh

$ /bin/bash -n /Users/xpy/Documents/RichardHub/Git/deep-research-skill/scripts/model-router.sh && echo "PASS: model-router.sh" || echo "FAIL: model-router.sh"
PASS: model-router.sh

$ /bin/bash -n /Users/xpy/Documents/RichardHub/Git/deep-research-skill/scripts/search.sh && echo "PASS: search.sh" || echo "FAIL: search.sh"
PASS: search.sh

$ /bin/bash -n /Users/xpy/Documents/RichardHub/Git/deep-research-skill/scripts/setup.sh && echo "PASS: setup.sh" || echo "FAIL: setup.sh"
PASS: setup.sh

$ /bin/bash -n /Users/xpy/Documents/RichardHub/Git/deep-research-skill/eval/run-eval.sh && echo "PASS: run-eval.sh" || echo "FAIL: run-eval.sh"
PASS: run-eval.sh

$ export CI=true DEBIAN_FRONTEND=noninteractive GIT_TERMINAL_PROMPT=0 GCM_INTERACTIVE=never HOMEBREW_NO_AUTO_UPDATE=1 GIT_EDITOR=: EDITOR=: VISUAL='' GIT_SEQUENCE_EDITOR=: GIT_MERGE_AUTOEDIT=no GIT_PAGER=cat PAGER=cat npm_config_yes=true PIP_NO_INPUT=1 YARN_ENABLE_IMMUTABLE_INSTALLS=false; cd /Users/xpy/Documents/RichardHub/Git && git diff --check -- deep-research-skill 2>&1
(no output)

All syntax checks pass. Now running dry-run tests and eval:
$ TASK_FILE="/tmp/deep-research-test-task.md"
OUTPUT_DIR="/tmp/deep-research-test-output"
REPO_ROOT="/Users/xpy/Documents/RichardHub/Git"

echo "# 智慧停车行业测试任务" > "$TASK_FILE"
echo "评估智慧停车在二线城市的市场规模和竞争格局。需要联网搜索最新行业数据。" >> "$TASK_FILE"

rm -rf "$OUTPUT_DIR"

echo "=== Testing generic-research-runner.sh ==="
/Users/xpy/Documents/RichardHub/Git/deep-research-skill/scripts/generic-research-runner.sh high_quality "$TASK_FILE" "$OUTPUT_DIR/generic" "$REPO_ROOT" --dry-run --sequential 2>&1

echo ""
echo "=== Artifact check for generic runner ==="
for artifact in run-summary.md execution-context.md source_failure_log.md events.ndjson; do
  if [ -f "$OUTPUT_DIR/generic/$artifact" ]; then
    echo "  [YES] $artifact"
  else
    echo "  [MISSING] $artifact"
  fi
done

echo ""
echo "=== Event count for generic runner ==="
wc -l "$OUTPUT_DIR/generic/events.ndjson" 2>/dev/null || echo "  No events file"

echo ""
echo "=== Testing opencode-research-runner.sh ==="
/Users/xpy/Documents/RichardHub/Git/deep-research-skill/scripts/opencode-research-runner.sh high_quality "$TASK_FILE" "$OUTPUT_DIR/opencode" "$REPO_ROOT" --dry-run --sequential 2>&1

echo ""
echo "=== Artifact check for opencode runner ==="
for artifact in run-summary.md execution-context.md source_failure_log.md events.ndjson; do
  if [ -f "$OUTPUT_DIR/opencode/$artifact" ]; then
    echo "  [YES] $artifact"
  else
    echo "  [MISSING] $artifact"
  fi
done

echo ""
echo "=== Event count for opencode runner ==="
wc -l "$OUTPUT_DIR/opencode/events.ndjson" 2>/dev/null || echo "  No events file"
=== Testing generic-research-runner.sh ===
WARNING: Local config not found: /Users/xpy/.config/deep-research-skill/config.env
Run /Users/xpy/Documents/RichardHub/Git/deep-research-skill/scripts/setup.sh to configure model providers, endpoints, credentials, and search API keys.

== Stage: stage_1_planning ==
Prepared planner_agent with model opencode-go/deepseek-v4-pro
Prompt: /tmp/deep-research-test-output/generic/prompts/01-planner_agent.md

== Stage: stage_2_evidence_collection ==
Prepared source_agent with model opencode-go/deepseek-v4-flash
Prompt: /tmp/deep-research-test-output/generic/prompts/02-source_agent.md
Prepared long_context_agent with model opencode-go/kimi-k2.6
Prompt: /tmp/deep-research-test-output/generic/prompts/03-long_context_agent.md

== Stage: stage_3_analysis_and_scenario ==
Prepared analyst_agent with model opencode-go/deepseek-v4-pro
Prompt: /tmp/deep-research-test-output/generic/prompts/04-analyst_agent.md
Prepared scenario_agent with model opencode-go/deepseek-v4-pro
Prompt: /tmp/deep-research-test-output/generic/prompts/05-scenario_agent.md

== Stage: stage_4_writing ==
Prepared writer_agent with model opencode-go/deepseek-v4-pro
Prompt: /tmp/deep-research-test-output/generic/prompts/06-writer_agent.md

== Stage: stage_5_review ==
Prepared reviewer_agent with model opencode-go/deepseek-v4-pro
Prompt: /tmp/deep-research-test-output/generic/prompts/07-reviewer_agent.md

Deep Research generic run complete.
Summary: /tmp/deep-research-test-output/generic/run-summary.md
Events: /tmp/deep-research-test-output/generic/events.ndjson
Outputs: /tmp/deep-research-test-output/generic/outputs

Artifacts produced:
  - run-summary.md: yes
  - execution-context.md: yes
  - source_failure_log.md: yes
  - events.ndjson: yes

=== Artifact check for generic runner ===
  [YES] run-summary.md
  [YES] execution-context.md
  [YES] source_failure_log.md
  [YES] events.ndjson

=== Event count for generic runner ===
      26 /tmp/deep-research-test-output/generic/events.ndjson

=== Testing opencode-research-runner.sh ===
WARNING: Local config not found: /Users/xpy/.config/deep-research-skill/config.env
Run /Users/xpy/Documents/RichardHub/Git/deep-research-skill/scripts/setup.sh to configure model providers, endpoints, credentials, and search API keys.

== Stage: planning ==
Prepared planner_agent with model opencode-go/deepseek-v4-pro
Prompt: /tmp/deep-research-test-output/opencode/prompts/01-planner_agent.md

== Stage: evidence_collection ==
Prepared source_agent with model opencode-go/deepseek-v4-flash
Prompt: /tmp/deep-research-test-output/opencode/prompts/02-source_agent.md
Prepared long_context_agent with model opencode-go/kimi-k2.6
Prompt: /tmp/deep-research-test-output/opencode/prompts/03-long_context_agent.md

== Stage: analysis_and_scenario ==
Prepared analyst_agent with model opencode-go/deepseek-v4-pro
Prompt: /tmp/deep-research-test-output/opencode/prompts/04-analyst_agent.md
Prepared scenario_agent with model opencode-go/deepseek-v4-pro
Prompt: /tmp/deep-research-test-output/opencode/prompts/05-scenario_agent.md

== Stage: writing ==
Prepared writer_agent with model opencode-go/deepseek-v4-pro
Prompt: /tmp/deep-research-test-output/opencode/prompts/06-writer_agent.md

== Stage: review ==
Prepared reviewer_agent with model opencode-go/deepseek-v4-pro
Prompt: /tmp/deep-research-test-output/opencode/prompts/07-reviewer_agent.md

Deep Research OpenCode run complete.
Summary: /tmp/deep-research-test-output/opencode/run-summary.md
Events: /tmp/deep-research-test-output/opencode/events.ndjson
Outputs: /tmp/deep-research-test-output/opencode/outputs

=== Artifact check for opencode runner ===
  [YES] run-summary.md
  [YES] execution-context.md
  [YES] source_failure_log.md
  [YES] events.ndjson

=== Event count for opencode runner ===
      26 /tmp/deep-research-test-output/opencode/events.ndjson

Both runners working. All 4 artifacts produced, 26 events each. Now running eval harness:
$ export DEEP_RESEARCH_EVAL_TEMP="/tmp/deep-research-eval-test" DEEP_RESEARCH_EVAL_RUNNER="generic" DEEP_RESEARCH_EVAL_REPO_ROOT="/Users/xpy/Documents/RichardHub/Git" DEEP_RESEARCH_EVAL_TASK="all"; /Users/xpy/Documents/RichardHub/Git/deep-research-skill/eval/run-eval.sh generic all 2>&1
=== Deep Research Eval Harness ===
Runner: generic
Task: all
Dry run: 0
Temp: /tmp/deep-research-eval-test


--- Evaluating: business_decision ---
  Running: /Users/xpy/Documents/RichardHub/Git/deep-research-skill/scripts/generic-research-runner.sh high_quality /tmp/deep-research-eval-test/business_decision-task.md /tmp/deep-research-eval-test/outputs/business_decision /Users/xpy/Documents/RichardHub/Git --dry-run --sequential
  [PASS] run-summary.md: /tmp/deep-research-eval-test/outputs/business_decision/run-summary.md
  [PASS] execution-context.md: /tmp/deep-research-eval-test/outputs/business_decision/execution-context.md
  [PASS] source_failure_log.md: /tmp/deep-research-eval-test/outputs/business_decision/source_failure_log.md
  [PASS] events.ndjson: /tmp/deep-research-eval-test/outputs/business_decision/events.ndjson
  [PASS] prompts/: /tmp/deep-research-eval-test/outputs/business_decision/prompts (has files)
  [PASS] outputs/: /tmp/deep-research-eval-test/outputs/business_decision/outputs (has files)
  [PASS] logs/: /tmp/deep-research-eval-test/outputs/business_decision/logs (has files)
  [FAIL] events: run_started: 'run_started' NOT found in /tmp/deep-research-eval-test/outputs/business_decision/events.ndjson
  [FAIL] events: run_completed: 'run_completed' NOT found in /tmp/deep-research-eval-test/outputs/business_decision/events.ndjson
  [PASS] events: all lines are valid JSON
  [PASS] summary: has model mapping: found 'requested_model' in /tmp/deep-research-eval-test/outputs/business_decision/run-summary.md
  [PASS] summary: has detection status: found 'actual_model_detection_status' in /tmp/deep-research-eval-test/outputs/business_decision/run-summary.md
  [PASS] context: has detection status: found 'actual_model_detection_status' in /tmp/deep-research-eval-test/outputs/business_decision/execution-context.md
  [PASS] context: has route status: found 'model_route_execution_status' in /tmp/deep-research-eval-test/outputs/business_decision/execution-context.md

  Result: FAIL

--- Evaluating: general_research ---
  Running: /Users/xpy/Documents/RichardHub/Git/deep-research-skill/scripts/generic-research-runner.sh balanced /tmp/deep-research-eval-test/general_research-task.md /tmp/deep-research-eval-test/outputs/general_research /Users/xpy/Documents/RichardHub/Git --dry-run --sequential
  [PASS] run-summary.md: /tmp/deep-research-eval-test/outputs/general_research/run-summary.md
  [PASS] execution-context.md: /tmp/deep-research-eval-test/outputs/general_research/execution-context.md
  [PASS] source_failure_log.md: /tmp/deep-research-eval-test/outputs/general_research/source_failure_log.md
  [PASS] events.ndjson: /tmp/deep-research-eval-test/outputs/general_research/events.ndjson
  [PASS] prompts/: /tmp/deep-research-eval-test/outputs/general_research/prompts (has files)
  [PASS] outputs/: /tmp/deep-research-eval-test/outputs/general_research/outputs (has files)
  [PASS] logs/: /tmp/deep-research-eval-test/outputs/general_research/logs (has files)
  [FAIL] events: run_started: 'run_started' NOT found in /tmp/deep-research-eval-test/outputs/general_research/events.ndjson
  [FAIL] events: run_completed: 'run_completed' NOT found in /tmp/deep-research-eval-test/outputs/general_research/events.ndjson
  [PASS] events: all lines are valid JSON
  [PASS] summary: has model mapping: found 'requested_model' in /tmp/deep-research-eval-test/outputs/general_research/run-summary.md
  [PASS] summary: has detection status: found 'actual_model_detection_status' in /tmp/deep-research-eval-test/outputs/general_research/run-summary.md
  [PASS] context: has detection status: found 'actual_model_detection_status' in /tmp/deep-research-eval-test/outputs/general_research/execution-context.md
  [PASS] context: has route status: found 'model_route_execution_status' in /tmp/deep-research-eval-test/outputs/general_research/execution-context.md

  Result: FAIL

--- Evaluating: government_report ---
  Running: /Users/xpy/Documents/RichardHub/Git/deep-research-skill/scripts/generic-research-runner.sh high_quality /tmp/deep-research-eval-test/government_report-task.md /tmp/deep-research-eval-test/outputs/government_report /Users/xpy/Documents/RichardHub/Git --dry-run --sequential
  [PASS] run-summary.md: /tmp/deep-research-eval-test/outputs/government_report/run-summary.md
  [PASS] execution-context.md: /tmp/deep-research-eval-test/outputs/government_report/execution-context.md
  [PASS] source_failure_log.md: /tmp/deep-research-eval-test/outputs/government_report/source_failure_log.md
  [PASS] events.ndjson: /tmp/deep-research-eval-test/outputs/government_report/events.ndjson
  [PASS] prompts/: /tmp/deep-research-eval-test/outputs/government_report/prompts (has files)
  [PASS] outputs/: /tmp/deep-research-eval-test/outputs/government_report/outputs (has files)
  [PASS] logs/: /tmp/deep-research-eval-test/outputs/government_report/logs (has files)
  [FAIL] events: run_started: 'run_started' NOT found in /tmp/deep-research-eval-test/outputs/government_report/events.ndjson
  [FAIL] events: run_completed: 'run_completed' NOT found in /tmp/deep-research-eval-test/outputs/government_report/events.ndjson
  [PASS] events: all lines are valid JSON
  [PASS] summary: has model mapping: found 'requested_model' in /tmp/deep-research-eval-test/outputs/government_report/run-summary.md
  [PASS] summary: has detection status: found 'actual_model_detection_status' in /tmp/deep-research-eval-test/outputs/government_report/run-summary.md
  [PASS] context: has detection status: found 'actual_model_detection_status' in /tmp/deep-research-eval-test/outputs/government_report/execution-context.md
  [PASS] context: has route status: found 'model_route_execution_status' in /tmp/deep-research-eval-test/outputs/government_report/execution-context.md

  Result: FAIL

--- Evaluating: investment_analysis ---
  Running: /Users/xpy/Documents/RichardHub/Git/deep-research-skill/scripts/generic-research-runner.sh high_quality /tmp/deep-research-eval-test/investment_analysis-task.md /tmp/deep-research-eval-test/outputs/investment_analysis /Users/xpy/Documents/RichardHub/Git --dry-run --sequential
  [PASS] run-summary.md: /tmp/deep-research-eval-test/outputs/investment_analysis/run-summary.md
  [PASS] execution-context.md: /tmp/deep-research-eval-test/outputs/investment_analysis/execution-context.md
  [PASS] source_failure_log.md: /tmp/deep-research-eval-test/outputs/investment_analysis/source_failure_log.md
  [PASS] events.ndjson: /tmp/deep-research-eval-test/outputs/investment_analysis/events.ndjson
  [PASS] prompts/: /tmp/deep-research-eval-test/outputs/investment_analysis/prompts (has files)
  [PASS] outputs/: /tmp/deep-research-eval-test/outputs/investment_analysis/outputs (has files)
  [PASS] logs/: /tmp/deep-research-eval-test/outputs/investment_analysis/logs (has files)
  [FAIL] events: run_started: 'run_started' NOT found in /tmp/deep-research-eval-test/outputs/investment_analysis/events.ndjson
  [FAIL] events: run_completed: 'run_completed' NOT found in /tmp/deep-research-eval-test/outputs/investment_analysis/events.ndjson
  [PASS] events: all lines are valid JSON
  [PASS] summary: has model mapping: found 'requested_model' in /tmp/deep-research-eval-test/outputs/investment_analysis/run-summary.md
  [PASS] summary: has detection status: found 'actual_model_detection_status' in /tmp/deep-research-eval-test/outputs/investment_analysis/run-summary.md
  [PASS] context: has detection status: found 'actual_model_detection_status' in /tmp/deep-research-eval-test/outputs/investment_analysis/execution-context.md
  [PASS] context: has route status: found 'model_route_execution_status' in /tmp/deep-research-eval-test/outputs/investment_analysis/execution-context.md

  Result: FAIL

--- Evaluating: technical_route ---
  Running: /Users/xpy/Documents/RichardHub/Git/deep-research-skill/scripts/generic-research-runner.sh high_quality /tmp/deep-research-eval-test/technical_route-task.md /tmp/deep-research-eval-test/outputs/technical_route /Users/xpy/Documents/RichardHub/Git --dry-run --sequential
  [PASS] run-summary.md: /tmp/deep-research-eval-test/outputs/technical_route/run-summary.md
  [PASS] execution-context.md: /tmp/deep-research-eval-test/outputs/technical_route/execution-context.md
  [PASS] source_failure_log.md: /tmp/deep-research-eval-test/outputs/technical_route/source_failure_log.md
  [PASS] events.ndjson: /tmp/deep-research-eval-test/outputs/technical_route/events.ndjson
  [PASS] prompts/: /tmp/deep-research-eval-test/outputs/technical_route/prompts (has files)
  [PASS] outputs/: /tmp/deep-research-eval-test/outputs/technical_route/outputs (has files)
  [PASS] logs/: /tmp/deep-research-eval-test/outputs/technical_route/logs (has files)
  [FAIL] events: run_started: 'run_started' NOT found in /tmp/deep-research-eval-test/outputs/technical_route/events.ndjson
  [FAIL] events: run_completed: 'run_completed' NOT found in /tmp/deep-research-eval-test/outputs/technical_route/events.ndjson
  [PASS] events: all lines are valid JSON
  [PASS] summary: has model mapping: found 'requested_model' in /tmp/deep-research-eval-test/outputs/technical_route/run-summary.md
  [PASS] summary: has detection status: found 'actual_model_detection_status' in /tmp/deep-research-eval-test/outputs/technical_route/run-summary.md
  [PASS] context: has detection status: found 'actual_model_detection_status' in /tmp/deep-research-eval-test/outputs/technical_route/execution-context.md
  [PASS] context: has route status: found 'model_route_execution_status' in /tmp/deep-research-eval-test/outputs/technical_route/execution-context.md

  Result: FAIL

========================================
Eval Summary
========================================
Tasks evaluated: 5
Passed: 0
Failed: 5

RESULT: SOME TASKS FAILED

$ head -3 /tmp/deep-research-eval-test/outputs/business_decision/events.ndjson 2>/dev/null; echo "---"; tail -3 /tmp/deep-research-eval-test/outputs/business_decision/events.ndjson 2>/dev/null
---

The eval fails because it searches for literal `run_started` but events use `phase=run, status=started`. Let me check actual events:
$ cat /tmp/deep-research-eval-test/outputs/business_decision/events.ndjson 2>/dev/null | head -5; echo "==="; wc -l /tmp/deep-research-eval-test/outputs/business_decision/events.ndjson 2>/dev/null; echo "==="; ls -la /tmp/deep-research-eval-test/outputs/business_decision/ 2>/dev/null
===
===

$ ls -la /tmp/deep-research-eval-test/ 2>/dev/null; echo "==="; ls /tmp/deep-research-eval-test/outputs/ 2>/dev/null
===

The eval script's grep patterns are wrong — events use `"phase":"run"` + `"status":"started"` not `run_started`. Fixing the eval:
$ python3 -c "
filepath = '/Users/xpy/Documents/RichardHub/Git/deep-research-skill/eval/run-eval.sh'
with open(filepath, 'r') as f:
    content = f.read()

# Fix the event content checks
old1 = 'check_content \"\$output_dir/events.ndjson\" \"run_started\" \"events: run_started\" || task_passed=0'
new1 = 'check_content \"\$output_dir/events.ndjson\" \"phase.*run.*status.*started\" \"events: run started\" || task_passed=0'
content = content.replace(old1, new1)

old2 = 'check_content \"\$output_dir/events.ndjson\" \"run_completed\" \"events: run_completed\" || task_passed=0'
new2 = 'check_content \"\$output_dir/events.ndjson\" \"phase.*run.*status.*completed\" \"events: run completed\" || task_passed=0'
content = content.replace(old2, new2)

with open(filepath, 'w') as f:
    f.write(content)
print('SUCCESS: Fixed eval event check patterns')
"

SUCCESS: Fixed eval event check patterns

Now re-run eval with fixed patterns:
$ export DEEP_RESEARCH_EVAL_TEMP="/tmp/deep-research-eval-test2" DEEP_RESEARCH_EVAL_RUNNER="generic" DEEP_RESEARCH_EVAL_REPO_ROOT="/Users/xpy/Documents/RichardHub/Git" DEEP_RESEARCH_EVAL_TASK="all"; /Users/xpy/Documents/RichardHub/Git/deep-research-skill/eval/run-eval.sh generic all 2>&1
=== Deep Research Eval Harness ===
Runner: generic
Task: all
Dry run: 0
Temp: /tmp/deep-research-eval-test2


--- Evaluating: business_decision ---
  Running: /Users/xpy/Documents/RichardHub/Git/deep-research-skill/scripts/generic-research-runner.sh high_quality /tmp/deep-research-eval-test2/business_decision-task.md /tmp/deep-research-eval-test2/outputs/business_decision /Users/xpy/Documents/RichardHub/Git --dry-run --sequential
  [PASS] run-summary.md: /tmp/deep-research-eval-test2/outputs/business_decision/run-summary.md
  [PASS] execution-context.md: /tmp/deep-research-eval-test2/outputs/business_decision/execution-context.md
  [PASS] source_failure_log.md: /tmp/deep-research-eval-test2/outputs/business_decision/source_failure_log.md
  [PASS] events.ndjson: /tmp/deep-research-eval-test2/outputs/business_decision/events.ndjson
  [PASS] prompts/: /tmp/deep-research-eval-test2/outputs/business_decision/prompts (has files)
  [PASS] outputs/: /tmp/deep-research-eval-test2/outputs/business_decision/outputs (has files)
  [PASS] logs/: /tmp/deep-research-eval-test2/outputs/business_decision/logs (has files)
  [PASS] events: run started: found 'phase.*run.*status.*started' in /tmp/deep-research-eval-test2/outputs/business_decision/events.ndjson
  [PASS] events: run completed: found 'phase.*run.*status.*completed' in /tmp/deep-research-eval-test2/outputs/business_decision/events.ndjson
  [PASS] events: all lines are valid JSON
  [PASS] summary: has model mapping: found 'requested_model' in /tmp/deep-research-eval-test2/outputs/business_decision/run-summary.md
  [PASS] summary: has detection status: found 'actual_model_detection_status' in /tmp/deep-research-eval-test2/outputs/business_decision/run-summary.md
  [PASS] context: has detection status: found 'actual_model_detection_status' in /tmp/deep-research-eval-test2/outputs/business_decision/execution-context.md
  [PASS] context: has route status: found 'model_route_execution_status' in /tmp/deep-research-eval-test2/outputs/business_decision/execution-context.md

  Result: PASS

--- Evaluating: general_research ---
  Running: /Users/xpy/Documents/RichardHub/Git/deep-research-skill/scripts/generic-research-runner.sh balanced /tmp/deep-research-eval-test2/general_research-task.md /tmp/deep-research-eval-test2/outputs/general_research /Users/xpy/Documents/RichardHub/Git --dry-run --sequential
  [PASS] run-summary.md: /tmp/deep-research-eval-test2/outputs/general_research/run-summary.md
  [PASS] execution-context.md: /tmp/deep-research-eval-test2/outputs/general_research/execution-context.md
  [PASS] source_failure_log.md: /tmp/deep-research-eval-test2/outputs/general_research/source_failure_log.md
  [PASS] events.ndjson: /tmp/deep-research-eval-test2/outputs/general_research/events.ndjson
  [PASS] prompts/: /tmp/deep-research-eval-test2/outputs/general_research/prompts (has files)
  [PASS] outputs/: /tmp/deep-research-eval-test2/outputs/general_research/outputs (has files)
  [PASS] logs/: /tmp/deep-research-eval-test2/outputs/general_research/logs (has files)
  [PASS] events: run started: found 'phase.*run.*status.*started' in /tmp/deep-research-eval-test2/outputs/general_research/events.ndjson
  [PASS] events: run completed: found 'phase.*run.*status.*completed' in /tmp/deep-research-eval-test2/outputs/general_research/events.ndjson
  [PASS] events: all lines are valid JSON
  [PASS] summary: has model mapping: found 'requested_model' in /tmp/deep-research-eval-test2/outputs/general_research/run-summary.md
  [PASS] summary: has detection status: found 'actual_model_detection_status' in /tmp/deep-research-eval-test2/outputs/general_research/run-summary.md
  [PASS] context: has detection status: found 'actual_model_detection_status' in /tmp/deep-research-eval-test2/outputs/general_research/execution-context.md
  [PASS] context: has route status: found 'model_route_execution_status' in /tmp/deep-research-eval-test2/outputs/general_research/execution-context.md

  Result: PASS

--- Evaluating: government_report ---
  Running: /Users/xpy/Documents/RichardHub/Git/deep-research-skill/scripts/generic-research-runner.sh high_quality /tmp/deep-research-eval-test2/government_report-task.md /tmp/deep-research-eval-test2/outputs/government_report /Users/xpy/Documents/RichardHub/Git --dry-run --sequential
  [PASS] run-summary.md: /tmp/deep-research-eval-test2/outputs/government_report/run-summary.md
  [PASS] execution-context.md: /tmp/deep-research-eval-test2/outputs/government_report/execution-context.md
  [PASS] source_failure_log.md: /tmp/deep-research-eval-test2/outputs/government_report/source_failure_log.md
  [PASS] events.ndjson: /tmp/deep-research-eval-test2/outputs/government_report/events.ndjson
  [PASS] prompts/: /tmp/deep-research-eval-test2/outputs/government_report/prompts (has files)
  [PASS] outputs/: /tmp/deep-research-eval-test2/outputs/government_report/outputs (has files)
  [PASS] logs/: /tmp/deep-research-eval-test2/outputs/government_report/logs (has files)
  [PASS] events: run started: found 'phase.*run.*status.*started' in /tmp/deep-research-eval-test2/outputs/government_report/events.ndjson
  [PASS] events: run completed: found 'phase.*run.*status.*completed' in /tmp/deep-research-eval-test2/outputs/government_report/events.ndjson
  [PASS] events: all lines are valid JSON
  [PASS] summary: has model mapping: found 'requested_model' in /tmp/deep-research-eval-test2/outputs/government_report/run-summary.md
  [PASS] summary: has detection status: found 'actual_model_detection_status' in /tmp/deep-research-eval-test2/outputs/government_report/run-summary.md
  [PASS] context: has detection status: found 'actual_model_detection_status' in /tmp/deep-research-eval-test2/outputs/government_report/execution-context.md
  [PASS] context: has route status: found 'model_route_execution_status' in /tmp/deep-research-eval-test2/outputs/government_report/execution-context.md

  Result: PASS

--- Evaluating: investment_analysis ---
  Running: /Users/xpy/Documents/RichardHub/Git/deep-research-skill/scripts/generic-research-runner.sh high_quality /tmp/deep-research-eval-test2/investment_analysis-task.md /tmp/deep-research-eval-test2/outputs/investment_analysis /Users/xpy/Documents/RichardHub/Git --dry-run --sequential
  [PASS] run-summary.md: /tmp/deep-research-eval-test2/outputs/investment_analysis/run-summary.md
  [PASS] execution-context.md: /tmp/deep-research-eval-test2/outputs/investment_analysis/execution-context.md
  [PASS] source_failure_log.md: /tmp/deep-research-eval-test2/outputs/investment_analysis/source_failure_log.md
  [PASS] events.ndjson: /tmp/deep-research-eval-test2/outputs/investment_analysis/events.ndjson
  [PASS] prompts/: /tmp/deep-research-eval-test2/outputs/investment_analysis/prompts (has files)
  [PASS] outputs/: /tmp/deep-research-eval-test2/outputs/investment_analysis/outputs (has files)
  [PASS] logs/: /tmp/deep-research-eval-test2/outputs/investment_analysis/logs (has files)
  [PASS] events: run started: found 'phase.*run.*status.*started' in /tmp/deep-research-eval-test2/outputs/investment_analysis/events.ndjson
  [PASS] events: run completed: found 'phase.*run.*status.*completed' in /tmp/deep-research-eval-test2/outputs/investment_analysis/events.ndjson
  [PASS] events: all lines are valid JSON
  [PASS] summary: has model mapping: found 'requested_model' in /tmp/deep-research-eval-test2/outputs/investment_analysis/run-summary.md
  [PASS] summary: has detection status: found 'actual_model_detection_status' in /tmp/deep-research-eval-test2/outputs/investment_analysis/run-summary.md
  [PASS] context: has detection status: found 'actual_model_detection_status' in /tmp/deep-research-eval-test2/outputs/investment_analysis/execution-context.md
  [PASS] context: has route status: found 'model_route_execution_status' in /tmp/deep-research-eval-test2/outputs/investment_analysis/execution-context.md

  Result: PASS

--- Evaluating: technical_route ---
  Running: /Users/xpy/Documents/RichardHub/Git/deep-research-skill/scripts/generic-research-runner.sh high_quality /tmp/deep-research-eval-test2/technical_route-task.md /tmp/deep-research-eval-test2/outputs/technical_route /Users/xpy/Documents/RichardHub/Git --dry-run --sequential
  [PASS] run-summary.md: /tmp/deep-research-eval-test2/outputs/technical_route/run-summary.md
  [PASS] execution-context.md: /tmp/deep-research-eval-test2/outputs/technical_route/execution-context.md
  [PASS] source_failure_log.md: /tmp/deep-research-eval-test2/outputs/technical_route/source_failure_log.md
  [PASS] events.ndjson: /tmp/deep-research-eval-test2/outputs/technical_route/events.ndjson
  [PASS] prompts/: /tmp/deep-research-eval-test2/outputs/technical_route/prompts (has files)
  [PASS] outputs/: /tmp/deep-research-eval-test2/outputs/technical_route/outputs (has files)
  [PASS] logs/: /tmp/deep-research-eval-test2/outputs/technical_route/logs (has files)
  [PASS] events: run started: found 'phase.*run.*status.*started' in /tmp/deep-research-eval-test2/outputs/technical_route/events.ndjson
  [PASS] events: run completed: found 'phase.*run.*status.*completed' in /tmp/deep-research-eval-test2/outputs/technical_route/events.ndjson
  [PASS] events: all lines are valid JSON
  [PASS] summary: has model mapping: found 'requested_model' in /tmp/deep-research-eval-test2/outputs/technical_route/run-summary.md
  [PASS] summary: has detection status: found 'actual_model_detection_status' in /tmp/deep-research-eval-test2/outputs/technical_route/run-summary.md
  [PASS] context: has detection status: found 'actual_model_detection_status' in /tmp/deep-research-eval-test2/outputs/technical_route/execution-context.md
  [PASS] context: has route status: found 'model_route_execution_status' in /tmp/deep-research-eval-test2/outputs/technical_route/execution-context.md

  Result: PASS

========================================
Eval Summary
========================================
Tasks evaluated: 5
Passed: 5
Failed: 0

RESULT: ALL TASKS PASSED

$ # Quick JSON validation of events
python3 -c "
import json
with open('/tmp/deep-research-test-output/generic/events.ndjson') as f:
    lines = f.readlines()
print(f'Total events: {len(lines)}')
phases = {}
statuses = {}
for i, line in enumerate(lines, 1):
    evt = json.loads(line.strip())
    p = evt.get('phase','?')
    s = evt.get('status','?')
    phases[p] = phases.get(p,0)+1
    statuses[s] = statuses.get(s,0)+1
    # Verify no secrets in any field
    for k,v in evt.items():
        if isinstance(v, str) and ('key' in k.lower() or 'secret' in k.lower() or 'token' in k.lower() or 'credential' in k.lower()):
            if v:
                print(f'  WARNING: potential secret in {k}')
print('Phases:', json.dumps(phases, indent=2))
print('Statuses:', json.dumps(statuses, indent=2))
print('JSON valid: YES')
# Check for API keys
full = open('/tmp/deep-research-test-output/generic/events.ndjson').read()
if 'sk-' in full or 'api_key' in full:
    print('SECURITY WARNING: potential API key found!')
else:
    print('Security: No API keys detected')
"
Total events: 26
Phases: {
  "run": 2,
  "stage_1_planning": 4,
  "stage_2_evidence_collection": 6,
  "stage_3_analysis_and_scenario": 6,
  "stage_4_writing": 4,
  "stage_5_review": 4
}
Statuses: {
  "started": 13,
  "completed": 13
}
JSON valid: YES
Security: No API keys detected

All 5 eval tasks passed, all 4 artifacts produced per task. Let me do final validation on events content:
$ grep -c "^-" /Users/xpy/Documents/RichardHub/Git/deep-research-skill/references/output-rules.md | head -1; echo "---"; grep "events.ndjson\|进度事件" /Users/xpy/Documents/RichardHub/Git/deep-research-skill/references/output-rules.md
68
---
- 进度事件日志路径（`events.ndjson`）。

Events validation: 26 events, balanced started/completed, no API keys. Let me verify the output-rules.md is intact:
# Todos
[✓] Create references/host-adapter-contract.md — multi-host integration contract
[✓] Update opencode-research-runner.sh to write events.ndjson
[✓] Create scripts/generic-research-runner.sh — host-neutral prompt/artifact generator
[✓] Create references/search-adapter-contract.md — search backend contract
[✓] Create eval/ directory with example tasks, rubric.yaml, run-eval.sh
[✓] Update SKILL.md progressive loading + Host Integration sections
[✓] Update references/opencode-runner.md — clarify OpenCode is one adapter
[✓] Update references/output-rules.md — mention events.ndjson
[✓] Verify syntax, dry-run both runners, run eval harness

All verification passes. Let me finalize the todo list and provide the summary:
## Result

**Status**: Done

### Files Changed

| File | Action | Description |
|------|--------|-------------|
| `references/host-adapter-contract.md` | **Created** | Multi-host adapter contract: config layer, agent invocation, model detection protocol, event schema, error codes, fallback behavior, host-specific notes, compliance checklist |
| `references/search-adapter-contract.md` | **Created** | Search backend contract: output formats, CLI flags, health checks, fallback order, failure logging, caching, MCP/native adapter guidance |
| `scripts/generic-research-runner.sh` | **Created** | Host-neutral runner (~560 lines): reads config, generates prompts/artifacts, writes `events.ndjson`, supports `--dry-run`/`--parallel`/`--sequential`, no OpenCode dependency |
| `eval/business_decision.yaml` | **Created** | Eval task: business decision scenario |
| `eval/government_report.yaml` | **Created** | Eval task: government report scenario |
| `eval/technical_route.yaml` | **Created** | Eval task: technical route scenario |
| `eval/investment_analysis.yaml` | **Created** | Eval task: investment analysis scenario |
| `eval/general_research.yaml` | **Created** | Eval task: general research scenario |
| `eval/rubric.yaml` | **Created** | Scoring rubric: global + per-task criteria with weights |
| `eval/run-eval.sh` | **Created** | Eval harness: runs runner in dry-run, validates all artifacts, checks event content, validates JSON |
| `scripts/opencode-research-runner.sh` | **Updated** | Added `events.ndjson` support: `write_event()` function, 26 events per run (run_started/completed, agent_started/completed/failed, stage_started/completed) |
| `SKILL.md` | **Updated** | Host Integration: added generic runner, search adapter contract, events.ndjson; Progressive Loading: added host-adapter-contract, search-adapter-contract, generic runner for non-OpenCode hosts; OpenCode Adapter: added generic runner alternative |
| `references/opencode-runner.md` | **Updated** | Added note clarifying OpenCode is ONE adapter; listed `events.ndjson` in outputs |
| `references/output-rules.md` | **Updated** | Added `events.ndjson` path to completion summary checklist |

### Tests Run

| Test | Result |
|------|--------|
| `bash -n` syntax check (6 .sh files) | **PASS** |
| `git diff --check` whitespace | **PASS** (no errors) |
| `generic-research-runner.sh --dry-run` | **PASS** — all 4 artifacts produced, 26 events |
| `opencode-research-runner.sh --dry-run` | **PASS** — all 4 artifacts produced, 26 events |
| `run-eval.sh` (5 task types, generic runner) | **PASS** — 5/5 tasks pass |
| `events.ndjson` JSON validity | **PASS** — all lines valid JSON |
| `events.ndjson` security scan | **PASS** — no API keys detected |

### Errors

None.

### Next Action

Codex review. No blockers.

### Risk Level

**Low**. Changes are additive:
- New files only in `deep-research-skill/`
- Existing `opencode-research-runner.sh` only augmented with event logging (backward compatible)
- No secrets, credentials, or environment variables modified
- All shell scripts compatible with macOS Bash 3.2 (no `mapfile`, no associative arrays)
