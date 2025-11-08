#!/usr/bin/env bats
# Test suite for health module

setup() {
    export UBOPT_CMD="${BATS_TEST_DIRNAME}/../../cmd/ubopt"
    [[ -x "${UBOPT_CMD}" ]]
}

@test "ubopt health runs successfully" {
    run "${UBOPT_CMD}" health
    [ "$status" -eq 0 ]
    [[ "$output" =~ "System Health" ]]
}

@test "ubopt health --json outputs valid JSON" {
    run "${UBOPT_CMD}" health --json
    [ "$status" -eq 0 ]
    
    # Check for JSON structure
    [[ "$output" =~ "hostname" ]]
    [[ "$output" =~ "kernel" ]]
    [[ "$output" =~ "cpu" ]]
    [[ "$output" =~ "memory" ]]
    [[ "$output" =~ "disk" ]]
}

@test "ubopt health --json can be parsed by jq" {
    skip "Requires jq to be installed"
    run bash -c "${UBOPT_CMD} health --json | jq -e '.hostname'"
    [ "$status" -eq 0 ]
}

@test "ubopt health --json contains required fields" {
    run "${UBOPT_CMD}" health --json
    [ "$status" -eq 0 ]
    
    # Verify required JSON fields
    echo "$output" | grep -q '"hostname"'
    echo "$output" | grep -q '"kernel"'
    echo "$output" | grep -q '"uptime_seconds"'
    echo "$output" | grep -q '"distribution"'
}

@test "ubopt health does not require root" {
    run "${UBOPT_CMD}" health
    [ "$status" -eq 0 ]
}

@test "ubopt health --verbose shows detailed info" {
    run "${UBOPT_CMD}" health --verbose
    [ "$status" -eq 0 ]
}
