#!/usr/bin/env bash
# =============================================================================
# Logging Infrastructure Test
# =============================================================================

set -eo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "${SCRIPT_DIR}"

echo "=== Logging Infrastructure Tests ==="
echo ""

# Test 1: Makefile verify-logrotate target exists
echo "Test 1: verify-logrotate target in Makefile"
if grep -q "^verify-logrotate:" Makefile; then
    echo "✓ verify-logrotate target exists"
else
    echo "✗ verify-logrotate target missing"
    exit 1
fi
echo ""

# Test 2: Logrotate config file exists
echo "Test 2: Logrotate config file presence"
if [[ -f packaging/logrotate/ubopt ]]; then
    echo "✓ Logrotate config exists: packaging/logrotate/ubopt"
else
    echo "✗ Logrotate config missing"
    exit 1
fi
echo ""

# Test 3: Logrotate config has required directives
echo "Test 3: Logrotate config content"
if grep -q "/var/log/ubopt/ubopt.log" packaging/logrotate/ubopt && \
   grep -q "rotate" packaging/logrotate/ubopt && \
   grep -q "compress" packaging/logrotate/ubopt; then
    echo "✓ Logrotate config has required directives"
else
    echo "✗ Logrotate config missing directives"
    exit 1
fi
echo ""

# Test 4: Verify logrotate works
echo "Test 4: Run verify-logrotate target"
if make verify-logrotate 2>&1 | grep -q "Logrotate configuration"; then
    echo "✓ verify-logrotate target runs successfully"
else
    echo "✗ verify-logrotate target failed"
    exit 1
fi
echo ""

# Test 5: lib/common.sh has init_logging function
echo "Test 5: init_logging function in lib/common.sh"
if grep -q "^init_logging()" lib/common.sh; then
    echo "✓ init_logging function exists"
else
    echo "✗ init_logging function missing"
    exit 1
fi
echo ""

# Test 6: Log directory creation
echo "Test 6: Log directory and file creation"
source lib/common.sh
if [[ -d "${UBOPT_LOG_DIR}" ]] && [[ -f "${UBOPT_LOG_FILE}" ]]; then
    echo "✓ Log directory and file exist: ${UBOPT_LOG_FILE}"
else
    echo "✗ Log directory/file not created"
    exit 1
fi
echo ""

echo "=== All logging infrastructure tests passed ==="
