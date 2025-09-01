#!/usr/bin/env bats

# AI-Oriented Integration Tests: Workflow Modes
# Tests preview mode, force mode, debug mode, and error handling scenarios

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

@test "preview mode - shows diff and manual apply instructions" {
    # AI gets preview by default, then manually applies
    run "$SCRIPT_UNDER_TEST" app.py "2c
    print('Hello, AI World!')
.
w
q"
    [ "$status" -eq 0 ]
    
    # Should show diff output
    [[ "$output" == *"-"*"Hello World"* ]]
    [[ "$output" == *"+"*"Hello, AI World"* ]]
    
    # Should show manual apply instructions
    [[ "$output" == *"To apply these changes, run:"* ]]
    [[ "$output" == *"mv 'app.py.eed.preview' 'app.py'"* ]]
    
    # Original file unchanged
    run grep -q "Hello World" app.py
    [ "$status" -eq 0 ]
    
    # Preview file created with changes
    [ -f app.py.eed.preview ]
    run grep -q "Hello, AI World" app.py.eed.preview
    [ "$status" -eq 0 ]
}

@test "preview mode - complete apply workflow" {
    # Test the full preview → apply workflow
    run "$SCRIPT_UNDER_TEST" app.py "3a
    # Added by AI
    print('Debug info')
.
w
q"
    [ "$status" -eq 0 ]
    
    # Verify preview created
    [ -f app.py.eed.preview ]
    run grep -q "Added by AI" app.py.eed.preview
    [ "$status" -eq 0 ]
    
    # Apply the changes manually (as AI would do)
    run mv app.py.eed.preview app.py
    [ "$status" -eq 0 ]
    
    # Verify changes applied
    run grep -q "Added by AI" app.py
    [ "$status" -eq 0 ]
    run grep -q "Debug info" app.py
    [ "$status" -eq 0 ]
}

@test "preview mode - complete discard workflow" {
    # Test the preview → discard workflow  
    run "$SCRIPT_UNDER_TEST" app.py "1c
# This change will be discarded
.
w
q"
    [ "$status" -eq 0 ]
    
    # Verify preview created
    [ -f app.py.eed.preview ]
    run grep -q "discarded" app.py.eed.preview
    [ "$status" -eq 0 ]
    
    # Discard the changes (as AI might do)
    run rm app.py.eed.preview
    [ "$status" -eq 0 ]
    
    # Original file unchanged
    run grep -q "def main" app.py
    [ "$status" -eq 0 ]
    run grep -q "discarded" app.py
    [ "$status" -ne 0 ]
}

@test "force mode - direct application with success message" {
    # AI uses --force for direct application
    run "$SCRIPT_UNDER_TEST" --force app.py "2s/Hello World/Hello, Force Mode/
w
q"
    [ "$status" -eq 0 ]
    
    # Should show success message
    [[ "$output" == *"✨"* ]]
    
    # Should NOT show manual apply instructions
    [[ "$output" != *"To apply these changes, run:"* ]]
    [[ "$output" != *"mv"*".eed.preview"* ]]
    
    # Changes applied directly
    run grep -q "Hello, Force Mode" app.py
    [ "$status" -eq 0 ]
    run grep -q "Hello World" app.py
    [ "$status" -ne 0 ]
    
    # No preview file left behind
    [ ! -f app.py.eed.preview ]
}

@test "debug mode - shows detailed execution information" {
    # AI uses --debug to understand what eed is doing
    run "$SCRIPT_UNDER_TEST" --debug --force config.ini "2a
user=testuser
.
w
q"
    [ "$status" -eq 0 ]
    
    # Should show debug messages
    [[ "$output" == *"Debug mode: executing ed"* ]]
    [[ "$output" == *"--force mode enabled"* ]]
    
    # Changes should still be applied
    run grep -q "user=testuser" config.ini
    [ "$status" -eq 0 ]
}

@test "error handling - invalid command preserves original file" {
    # AI provides invalid ed command
    run "$SCRIPT_UNDER_TEST" app.py "invalid_command_123"
    [ "$status" -ne 0 ]
    
    # Should show error message
    [[ "$output" == *"Invalid ed command detected"* ]]
    
    # Original file completely unchanged
    run grep -q "def main" app.py
    [ "$status" -eq 0 ]
    run grep -q "Hello World" app.py
    [ "$status" -eq 0 ]
    
    # No preview file created
    [ ! -f app.py.eed.preview ]
}

@test "error handling - ed execution failure protects original" {
    # AI provides command that will fail during execution
    run "$SCRIPT_UNDER_TEST" --force app.py "1c
new content
.
999p
q"
    [ "$status" -ne 0 ]
    
    # Should show execution error
    [[ "$output" == *"Edit command failed"* ]]
    [[ "$output" == *"No changes were made to the original file"* ]]
    
    # Original file completely preserved
    original_content=$(cat app.py)
    [[ "$original_content" == *"def main"* ]]
    [[ "$original_content" == *"Hello World"* ]]
    
    # No corrupted files left behind
    [ ! -f app.py.eed.preview ]
}

@test "git integration - force mode stages changes automatically" {
    # Initialize git repo and add initial files
    run git init .
    [ "$status" -eq 0 ]
    run git config user.email "test@example.com"
    [ "$status" -eq 0 ]
    run git config user.name "Test User"
    [ "$status" -eq 0 ]
    
    # Add file to git tracking first
    run git add app.py
    [ "$status" -eq 0 ]
    run git commit -m "Initial commit"
    [ "$status" -eq 0 ]
    
    # AI makes changes in force mode
    run "$SCRIPT_UNDER_TEST" --force app.py "1a
# AI-added comment
.
w
q"
    [ "$status" -eq 0 ]
    
    # Changes should be automatically staged by eed
    run git status --porcelain
    [[ "$output" == *"M  app.py"* ]]
    
    # Verify the change was made
    run grep -q "AI-added comment" app.py
    [ "$status" -eq 0 ]
}

@test "no changes scenario - handles gracefully" {
    # AI runs command that makes no actual changes
    run "$SCRIPT_UNDER_TEST" app.py "w
q"
    [ "$status" -eq 0 ]
    
    # Should complete successfully
    [[ "$output" == *"Review the changes below"* ]]
    
    # Files should be identical
    [ -f app.py.eed.preview ]
    run diff app.py app.py.eed.preview
    [ "$status" -eq 0 ]
}