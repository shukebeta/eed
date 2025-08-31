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
    export EED_TESTING=true

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
    [[ "$output" == *"✨"* ]]

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
    [ ! -f sample.txt.eed.preview ]
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
    [[ "$output" == *"✨"* ]]
    
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

    # Should show error message
    [[ "$output" == *"Edit command failed"* ]]

    # Original file should be unchanged (never touched)
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

    [[ "$output" == *"Error: Unknown option '--unknown'"* ]]
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

@test "critical safety - edit failure never corrupts original file" {
    # Test that original file is NEVER touched when edit fails
    # This tests the bug fix where we used to mv corrupted preview over original

    # Create original content
    echo "CRITICAL_DATA_LINE_1" > sample.txt
    echo "CRITICAL_DATA_LINE_2" >> sample.txt

    # Record original content and timestamp
    original_content="$(cat sample.txt)"
    original_stat="$(stat sample.txt)"

    # Force mode with failing command - should not corrupt original
    run $SCRIPT_UNDER_TEST --force sample.txt "1c
new content
.
999p
q"
    [ "$status" -ne 0 ]

    # Original file must be completely untouched
    [[ "$(cat sample.txt)" == "$original_content" ]]
    [[ "$(stat sample.txt)" == "$original_stat" ]]

    # No preview file should remain
    [ ! -f sample.txt.eed.preview ]

    # Preview mode with failing command - should also not corrupt original
    run $SCRIPT_UNDER_TEST sample.txt "1c
another attempt
.
999p
q"
    [ "$status" -ne 0 ]

    # Original file still completely untouched
    [[ "$(cat sample.txt)" == "$original_content" ]]
    [[ "$(stat sample.txt)" == "$original_stat" ]]

    # No preview file should remain
    [ ! -f sample.txt.eed.preview ]
}

@test "force mode - auto-reordering cancels force mode" {
    # Test that --force is cancelled when script reordering occurs
    run $SCRIPT_UNDER_TEST --force sample.txt "1d
2d
3d
w
q"
    [ "$status" -eq 0 ]
    
    # Should show reordering and force cancellation message
    [[ "$output" == *"Auto-reordering script to prevent line numbering conflicts"* ]]
    [[ "$output" == *"Script reordered for safety (--force disabled)"* ]]
    
    # Should create preview file (force mode cancelled)
    [ -f sample.txt.eed.preview ]
    
    # Should show preview instructions instead of direct edit
    [[ "$output" == *"To apply these changes, run:"* ]]
    
    # Original file should be unchanged
    [[ "$(cat sample.txt)" == $'line1\nline2\nline3' ]]
}

@test "line number validation - single out-of-range line" {
    # Test line number validation with out-of-range line number
    run $SCRIPT_UNDER_TEST sample.txt "5d
q"
    [ "$status" -ne 0 ]
    
    # Should show precise error message
    [[ "$output" == *"Line number error in command '5d'"* ]]
    [[ "$output" == *"Line 5 does not exist (file has only 3 lines)"* ]]
    
    # Original file should be unchanged
    [[ "$(cat sample.txt)" == $'line1\nline2\nline3' ]]
}

@test "line number validation - range with out-of-range end" {
    # Test range command with out-of-range end line
    run $SCRIPT_UNDER_TEST sample.txt "1,10d
q"
    [ "$status" -ne 0 ]
    
    # Should show precise error message for end line
    [[ "$output" == *"Line number error in command '1,10d'"* ]]
    [[ "$output" == *"Line 10 does not exist (file has only 3 lines)"* ]]
    
    # Original file should be unchanged
    [[ "$(cat sample.txt)" == $'line1\nline2\nline3' ]]
}

@test "line number validation - dollar sign should work" {
    # Test that $ (last line) is handled correctly
    run $SCRIPT_UNDER_TEST sample.txt "1,\$d
w
q"
    [ "$status" -eq 0 ]
    
    # Should create preview (not error out)
    [ -f sample.txt.eed.preview ]
    
    # Preview should be empty (all lines deleted)
    [[ "$(cat sample.txt.eed.preview)" == "" ]]
}

@test "line number validation - valid ranges work normally" {
    # Test that valid line numbers work as expected
    run $SCRIPT_UNDER_TEST sample.txt "2d
w
q"
    [ "$status" -eq 0 ]
    
    # Should create preview
    [ -f sample.txt.eed.preview ]
    
    # Should show line2 was deleted
    [[ "$output" == *"-line2"* ]]
}

@test "line number validation - reject invalid operations on non-existent files" {
    # Test that we reject invalid operations without creating unnecessary files
    rm -f new_test_file.txt  # Ensure file doesn't exist

    run $SCRIPT_UNDER_TEST new_test_file.txt "5d
q"
    [ "$status" -ne 0 ]

    # Should show error for attempting to delete line 5 from non-existent/empty file
    [[ "$output" == *"Line number error in command '5d'"* ]]
    [[ "$output" == *"Line 5 does not exist (file has only 1 lines)"* ]]
    [[ "$output" == *"Line number validation failed"* ]]

    # Should NOT create file for invalid operations
    [ ! -f new_test_file.txt ]

    # Clean up
    rm -f new_test_file.txt
}

@test "line number validation - new file with valid line 1 works" {
    # Test that line 1 operations work on new files
    rm -f new_test_file2.txt  # Ensure file doesn't exist

    run $SCRIPT_UNDER_TEST new_test_file2.txt "1a
hello world
.
w
q"
    [ "$status" -eq 0 ]

    # Should create preview successfully
    [ -f new_test_file2.txt.eed.preview ]

    # Preview should contain the added content
    [[ "$(cat new_test_file2.txt.eed.preview)" == $'\nhello world' ]]

    # Clean up
    rm -f new_test_file2.txt new_test_file2.txt.eed.preview
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

@test "preview mode - auto-reordering shows reorder message" {
    # Test that reordering message appears in preview mode (not just force mode)
    run $SCRIPT_UNDER_TEST sample.txt "1d
2d
3d
w
q"
    [ "$status" -eq 0 ]
    
    # Should show reordering message
    [[ "$output" == *"Auto-reordering script to prevent line numbering conflicts"* ]]
    [[ "$output" == *"Original: (1,2,3) → Reordered: (3,2,1)"* ]]
    
    # Should create preview file (normal preview mode)
    [ -f sample.txt.eed.preview ]
    
    # Should show preview instructions  
    [[ "$output" == *"To apply these changes, run:"* ]]
    
    # Original file should be unchanged
    [[ "$(cat sample.txt)" == $'line1\nline2\nline3' ]]
}

@test "preview mode - no reordering when already in reverse order" {
    # Test that reverse order commands don't trigger unnecessary reordering
    run $SCRIPT_UNDER_TEST sample.txt "3d
2d
1d
w
q"
    [ "$status" -eq 0 ]
    
    # Should NOT show reordering message
    [[ "$output" != *"Auto-reordering script"* ]]
    
    # Should create preview file normally
    [ -f sample.txt.eed.preview ]
    
    # Should show preview instructions
    [[ "$output" == *"To apply these changes, run:"* ]]
    
    # Original file should be unchanged
    [[ "$(cat sample.txt)" == $'line1\nline2\nline3' ]]
}
