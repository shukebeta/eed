#!/usr/bin/env bats

# Regression test for smart dot protection false positive
# Bug: Multiple c/a/i commands with their own terminators were incorrectly
# treated as a single input block, with only the last dot recognized as terminator

setup() {
    TEST_DIR=$(mktemp -d)
    cd "$TEST_DIR"
    
    git init --quiet
    git config user.email "test@test.com"
    git config user.name "Test User"
    
    # Create test file
    cat > test.txt <<'TESTFILE'
line 1
line 2
line 3
TESTFILE
    
    git add .
    git commit -m "Initial" --quiet
}

teardown() {
    cd /
    rm -rf "$TEST_DIR"
}

@test "smart dot: multiple c commands with separate terminators" {
    # This is the pattern that caused the false positive
    run bash -c 'echo "1c
CHANGED 1
.
2c
CHANGED 2
.
3c
CHANGED 3
.
w
q" | "'"$BATS_TEST_DIRNAME"'/../eed" -m "test" test.txt'
    
    [ "$status" -eq 0 ]
    
    # Verify correct result
    run cat test.txt
    [ "$status" -eq 0 ]
    [ "${lines[0]}" = "CHANGED 1" ]
    [ "${lines[1]}" = "CHANGED 2" ]
    [ "${lines[2]}" = "CHANGED 3" ]
    
    # Should NOT contain literal command text
    [[ "$output" != *"2c"* ]]
    [[ "$output" != *"3c"* ]]
}

@test "smart dot: multiple a commands with separate terminators" {
    run bash -c 'echo "1a
ADDED AFTER 1
.
2a
ADDED AFTER 2
.
w
q" | "'"$BATS_TEST_DIRNAME"'/../eed" -m "test" test.txt'
    
    [ "$status" -eq 0 ]
    
    run cat test.txt
    [ "$status" -eq 0 ]
    [ "${lines[0]}" = "line 1" ]
    [ "${lines[1]}" = "ADDED AFTER 1" ]
    [ "${lines[2]}" = "line 2" ]
    [ "${lines[3]}" = "ADDED AFTER 2" ]
}

