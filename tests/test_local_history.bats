#!/usr/bin/env bats

# Test suite for eed local history system (WIP auto-save functionality)

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

@test "git mode auto-commits with custom message when -m provided" {
    # Purpose: Verify auto-commit workflow in git mode with custom message
    local test_content="# Test comment added"
    local commit_msg="add test comment"

    # Use -m flag to provide custom commit message
    run "$EED_SCRIPT" -m "$commit_msg" "test.txt" - <<EOF
1a
$test_content
.
w
q
EOF
    assert_success

    # In git mode, file is modified directly and committed
    verify_file_contains "test.txt" "$test_content"

    verify_git_commit_message "$commit_msg"
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
    # Note: Path may be normalized (symlinks resolved), so check for "commit" and "subfile.txt"
    assert_output_contains "commit"
    assert_output_contains "subfile.txt"
}

