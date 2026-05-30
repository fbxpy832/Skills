# OMA Model Recommendation

This report gives recommendations only. It does not modify OMA or OpenCode configuration.

No concrete model list was safely detected during preflight. Do not hard-code GPT, Claude, Gemini, or other external model names unless OpenCode / OMA reports them as available under the user's current plan.

## Role Strategy

planner agent:
Use a strong reasoning model with stable context and moderate cost. It plans architecture and task decomposition, not bulk coding.

coder agent:
Use a strong coding model with reliable tool use and instruction following. It performs actual file edits.

tester agent:
Use a fast, low-cost model with stable log analysis. It identifies commands, interprets failures, and suggests tests.

reviewer agent:
Use a strict reasoning model that is not too lenient. Prefer a different model from coder when available to reduce blind spots.

repair agent:
Use a patch-focused coding model. It may match coder or use a faster model for targeted fixes.

## OpenCode Go Notes

Use only models reported by OpenCode / OMA as available. If OpenCode Go does not support explicit model or agent selection, keep role separation prompt-based and let Codex perform final review.
