#!/usr/bin/env bats

# Unit tests for safety override functions

setup() {
    # Source the functions we need to test
    source "$BATS_TEST_DIRNAME/../lib/eed_validator.sh"
    source "$BATS_TEST_DIRNAME/../lib/eed_regex_patterns.sh"
}

# === has_complex_patterns Tests ===

@test "has_complex_patterns identifies simple commands as non-complex" {
    run has_complex_patterns "5d"
    [ "$status" -eq 1 ]  # Should return 1 (false) for simple patterns
}

@test "has_complex_patterns identifies global commands as complex" {
    run has_complex_patterns "g/pattern/d"
    [ "$status" -eq 0 ]  # Should return 0 (true) for complex patterns
}

@test "has_complex_patterns identifies move commands as complex" {
    run has_complex_patterns "5m10"
    [ "$status" -eq 0 ]  # Should return 0 (true) for complex patterns
}

@test "has_complex_patterns identifies transfer commands as complex" {
    run has_complex_patterns "1,3t7"
    [ "$status" -eq 0 ]  # Should return 0 (true) for complex patterns
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