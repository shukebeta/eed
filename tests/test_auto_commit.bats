#!/usr/bin/env bats

# Auto-Commit Feature Tests
# Tests git mode, auto-commit, and manual commit mode

setup() {
    # Determine repository root using BATS_TEST_DIRNAME
    REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"

    # Create unique test directory and switch into it
    TEST_DIR="$(mktemp -d)"
    cd "$TEST_DIR"

    # Use the repository eed executable directly
    SCRIPT_UNDER_TEST="$REPO_ROOT/eed"

    # Prevent logging during tests
    export EED_TESTING=true

    # Create sample files for testing
    cat > app.py << 'EOF'
def main():
    print("Hello World")
    return 0

if __name__ == "__main__":
    main()
EOF

    cat > config.ini << 'EOF'
[database]
host=localhost
port=5432
name=testdb
EOF
}

teardown() {
    cd /
    rm -rf "$TEST_DIR"
}

@test "non-git repo - uses preview mode regardless of -m parameter" {
    # Test that non-git repositories always use preview mode
    run "$SCRIPT_UNDER_TEST" app.py -m "Test commit" "2c
    print('Updated content')
.
w
q"
    [ "$status" -eq 0 ]

    # Should show preview mode output
    [[ "$output" == *"Review the changes below"* ]]
    [[ "$output" == *"To apply these changes, run:"* ]]
    [[ "$output" == *"mv 'app.py.eed.preview' 'app.py'"* ]]

    # Original file unchanged
    run grep -q "Hello World" app.py
    [ "$status" -eq 0 ]

    # Preview file created
    [ -f app.py.eed.preview ]
    run grep -q "Updated content" app.py.eed.preview
    [ "$status" -eq 0 ]
}

@test "git repo with -m parameter - auto-commit mode" {
    # Initialize git repo
    run git init .
    [ "$status" -eq 0 ]
    run git config user.email "test@example.com"
    [ "$status" -eq 0 ]
    run git config user.name "Test User"
    [ "$status" -eq 0 ]

    # Add files to git tracking (ensure clean working directory)
    run git add .
    [ "$status" -eq 0 ]
    run git commit -m "Initial commit"
    [ "$status" -eq 0 ]

    # Test auto-commit with -m parameter
    run "$SCRIPT_UNDER_TEST" app.py -m "Update greeting message" "2c
    print('Hello, Git World!')
.
w
q"
    [ "$status" -eq 0 ]

    # Should show auto-commit success message
    [[ "$output" == *"Changes successfully committed"* ]]

    # File should be directly updated (no preview file)
    run grep -q "Hello, Git World!" app.py
    [ "$status" -eq 0 ]
    [ ! -f app.py.eed.preview ]

    # Verify git commit was created
    run git log --oneline -1
    [ "$status" -eq 0 ]
    [[ "$output" == *"Update greeting message"* ]]

    # Verify file is staged and committed
    run git status --porcelain
    [ "$status" -eq 0 ]
    git_status_output="$output"
    [ -z "$git_status_output" ]  # No unstaged changes
}

@test "git repo without -m parameter - quick edit mode" {
    # Initialize git repo
    run git init .
    [ "$status" -eq 0 ]
    run git config user.email "test@example.com"
    [ "$status" -eq 0 ]
    run git config user.name "Test User"
    [ "$status" -eq 0 ]

    # Add file to git tracking
    run git add .
    [ "$status" -eq 0 ]
    run git commit -m "Initial commit"
    [ "$status" -eq 0 ]

    # Test quick edit mode without -m parameter
    run "$SCRIPT_UNDER_TEST" app.py "2c
    print('Quick edit test')
.
w
q"
    [ "$status" -eq 0 ]

    # Should show auto-commit success message
    [[ "$output" == *"Changes successfully committed"* ]]

    # File should be directly updated (no preview file)
    run grep -q "Quick edit test" app.py
    [ "$status" -eq 0 ]
    [ ! -f app.py.eed.preview ]

    # Verify git commit was created with quick edit message
    run git log --format="%s" -1
    [ "$status" -eq 0 ]
    [[ "$output" == *"Quick edit on app.py at"* ]]

    # Verify file is committed (no uncommitted changes)
    run git status --porcelain
    [ "$status" -eq 0 ]
    git_status_output="$output"
    [ -z "$git_status_output" ]  # No uncommitted changes
}

@test "git repo - --message parameter (long form)" {
    # Initialize git repo
    run git init .
    [ "$status" -eq 0 ]
    run git config user.email "test@example.com"
    [ "$status" -eq 0 ]
    run git config user.name "Test User"
    [ "$status" -eq 0 ]

    # Add file to git tracking
    run git add .
    [ "$status" -eq 0 ]
    run git commit -m "Initial commit"
    [ "$status" -eq 0 ]

    # Test auto-commit with --message parameter
    run "$SCRIPT_UNDER_TEST" app.py --message "Long form commit message" "2c
    print('Long form test')
.
w
q"
    [ "$status" -eq 0 ]

    # Should show auto-commit success message
    [[ "$output" == *"Changes successfully committed"* ]]

    # Verify git commit was created with correct message
    run git log --oneline -1
    [ "$status" -eq 0 ]
    [[ "$output" == *"Long form commit message"* ]]
}

@test "git repo - edit failure rollback in git mode" {
    # Initialize git repo
    run git init .
    [ "$status" -eq 0 ]
    run git config user.email "test@example.com"
    [ "$status" -eq 0 ]
    run git config user.name "Test User"
    [ "$status" -eq 0 ]

    # Add file to git tracking
    run git add .
    [ "$status" -eq 0 ]
    run git commit -m "Initial commit"
    [ "$status" -eq 0 ]

    # Store original content
    original_content=$(cat app.py)

    # Test edit failure in git mode
    run "$SCRIPT_UNDER_TEST" app.py -m "This should fail" "1c
new content
.
999p
q"
    [ "$status" -ne 0 ]

    # Should show error message
    [[ "$output" == *"Edit command failed"* ]]

    # File should be rolled back to original content
    current_content=$(cat app.py)
    [ "$original_content" = "$current_content" ]

    # No git changes should exist
    run git status --porcelain
    [ "$status" -eq 0 ]
    git_status_output="$output"
    [ -z "$git_status_output" ]  # No changes

    # No new commit created
    run git log --oneline -1
    [ "$status" -eq 0 ]
    [[ "$output" == *"Initial commit"* ]]
}

@test "git repo - empty diff handling in auto-commit mode" {
    # Initialize git repo
    run git init .
    [ "$status" -eq 0 ]
    run git config user.email "test@example.com"
    [ "$status" -eq 0 ]
    run git config user.name "Test User"
    [ "$status" -eq 0 ]

    # Add file to git tracking
    run git add .
    [ "$status" -eq 0 ]
    run git commit -m "Initial commit"
    [ "$status" -eq 0 ]

    # Test command that makes no changes
    run "$SCRIPT_UNDER_TEST" app.py -m "No actual changes" "w
q"
    [ "$status" -eq 0 ]

    # Should handle gracefully without creating empty commit
    [[ "$output" == *"No changes were made to the file content"* ]]

    # File unchanged
    run grep -q "Hello World" app.py
    [ "$status" -eq 0 ]
}

@test "git repo - file creation in auto-commit mode" {
    # Initialize git repo
    run git init .
    [ "$status" -eq 0 ]
    run git config user.email "test@example.com"
    [ "$status" -eq 0 ]
    run git config user.name "Test User"
    [ "$status" -eq 0 ]

    # Create initial commit
    echo "initial" > README.md
    run git add README.md
    [ "$status" -eq 0 ]
    run git commit -m "Initial commit"
    [ "$status" -eq 0 ]

    # Test creating new file in auto-commit mode
    run "$SCRIPT_UNDER_TEST" newfile.txt -m "Create new file" "a
This is a new file
created by eed
.
w
q"
    [ "$status" -eq 0 ]

    # Should show auto-commit success
    [[ "$output" == *"Changes successfully committed"* ]]

    # New file should exist with content
    [ -f newfile.txt ]
    run grep -q "This is a new file" newfile.txt
    [ "$status" -eq 0 ]

    # Verify git commit
    run git log --oneline -1
    [ "$status" -eq 0 ]
    [[ "$output" == *"Create new file"* ]]

    # File should be tracked by git
    run git ls-files newfile.txt
    [ "$status" -eq 0 ]
    [[ "$output" == "newfile.txt" ]]
}

@test "git repo detection - target file directory not cwd" {
    # Create subdirectory with git repo
    mkdir -p gitdir
    (cd gitdir && git init . && git config user.email "test@example.com" && git config user.name "Test User")

    # Add test file in git directory
    echo "test content" > gitdir/testfile.txt
    (cd gitdir && git add testfile.txt && git commit -m "Initial commit")

    # Verify current directory is NOT a git repo
    run git rev-parse --is-inside-work-tree
    [ "$status" -ne 0 ]

    # Test: eed should detect git from target file's directory and use auto-commit
    run "$SCRIPT_UNDER_TEST" gitdir/testfile.txt -m "Auto-commit from parent dir" "a
# Added from parent directory
.
w
q"
    [ "$status" -eq 0 ]

    # Should show auto-commit success
    [[ "$output" == *"Changes successfully committed"* ]]

    # File should be updated
    run grep -q "Added from parent directory" gitdir/testfile.txt
    [ "$status" -eq 0 ]

    # Verify commit was created in the target directory's repo
    cd gitdir
    run git log --oneline -1
    [ "$status" -eq 0 ]
    [[ "$output" == *"Auto-commit from parent dir"* ]]
    cd ..
}

@test "git repo - commit message with special characters" {
    # Initialize git repo
    run git init .
    [ "$status" -eq 0 ]
    run git config user.email "test@example.com"
    [ "$status" -eq 0 ]
    run git config user.name "Test User"
    [ "$status" -eq 0 ]

    # Add file to git tracking
    run git add .
    [ "$status" -eq 0 ]
    run git commit -m "Initial commit"
    [ "$status" -eq 0 ]

    # Test commit message with special characters
    run "$SCRIPT_UNDER_TEST" app.py -m "Fix: handle edge case with 'quotes' and \"double quotes\"" "2c
    print('Fixed edge case')
.
w
q"
    [ "$status" -eq 0 ]

    # Should handle special characters correctly
    [[ "$output" == *"Changes successfully committed"* ]]

    # Verify commit message preserved special characters
    run git log --format="%s" -1
    [ "$status" -eq 0 ]
    [[ "$output" == *"Fix: handle edge case with 'quotes' and \"double quotes\""* ]]
}

@test "parameter parsing - -m before filename" {
    # Test parameter order flexibility
    run git init .
    [ "$status" -eq 0 ]
    run git config user.email "test@example.com"
    [ "$status" -eq 0 ]
    run git config user.name "Test User"
    [ "$status" -eq 0 ]

    run git add .
    [ "$status" -eq 0 ]
    run git commit -m "Initial commit"
    [ "$status" -eq 0 ]

    # Test: -m parameter before filename
    run "$SCRIPT_UNDER_TEST" -m "Parameter order test" app.py "2c
    print('Parameter order works')
.
w
q"
    [ "$status" -eq 0 ]

    # Should work correctly
    [[ "$output" == *"Changes successfully committed"* ]]

    # Verify changes applied
    run grep -q "Parameter order works" app.py
    [ "$status" -eq 0 ]

    # Verify commit message
    run git log --format="%s" -1
    [ "$status" -eq 0 ]
    [[ "$output" == *"Parameter order test"* ]]
}

@test "parameter parsing - --message before filename" {
    # Test long form parameter order
    run git init .
    [ "$status" -eq 0 ]
    run git config user.email "test@example.com"
    [ "$status" -eq 0 ]
    run git config user.name "Test User"
    [ "$status" -eq 0 ]

    run git add .
    [ "$status" -eq 0 ]
    run git commit -m "Initial commit"
    [ "$status" -eq 0 ]

    # Test: --message parameter before filename
    run "$SCRIPT_UNDER_TEST" --message "Long form parameter test" app.py "2c
    print('Long form parameter works')
.
w
q"
    [ "$status" -eq 0 ]

    # Should work correctly
    [[ "$output" == *"Changes successfully committed"* ]]

    # Verify commit message
    run git log --format="%s" -1
    [ "$status" -eq 0 ]
    [[ "$output" == *"Long form parameter test"* ]]
}
