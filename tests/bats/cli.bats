#!/usr/bin/env bats
# Test suite for CLI functionality

setup() {
    # Get the directory where ubopt is located
    export UBOPT_CMD="${BATS_TEST_DIRNAME}/../../cmd/ubopt"
    
    # Ensure the command exists and is executable
    [[ -x "${UBOPT_CMD}" ]]
}

@test "ubopt --help shows usage" {
    run "${UBOPT_CMD}" --help
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Cool Llama" ]]
    [[ "$output" =~ "Usage:" ]]
}

@test "ubopt --version shows version" {
    run "${UBOPT_CMD}" --version
    [ "$status" -eq 0 ]
    [[ "$output" =~ "v1.0.0" ]]
}

@test "ubopt with no command shows help" {
    run "${UBOPT_CMD}"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Usage:" ]]
}

@test "ubopt with unknown command fails" {
    run "${UBOPT_CMD}" invalid-command
    [ "$status" -eq 1 ]
    [[ "$output" =~ "Unknown command" ]]
}

@test "ubopt update --help works" {
    run "${UBOPT_CMD}" update --help
    [ "$status" -eq 0 ]
}

@test "ubopt health --help works" {
    run "${UBOPT_CMD}" health --help
    [ "$status" -eq 0 ]
}

@test "ubopt --dry-run flag is recognized" {
    run "${UBOPT_CMD}" --dry-run health
    [ "$status" -eq 0 ]
}

@test "ubopt --verbose flag is recognized" {
    run "${UBOPT_CMD}" --verbose health
    [ "$status" -eq 0 ]
}

@test "ubopt supports combined flags" {
    run "${UBOPT_CMD}" --dry-run --verbose health
    [ "$status" -eq 0 ]
}
