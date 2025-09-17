#!/usr/bin/env bats

# Integration tests for error_exit function usage in main eed script

setup() {
    REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
    TEST_DIR="$(mktemp -d)"
    cd "$TEST_DIR"

    SCRIPT_UNDER_TEST="$REPO_ROOT/eed"
}

teardown() {
    cd /
    rm -rf "$TEST_DIR"
}

@test "error_exit integration: File path is required" {
    run "$SCRIPT_UNDER_TEST"
    [ "$status" -eq 1 ]
    [[ "$output" == *"✗ Error: File path is required"* ]]
    [[ "$output" == *"Use 'eed --help' for usage information"* ]]
}

@test "error_exit integration: Too many arguments (stdin case)" {
    run "$SCRIPT_UNDER_TEST" file.txt script1 script2 script3
    [ "$status" -eq 1 ]
    [[ "$output" == *"✗ Error: Too many arguments"* ]]
    [[ "$output" == *"Use 'eed --help' for usage information"* ]]
}

@test "error_exit integration: Too many arguments (flag case)" {
    run "$SCRIPT_UNDER_TEST" file.txt script1 script2
    [ "$status" -eq 1 ]
    [[ "$output" == *"✗ Error: Too many arguments"* ]]
    [[ "$output" == *"Use 'eed --help' for usage information"* ]]
}

@test "error_exit integration: Debug mode shows location info" {
    run "$SCRIPT_UNDER_TEST" --debug
    [ "$status" -eq 1 ]
    [[ "$output" == *"✗ Error: File path is required"* ]]
    [[ "$output" == *"Location:"* ]]
    [[ "$output" == *"eed:"* ]]

}
@test "error_exit integration: Unknown option" {
    run "$SCRIPT_UNDER_TEST" --invalid-flag
    [ "$status" -eq 1 ]
    [[ "$output" == *"✗ Error: Unknown option '--invalid-flag'"* ]]
    [[ "$output" == *"Use 'eed --help' for usage information"* ]]
}


