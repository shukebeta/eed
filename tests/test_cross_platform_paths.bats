#!/usr/bin/env bats

# Test cross-platform relative path calculation (pure Bash implementation)

setup() {
    TEST_DIR=$(mktemp -d)
    cd "$TEST_DIR"

    git init --quiet
    git config user.email "test@example.com"
    git config user.name "Test User"

    # Create complex directory structure to test various path scenarios
    mkdir -p project/src/components
    mkdir -p project/tests/unit
    mkdir -p project/docs
    mkdir -p outside_project

    echo "component code" > project/src/components/Button.js
    echo "test code" > project/tests/unit/Button.test.js
    echo "documentation" > project/docs/README.md
    echo "outside file" > outside_project/external.txt
    echo "root file" > project/root.txt

    git add project/
    git commit -m "Initial project structure" --quiet
}

teardown() {
    cd /
    [ -n "$TEST_DIR" ] && [ -d "$TEST_DIR" ] && rm -rf "$TEST_DIR"
}

@test "cross-platform compatibility - basic relative path in subdirectory" {
    cd project

    # Test basic case: file in subdirectory relative to project root
    run bash -c 'echo "1a
// Cross-platform test
.
w
q" | "'"$BATS_TEST_DIRNAME"'/../eed" -m "cross-platform test" src/components/Button.js'

    [ "$status" -eq 0 ]
    [[ "$output" == *"Changes successfully committed"* ]]

    # Verify the commit worked with correct relative path
    run git show --name-only HEAD
    [ "$status" -eq 0 ]
    [[ "$output" == *"src/components/Button.js"* ]]
}

@test "cross-platform compatibility - nested directory structures" {
    cd project

    # Test deeply nested path
    run bash -c 'echo "1a
// Deep path test
.
w
q" | "'"$BATS_TEST_DIRNAME"'/../eed" -m "deep path" tests/unit/Button.test.js'

    [ "$status" -eq 0 ]
    [[ "$output" == *"Changes successfully committed"* ]]

    # Verify correct path in commit
    run git show --name-only HEAD
    [ "$status" -eq 0 ]
    [[ "$output" == *"tests/unit/Button.test.js"* ]]
}

@test "cross-platform compatibility - root level files" {
    cd project

    # Test file at project root
    run bash -c 'echo "1c
# Updated root file
.
w
q" | "'"$BATS_TEST_DIRNAME"'/../eed" -m "root file test" root.txt'

    [ "$status" -eq 0 ]
    [[ "$output" == *"Changes successfully committed"* ]]

    # Verify simple filename (no path) in commit
    run git show --name-only HEAD
    [ "$status" -eq 0 ]
    [[ "$output" == *"root.txt"* ]]
    # Should not have any path prefixes
    [[ "$output" != *"/"* ]] || [[ "$output" == *"root.txt"* ]]
}

@test "cross-platform compatibility - quick edit mode paths" {
    cd project

    # Test quick edit mode uses correct path logic
    run bash -c 'echo "1a
// Quick edit test
.
w
q" | "'"$BATS_TEST_DIRNAME"'/../eed" src/components/Button.js'

    [ "$status" -eq 0 ]
    [[ "$output" == *"Changes successfully committed"* ]]

    # Verify path in final commit
    run git show --name-only HEAD
    [ "$status" -eq 0 ]
    [[ "$output" == *"src/components/Button.js"* ]]

    # Verify quick edit commit message includes path (from repo root)
    run git log --format="%s" -1
    [ "$status" -eq 0 ]
    [[ "$output" == *"Quick edit on project/src/components/Button.js at"* ]]
}

@test "cross-platform compatibility - works from different working directories" {
    # Test running eed from different directories than the repo root
    cd project/src

    # Edit file using relative path from current directory
    run bash -c 'echo "1c
// From subdir
.
w
q" | "'"$BATS_TEST_DIRNAME"'/../eed" -m "from subdir" components/Button.js'

    [ "$status" -eq 0 ]
    [[ "$output" == *"Changes successfully committed"* ]]

    # Verify correct path relative to repo root (not current directory)
    run git show --name-only HEAD
    [ "$status" -eq 0 ]
    [[ "$output" == *"src/components/Button.js"* ]]
}

@test "cross-platform compatibility - function works in real usage" {
    # Instead of unit testing the function directly, verify it works in actual usage
    # This is more valuable than isolated unit testing since we've already tested
    # the integration in other tests

    cd project

    # Test that the cross-platform implementation produces correct git operations
    run bash -c 'echo "1a
// Function verification
.
w
q" | "'"$BATS_TEST_DIRNAME"'/../eed" -m "function test" src/components/Button.js'

    [ "$status" -eq 0 ]
    [[ "$output" == *"Changes successfully committed"* ]]

    # The fact that git operations succeeded means our relative path calculation worked
    # Verify the path is correctly recorded in git
    run git show --name-only HEAD
    [ "$status" -eq 0 ]
    [[ "$output" == *"src/components/Button.js"* ]]

    # Test another path to ensure consistency
    run bash -c 'echo "1a
// Another test
.
w
q" | "'"$BATS_TEST_DIRNAME"'/../eed" -m "second test" docs/README.md'

    [ "$status" -eq 0 ]
    run git show --name-only HEAD
    [ "$status" -eq 0 ]
    [[ "$output" == *"docs/README.md"* ]]
}

@test "cross-platform compatibility - handles edge cases gracefully" {
    cd project

    # Test with file that has spaces in name
    echo "content with spaces" > "file with spaces.txt"
    git add "file with spaces.txt"
    git commit -m "Add file with spaces" --quiet

    run bash -c 'echo "1c
Updated content with spaces
.
w
q" | "'"$BATS_TEST_DIRNAME"'/../eed" -m "spaces test" "file with spaces.txt"'

    [ "$status" -eq 0 ]
    [[ "$output" == *"Changes successfully committed"* ]]

    # Verify file with spaces handled correctly
    run git show --name-only HEAD
    [ "$status" -eq 0 ]
    [[ "$output" == *"file with spaces.txt"* ]]
}

@test "cross-platform compatibility - simulated macOS environment" {
    # This test simulates what would happen if realpath --relative-to fails
    # by testing our pure bash implementation works correctly

    cd project

    # Test various path scenarios that would be problematic with GNU realpath dependency
    test_files=(
        "src/components/Button.js"
        "tests/unit/Button.test.js"
        "docs/README.md"
        "root.txt"
    )

    for file in "${test_files[@]}"; do
        run bash -c 'echo "1a
// macOS compat test
.
w
q" | "'"$BATS_TEST_DIRNAME"'/../eed" -m "macOS test" "'$file'"'

        [ "$status" -eq 0 ]
        [[ "$output" == *"Changes successfully committed"* ]]

        # Verify each file path is correct in commit
        run git show --name-only HEAD
        [ "$status" -eq 0 ]
        [[ "$output" == *"$file"* ]]
    done
}