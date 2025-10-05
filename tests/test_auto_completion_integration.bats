#!/usr/bin/env bats

# Integration tests for auto-completion feature
# These tests verify that auto-completion works end-to-end in real scenarios

setup() {
    # Determine repository root using BATS_TEST_DIRNAME
    if [ -z "$REPO_ROOT" ]; then
        export REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
    fi

    export PATH="$REPO_ROOT:$PATH"
    export EED_TESTING=true  # Prevent log file creation

    # Create a temporary test directory
    export TEST_DIR=$(mktemp -d)
    cd "$TEST_DIR"

    # Create test file with initial content
    echo -e "line 1\nline 2\nline 3" > test.txt
}

teardown() {
    cd /
    rm -rf "$TEST_DIR"
}

@test "integration: auto-completion adds w and q to modifying command" {
    # Test that auto-completion actually works in real execution
    run eed --debug test.txt "1d"

    # Should succeed (exit 0) because w/q are auto-added
    [ "$status" -eq 0 ]

    # Should contain auto-completion message
    echo "$output" | grep -q "Auto-completed missing ed commands: w and q"

    # Should show preview diff (indicating the command actually worked)
    echo "$output" | grep -q "line 1"
}

@test "integration: auto-completion adds only q to modifying command with w" {
    # Test command that has w but missing q
    run eed --debug test.txt $'$d\nw'

    # Should succeed
    [ "$status" -eq 0 ]

    # Should only add q, not w and q
    echo "$output" | grep -q "Auto-completed missing ed commands: q"
    ! echo "$output" | grep -q "Auto-completed missing ed commands: w and q"
}

@test "integration: auto-completion adds q to view-only command" {
    # Test view command without q
    run eed --debug test.txt "p"

    # Should succeed
    [ "$status" -eq 0 ]

    # Should add q
    echo "$output" | grep -q "Auto-completed missing ed commands: q"
}

@test "integration: complete script needs no auto-completion" {
    # Test complete script - should not auto-complete
    run eed test.txt $'$d\nw\nq'

    # Should succeed
    [ "$status" -eq 0 ]

    # Should NOT mention auto-completion
    ! echo "$output" | grep -q "Auto-completed"
}

@test "integration: auto-completion works with input mode commands" {
    # Test input mode command with proper terminator, missing w/q
    run eed --debug test.txt $'$a\nnew line at end\n.'

    # Should succeed with auto-completion
    [ "$status" -eq 0 ]

    # Should add w and q
    echo "$output" | grep -q "Auto-completed missing ed commands: w and q"
}

@test "integration: auto-completion works after reordering" {
    # Test that auto-completion still works when reordering occurs
    # Use a script that will be reordered (out-of-order line numbers)
    run eed --debug test.txt $'3d\n1d'

    # Should succeed
    [ "$status" -eq 0 ]

    # Should contain auto-completion message (w and q added)
    echo "$output" | grep -q "Auto-completed missing ed commands: w and q"

    # Should show that reordering occurred AND auto-completion worked
    # (This tests that auto-completion happens AFTER reordering)
    echo "$output" | grep -q "Edits applied to a temporary preview"
}

@test "integration: auto-completion works in git repository" {
    # Initialize git repo to test git mode
    git init >/dev/null 2>&1
    git config user.email "test@example.com"
    git config user.name "Test User"
    git add test.txt >/dev/null 2>&1
    git commit -m "Initial commit" >/dev/null 2>&1

    # Test auto-completion in git mode (auto-commits)
    run eed --debug test.txt "1d"

    # Should succeed
    [ "$status" -eq 0 ]

    # Should contain auto-completion message
    echo "$output" | grep -q "Auto-completed missing ed commands: w and q"

    # Should show auto-commit success (git mode auto-commits)
    echo "$output" | grep -q "Changes successfully committed"
}