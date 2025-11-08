#!/usr/bin/env bats
# Test suite for update module with dry-run

setup() {
    export UBOPT_CMD="${BATS_TEST_DIRNAME}/../../cmd/ubopt"
    [[ -x "${UBOPT_CMD}" ]]
}

@test "ubopt update check --dry-run succeeds" {
    run "${UBOPT_CMD}" update check --dry-run
    # Exit code 0 (no updates) or 20 (updates available) are both valid
    [[ "$status" -eq 0 || "$status" -eq 20 ]]
}

@test "ubopt update check does not require root" {
    run "${UBOPT_CMD}" update check
    # Should work without root for checking
    [[ "$status" -eq 0 || "$status" -eq 20 ]]
}

@test "ubopt update apply --dry-run does not modify system" {
    # Store initial package count (if we can)
    if command -v dpkg >/dev/null 2>&1; then
        before=$(dpkg -l | wc -l)
    elif command -v rpm >/dev/null 2>&1; then
        before=$(rpm -qa | wc -l)
    elif command -v pacman >/dev/null 2>&1; then
        before=$(pacman -Q | wc -l)
    else
        skip "No supported package manager found"
    fi
    
    # Run dry-run (without sudo, should not fail)
    run "${UBOPT_CMD}" update apply --dry-run
    [ "$status" -eq 0 ]
    
    # Verify package count unchanged
    if command -v dpkg >/dev/null 2>&1; then
        after=$(dpkg -l | wc -l)
    elif command -v rpm >/dev/null 2>&1; then
        after=$(rpm -qa | wc -l)
    elif command -v pacman >/dev/null 2>&1; then
        after=$(pacman -Q | wc -l)
    fi
    
    [ "$before" -eq "$after" ]
}

@test "ubopt update apply --dry-run shows what would be done" {
    run "${UBOPT_CMD}" update apply --dry-run --verbose
    [ "$status" -eq 0 ]
    [[ "$output" =~ "DRY-RUN" ]]
}

@test "ubopt update apply --security --dry-run works" {
    run "${UBOPT_CMD}" update apply --security --dry-run
    [ "$status" -eq 0 ]
}

@test "ubopt update check returns appropriate exit codes" {
    run "${UBOPT_CMD}" update check
    # 0 = no updates, 20 = updates available, 1 = error
    [[ "$status" -eq 0 || "$status" -eq 20 || "$status" -eq 1 ]]
}

@test "ubopt update --dry-run does not create backup files" {
    backup_dir="/var/backups/ubopt"
    
    # Count existing backups
    if [[ -d "$backup_dir" ]]; then
        before=$(find "$backup_dir" -type f 2>/dev/null | wc -l)
    else
        before=0
    fi
    
    # Run dry-run
    run "${UBOPT_CMD}" update apply --dry-run
    [ "$status" -eq 0 ]
    
    # Count backups after
    if [[ -d "$backup_dir" ]]; then
        after=$(find "$backup_dir" -type f 2>/dev/null | wc -l)
    else
        after=0
    fi
    
    # Should be the same (no new backups in dry-run)
    [ "$before" -eq "$after" ]
}
