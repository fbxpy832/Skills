#!/usr/bin/env bash
# hermes-dev-skill/scripts/phases/01_clarify.sh
# Phase 1: requirements clarification. This phase is driven by Hermes
# (the LLM), not by a script. The script exists as a marker so the
# orchestrator can invoke "the phase 1 entry point" uniformly. It is a
# no-op; Hermes handles the dialogue directly.
set -euo pipefail
JOB_ID="${1:-}"
if [ -z "$JOB_ID" ]; then
    echo "usage: $0 <job_id>" >&2
    exit 1
fi
echo "[phase1/clarify] job=$JOB_ID — driven by Hermes, no-op script"
exit 0
