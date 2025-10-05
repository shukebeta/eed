#!/usr/bin/env bats

# Test dirname safety fixes - prevents partial WIP commits
# This test verifies the fix for the critical security issue where
# cd "$(dirname "$file_path")" caused git operations to work only
# in subdirectories, missing uncommitted changes in other parts of the project.

setup() {
    # Create a temporary directory for each test
    TEST_DIR=$(mktemp -d)
    cd "$TEST_DIR"
    
    # Initialize git repo with proper config
    git init --quiet
    git config user.email "test@example.com" 
    git config user.name "Test User"
    
    # Create realistic project structure
    mkdir -p src/components src/utils
    echo '{"name": "test-project", "version": "1.0.0"}' > package.json
    echo 'export default function Button() { return <button>Click me</button>; }' > src/components/Button.js
    echo 'export const helper = () => "help";' > src/utils/helper.js
    
    # Initial commit
    git add .
    git commit -m "Initial commit" --quiet
}

teardown() {
    # Cleanup
    cd /
    [ -n "$TEST_DIR" ] && [ -d "$TEST_DIR" ] && rm -rf "$TEST_DIR"
}

@test "dirname safety - WIP auto-save includes all project files" {
    # Modify file in project root (simulating user's uncommitted work)
    echo '{"name": "test-project", "version": "1.1.0", "scripts": {"test": "echo test"}}' > package.json
    
    # Also modify file in different subdirectory
    echo 'export const helper = () => "updated helper";' > src/utils/helper.js
    
    # Verify we have uncommitted changes
    run git diff-index --quiet HEAD --
    [ "$status" -eq 1 ] # Should have uncommitted changes
    
    # Use eed to edit file in another subdirectory - this should trigger auto_save_work_in_progress
    run bash -c 'echo "1a
// Updated component  
.
w
q" | "'"$BATS_TEST_DIRNAME"'/../eed" -m "Update Button component" src/components/Button.js'
    
    [ "$status" -eq 0 ]
    [[ "$output" == *"Auto-saving work in progress"* ]]
    [[ "$output" == *"Changes successfully committed"* ]]
    
    # Verify WIP commit was created
    run git log --grep="WIP auto-save" --format="%H" -1
    [ "$status" -eq 0 ]
    [ -n "$output" ] # Should have a commit hash
    
    WIP_COMMIT="$output"
    
    # Critical check: Verify ALL modified files are in the WIP commit
    run git show --name-only "$WIP_COMMIT"
    [ "$status" -eq 0 ]
    [[ "$output" == *"package.json"* ]]     # Root file must be included
    [[ "$output" == *"src/utils/helper.js"* ]] # Other subdirectory file must be included
    
    # Verify the commit message is correct
    run git show --format="%s" -s "$WIP_COMMIT"
    [ "$status" -eq 0 ]
    [[ "$output" == "eed-history: WIP auto-save before new edit" ]]
}

@test "dirname safety - WIP auto-save with nested subdirectories" {
    # Create deeper nesting
    mkdir -p deep/nested/path
    echo 'const nested = "deep";' > deep/nested/path/file.js
    git add deep/nested/path/file.js
    git commit -m "Add nested file" --quiet
    
    # Modify files at different levels
    echo '{"name": "test-project", "version": "2.0.0"}' > package.json  # Root
    echo 'export const helper = () => "v2";' > src/utils/helper.js      # Mid-level
    echo 'const nested = "updated deep";' > deep/nested/path/file.js    # Deep
    
    # Edit file at yet another level
    mkdir -p another/level
    run bash -c 'echo "1a
console.log(\"new file\");
.
w
q" | "'"$BATS_TEST_DIRNAME"'/../eed" -m "Add new file" another/level/newfile.js'
    
    [ "$status" -eq 0 ]
    [[ "$output" == *"Auto-saving work in progress"* ]]
    
    # Get WIP commit
    run git log --grep="WIP auto-save" --format="%H" -1  
    [ "$status" -eq 0 ]
    WIP_COMMIT="$output"
    
    # Verify ALL modified files from ALL levels are included
    run git show --name-only "$WIP_COMMIT"
    [ "$status" -eq 0 ]
    [[ "$output" == *"package.json"* ]]
    [[ "$output" == *"src/utils/helper.js"* ]]
    [[ "$output" == *"deep/nested/path/file.js"* ]]
}

@test "dirname safety - no WIP commit when no changes exist" {
    # No uncommitted changes exist
    run git diff-index --quiet HEAD --
    [ "$status" -eq 0 ] # Should have no uncommitted changes
    
    # Use eed - should not create WIP commit
    run bash -c 'echo "1a
// No WIP needed
.
w
q" | "'"$BATS_TEST_DIRNAME"'/../eed" -m "Update without WIP" src/components/Button.js'
    
    [ "$status" -eq 0 ]
    [[ "$output" != *"Auto-saving work in progress"* ]]
    
    # Verify no WIP commit was created
    run git log --grep="WIP auto-save" --format="%H" -1
    [ "$status" -eq 0 ]
    [ -z "$output" ] # Should be empty - no WIP commit
}

@test "dirname safety - git operations use correct repository root" {
    # Create a scenario where the file is in a subdirectory but git operations
    # need to work from repo root
    mkdir -p very/deep/subdirectory
    
    # Modify file in root
    echo '{"name": "test-project", "version": "3.0.0"}' > package.json
    
    # Edit file in deep subdirectory
    run bash -c 'echo "1a
export const deep = \"file\";
.
w
q" | "'"$BATS_TEST_DIRNAME"'/../eed" -m "Deep edit" very/deep/subdirectory/deep.js'
    
    [ "$status" -eq 0 ]
    [[ "$output" == *"Auto-saving work in progress"* ]]
    [[ "$output" == *"Changes successfully committed"* ]]
    
    # Verify git history shows proper commits
    run git log --oneline -3
    [ "$status" -eq 0 ]
    [[ "$output" == *"Deep edit"* ]]
    [[ "$output" == *"WIP auto-save"* ]]
    
    # Verify the final commit includes the file with correct path
    run git show --name-only HEAD
    [ "$status" -eq 0 ]
    [[ "$output" == *"very/deep/subdirectory/deep.js"* ]]
}

@test "dirname safety - auto-commit mode preserves correct paths" {
    # Test auto-commit (without -m flag) with WIP auto-save
    echo '{"dependencies": {"new": "1.0.0"}}' > package.json

    # Edit file in subdirectory - should auto-save package.json first, then commit Button.js
    run bash -c 'echo "1a
// Quick edit test
.
w
q" | "'"$BATS_TEST_DIRNAME"'/../eed" src/components/Button.js'

    [ "$status" -eq 0 ]
    [[ "$output" == *"Auto-saving work in progress"* ]]
    [[ "$output" == *"Changes successfully committed"* ]]

    # Verify 2 eed-history commits were created (one for package.json, one for Button.js)
    run git log --grep="eed-history:" --oneline -n 2
    [ "$status" -eq 0 ]

    # Should have exactly 2 eed-history commits
    commit_count=$(echo "$output" | wc -l)
    [ "$commit_count" -eq 2 ]

    # Verify latest commit (Button.js quick edit) has correct path
    run git log --grep="Quick edit" --format="%H" -n 1
    [ "$status" -eq 0 ]
    LATEST_COMMIT="$output"

    run git show --name-only "$LATEST_COMMIT"
    [ "$status" -eq 0 ]
    [[ "$output" == *"src/components/Button.js"* ]]

    # Verify second-to-last commit (package.json WIP auto-save) has package.json
    run git log --grep="WIP auto-save" --format="%H" -n 1
    [ "$status" -eq 0 ]
    PREVIOUS_COMMIT="$output"

    run git show --name-only "$PREVIOUS_COMMIT"
    [ "$status" -eq 0 ]
    [[ "$output" == *"package.json"* ]]
}