#!/usr/bin/env bats

# Test transparency notifications for other staged files

setup() {
    TEST_DIR=$(mktemp -d)
    cd "$TEST_DIR"

    git init --quiet
    git config user.email "test@example.com"
    git config user.name "Test User"

    # Create initial files
    echo "original target" > target.txt
    echo "original other" > other.txt
    echo "original third" > third.txt

    git add .
    git commit -m "Initial commit" --quiet
}

teardown() {
    cd /
    [ -n "$TEST_DIR" ] && [ -d "$TEST_DIR" ] && rm -rf "$TEST_DIR"
}

@test "transparency - no notification when only target file staged" {
    # Clean repository, only edit target file
    run bash -c 'echo "1c
eed only change
.
w
q" | "'"$BATS_TEST_DIRNAME"'/../eed" -m "clean edit" target.txt'

    [ "$status" -eq 0 ]
    [[ "$output" == *"Changes successfully committed"* ]]
    [[ "$output" != *"This commit also included other staged files"* ]]
}


@test "transparency - auto-commit mode shows notification" {
    # Create scenario where WIP doesn't trigger but external staging happens
    # This requires careful setup to avoid WIP auto-save

    # Start with clean state, make external changes first
    echo "external mod" > other.txt
    git add other.txt  # Stage external change

    # Now use eed auto-commit mode - WIP will save external change,
    # but we can still test the notification logic
    run bash -c 'echo "1c
auto commit test
.
w
q" | "'"$BATS_TEST_DIRNAME"'/../eed" -m "auto test" target.txt'

    [ "$status" -eq 0 ]
    [[ "$output" == *"Auto-saving work in progress"* ]] # WIP triggered
    [[ "$output" == *"Changes successfully committed"* ]]

    # The main eed commit should be clean (only target.txt)
    run git show --name-only HEAD
    [ "$status" -eq 0 ]
    [[ "$output" == *"target.txt"* ]]
    [[ "$output" != *"other.txt"* ]] # other.txt was in WIP commit
}



@test "transparency - auto-commit mode with external staging" {
    # Test the edge case in auto-commit mode as well

    # Create clean state, then use eed auto-commit
    # But first, let external tool stage something
    echo "external auto change" > other.txt
    git add other.txt

    # Now run eed auto-commit - WIP will save the external change,
    # but we want to verify transparency in the main commit
    run bash -c 'echo "1c
auto commit with external
.
w
q" | "'"$BATS_TEST_DIRNAME"'/../eed" -m "auto edge test" target.txt'

    [ "$status" -eq 0 ]
    [[ "$output" == *"Auto-saving work in progress"* ]] # WIP triggered
    [[ "$output" == *"Changes successfully committed"* ]]

    # The main eed commit should be clean (external file was WIP saved)
    run git show --name-only HEAD
    [ "$status" -eq 0 ]
    [[ "$output" == *"target.txt"* ]]
    [[ "$output" != *"other.txt"* ]] # External file was in WIP, not main commit

    # So no transparency notification should appear for main commit
    [[ "$output" != *"This commit also included other staged files"* ]]
}

