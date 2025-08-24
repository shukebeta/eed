#!/usr/bin/env bats

# Tests for the new Preview-Confirm workflow functionality
# Tests the --force flag and default preview behavior

setup() {
    TEST_DIR="$(mktemp -d)"
    cd "$TEST_DIR"
    export PATH="/home/davidwei/Projects/pkb/bin:$PATH"
    
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
    run /home/davidwei/Projects/pkb/bin/eed sample.txt "2c
new line2
.
w
q"
    [ "$status" -eq 0 ]

    # Should show diff output
    [[ "$output" == *"--- sample.txt"* ]]
    [[ "$output" == *"+++ sample.txt.eed.bak"* ]]
    [[ "$output" == *"-line2"* ]]
    [[ "$output" == *"+new line2"* ]]

    # Should show instructions
    [[ "$output" == *"To apply these changes, run:"* ]]
    [[ "$output" == *"mv 'sample.txt.eed.bak' 'sample.txt'"* ]]
    [[ "$output" == *"To discard these changes, run:"* ]]
    [[ "$output" == *"rm 'sample.txt.eed.bak'"* ]]

    # Original file should be unchanged
    [[ "$(cat sample.txt)" == $'line1\nline2\nline3' ]]

    # Backup file should contain the changes
    [ -f sample.txt.eed.bak ]
    [[ "$(cat sample.txt.eed.bak)" == $'line1\nnew line2\nline3' ]]
}

@test "preview mode - view-only script executes directly" {
    # View-only scripts should not use preview mode
    run /home/davidwei/Projects/pkb/bin/eed sample.txt ",p
q"
    [ "$status" -eq 0 ]

    # Should show file contents directly
    [[ "$output" == *"line1"* ]]
    [[ "$output" == *"line2"* ]]
    [[ "$output" == *"line3"* ]]

    # Should not create backup file
    [ ! -f sample.txt.eed.bak ]

    # Should not show diff or instructions
    [[ "$output" != *"To apply these changes"* ]]
    [[ "$output" != *"mv"* ]]
}

@test "force mode - modifying script edits directly" {
    # Test --force flag behavior
    run /home/davidwei/Projects/pkb/bin/eed --force sample.txt "2c
new line2
.
w
q"
    [ "$status" -eq 0 ]

    # Should indicate force mode
    [[ "$output" == *"--force mode enabled. Editing file directly."* ]]
    [[ "$output" == *"Successfully edited sample.txt directly."* ]]

    # Should not show diff or instructions
    [[ "$output" != *"To apply these changes"* ]]
    [[ "$output" != *"mv"* ]]

    # File should be modified directly
    [[ "$(cat sample.txt)" == $'line1\nnew line2\nline3' ]]

    # Should not leave backup file
    [ ! -f sample.txt.eed.bak ]
}

@test "force mode - view-only script still executes directly" {
    # View-only should behave same in force mode
    run /home/davidwei/Projects/pkb/bin/eed --force sample.txt ",p
q"
    [ "$status" -eq 0 ]

    # Should show file contents
    [[ "$output" == *"line1"* ]]
    [[ "$output" == *"line2"* ]]
    [[ "$output" == *"line3"* ]]

    # Should not create backup
    [ ! -f sample.txt.eed.bak ]
}

@test "preview mode - error handling preserves original file" {
    # Test error in preview mode
    run /home/davidwei/Projects/pkb/bin/eed sample.txt "invalid_command"
    [ "$status" -ne 0 ]

    # Should show error message
    [[ "$output" == *"Invalid ed command detected"* ]]

    # Original file should be unchanged
    [[ "$(cat sample.txt)" == $'line1\nline2\nline3' ]]

    # Should not create backup file
    [ ! -f sample.txt.eed.bak ]
}

@test "force mode - error handling restores backup" {
    # Create a scenario where ed fails in force mode
    # Use a command that will fail after modification
    run /home/davidwei/Projects/pkb/bin/eed --force sample.txt "2c
new line2
.
999p
q"
    [ "$status" -ne 0 ]

    # Should show error and restoration message
    [[ "$output" == *"Edit command failed, restoring backup"* ]]

    # Original file should be restored (unchanged)
    [[ "$(cat sample.txt)" == $'line1\nline2\nline3' ]]
}

@test "preview mode - successful apply workflow" {
    # Test the complete workflow: preview then apply
    run /home/davidwei/Projects/pkb/bin/eed sample.txt "1c
modified line1
.
w
q"
    [ "$status" -eq 0 ]

    # Should create backup with changes
    [ -f sample.txt.eed.bak ]
    [[ "$(cat sample.txt.eed.bak)" == $'modified line1\nline2\nline3' ]]

    # Apply the changes using the provided command
    run mv sample.txt.eed.bak sample.txt
    [ "$status" -eq 0 ]

    # File should now have the changes
    [[ "$(cat sample.txt)" == $'modified line1\nline2\nline3' ]]

    # Backup file should be gone
    [ ! -f sample.txt.eed.bak ]
}

@test "preview mode - successful discard workflow" {
    # Test the complete workflow: preview then discard
    run /home/davidwei/Projects/pkb/bin/eed sample.txt "1c
modified line1
.
w
q"
    [ "$status" -eq 0 ]

    # Should create backup with changes
    [ -f sample.txt.eed.bak ]

    # Discard the changes using the provided command
    run rm sample.txt.eed.bak
    [ "$status" -eq 0 ]

    # Original file should be unchanged
    [[ "$(cat sample.txt)" == $'line1\nline2\nline3' ]]

    # Backup file should be gone
    [ ! -f sample.txt.eed.bak ]
}

@test "flag parsing - combined flags work correctly" {
    # Test --debug --force combination
    run /home/davidwei/Projects/pkb/bin/eed --debug --force sample.txt "2c
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
    run /home/davidwei/Projects/pkb/bin/eed --unknown sample.txt "p"
    [ "$status" -ne 0 ]

    [[ "$output" == *"Error: Unknown option --unknown"* ]]
}

@test "preview mode - complex diff shows properly" {
    # Create a more complex change to test diff output
    run /home/davidwei/Projects/pkb/bin/eed sample.txt "$(cat <<'EOF'
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

    # Backup should contain all changes
    [ -f sample.txt.eed.bak ]
    content="$(cat sample.txt.eed.bak)"
    [[ "$content" == *"CHANGED LINE 1"* ]]
    [[ "$content" == *"new line after line3"* ]]
}

@test "preview mode - no changes results in empty diff" {
    # Test script that makes no actual changes
    run /home/davidwei/Projects/pkb/bin/eed sample.txt "w
q"
    [ "$status" -eq 0 ]

    # Should still create backup and show diff (even if empty)
    [ -f sample.txt.eed.bak ]

    # Diff should be empty or minimal
    [[ "$output" == *"Review the changes below"* ]]

    # Both files should be identical
    run diff sample.txt sample.txt.eed.bak
    [ "$status" -eq 0 ]
}