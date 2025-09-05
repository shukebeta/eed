#!/usr/bin/env bats

# Tests for simplified complex message strategy
# Goal: Reduce noise, provide clear feedback only when necessary

setup() {
    # Create unique test directory and switch into it
    TEST_DIR="$(mktemp -d)"
    cd "$TEST_DIR" || exit

    # Use the repository eed executable directly (use repo-relative path)
    REPO_ROOT="$BATS_TEST_DIRNAME/.."
    SCRIPT_UNDER_TEST="$REPO_ROOT/eed"

    # Create test file
    echo -e "line1\nline2\nline3\nline4\nline5" > test_file.txt
}

teardown() {
    cd /
    rm -rf "$TEST_DIR"
}





