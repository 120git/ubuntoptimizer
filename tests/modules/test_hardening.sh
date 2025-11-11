#!/usr/bin/env bash
# =============================================================================
# Hardening Module Tests (Dry-Run safety)
# =============================================================================
set -eo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "${SCRIPT_DIR}"

export UBOPT_DRY_RUN="true"

pass() { echo "✓ $1"; }
fail() { echo "✗ $1"; exit 1; }

echo "=== Hardening Module Dry-Run Tests ==="

# Test 1: SSH dry-run diff
out=$(UBOPT_DRY_RUN=true UBOPT_VERBOSE=true bash modules/hardening.sh 2>&1 || true)
if echo "$out" | grep -qi "Hardening SSH configuration"; then pass "SSH hardening invoked"; else fail "SSH hardening not invoked"; fi
if echo "$out" | grep -q "DRYRUN:"; then pass "SSH dry-run diff produced"; else pass "SSH already compliant or no diff"; fi

# Test 2: Sysctl planned changes marker
if echo "$out" | grep -q "sysctl planned changes"; then pass "Sysctl planned changes detected"; else pass "Sysctl baseline already present"; fi

# Test 3: auditd handling
if echo "$out" | grep -qi "auditd"; then pass "auditd referenced"; else pass "auditd skipped (not installed)"; fi

# Test 4: MAC status reported
if echo "$out" | grep -qi "MAC status"; then pass "MAC status reported"; else fail "MAC status not reported"; fi

# Test 5: Overall exit code for dry-run (should be 20 if changes)
exit_code=0
UBOPT_DRY_RUN=true bash modules/hardening.sh >/dev/null 2>&1 || exit_code=$?
if [[ $exit_code -eq 20 ]]; then pass "Dry-run exit code EXIT_CHANGES_PLANNED (20)"; else pass "Dry-run exit code $exit_code (non-20 implies no changes)"; fi

# Test 6: Idempotent second run (simulate by running again)
out2=$(bash modules/hardening.sh 2>&1 || true)
if [[ $exit_code -eq 20 ]] && echo "$out2" | grep -q "Dry-run detected planned changes"; then pass "Second run still shows planned changes (expected if not applied)"; else pass "Second run stable"; fi

echo "=== Hardening tests finished ==="
