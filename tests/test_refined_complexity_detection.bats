#!/usr/bin/env bats

# Tests for refined complexity detection focusing on mixed addressing modes

setup() {
    REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
    source "$REPO_ROOT/lib/eed_validator.sh"
}

# Single addressing modes should be safe
@test "refined complexity: single search pattern is safe" {
    local script="/pattern/c
replacement
.
w
q"
    run no_complex_patterns "$script"
    [ "$status" -eq 0 ]  # Safe (not complex)
}

@test "refined complexity: single global operation is safe" {
    local script="g/pattern/d
w
q"
    run no_complex_patterns "$script"
    [ "$status" -eq 0 ]  # Safe (not complex)
}

@test "refined complexity: single numeric operation is safe" {
    local script="1c
replacement
.
w
q"
    run no_complex_patterns "$script"
    [ "$status" -eq 0 ]  # Safe (not complex)
}

@test "refined complexity: single dollar operation is safe" {
    local script="$d
w
q"
    run no_complex_patterns "$script"
    [ "$status" -eq 0 ]  # Safe (not complex)
}

# Mixed addressing modes should be complex
@test "refined complexity: search + numeric is complex" {
    local script="/pattern/c
replacement
.
5d
w
q"
    run no_complex_patterns "$script"
    [ "$status" -eq 1 ]  # Complex
}

@test "refined complexity: global + numeric is complex" {
    local script="g/pattern/d
1c
replacement
.
w
q"
    run no_complex_patterns "$script"
    [ "$status" -eq 1 ]  # Complex
}

@test "refined complexity: search + global is complex" {
    local script="/pattern1/c
replacement
.
g/pattern2/d
w
q"
    run no_complex_patterns "$script"
    [ "$status" -eq 1 ]  # Complex
}

@test "refined complexity: search + dollar is allowed" {
    local script="/pattern/c
replacement
.
$d
w
q"
    run no_complex_patterns "$script"
    [ "$status" -eq 0 ]  # Allowed (not complex)
}

# Move/transfer commands should always be complex
@test "refined complexity: move commands are always complex" {
    local script="1m5
w
q"
    run no_complex_patterns "$script"
    [ "$status" -eq 1 ]  # Always complex
}

# Multiple commands of the same type should remain safe
@test "refined complexity: multiple search patterns are safe" {
    local script="/pattern1/c
replacement1
.
/pattern2/c
replacement2
.
w
q"
    run no_complex_patterns "$script"
    [ "$status" -eq 0 ]  # Safe (same addressing mode)
}

@test "refined complexity: multiple global operations are safe" {
    local script="g/pattern1/d
g/pattern2/d
w
q"
    run no_complex_patterns "$script"
    [ "$status" -eq 0 ]  # Safe (same addressing mode)
}

@test "refined complexity: multiple numeric operations are safe" {
    local script="1d
5c
replacement
.
w
q"
    run no_complex_patterns "$script"
    [ "$status" -eq 0 ]  # Safe (same addressing mode)
}

# Edge case: The original problematic case should now work in force mode
@test "refined complexity: original slash escaping case should be safe" {
    # This simulates the auto-fixed version of ///test/c
    local script="/\/\/test/c
replacement
.
w
q"
    run no_complex_patterns "$script"
    [ "$status" -eq 0 ]  # Safe (single search pattern)
}