#!/usr/bin/env bats

# Integration tests for safety override functionality

setup() {
    # Determine repository root
    if [ -n "${BATS_TEST_DIRNAME:-}" ]; then
        REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
    else
        SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
        REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
    fi
    
    # Use the repository eed executable directly
    SCRIPT_UNDER_TEST="$REPO_ROOT/eed"
    chmod +x "$SCRIPT_UNDER_TEST" 2>/dev/null || true
    
    # Create test file
    TEST_DIR="$(mktemp -d)"
    TEST_FILE="$TEST_DIR/test_file.txt"
    echo -e "line1\nline2\nline3\nline4\nline5" > "$TEST_FILE"
}

teardown() {
    rm -f "$TEST_FILE" "$TEST_FILE.eed.preview"
    rm -rf "$TEST_DIR"
}

@test "safety override does not trigger for simple operations" {
    script=$'5d\nw\nq'
    
    run bash -c "echo '$script' | '$SCRIPT_UNDER_TEST' --force '$TEST_FILE' -"
    
    # Should not contain safety override message
    [[ ! "$output" =~ "SAFETY.*--force ignored" ]]
}

@test "safety override triggers for complex unordered operations" {
    script=$'g/line2/d\nw\nq'
    
    run bash -c "echo '$script' | '$SCRIPT_UNDER_TEST' --force '$TEST_FILE' -"
    
    # Should contain new simplified safety message
    [[ "$output" =~ "Complex script detected" ]]
    [[ "$output" =~ "--force disabled" ]]
}

@test "simplified messaging - no machine tags in output" {
    script=$'g/line2/d\nw\nq'
    
    run bash -c "echo '$script' | '$SCRIPT_UNDER_TEST' --force '$TEST_FILE' - 2>&1"
    
    # Should NOT contain old machine-readable tags (noise reduction)
    ! [[ "$output" =~ "EED-SAFETY-OVERRIDE" ]]
    ! [[ "$output" =~ "SAFETY.*ignored" ]]
}

@test "EED_FORCE_OVERRIDE bypasses safety checks" {
    script=$'g/line/d\n1d\n3d\nw\nq'
    
    run bash -c "echo '$script' | EED_FORCE_OVERRIDE=true '$SCRIPT_UNDER_TEST' --force '$TEST_FILE' -"
    
    # Should not contain safety override message when override is set
    [[ ! "$output" =~ "SAFETY.*--force ignored" ]]
}