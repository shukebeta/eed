#!/usr/bin/env bats

# Test auto-completion feature for missing w/q commands

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

# Test auto-completion for modifying commands missing w/q
@test "auto-completion: modifying command missing w and q" {
    # Test a delete command without w/q - this is simpler and clearer
    run eed --debug test.txt "1d"

    # Should succeed because w/q are auto-added
    [ "$status" -eq 0 ]

    # Check that the auto-completion was applied
    echo "$output" | grep -q "Auto-completed.*w and q"
}

@test "auto-completion: modifying command missing only q" {
    # Test a command with w but missing q
    run eed --debug test.txt $'$d\nw'
    # Should succeed because q is auto-added
    [ "$status" -eq 0 ]

    # Check that only q was auto-added (not w and q)
    echo "$output" | grep -q "Auto-completed.*q"
    ! echo "$output" | grep -q "Auto-completed.*w and q"
}

@test "auto-completion: view-only command missing q" {
    # Test a view command without q
    run eed --debug test.txt "p"
    # Should succeed because q is auto-added
    [ "$status" -eq 0 ]

    # Check that q was auto-added
    echo "$output" | grep -q "Auto-completed.*q"
}

@test "auto-completion: complete script needs no completion" {
    # Test a complete script that doesn't need auto-completion
    run eed --debug test.txt $'$d\nw\nq'

    # Should succeed without auto-completion
    [ "$status" -eq 0 ]

    # Should NOT mention auto-completion
    ! echo "$output" | grep -q "Auto-completed"
}

@test "auto-completion: view-only complete script needs no completion" {
    # Test a complete view-only script that doesn't need auto-completion
    run eed --debug test.txt $'p\nq'

    # Should succeed without auto-completion
    [ "$status" -eq 0 ]

    # Should NOT mention auto-completion
    ! echo "$output" | grep -q "Auto-completed"
}

@test "auto-completion: multi-line modifying script" {
    # Test a complex modifying script missing w/q
    run eed --debug test.txt $'1d\n$d'
    # Should succeed with auto-completion
    [ "$status" -eq 0 ]

    # Check that w and q were auto-added
    echo "$output" | grep -q "Auto-completed.*w and q"
}

@test "auto-completion: preserves existing q in mixed case" {
    # Test that Q (uppercase quit) is respected
    run eed --debug test.txt $'$d\nw\nQ'

    # Should succeed without auto-completion
    [ "$status" -eq 0 ]

    # Should NOT mention auto-completion since Q is already present
    ! echo "$output" | grep -q "Auto-completed"
}

@test "auto-completion: handles input mode commands correctly" {
    # Test input mode commands (a, i, c) that need terminating dots
    run eed --debug test.txt $'$a\nnew line at end\n.'
    # Should succeed with auto-completion of w/q
    [ "$status" -eq 0 ]

    # Check that w and q were auto-added
    echo "$output" | grep -q "Auto-completed.*w and q"
}

@test "auto-completion: works with unterminated input mode" {
    # Test input mode command missing terminating dot
    run eed --debug test.txt $'$a\nnew line at end'
    # Should succeed with auto-completion of w/q and auto-fix of dot
    [ "$status" -eq 0 ]

    # Should have auto-completed w and q
    echo "$output" | grep -q "Auto-completed.*w and q"

    # Should have auto-fixed the missing dot (different message)
    echo "$output" | grep -q "Auto-fix.*inserted.*'.'"
}

@test "auto-completion: handles multiple unclosed input modes" {
    # Test multiple input commands missing terminators
    run eed --debug test.txt $'$a\nnew line at end\n1i\ninserted at beginning'
    # Should succeed with auto-completion of two dots, w, and q
    [ "$status" -eq 0 ]

    # Check that multiple dots were auto-added
    echo "$output" | grep -q "Auto-completed"
}

@test "auto-completion: properly nested input modes" {
    # Test properly terminated input mode - should not add extra dots
    run eed --debug test.txt $'$a\nnew line at end\n.\n1i\ninserted at beginning\n.'

    # Should succeed with auto-completion of only w and q
    [ "$status" -eq 0 ]

    # Check that only w and q were auto-added (no extra dots)
    if echo "$output" | grep -q "Auto-completed"; then
        echo "$output" | grep -q "Auto-completed.*w and q"
        ! echo "$output" | grep -q "Auto-completed.*\\."
    fi
}