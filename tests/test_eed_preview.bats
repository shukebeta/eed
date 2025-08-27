#!/usr/bin/env bats

# Tests for the new Preview-Confirm workflow functionality
# Tests the --force flag and default preview behavior

setup() {
    # Determine repository root using BATS_TEST_DIRNAME
    REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"

    # Create unique test directory and switch into it
    TEST_DIR="$(mktemp -d)"
    cd "$TEST_DIR"

    # Use the repository eed executable directly
    SCRIPT_UNDER_TEST="$REPO_ROOT/eed"

    # Prevent logging during tests
    export EED_TESTING=1

    # Create sample file for testing
    cat > sample.txt << 'EOF'
line1
line2
line3
EOF
}

teardown() {
    cd /
    rm -rf "$TEST_DIR"
}

@test "preview mode - modifying script shows diff and instructions" {
    # Test default preview mode behavior
    run $SCRIPT_UNDER_TEST sample.txt "2c
new line2
.
w
q"
    [ "$status" -eq 0 ]

    # Should show changed lines in diff output
    [[ "$output" == *"-line2"* ]]
    [[ "$output" == *"+new line2"* ]]

    # Should mention preview filename
    [[ "$output" == *".eed.preview"* ]]

    # Should show instructions to apply/discard the preview
    [[ "$output" == *"To apply these changes, run:"* ]]
    [[ "$output" == *"mv 'sample.txt.eed.preview' 'sample.txt'"* ]]
    [[ "$output" == *"To discard these changes, run:"* ]]
    [[ "$output" == *"rm 'sample.txt.eed.preview'"* ]]

    # Original file should be unchanged
    [[ "$(cat sample.txt)" == $'line1\nline2\nline3' ]]

    # Preview file should contain the changes
    [ -f sample.txt.eed.preview ]
    [[ "$(cat sample.txt.eed.preview)" == $'line1\nnew line2\nline3' ]]
}

@test "preview mode - view-only script executes directly" {
    # View-only scripts should not use preview mode
    run $SCRIPT_UNDER_TEST sample.txt ",p
q"
    [ "$status" -eq 0 ]

    # Should show file contents directly
    [[ "$output" == *"line1"* ]]
    [[ "$output" == *"line2"* ]]
    [[ "$output" == *"line3"* ]]

    # Should not create preview file
    [ ! -f sample.txt.eed.preview ]

    # Should not show diff or instructions
    [[ "$output" != *"To apply these changes"* ]]
    [[ "$output" != *"mv"* ]]
}

@test "force mode - modifying script edits directly" {
    # Test --force flag behavior
    run $SCRIPT_UNDER_TEST --force sample.txt "2c
new line2
.
w
q"
    [ "$status" -eq 0 ]

    # Should indicate force mode and preview application
    [[ "$output" == *"Note: --force mode enabled. Editing preview file"* ]]
    [[ "$output" == *"✓ Successfully edited preview file."* ]]
    [[ "$output" == *"✓ Changes applied directly (force mode enabled)"* ]]

    # Should not show diff or instructions as primary workflow (preview applied)
    [[ "$output" != *"To apply these changes"* ]]

    # File should be modified directly
    [[ "$(cat sample.txt)" == $'line1\nnew line2\nline3' ]]

    # Should not leave preview file after apply
    [ ! -f sample.txt.eed.preview ]
}


@test "force mode - view-only script still executes directly" {
    # View-only should behave same in force mode
    run $SCRIPT_UNDER_TEST --force sample.txt ",p
q"
    [ "$status" -eq 0 ]

    # Should show file contents
    [[ "$output" == *"line1"* ]]
    [[ "$output" == *"line2"* ]]
    [[ "$output" == *"line3"* ]]

    # Should not create preview
    [ \! -f sample.txt.eed.preview ]
}

@test "force mode - shows clear success message without confusing mv command" {
    # Test that --force mode shows clear message instead of confusing mv instruction
    run $SCRIPT_UNDER_TEST --force sample.txt "2c
new line2
.
w
q"
    [ "$status" -eq 0 ]

    # Should show clear force mode success message
    [[ "$output" == *"✓ Changes applied directly (force mode enabled)"* ]]
    
    # File should be modified directly
    [[ "$(cat sample.txt)" == $'line1\nnew line2\nline3' ]]

    # Should not create preview
    [ ! -f sample.txt.eed.preview ]
}

@test "preview mode - error handling preserves original file" {
    # Test error in preview mode
    run $SCRIPT_UNDER_TEST sample.txt "invalid_command"
    [ "$status" -ne 0 ]

    # Should show error message
    [[ "$output" == *"Invalid ed command detected"* ]]

    # Original file should be unchanged
    [[ "$(cat sample.txt)" == $'line1\nline2\nline3' ]]

    # Should not create preview file
    [ ! -f sample.txt.eed.preview ]
}

@test "force mode - error handling restores preview" {
    # Create a scenario where ed fails in force mode
    # Use a command that will fail after modification
    run $SCRIPT_UNDER_TEST --force sample.txt "2c
new line2
.
999p
q"
    [ "$status" -ne 0 ]

    # Should show error and restoration message
    [[ "$output" == *"Edit command failed, restoring preview"* ]]

    # Original file should be restored (unchanged)
    [[ "$(cat sample.txt)" == $'line1\nline2\nline3' ]]
}

@test "preview mode - successful apply workflow" {
    # Test the complete workflow: preview then apply
    run $SCRIPT_UNDER_TEST sample.txt "1c
modified line1
.
w
q"
    [ "$status" -eq 0 ]

    # Should create preview with changes
    [ -f sample.txt.eed.preview ]
    [[ "$(cat sample.txt.eed.preview)" == $'modified line1\nline2\nline3' ]]

    # Apply the changes using the provided command
    run mv sample.txt.eed.preview sample.txt
    [ "$status" -eq 0 ]

    # File should now have the changes
    [[ "$(cat sample.txt)" == $'modified line1\nline2\nline3' ]]

    # Preview file should be gone
    [ ! -f sample.txt.eed.preview ]
}

@test "preview mode - successful discard workflow" {
    # Test the complete workflow: preview then discard
    run $SCRIPT_UNDER_TEST sample.txt "1c
modified line1
.
w
q"
    [ "$status" -eq 0 ]

    # Should create preview with changes
    [ -f sample.txt.eed.preview ]

    # Discard the changes using the provided command
    run rm sample.txt.eed.preview
    [ "$status" -eq 0 ]

    # Original file should be unchanged
    [[ "$(cat sample.txt)" == $'line1\nline2\nline3' ]]

    # Preview file should be gone
    [ ! -f sample.txt.eed.preview ]
}

@test "flag parsing - combined flags work correctly" {
    # Test --debug --force combination
    run $SCRIPT_UNDER_TEST --debug --force sample.txt "2c
debug test
.
w
q"
    [ "$status" -eq 0 ]

    # Should show both debug and force mode messages
    [[ "$output" == *"--force mode enabled"* ]]
    [[ "$output" == *"Debug mode: executing ed"* ]]

    # File should be modified directly (force mode)
    [[ "$(cat sample.txt)" == $'line1\ndebug test\nline3' ]]
}

@test "flag parsing - unknown flag rejected" {
    # Test unknown flag handling
    run $SCRIPT_UNDER_TEST --unknown sample.txt "p"
    [ "$status" -ne 0 ]

    [[ "$output" == *"Error: Unknown option --unknown"* ]]
}

@test "preview mode - complex diff shows properly" {
    # Create a more complex change to test diff output
    run $SCRIPT_UNDER_TEST sample.txt "$(cat <<'EOF'
1c
CHANGED LINE 1
.
3a
new line after line3
.
w
q
EOF
)"
    [ "$status" -eq 0 ]

    # Should show proper diff with multiple changes
    [[ "$output" == *"-line1"* ]]
    [[ "$output" == *"+CHANGED LINE 1"* ]]
    [[ "$output" == *"+new line after line3"* ]]

    # Preview should contain all changes
    [ -f sample.txt.eed.preview ]
    content="$(cat sample.txt.eed.preview)"
    [[ "$content" == *"CHANGED LINE 1"* ]]
    [[ "$content" == *"new line after line3"* ]]
}

@test "preview mode - no changes results in empty diff" {
    # Test script that makes no actual changes
    run $SCRIPT_UNDER_TEST sample.txt "w
q"
    [ "$status" -eq 0 ]

    # Should still create preview and show diff (even if empty)
    [ -f sample.txt.eed.preview ]

    # Diff should mention review prompt
    [[ "$output" == *"Review the changes below"* ]]

    # Both files should be identical
    run diff sample.txt sample.txt.eed.preview
    [ "$status" -eq 0 ]
}
