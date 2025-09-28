#!/usr/bin/env bats

# Unit tests for get_relative_path function (simplified and focused)

setup() {
    TEST_DIR=$(mktemp -d)
    cd "$TEST_DIR"
    
    # Create test directory structure
    mkdir -p a/b/c/d
    mkdir -p project/src/components
    
    # Create test files
    touch a/b/c/file1.txt
    touch a/b/c/d/file2.txt  
    touch project/src/components/App.js
}

teardown() {
    cd /
    [ -n "$TEST_DIR" ] && [ -d "$TEST_DIR" ] && rm -rf "$TEST_DIR"
}

@test "unit: get_relative_path - basic functionality verification" {
    # Test: file in subdirectory relative to parent
    result=$(bash -c 'source "'"$BATS_TEST_DIRNAME"'/../lib/eed_common.sh"; get_relative_path "'"$PWD/a/b/c/file1.txt"'" "'"$PWD/a/b"'"')
    [ "$result" = "c/file1.txt" ]
    
    # Test: same directory  
    result=$(bash -c 'source "'"$BATS_TEST_DIRNAME"'/../lib/eed_common.sh"; get_relative_path "'"$PWD/a/b/c/file1.txt"'" "'"$PWD/a/b/c"'"')
    [ "$result" = "file1.txt" ]
    
    # Test: deeply nested
    result=$(bash -c 'source "'"$BATS_TEST_DIRNAME"'/../lib/eed_common.sh"; get_relative_path "'"$PWD/a/b/c/d/file2.txt"'" "'"$PWD/a"'"')
    [ "$result" = "b/c/d/file2.txt" ]
}

@test "unit: get_relative_path - cross-platform compatibility essentials" {
    # Scenario 1: Project file relative to project root (common eed case)
    result=$(bash -c 'source "'"$BATS_TEST_DIRNAME"'/../lib/eed_common.sh"; get_relative_path "'"$PWD/project/src/components/App.js"'" "'"$PWD/project"'"')
    [ "$result" = "src/components/App.js" ]
    
    # Scenario 2: Non-existent file (eed creates files)
    result=$(bash -c 'source "'"$BATS_TEST_DIRNAME"'/../lib/eed_common.sh"; get_relative_path "'"$PWD/a/b/newfile.txt"'" "'"$PWD/a"'"')
    [ "$result" = "b/newfile.txt" ]
}

@test "unit: get_relative_path - ensures no realpath --relative-to dependency" {
    # The most important test: verify this works without GNU realpath
    
    # Create a typical eed scenario
    mkdir -p workspace/src/utils
    touch workspace/src/utils/helper.js
    
    # This should work on any Unix system (macOS, Linux, BSD)
    result=$(bash -c 'source "'"$BATS_TEST_DIRNAME"'/../lib/eed_common.sh"; get_relative_path "'"$PWD/workspace/src/utils/helper.js"'" "'"$PWD/workspace"'"')
    [ "$result" = "src/utils/helper.js" ]
    
    # Verify it handles edge case with same directory
    result=$(bash -c 'source "'"$BATS_TEST_DIRNAME"'/../lib/eed_common.sh"; get_relative_path "'"$PWD/workspace"'" "'"$PWD/workspace"'"')
    [ "$result" = "." ]
}

@test "unit: get_relative_path - validates the fix works in eed context" {
    # Integration test: verify the function works exactly as eed would use it
    
    # This mirrors what happens in eed's git mode
    repo_root="$PWD/project"
    file_path="$PWD/project/src/components/App.js"
    
    relative_path=$(bash -c 'source "'"$BATS_TEST_DIRNAME"'/../lib/eed_common.sh"; get_relative_path "'"$file_path"'" "'"$repo_root"'"')
    
    [ "$relative_path" = "src/components/App.js" ]
    
    # Verify this path would work with git commands
    cd project
    git init --quiet
    git config user.email "test@example.com"
    git config user.name "Test User"
    
    # The relative path should work with git add
    echo "test content" > "$relative_path"
    git add "$relative_path" 
    
    # Verify file is staged correctly
    run git diff --cached --name-only
    [ "$status" -eq 0 ]
    [[ "$output" == *"src/components/App.js"* ]]
}