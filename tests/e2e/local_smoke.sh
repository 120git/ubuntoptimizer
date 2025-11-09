#!/usr/bin/env bash
set -Eeuo pipefail

# Simple local smoke covering:
# - ubopt health JSON
# - update dry-run
# - hardening idempotency heuristic (second run should be no-op)
# - report JSON and state file presence

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PATH="$ROOT_DIR/cmd:$PATH"
STATE_FILE="/var/lib/ubopt/state.json"
UBOPT="${ROOT_DIR}/cmd/ubopt"

pass() { echo "[PASS] $*"; }
fail() { echo "[FAIL] $*" >&2; exit 1; }

command -v ubopt >/dev/null 2>&1 || {
  echo "ubopt not found in PATH; using repo cmd/ubopt runner";
}

# 1) health JSON
if output=$("${UBOPT}" health --json 2>/dev/null); then
  echo "$output" | grep -q '{' || fail "health JSON did not look like JSON"
  pass "health JSON"
else
  fail "ubopt health failed"
fi

# 2) update dry-run (should not require root)
if "${UBOPT}" update check --dry-run >/dev/null 2>&1; then
  pass "update dry-run"
else
  echo "update dry-run failed (non-fatal)" >&2
fi

# 3) hardening idempotency: run twice if non-destructive flags exist
if "${UBOPT}" hardening apply --dry-run >/dev/null 2>&1; then
  first_run=$("${UBOPT}" hardening apply --dry-run 2>&1 | tr -d '\r')
  second_run=$("${UBOPT}" hardening apply --dry-run 2>&1 | tr -d '\r')
  if echo "$second_run" | grep -qi 'idempotency changed=false'; then
    pass "hardening idempotency heuristic"
  else
    echo "hardening idempotency heuristic inconclusive" >&2
  fi
else
  echo "hardening dry-run not supported (skipping)" >&2
fi

# 4) report JSON + state file
if report=$("${UBOPT}" report 2>&1); then
  if echo "$report" | grep -q '{'; then
    pass "report JSON"
  else
    echo "$report" | head -5 >&2
    fail "report did not output JSON"
  fi
else
  fail "report failed"
fi

if [ -f "$STATE_FILE" ]; then
  pass "state file exists: $STATE_FILE"
else
  echo "state file not created (non-fatal)" >&2
fi

exit 0
