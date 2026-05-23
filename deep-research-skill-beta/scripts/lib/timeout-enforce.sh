# =============================================================================
# lib/timeout-enforce.sh — Shared timeout enforcement for knowledge adapters
# =============================================================================
# Source this file AFTER arg parsing and validation but BEFORE main logic.
# Expects: TIMEOUT, ORIGINAL_ARGS, SCRIPT_DIR to be set in the calling context.
# On timeout: prints "ERROR: timeout" to stderr and exits 2.
# =============================================================================

if [ "${TIMEOUT:-0}" -gt 0 ] 2>/dev/null && [ -z "${_DEEP_RESEARCH_IN_TIMEOUT:-}" ]; then
  export _DEEP_RESEARCH_IN_TIMEOUT=1
  _D_R_RC=0

  if command -v timeout &>/dev/null; then
    timeout "$TIMEOUT" "$0" "${ORIGINAL_ARGS[@]}" || _D_R_RC=$?
  elif command -v gtimeout &>/dev/null; then
    gtimeout "$TIMEOUT" "$0" "${ORIGINAL_ARGS[@]}" || _D_R_RC=$?
  else
    # python3 fallback: use Popen + process group kill to ensure entire
    # process tree (including orphaned children like sleep/rg) is terminated.
    python3 -c "
import subprocess, sys, os, signal

TIMEOUT = ${TIMEOUT}
proc = subprocess.Popen(sys.argv[1:], start_new_session=True)
try:
    proc.wait(timeout=TIMEOUT)
except subprocess.TimeoutExpired:
    # Kill entire process group — kills the child AND its descendants
    try:
        os.killpg(os.getpgid(proc.pid), signal.SIGKILL)
    except ProcessLookupError:
        pass
    proc.wait()
    sys.exit(124)

sys.exit(proc.returncode)
" "$0" "${ORIGINAL_ARGS[@]}" || _D_R_RC=$?
  fi

  if [ "$_D_R_RC" = 124 ]; then
    echo "ERROR: timeout" >&2
    exit 2
  fi
  exit "$_D_R_RC"
fi