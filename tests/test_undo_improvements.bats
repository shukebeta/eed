#!/usr/bin/env bats

# Test the improved --undo functionality using git revert

setup() {
    # Create a temporary directory for each test
    TEST_DIR=$(mktemp -d)
    cd "$TEST_DIR"

    # Initialize git repo with proper config
    git init --quiet
    git config user.email "test@example.com"
    git config user.name "Test User"

    # Create initial project structure
    echo 'function hello() { console.log("Hello"); }' > script.js
    echo '# Project' > README.md

    # Initial commit
    git add .
    git commit -m "Initial commit" --quiet
}

teardown() {
    # Cleanup
    cd /
    [ -n "$TEST_DIR" ] && [ -d "$TEST_DIR" ] && rm -rf "$TEST_DIR"
}

@test "undo - basic revert functionality" {
    # Make a change with eed
    run bash -c 'echo "1c
function hello() { console.log(\"Hello World\"); }
.
w
q" | "'"$BATS_TEST_DIRNAME"'/../eed" -m "Update greeting" script.js'

    [ "$status" -eq 0 ]
    [[ "$output" == *"Changes successfully committed"* ]]

    # Verify the change was made
    run cat script.js
    [ "$status" -eq 0 ]
    [[ "$output" == *"Hello World"* ]]

    # Count commits before undo
    run git log --oneline
    [ "$status" -eq 0 ]
    local commits_before=$(echo "$output" | wc -l)

    # Now undo the change
    run "$BATS_TEST_DIRNAME"/../eed --undo
    [ "$status" -eq 0 ]
    [[ "$output" == *"Last eed-history commit undone"* ]]
    [[ "$output" == *"Original commit preserved in history"* ]]

    # Verify the file content is reverted
    run cat script.js
    [ "$status" -eq 0 ]
    [[ "$output" == *"Hello"* ]]
    [[ "$output" != *"Hello World"* ]]

    # Verify history is preserved (should have one more commit - the revert)
    run git log --oneline
    [ "$status" -eq 0 ]
    local commits_after=$(echo "$output" | wc -l)
    [ "$commits_after" -eq $((commits_before + 1)) ]

    # Verify the revert commit message
    [[ "$output" == *"Revert"* ]]
    [[ "$output" == *"Update greeting"* ]]
}

@test "undo - finds eed-history commit even with intermediate commits" {
    # Make an eed change
    run bash -c 'echo "1a
// Added by eed
.
w
q" | "'"$BATS_TEST_DIRNAME"'/../eed" -m "Add comment" script.js'
    [ "$status" -eq 0 ]

    # Make manual commits after eed
    echo "# Updated README" > README.md
    git add README.md
    git commit -m "Manual commit 1" --quiet

    echo "# Updated README again" > README.md
    git add README.md
    git commit -m "Manual commit 2" --quiet

    # Verify the eed change is still there
    run cat script.js
    [ "$status" -eq 0 ]
    [[ "$output" == *"Added by eed"* ]]

    # Now undo - should find the eed-history commit despite intermediate commits
    run "$BATS_TEST_DIRNAME"/../eed --undo
    [ "$status" -eq 0 ]
    [[ "$output" == *"Last eed-history commit undone"* ]]

    # Verify the eed change is reverted but manual commits remain
    run cat script.js
    [ "$status" -eq 0 ]
    [[ "$output" != *"Added by eed"* ]]

    run cat README.md
    [ "$status" -eq 0 ]
    [[ "$output" == "# Updated README again" ]]
}

@test "undo - error handling when no eed-history commits exist" {
    # Try to undo when no eed commits exist
    run "$BATS_TEST_DIRNAME"/../eed --undo
    [ "$status" -eq 1 ]
    [[ "$output" == *"No eed-history commit found to undo"* ]]
    [[ "$output" == *"git log --grep"* ]]
}

@test "undo - works from subdirectory" {
    # Create subdirectory
    mkdir subdir
    cd subdir

    # Make eed change from root
    run bash -c 'echo "1a
// From subdir
.
w
q" | "'"$BATS_TEST_DIRNAME"'/../eed" -m "Add from subdir" ../script.js'
    [ "$status" -eq 0 ]

    # Undo from subdirectory
    run "$BATS_TEST_DIRNAME"/../eed --undo
    [ "$status" -eq 0 ]
    [[ "$output" == *"Last eed-history commit undone"* ]]

    # Verify change was reverted
    run cat ../script.js
    [ "$status" -eq 0 ]
    [[ "$output" != *"From subdir"* ]]
}

@test "undo - double undo (revert the revert)" {
    # Make an eed change
    run bash -c 'echo "1c
function hello() { console.log(\"Goodbye\"); }
.
w
q" | "'"$BATS_TEST_DIRNAME"'/../eed" -m "Change to goodbye" script.js'
    [ "$status" -eq 0 ]

    # Verify change
    run cat script.js
    [ "$status" -eq 0 ]
    [[ "$output" == *"Goodbye"* ]]

    # First undo
    run "$BATS_TEST_DIRNAME"/../eed --undo
    [ "$status" -eq 0 ]

    # Verify reverted
    run cat script.js
    [ "$status" -eq 0 ]
    [[ "$output" != *"Goodbye"* ]]
    [[ "$output" == *"Hello"* ]]

    # Second undo (revert the revert) - should restore the change
    run git revert HEAD --no-edit
    [ "$status" -eq 0 ]

    # Verify change is restored
    run cat script.js
    [ "$status" -eq 0 ]
    [[ "$output" == *"Goodbye"* ]]
}

@test "undo - error handling not in git repo" {
    # Create non-git directory
    NON_GIT_DIR=$(mktemp -d)
    cd "$NON_GIT_DIR"

    # Try to undo outside git repo
    run "$BATS_TEST_DIRNAME"/../eed --undo
    [ "$status" -eq 1 ]
    [[ "$output" == *"Not in a git repository"* ]]

    # Cleanup
    rm -rf "$NON_GIT_DIR"
}

@test "undo - preserves complete git history" {
    # Make multiple eed changes
    run bash -c 'echo "1a
// First change
.
w
q" | "'"$BATS_TEST_DIRNAME"'/../eed" -m "First eed change" script.js'
    [ "$status" -eq 0 ]

    run bash -c 'echo "2a
// Second change
.
w
q" | "'"$BATS_TEST_DIRNAME"'/../eed" -m "Second eed change" script.js'
    [ "$status" -eq 0 ]

    # Manual commit in between
    echo "# Manual change" > README.md
    git add README.md
    git commit -m "Manual commit between eed changes" --quiet

    # Get full history before undo
    run git log --oneline --grep="eed-history:"
    [ "$status" -eq 0 ]
    local eed_commits_before=$(echo "$output" | wc -l)
    [ "$eed_commits_before" -eq 2 ]

    # Undo should revert most recent eed commit
    run "$BATS_TEST_DIRNAME"/../eed --undo
    [ "$status" -eq 0 ]

    # Verify all eed commits still exist in history
    run git log --oneline --grep="eed-history:"
    [ "$status" -eq 0 ]
    # Should have exactly 2 eed-history commits
    [[ "$output" == *"First eed change"* ]]
    [[ "$output" == *"Second eed change"* ]]

    # Verify revert commit exists
    run git log --oneline --grep="Revert"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Second eed change"* ]]

    # Verify manual commit is untouched
    run git log --oneline --grep="Manual commit"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Manual commit between eed changes"* ]]
}
