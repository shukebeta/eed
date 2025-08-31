#!/usr/bin/env bats

# Unit tests for safety override functions

setup() {
    # Source the functions we need to test
    source "$BATS_TEST_DIRNAME/../lib/eed_validator.sh"
    source "$BATS_TEST_DIRNAME/../lib/eed_regex_patterns.sh"
}

# === determine_ordering Tests ===

@test "determine_ordering identifies single operation" {
    run determine_ordering "5d"
    [ "$status" -eq 0 ]
    [ "$output" = "single" ]
}

@test "determine_ordering identifies ascending pattern" {
    run determine_ordering $'1d\n2d\n3d'
    [ "$status" -eq 0 ]
    [ "$output" = "ascending" ]
}

@test "determine_ordering identifies unordered pattern" {
    run determine_ordering $'3d\n1d\n2d'
    [ "$status" -eq 0 ]
    [ "$output" = "unordered" ]
}