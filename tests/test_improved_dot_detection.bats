#!/usr/bin/env bats

# Tests for improved dot detection algorithm
# Implements the temporal reasoning approach to distinguish between
# legitimate ed command dots vs tutorial/documentation content dots

setup() {
    REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
    source "$REPO_ROOT/lib/eed_smart_dot_protection.sh"
    source "$REPO_ROOT/lib/eed_validator.sh"
    export EED_TESTING=true
}

# Test case 1: Normal AI editor script (should NOT trigger smart dot)
@test "improved detection: normal AI editor script - no false positives" {
    local script="1c
new content
.
w
q"
    
    local confidence
    confidence=$(detect_ed_tutorial_context "$script" "test.txt")
    
    # Should have low confidence (not tutorial context)
    [ "$confidence" -lt 70 ]
}

# Test case 2: Tutorial display script (SHOULD trigger smart dot)
@test "improved detection: tutorial script with content after q - should trigger" {
    local script="1a
first line.
second line.
.
w
q
Then you can verify by running:
.
w
q"
    
    local confidence
    confidence=$(detect_ed_tutorial_context "$script" "tutorial.md")
    
    # Should have high confidence (tutorial context with .md file)
    [ "$confidence" -ge 70 ]
}

# Test case 3: Interactive editing (boundary case)
@test "improved detection: interactive editing - boundary case handling" {
    local script="1c
test
.
.p
1c
final
.
w
q"
    
    local confidence
    confidence=$(detect_ed_tutorial_context "$script" "work.txt")
    
    # Should have low confidence (legitimate interactive editing)
    [ "$confidence" -lt 70 ]
}

# Test case 4: Current failing test44 scenario (complex but legal ed script)
@test "improved detection: conditional save workflow - should NOT trigger" {
    local script="1c
TEST CHANGE
.
.p
1c
FINAL CHANGE
.
w
q"
    
    local confidence
    confidence=$(detect_ed_tutorial_context "$script" "sample.txt")
    
    # Should have low confidence - this is legitimate ed syntax
    [ "$confidence" -lt 40 ]
    
    # The key test: script ends with q and no content after
    # This should NOT be considered tutorial context
}

# Test case 5: Verify transform behavior on tutorial content
@test "improved detection: tutorial content gets properly transformed" {
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

# Test case 6: Normal scripts should pass through unchanged
@test "improved detection: normal scripts unchanged by transform" {
    local script="1d
2a
new line
.
w
q"
    
    # This should NOT be detected as needing transformation
    local confidence
    confidence=$(detect_ed_tutorial_context "$script" "normal.txt")
    [ "$confidence" -lt 70 ]
}

# Test case 7: Mixed scenario - multiple q commands
@test "improved detection: multiple q commands - complex case" {
    local script="1c
content
.
q
2c
more content
.
q"
    
    local confidence
    confidence=$(detect_ed_tutorial_context "$script" "test.txt")
    
    # Should not trigger - both q commands end normally
    [ "$confidence" -lt 70 ]
}

# Test case 8: Confirm the specific pattern that caused test44 to fail
@test "improved detection: test44 failure pattern analysis" {
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
    run detect_dot_trap "$script"
    local trap_result=$?
    
    # Current implementation detects this as trap, but it shouldn't
    # After improvement, this should NOT be detected as trap
    echo "Dot trap detection result: $trap_result"
    echo "Output: $output"
    
    # For now, document the current behavior
    # TODO: After implementing improved logic, this should return 0 (no trap)
}