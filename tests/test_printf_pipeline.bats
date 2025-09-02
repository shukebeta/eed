#!/usr/bin/env bats
# Test suite specifically for printf pipeline functionality with eed
# This test isolates the printf | eed pattern to verify Git Bash compatibility

setup() {
    REPO_ROOT="$BATS_TEST_DIRNAME/.."
    SCRIPT_UNDER_TEST="$REPO_ROOT/eed"
    TEST_DIR=$(mktemp -d)
    cd "$TEST_DIR"
    export EED_TESTING=true
}

teardown() {
    cd /
    rm -rf "$TEST_DIR"
}

@test "printf pipeline - simple delete command" {
    # Create test file
    echo -e "line1\nline2\nline3" > test.txt
    
    # Test direct printf pipeline (not through bats run)
    printf '1d\nw\nq\n' | "$SCRIPT_UNDER_TEST" --force test.txt -
    
    # Verify result
    run cat test.txt
    [ "${lines[0]}" = "line2" ]
    [ "${lines[1]}" = "line3" ]
}

@test "printf pipeline - simple insert command" {
    # Create test file
    echo -e "line1\nline2" > test.txt
    
    # Test printf pipeline with insert
    printf '1a\ninserted\n.\nw\nq\n' | "$SCRIPT_UNDER_TEST" --force test.txt -
    
    # Verify result
    run cat test.txt
    [ "${lines[0]}" = "line1" ]
    [ "${lines[1]}" = "inserted" ]
    [ "${lines[2]}" = "line2" ]
}

@test "printf pipeline - complex multi-command script" {
    # Create test file  
    echo -e "line1\nline2\nline3" > test.txt
    
    # Test the exact pattern that was failing
    printf '1c\nchanged1\n.\nw\n2c\nchanged2\n.\nw\nq\n' | EED_FORCE_OVERRIDE=true "$SCRIPT_UNDER_TEST" --force --disable-auto-reorder test.txt -
    
    # Verify both changes were applied
    run cat test.txt
    [ "${lines[0]}" = "changed1" ]
    [ "${lines[1]}" = "changed2" ]
    [ "${lines[2]}" = "line3" ]
}

@test "printf pipeline - demonstrates bats limitation" {
    # Create test file
    echo -e "line1\nline2\nline3" > test.txt
    
    # This approach doesn't work in bats because run only captures the first command
    # run bash -c "printf '1d\nw\nq\n'" | "$SCRIPT_UNDER_TEST" --force test.txt -
    
    # The real workaround is to not use bats run with pipes at all
    # Instead, use direct execution (no bats run) or heredoc
    
    # Working approach: direct execution without bats run
    bash -c "printf '1d\nw\nq\n'" | "$SCRIPT_UNDER_TEST" --force test.txt -
    exit_code=$?
    [ $exit_code -eq 0 ]
    
    # Verify result
    run cat test.txt
    [ "${lines[0]}" = "line2" ]
    [ "${lines[1]}" = "line3" ]
}

@test "printf pipeline - test GPT's claim about entire pipeline in bash -c" {
    # Create test file
    echo -e "line1\nline2\nline3" > test.txt
    cp test.txt test_backup.txt
    
    # GPT's recommended approach: entire pipeline inside bash -c with pipefail
    run bash -c 'set -o pipefail; printf "1d\nw\nq\n" | "$1" --force test.txt -' bash "$SCRIPT_UNDER_TEST"
    gpt_approach_status=$status
    
    # Check if it worked
    if [ $gpt_approach_status -eq 0 ]; then
        # Verify the file was actually modified
        run cat test.txt
        if [ "${lines[0]}" = "line2" ] && [ "${lines[1]}" = "line3" ]; then
            echo "✅ GPT's approach WORKS: entire pipeline in bash -c"
            gpt_works=true
        else
            echo "❌ GPT's approach exit code OK but file unchanged"
            gpt_works=false
        fi
    else
        echo "❌ GPT's approach FAILED with exit code: $gpt_approach_status"
        gpt_works=false
    fi
    
    # Compare with what would be the broken approach (now fixed to not generate warnings)
    cp test_backup.txt test2.txt  
    run bash -c 'printf "1d\nw\nq\n" | "$1" --force test2.txt -' bash "$SCRIPT_UNDER_TEST"
    comparison_approach_status=$status
    
    # Report results
    echo "GPT approach (pipeline in bash -c): $gpt_approach_status (works: $gpt_works)"
    echo "Comparison approach (also proper): $comparison_approach_status"
    
    # GPT's claim should be proven true
    [ "$gpt_works" = "true" ]
}