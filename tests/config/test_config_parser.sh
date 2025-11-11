#!/usr/bin/env bash
# =============================================================================
# Config Parser Test Suite
# Tests nested YAML parsing, arrays, and validation
# =============================================================================

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "${SCRIPT_DIR}"

# Source the config parser
source lib/common.sh
source tools/config.sh

# Test results
TESTS_PASSED=0
TESTS_FAILED=0

# Test helper
test_assert() {
    local desc="$1"
    local expected="$2"
    local actual="$3"
    
    if [[ "${expected}" == "${actual}" ]]; then
        echo "✓ ${desc}"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo "✗ ${desc}"
        echo "  Expected: ${expected}"
        echo "  Actual: ${actual}"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
}

# Set config file to example
export UBOPT_CONFIG_FILE="${SCRIPT_DIR}/etc/ubopt.example.yaml"

echo "=== Config Parser Tests ==="
echo "Config file: ${UBOPT_CONFIG_FILE}"
echo ""

# Load config
cfg_load "${UBOPT_CONFIG_FILE}"
echo "Loaded ${#CONFIG_CACHE[@]} config keys"
echo ""

echo "=== Testing Nested Keys ==="

# Test simple nested keys
test_assert "logging.level" "info" "$(cfg_get 'logging.level')"
test_assert "logging.directory" "/var/log/ubopt" "$(cfg_get 'logging.directory')"
test_assert "logging.json" "true" "$(cfg_get 'logging.json')"

# Test deeper nesting
test_assert "hardening.ssh.password_auth" "false" "$(cfg_get 'hardening.ssh.password_auth')"
test_assert "hardening.ssh.root_login" "false" "$(cfg_get 'hardening.ssh.root_login')"
test_assert "hardening.ssh.key_only" "true" "$(cfg_get 'hardening.ssh.key_only')"
test_assert "hardening.ssh.port" "22" "$(cfg_get 'hardening.ssh.port')"

# Test sysctl nested keys
test_assert "hardening.sysctl.ipv4_forward" "0" "$(cfg_get 'hardening.sysctl.ipv4_forward')"
test_assert "hardening.sysctl.ipv6_ra_accept" "0" "$(cfg_get 'hardening.sysctl.ipv6_ra_accept')"

# Test auditd nested keys
test_assert "hardening.auditd.enabled" "true" "$(cfg_get 'hardening.auditd.enabled')"
test_assert "hardening.auditd.suid_monitoring" "true" "$(cfg_get 'hardening.auditd.suid_monitoring')"

# Test backup config
test_assert "backup.dest" "/var/backups/ubopt" "$(cfg_get 'backup.dest')"
test_assert "backup.compression" "xz" "$(cfg_get 'backup.compression')"
test_assert "backup.mode" "tar" "$(cfg_get 'backup.mode')"
test_assert "backup.retention.count" "7" "$(cfg_get 'backup.retention.count')"
test_assert "backup.retention.days" "30" "$(cfg_get 'backup.retention.days')"

# Test benchmark config
test_assert "benchmark.duration" "30" "$(cfg_get 'benchmark.duration')"
test_assert "benchmark.format" "json" "$(cfg_get 'benchmark.format')"
test_assert "benchmark.cpu.threads" "auto" "$(cfg_get 'benchmark.cpu.threads')"
test_assert "benchmark.disk.size_mb" "100" "$(cfg_get 'benchmark.disk.size_mb')"

echo ""
echo "=== Testing Arrays ==="

# Test backup includes array
echo "Testing backup.includes[]:"
includes_count=0
while IFS= read -r item; do
    echo "  - ${item}"
    includes_count=$((includes_count + 1))
done < <(cfg_get_array 'backup.includes')
test_assert "backup.includes array count >= 1" "true" "$([[ ${includes_count} -ge 1 ]] && echo true || echo false)"

# Test backup excludes array
echo "Testing backup.excludes[]:"
excludes_count=0
while IFS= read -r item; do
    echo "  - ${item}"
    excludes_count=$((excludes_count + 1))
done < <(cfg_get_array 'backup.excludes')
test_assert "backup.excludes array count >= 1" "true" "$([[ ${excludes_count} -ge 1 ]] && echo true || echo false)"

# Test benchmark tests array
echo "Testing benchmark.tests[]:"
tests_count=0
while IFS= read -r item; do
    echo "  - ${item}"
    tests_count=$((tests_count + 1))
done < <(cfg_get_array 'benchmark.tests')
test_assert "benchmark.tests array count" "3" "${tests_count}"

# Test hardening auditd rules array
echo "Testing hardening.auditd.rules[]:"
rules_count=0
while IFS= read -r item; do
    echo "  - ${item}"
    rules_count=$((rules_count + 1))
done < <(cfg_get_array 'hardening.auditd.rules')
test_assert "hardening.auditd.rules array count" "3" "${rules_count}"

echo ""
echo "=== Testing Defaults ==="

# Test non-existent keys with defaults
test_assert "Default value" "default_value" "$(cfg_get 'nonexistent.key' 'default_value')"
test_assert "Empty default" "" "$(cfg_get 'another.missing.key' '')"

echo ""
echo "=== Testing cfg_has ==="

# Test key existence
if cfg_has 'logging.level'; then
    echo "✓ cfg_has: logging.level exists"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo "✗ cfg_has: logging.level should exist"
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi

if ! cfg_has 'nonexistent.key'; then
    echo "✓ cfg_has: nonexistent.key does not exist"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo "✗ cfg_has: nonexistent.key should not exist"
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi

echo ""
echo "=== Testing Config Validation ==="

# Test validation function
if cfg_validate; then
    echo "✓ Config validation passed"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo "✗ Config validation failed"
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi

echo ""
echo "=== Test Summary ==="
echo "Passed: ${TESTS_PASSED}"
echo "Failed: ${TESTS_FAILED}"
echo ""

if [[ ${TESTS_FAILED} -eq 0 ]]; then
    echo "✓ All tests passed!"
    exit 0
else
    echo "✗ Some tests failed"
    exit 1
fi
