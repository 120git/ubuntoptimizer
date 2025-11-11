#!/usr/bin/env bash
# =============================================================================
# Benchmark Module Test
# =============================================================================

set -eo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "${SCRIPT_DIR}"

export UBOPT_VERBOSE="false"

echo "=== Benchmark Module Tests ==="
echo ""

# Test 1: Help command
echo "Test 1: Help command"
if bash modules/benchmark.sh --help 2>&1 | grep -q "Benchmark Module"; then
    echo "✓ Help command works"
else
    echo "✗ Help command failed"
    exit 1
fi
echo ""

# Test 2: CPU benchmark with short duration
echo "Test 2: CPU benchmark (5 seconds)"
if bash modules/benchmark.sh --tests cpu --duration 5 2>&1 | grep -i "cpu benchmark" ; then
    echo "✓ CPU benchmark ran"
else
    echo "✗ CPU benchmark failed"
    exit 1
fi
echo ""

# Test 3: JSON output format
echo "Test 3: JSON output format"
output=$(bash modules/benchmark.sh --tests cpu --duration 3 --format json 2>/dev/null)
if echo "${output}" | grep -q '"test":' && echo "${output}" | grep -q '"host":'; then
    echo "✓ JSON output format valid"
else
    echo "✗ JSON output format invalid"
    exit 1
fi
echo ""

# Test 4: Multiple tests selection
echo "Test 4: Multiple tests (cpu,disk)"
output=$(bash modules/benchmark.sh --tests cpu,disk --duration 3 2>&1)
if echo "${output}" | grep -iq "cpu benchmark" && echo "${output}" | grep -iq "disk.*benchmark"; then
    echo "✓ Multiple test selection works"
else
    echo "✗ Multiple test selection failed"
    exit 1
fi
echo ""

# Test 5: Config defaults present
echo "Test 5: Config defaults in module"
if grep -q "benchmark.duration" modules/benchmark.sh && grep -q "benchmark.format" modules/benchmark.sh; then
    echo "✓ Config defaults present"
else
    echo "✗ Config defaults missing"
    exit 1
fi
echo ""

echo "=== All benchmark tests passed ==="
