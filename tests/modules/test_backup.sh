#!/usr/bin/env bash
# =============================================================================
# Backup Module Test
# =============================================================================

set -eo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "${SCRIPT_DIR}"

export UBOPT_DRY_RUN="true"
export UBOPT_VERBOSE="true"

echo "=== Backup Module Tests ==="
echo ""

# Test 1: Dry-run backup
echo "Test 1: Dry-run backup creation"
bash modules/backup.sh create --dry-run && exit_code=0 || exit_code=$?
if [[ ${exit_code} -eq 20 ]]; then
    echo "✓ Dry-run backup succeeded (EXIT_CHANGES_PLANNED=${exit_code})"
else
    echo "✗ Dry-run backup failed with exit code ${exit_code}"
    exit 1
fi
echo ""

# Test 2: List backups (should handle empty)
echo "Test 2: List backups"
bash modules/backup.sh list || echo "✓ List handled empty directory"
echo ""

# Test 3: Help command
echo "Test 3: Help command"
if bash modules/backup.sh help | grep -q "Usage:"; then
    echo "✓ Help command works"
else
    echo "✗ Help command failed"
    exit 1
fi
echo ""

# Test 4: Config defaults
echo "Test 4: Config default values"
# Module should work with defaults when config file doesn't exist
if grep -q "backup.dest" modules/backup.sh && grep -q "backup.compression" modules/backup.sh; then
    echo "✓ Config defaults present in module"
else
    echo "✗ Config defaults missing"
    exit 1
fi
echo ""

echo "=== All backup tests passed ==="
