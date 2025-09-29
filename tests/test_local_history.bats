#!/usr/bin/env bats

# Test suite for eed local history system (commit script and --undo functionality)

# Constants
readonly TEST_EMAIL="test@example.com"
readonly TEST_USER="Test User"
readonly INITIAL_CONTENT="initial content"
readonly EED_HISTORY_PREFIX="eed-history:"

setup() {
    # Create a temporary directory for this test
    TEST_TEMP_DIR="$(mktemp -d)"
    cd "$TEST_TEMP_DIR"
    
    # Initialize git repository
    git init .
    git config user.email "$TEST_EMAIL"
    git config user.name "$TEST_USER"
    
    # Create initial test file
    echo "$INITIAL_CONTENT" > test.txt
    git add test.txt
    git commit -m "initial commit"
    
    # Store the path to eed and commit scripts
    EED_SCRIPT="$BATS_TEST_DIRNAME/../eed"
    COMMIT_SCRIPT="$BATS_TEST_DIRNAME/../commit"
}

# Helper functions
assert_success() {
    [ "$status" -eq 0 ]
}

assert_failure() {
    [ "$status" -ne 0 ]
}

assert_output_contains() {
    local expected="$1"
    [[ "$output" == *"$expected"* ]]
}

create_eed_edit() {
    local file="$1"
    local content="$2"
    local position="${3:-1a}"  # default to append after line 1
    
    run "$EED_SCRIPT" "$file" - <<EOF
$position
$content
.
w
q
EOF
    assert_success
}

verify_preview_exists() {
    local file="$1"
    [ -f "$file.eed.preview" ]
}

verify_preview_removed() {
    local file="$1"
    [ ! -f "$file.eed.preview" ]
}

commit_changes() {
    local file="$1"
    local message="$2"

    # Use the upgraded commit script that handles both git mode and preview mode
    run "$COMMIT_SCRIPT" "$file" "$message"
    assert_success
}

verify_file_contains() {
    local file="$1"
    local content="$2"
    
    run grep -q "$content" "$file"
    assert_success
}

verify_file_not_contains() {
    local file="$1"
    local content="$2"
    
    run grep -q "$content" "$file"
    assert_failure
}

verify_git_commit_message() {
    local expected_message="$1"
    
    run git log -1 --oneline
    assert_success
    assert_output_contains "$EED_HISTORY_PREFIX $expected_message"
}

create_non_git_environment() {
    local dir_var="$1"
    eval "$dir_var=\"\$(mktemp -d)\""
    local dir_path
    eval "dir_path=\$$dir_var"
    cd "$dir_path"
}

cleanup_non_git_environment() {
    local dir_path="$1"
    cd "$TEST_TEMP_DIR"
    [ -n "$dir_path" ] && rm -rf "$dir_path"
}

teardown() {
    # Clean up
    cd /
    rm -rf "$TEST_TEMP_DIR"
}

@test "git mode stages changes and commit script creates git commit with eed-history prefix" {
    # Purpose: Verify complete commit workflow in git mode - direct editing and git integration
    local test_content="# Test comment added"
    local commit_msg="add test comment"

    create_eed_edit "test.txt" "$test_content"
    # In git mode, file is modified directly and staged (no preview file)
    verify_file_contains "test.txt" "$test_content"

    commit_changes "test.txt" "$commit_msg"

    verify_git_commit_message "$commit_msg"
}

@test "commit script displays comprehensive help information" {
    # Purpose: Verify help output contains all required information for users
    run "$COMMIT_SCRIPT" --help
    assert_success
    
    assert_output_contains "Apply eed preview changes"
    assert_output_contains "Usage: commit"
    assert_output_contains "eed --undo"
    assert_output_contains "EXAMPLES"
}

@test "commit script rejects invocation without required arguments" {
    # Purpose: Verify proper error handling and user guidance for missing arguments
    run "$COMMIT_SCRIPT"
    assert_failure
    
    assert_output_contains "Usage: commit"
    assert_output_contains "Use 'commit --help'"
}

@test "commit script fails when no staged changes exist" {
    # Purpose: Verify workflow enforcement - commit requires prior eed changes
    run "$COMMIT_SCRIPT" test.txt "some message"
    assert_failure

    assert_output_contains "No staged changes for test.txt"
    assert_output_contains "Run 'eed test.txt ...' first"

    # Verify original file unchanged
    verify_file_contains "test.txt" "$INITIAL_CONTENT"
}

@test "commit script fails gracefully outside git repository" {
    # Purpose: Verify git dependency is properly enforced and reported
    local nogit_dir
    create_non_git_environment nogit_dir
    
    echo "content" > file.txt
    echo "preview content" > file.txt.eed.preview
    
    run "$COMMIT_SCRIPT" file.txt "test message"
    assert_failure
    assert_output_contains "Not in a git repository"
    
    # Verify preview file preserved (atomic failure)
    [ -f "file.txt.eed.preview" ]
    
    cleanup_non_git_environment "$nogit_dir"
}

@test "eed --undo reverts last eed-history commit completely" {
    # Purpose: Verify undo functionality restores exact previous state
    local test_content="# Line added for undo test"
    local commit_msg="test undo functionality"
    
    # Record initial state
    local initial_line_count
    initial_line_count=$(wc -l < test.txt)
    
    create_eed_edit "test.txt" "$test_content"
    commit_changes "test.txt" "$commit_msg"
    verify_file_contains "test.txt" "$test_content"
    
    # Perform undo
    run "$EED_SCRIPT" --undo
    assert_success
    assert_output_contains "Last eed-history commit undone"
    
    # Verify complete reversion
    verify_file_not_contains "test.txt" "$test_content"
    verify_file_contains "test.txt" "$INITIAL_CONTENT"
    
    # Verify line count restored
    local final_line_count
    final_line_count=$(wc -l < test.txt)
    [ "$final_line_count" -eq "$initial_line_count" ]
}

@test "eed --undo fails gracefully outside git repository" {
    # Purpose: Verify undo command properly enforces git dependency
    local nogit_dir
    create_non_git_environment nogit_dir
    
    run "$EED_SCRIPT" --undo
    assert_failure
    assert_output_contains "Not in a git repository"
    
    cleanup_non_git_environment "$nogit_dir"
}

@test "eed --undo protects against undoing non-eed commits" {
    # Purpose: Verify safety mechanism when no eed-history commits exist
    echo "manual change" >> test.txt
    git add test.txt
    git commit -m "manual commit without eed-history prefix"

    run "$EED_SCRIPT" --undo
    assert_failure
    assert_output_contains "No eed-history commit found to undo"

    # Verify file unchanged (safety preserved)
    verify_file_contains "test.txt" "manual change"
}


@test "eed auto-saves uncommitted work before new edits" {
    # Purpose: Verify WIP protection prevents data loss during new edits
    local uncommitted_change="uncommitted manual edit"
    local new_edit="# New eed edit"
    
    # Make uncommitted changes (not yet in git)
    echo "$uncommitted_change" >> test.txt
    
    # Verify file is dirty
    run git diff --quiet test.txt
    assert_failure
    
    # Perform new eed edit - should trigger auto-save
    run "$EED_SCRIPT" test.txt - <<EOF
\$a
$new_edit
.
w
q
EOF
    assert_success
    assert_output_contains "Auto-saving work in progress"
    
    # Verify WIP commit was created
    run git log --oneline --grep="WIP auto-save"
    assert_success
    assert_output_contains "$EED_HISTORY_PREFIX WIP auto-save before new edit"
    
    # Verify WIP commit captured the uncommitted change
    run git show --name-only HEAD~1
    assert_success
    assert_output_contains "test.txt"
}

@test "eed detects git repository from target file location not cwd" {
    # Purpose: Verify git detection works with files in different git repositories
    
    # Create separate git repo in subdirectory
    mkdir subdir
    (cd subdir && \
     git init . && \
     git config user.email "$TEST_EMAIL" && \
     git config user.name "$TEST_USER" && \
     echo "subdir content" > subfile.txt && \
     git add subfile.txt && \
     git commit -m "subdir initial")
    
    # Move to parent directory (not a git repo)
    cd ..
    
    # Verify cwd is not a git repo
    run git rev-parse --is-inside-work-tree
    assert_failure
    
    # Test eed works with file in subdirectory git repo
    local subdir_path="$TEST_TEMP_DIR/subdir"
    create_eed_edit "$subdir_path/subfile.txt" "# Added to subdir file"
    
    # Verify git-aware output (should suggest commit command)
    assert_output_contains "commit \"$subdir_path/subfile.txt\""
}

@test "commit script maintains atomicity when git operations fail" {
    # Purpose: Verify commit operation is atomic - all changes or no changes
    local test_content="# Content for atomic test"

    create_eed_edit "test.txt" "$test_content"
    # In git mode, file is directly modified and staged
    verify_file_contains "test.txt" "$test_content"

    # Simulate git failure by corrupting repository
    rm -rf .git

    # Attempt commit - should fail cleanly
    run "$COMMIT_SCRIPT" test.txt "test message"
    assert_failure
    assert_output_contains "Not in a git repository"

    # Verify failure state - file remains modified but commit failed
    verify_file_contains "test.txt" "$test_content"
}
