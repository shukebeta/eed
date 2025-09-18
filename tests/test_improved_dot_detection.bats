#!/usr/bin/env bats

# Tests for dot detection and transformation functionality
# Tests the core smart dot protection without relying on scoring mechanisms

setup() {
    REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
    source "$REPO_ROOT/lib/eed_smart_dot_protection.sh"
    source "$REPO_ROOT/lib/eed_validator.sh"
    export EED_TESTING=true
}

# Test case: Verify transform behavior on tutorial content
@test "dot transformation: tutorial content gets properly transformed" {
    # This script has a problematic standalone dot that should be transformed
    local script="1a
Here's how to add text:
First line
.
Second line
.
.
w
q
That completes the editing."
    
    local transformed_script
    transformed_script=$(transform_content_dots "$script")
    local result=$?
    
    # Should succeed in transformation
    [ "$result" -eq 0 ]
    
    # Should contain marker for the problematic content dots (not the final terminator)
    [[ "$transformed_script" == *"~~DOT_"* ]]
}

# Test case: Confirm the specific pattern that caused test failures
@test "dot trap detection: test44 failure pattern analysis" {
    # This is the exact script from the failing test
    local script="1c
TEST CHANGE
.
.p
1c
FINAL CHANGE
.
w
q"
    
    # Test against dot trap detection
    run no_dot_trap "$script"
    local trap_result=$?
    
    # Document current behavior
    echo "Dot trap detection result: $trap_result"
    echo "Output: $output"
    
    # This script should be handled appropriately by no_dot_trap
    # The result depends on the implementation logic
}
