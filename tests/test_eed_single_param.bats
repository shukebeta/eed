#!/usr/bin/env bats

# TDD Tests for Single-Parameter Mode Eed
# These tests should FAIL initially (RED phase)
# Implementation will make them pass (GREEN phase)

setup() {
    # Determine repository root using BATS_TEST_DIRNAME
    REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"

    # Create unique test directory and switch into it
    TEST_DIR="$(mktemp -d)"
    cd "$TEST_DIR" || exit

    # Use the repository eed executable directly
    SCRIPT_UNDER_TEST="$REPO_ROOT/eed"

    # Prevent logging during tests
    export EED_TESTING=true
}

teardown() {
    cd /
    rm -rf "$TEST_DIR"
}

@test "single parameter with simple ed script" {
    cat > test.txt << 'EOF'
line1
line2
line3
EOF

    # Single parameter containing complete ed script
    run "$SCRIPT_UNDER_TEST" test.txt "3a
new line
.
w
q"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Edits applied to a temporary preview" ]]
    run grep -q "new line" test.txt.eed.preview
    [ "$status" -eq 0 ]
}

@test "single parameter with heredoc syntax" {
    cat > test.txt << 'EOF'
line1
line2
line3
EOF

    # Test heredoc integration
    run "$SCRIPT_UNDER_TEST" test.txt "$(cat <<'EOF'
2c
replaced line
.
w
q
EOF
)"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Edits applied to a temporary preview" ]]
    run grep -q "replaced line" test.txt.eed.preview
    [ "$status" -eq 0 ]
    # Original file should still have line2
    run grep -q "line2" test.txt
    [ "$status" -eq 0 ]
}

@test "manual w/q control - save and exit" {
    cat > test.txt << 'EOF'
original
EOF

    # User manually controls w/q
    run "$SCRIPT_UNDER_TEST" test.txt "1c
modified
.
w
q"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Edits applied to a temporary preview" ]]
    run grep -q "modified" test.txt.eed.preview
    [ "$status" -eq 0 ]
}

@test "manual w/q control - save without exit (complex workflow)" {
    cat > test.txt << 'EOF'
line1
line2
line3
EOF

    # Multi-step workflow with intermediate operations
    run "$SCRIPT_UNDER_TEST" test.txt - << 'EOF'
1c
changed1
.
w
2c
changed2
.
w
q
EOF
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Edits applied to a temporary preview" ]]
    run grep -q "changed1" test.txt.eed.preview
    [ "$status" -eq 0 ]
    run grep -q "changed2" test.txt.eed.preview
    [ "$status" -eq 0 ]
}

@test "Q command discards unsaved changes (no w command)" {
    cat > test.txt << 'EOF'
original
EOF

    # Script without w - Q command discards modifications
    run "$SCRIPT_UNDER_TEST" test.txt "1c
modified
.
Q"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Edits applied to a temporary preview" ]]
    [[ "$output" =~ "No changes were made to the file content" ]]
    # Q command discards changes, so original file unchanged
    run grep -q "original" test.txt
    [ "$status" -eq 0 ]
    run grep -q "modified" test.txt
    [ "$status" -ne 0 ]
}

@test "error handling - missing q should not hang" {
    cat > test.txt << 'EOF'
original
EOF

    # Script without q should still complete
    run "$SCRIPT_UNDER_TEST" test.txt "1c
modified
.
w"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Edits applied to a temporary preview" ]]
    run grep -q "modified" test.txt.eed.preview
    [ "$status" -eq 0 ]
}

@test "complex heredoc with nested quotes and special chars" {
    cat > test.txt << 'EOF'
placeholder
EOF

    # Test complex content with quotes and special characters
    run "$SCRIPT_UNDER_TEST" test.txt "$(cat <<'OUTER'
1c
Content with 'single' and "double" quotes
Line with $dollar and `backticks`
Line with \ backslashes and | pipes
.
w
q
OUTER
)"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Edits applied to a temporary preview" ]]
    run grep -q "single.*double" test.txt.eed.preview
    [ "$status" -eq 0 ]
    run grep -q "dollar.*backticks" test.txt.eed.preview
    [ "$status" -eq 0 ]
    run grep -q "backslashes.*pipes" test.txt.eed.preview
    [ "$status" -eq 0 ]
}


@test "empty script should return error" {
    cat > test.txt << 'EOF'
original content
EOF

    # Empty ed script should return error
    run "$SCRIPT_UNDER_TEST" test.txt ""
    [ "$status" -ne 0 ]
    [[ "$output" == *"Empty ed script provided"* ]]
    # File should remain unchanged
    run grep -q "original content" test.txt
    [ "$status" -eq 0 ]
}
