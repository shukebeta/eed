#!/usr/bin/env bats

# Critical security fix test: WIP auto-save must detect ALL changes
# This test verifies the fix for the data loss vulnerability where
# git diff-index only checked staged changes, missing unstaged modifications

setup() {
    TEST_DIR=$(mktemp -d)
    cd "$TEST_DIR"

    git init --quiet
    git config user.email "test@example.com"
    git config user.name "Test User"

    # Create initial files
    echo "original content" > file1.txt
    echo "original content" > file2.txt
    mkdir -p subdir
    echo "original content" > subdir/file3.txt

    git add .
    git commit -m "Initial commit" --quiet
}

teardown() {
    cd /
    [ -n "$TEST_DIR" ] && [ -d "$TEST_DIR" ] && rm -rf "$TEST_DIR"
}

@test "WIP auto-save - detects unstaged changes (DATA LOSS FIX)" {
    # Make unstaged changes (the critical case that was missed before)
    echo "unstaged modification" > file1.txt
    echo "another unstaged change" > file2.txt

    # Verify these are unstaged changes
    run git diff --quiet
    [ "$status" -ne 0 ] # Should have unstaged changes

    run git diff --cached --quiet
    [ "$status" -eq 0 ] # Should have no staged changes

    # Run eed - this MUST trigger WIP auto-save to prevent data loss
    run bash -c 'echo "1a
eed added this line
.
w
q" | "'"$BATS_TEST_DIRNAME"'/../eed" -m "eed edit" subdir/file3.txt'

    [ "$status" -eq 0 ]
    [[ "$output" == *"Auto-saving work in progress"* ]]

    # Critical verification: unstaged changes must be in WIP commit
    run git log --grep="WIP auto-save" --format="%H" -1
    [ "$status" -eq 0 ]
    WIP_COMMIT="$output"
    [ -n "$WIP_COMMIT" ]

    # Verify WIP commit contains the unstaged changes
    run git show --name-only "$WIP_COMMIT"
    [ "$status" -eq 0 ]
    [[ "$output" == *"file1.txt"* ]]
    [[ "$output" == *"file2.txt"* ]]

    # Verify WIP commit contains the actual content changes
    run git show "$WIP_COMMIT" -- file1.txt
    [ "$status" -eq 0 ]
    [[ "$output" == *"unstaged modification"* ]]
}

@test "WIP auto-save - detects staged changes" {
    # Make staged changes
    echo "staged modification" > file1.txt
    git add file1.txt

    # Verify these are staged changes
    run git diff --quiet
    [ "$status" -eq 0 ] # Should have no unstaged changes

    run git diff --cached --quiet
    [ "$status" -ne 0 ] # Should have staged changes

    # Run eed - should trigger WIP auto-save
    run bash -c 'echo "1a
eed line
.
w
q" | "'"$BATS_TEST_DIRNAME"'/../eed" -m "eed edit" file2.txt'

    [ "$status" -eq 0 ]
    [[ "$output" == *"Auto-saving work in progress"* ]]

    # Verify WIP commit was created
    run git log --grep="WIP auto-save" --format="%H" -1
    [ "$status" -eq 0 ]
    WIP_COMMIT="$output"

    # Verify staged changes are in WIP commit
    run git show "$WIP_COMMIT" -- file1.txt
    [ "$status" -eq 0 ]
    [[ "$output" == *"staged modification"* ]]
}

@test "WIP auto-save - detects mixed staged and unstaged changes" {
    # Make both staged and unstaged changes
    echo "staged change" > file1.txt
    git add file1.txt

    echo "unstaged change" > file2.txt
    # file2.txt is NOT staged

    # Verify mixed state
    run git diff --quiet
    [ "$status" -ne 0 ] # Has unstaged changes

    run git diff --cached --quiet
    [ "$status" -ne 0 ] # Has staged changes

    # Run eed - should save EVERYTHING
    run bash -c 'echo "1a
new content
.
w
q" | "'"$BATS_TEST_DIRNAME"'/../eed" -m "eed change" subdir/file3.txt'

    [ "$status" -eq 0 ]
    [[ "$output" == *"Auto-saving work in progress"* ]]

    # Get WIP commit
    run git log --grep="WIP auto-save" --format="%H" -1
    [ "$status" -eq 0 ]
    WIP_COMMIT="$output"

    # Verify BOTH staged and unstaged changes are saved
    run git show --name-only "$WIP_COMMIT"
    [ "$status" -eq 0 ]
    [[ "$output" == *"file1.txt"* ]] # staged change
    [[ "$output" == *"file2.txt"* ]] # unstaged change
}

@test "WIP auto-save - no save when truly clean working directory" {
    # Verify working directory is completely clean
    run git diff --quiet
    [ "$status" -eq 0 ] # No unstaged changes

    run git diff --cached --quiet
    [ "$status" -eq 0 ] # No staged changes

    # Run eed - should NOT trigger WIP save
    run bash -c 'echo "1a
clean directory edit
.
w
q" | "'"$BATS_TEST_DIRNAME"'/../eed" -m "clean edit" file1.txt'

    [ "$status" -eq 0 ]
    [[ "$output" != *"Auto-saving work in progress"* ]]

    # Verify no WIP commit was created
    run git log --grep="WIP auto-save" --format="%H" -1
    [ "$status" -eq 0 ]
    [ -z "$output" ] # Should be empty
}

@test "WIP auto-save - comprehensive data loss prevention test" {
    # Simulate a realistic scenario where user has been working
    # with multiple files in different states

    # 1. User modifies file but doesn't stage it
    echo "important work 1" > file1.txt

    # 2. User stages one change
    echo "important work 2" > file2.txt
    git add file2.txt

    # 3. User makes more unstaged changes
    echo "important work 3" > file2.txt  # Overwrite staged version

    # 4. User creates new file (untracked)
    echo "brand new work" > new_file.txt

    # At this point user has:
    # - Unstaged changes in file1.txt
    # - Mixed staged/unstaged in file2.txt
    # - Untracked file new_file.txt

    # AI calls eed to edit a different file - ALL user work must be preserved
    run bash -c 'echo "1c
AI modification
.
w
q" | "'"$BATS_TEST_DIRNAME"'/../eed" -m "AI change" subdir/file3.txt'

    [ "$status" -eq 0 ]
    [[ "$output" == *"Auto-saving work in progress"* ]]

    # Critical test: ALL user work must be in WIP commit
    run git log --grep="WIP auto-save" --format="%H" -1
    [ "$status" -eq 0 ]
    WIP_COMMIT="$output"

    # Verify all changes are preserved
    run git show --name-only "$WIP_COMMIT"
    [ "$status" -eq 0 ]
    [[ "$output" == *"file1.txt"* ]]     # unstaged changes
    [[ "$output" == *"file2.txt"* ]]     # mixed staged/unstaged
    [[ "$output" != *"new_file.txt"* ]]  # untracked file NOT saved (by design)

    # Verify actual content is preserved
    run git show "$WIP_COMMIT":file1.txt
    [ "$status" -eq 0 ]
    [[ "$output" == "important work 1" ]]

    run git show "$WIP_COMMIT":file2.txt
    [ "$status" -eq 0 ]
    [[ "$output" == "important work 3" ]] # Latest version preserved

}

@test "WIP auto-save - comparison with old buggy behavior simulation" {
    # This test demonstrates the difference between the old and new detection logic

    # Make unstaged changes (these would be missed by incomplete detection)
    echo "critical unstaged work" > file1.txt
    echo "more critical work" > file2.txt

    # The key difference is that we now use TWO checks instead of one:
    # 1. git diff --quiet (working directory vs index)
    # 2. git diff --cached --quiet (index vs HEAD)
    # Both must be clean for the repo to be considered clean

    # Working directory has changes
    run git -C "$PWD" diff --quiet
    [ "$status" -ne 0 ] # Should detect working dir changes

    # Index is clean (no staged changes)
    run git -C "$PWD" diff --cached --quiet
    [ "$status" -eq 0 ] # Index matches HEAD

    # With the fix, WIP save should trigger because working dir is dirty
    run bash -c 'echo "1a
eed addition
.
w
q" | "'"$BATS_TEST_DIRNAME"'/../eed" -m "test" subdir/file3.txt'

    [ "$status" -eq 0 ]
    [[ "$output" == *"Auto-saving work in progress"* ]]

    # Verify the critical work is saved
    run git log --grep="WIP auto-save" --format="%H" -1
    [ "$status" -eq 0 ]
    WIP_COMMIT="$output"

    run git show "$WIP_COMMIT":file1.txt
    [ "$status" -eq 0 ]
    [[ "$output" == "critical unstaged work" ]]
}
