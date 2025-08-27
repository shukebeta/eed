#!/usr/bin/env bats

# Tests for simplified complex message strategy
# Goal: Reduce noise, provide clear feedback only when necessary

setup() {
    # Create unique test directory and switch into it
    TEST_DIR="$(mktemp -d)"
    cd "$TEST_DIR"
    
    # Use the repository eed executable directly
    SCRIPT_UNDER_TEST="/home/davidwei/Projects/eed/eed"
    
    # Create test file
    echo -e "line1\nline2\nline3\nline4\nline5" > test_file.txt
}

teardown() {
    cd /
    rm -rf "$TEST_DIR"
}

@test "complex script with --force shows only one clear message" {
    script='g/line2/d
w
q'
    
    run bash -c "echo '$script' | '$SCRIPT_UNDER_TEST' --force test_file.txt -"
    
    # Should show only ONE user-friendly message about force being disabled
    [[ "$output" =~ "Complex script detected" ]]
    [[ "$output" =~ force.*disabled ]]
    
    # Should show exactly ONE user-visible complex message
    complex_count=$(echo "$output" | grep -c -i "complex" || true)
    [ "$complex_count" -eq 1 ]
}

@test "complex script without --force is silent about complexity" {
    script='g/line2/d
w
q'
    
    run bash -c "echo '$script' | '$SCRIPT_UNDER_TEST' test_file.txt -"
    
    # Should show preview workflow without complexity noise
    [[ "$output" =~ "preview" ]] || [[ "$output" =~ "diff" ]]
    
    # Should NOT mention "complex" to the user at all
    ! [[ "$output" =~ [Cc]omplex ]]
}

@test "debug mode can show technical details" {
    script='g/line2/d
w
q'
    
    run bash -c "echo '$script' | '$SCRIPT_UNDER_TEST' --debug test_file.txt -"
    
    # Debug mode can show technical COMPLEX: messages
    [[ "$output" =~ "COMPLEX:" ]] || [[ "$output" =~ "Debug" ]]
}
