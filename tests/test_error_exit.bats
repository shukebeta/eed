#!/usr/bin/env bats

# Unit tests for error_exit function

setup() {
    REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
    TEST_DIR="$(mktemp -d)"
    cd "$TEST_DIR"

    # Source the common functions
    source "$REPO_ROOT/lib/eed_common.sh"
}

teardown() {
    cd /
    rm -rf "$TEST_DIR"
}

@test "error_exit: basic error message format" {
    run error_exit "Test error message"
    [ "$status" -eq 1 ]
    [[ "$output" == "✗ Error: Test error message" ]]
}

@test "error_exit: custom exit code" {
    run error_exit "Test error" 42
    [ "$status" -eq 42 ]
    [[ "$output" == "✗ Error: Test error" ]]
}

@test "error_exit: with usage hint" {
    run error_exit "Test error" 1 true
    [ "$status" -eq 1 ]
    [[ "$output" == *"✗ Error: Test error"* ]]
    [[ "$output" == *"Use 'eed --help' for usage information"* ]]
}

@test "error_exit: debug mode shows location info" {
    DEBUG_MODE=true run error_exit "Test error"
    [ "$status" -eq 1 ]
    [[ "$output" == *"✗ Error: Test error"* ]]
    [[ "$output" == *"Location:"* ]]
}

@test "error_exit: no debug info without debug mode" {
    DEBUG_MODE=false run error_exit "Test error"
    [ "$status" -eq 1 ]
    [[ "$output" == "✗ Error: Test error" ]]
    [[ "$output" != *"Location:"* ]]
}

@test "error_exit: custom second message" {
    run error_exit "Test error" 1 "This is a custom message"
    [ "$status" -eq 1 ]
    [[ "$output" == *"✗ Error: Test error"* ]]
    [[ "$output" == *"This is a custom message"* ]]
    [[ "$output" != *"Use 'eed --help'"* ]]
}

