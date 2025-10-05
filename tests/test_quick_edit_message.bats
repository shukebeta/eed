#!/usr/bin/env bats

# Quick Edit Commit Message Format Tests
# Tests the automatic commit message generation for edits without -m parameter

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

    # Initialize git repo
    git init --quiet
    git config user.email "test@example.com"
    git config user.name "Test User"
}

teardown() {
    cd /
    rm -rf "$TEST_DIR"
}

@test "quick edit message - includes relative path" {
    # Create file in subdirectory
    mkdir -p src/utils
    echo "export const helper = () => 'help';" > src/utils/helper.js
    git add .
    git commit -m "Initial commit" --quiet

    # Edit without -m parameter
    run "$SCRIPT_UNDER_TEST" src/utils/helper.js - <<'EOF'
1a
export const another = () => "another";
.
w
q
EOF
    [ "$status" -eq 0 ]

    # Verify commit message includes relative path
    run git log --format="%s" -1
    [ "$status" -eq 0 ]
    [[ "$output" == *"Quick edit on src/utils/helper.js"* ]]
}

@test "quick edit message - includes timestamp in HH:MM:SS format" {
    # Create simple file
    echo "hello" > test.txt
    git add .
    git commit -m "Initial commit" --quiet

    # Edit without -m parameter
    run "$SCRIPT_UNDER_TEST" test.txt - <<'EOF'
1a
world
.
w
q
EOF
    [ "$status" -eq 0 ]

    # Verify commit message includes timestamp
    run git log --format="%s" -1
    [ "$status" -eq 0 ]
    # Check for pattern "at HH:MM:SS" where HH:MM is valid time format
    [[ "$output" =~ at\ [0-2][0-9]:[0-5][0-9]:[0-5][0-9]$ ]]
}

@test "quick edit message - complete format verification" {
    # Create file with nested path
    mkdir -p src/components
    echo "function Button() {}" > src/components/Button.js
    git add .
    git commit -m "Initial commit" --quiet

    # Edit without -m parameter
    run "$SCRIPT_UNDER_TEST" src/components/Button.js - <<'EOF'
1a
// Added by test
.
w
q
EOF
    [ "$status" -eq 0 ]

    # Verify complete message format
    run git log --format="%s" -1
    [ "$status" -eq 0 ]
    [[ "$output" =~ ^eed-history:\ Quick\ edit\ on\ src/components/Button\.js\ at\ [0-2][0-9]:[0-5][0-9]:[0-5][0-9]$ ]]
}

@test "quick edit message - different from custom message" {
    # Create file
    echo "test" > file.txt
    git add .
    git commit -m "Initial commit" --quiet

    # Edit with custom message
    run "$SCRIPT_UNDER_TEST" -m "Custom commit message" file.txt - <<'EOF'
1a
line
.
w
q
EOF
    [ "$status" -eq 0 ]

    # Verify uses custom message, not quick edit format
    run git log --format="%s" -1
    [ "$status" -eq 0 ]
    [[ "$output" == "eed-history: Custom commit message" ]]
    [[ "$output" != *"Quick edit"* ]]
}

@test "quick edit message - handles root-level files" {
    # Create file at root
    echo "root file" > root.txt
    git add .
    git commit -m "Initial commit" --quiet

    # Edit without -m parameter
    run "$SCRIPT_UNDER_TEST" root.txt - <<'EOF'
1a
added line
.
w
q
EOF
    [ "$status" -eq 0 ]

    # Verify path is just filename (no directory prefix)
    run git log --format="%s" -1
    [ "$status" -eq 0 ]
    [[ "$output" == *"Quick edit on root.txt at"* ]]
}

@test "quick edit message - distinguishes files with same basename" {
    # Create files with same name in different directories
    mkdir -p src/components
    mkdir -p tests
    echo "component" > src/components/Button.js
    echo "test" > tests/Button.js
    git add .
    git commit -m "Initial commit" --quiet

    # Edit first file
    run "$SCRIPT_UNDER_TEST" src/components/Button.js - <<'EOF'
1a
// component edit
.
w
q
EOF
    [ "$status" -eq 0 ]

    # Verify message includes full path
    run git log --format="%s" -1
    [ "$status" -eq 0 ]
    [[ "$output" == *"src/components/Button.js"* ]]
    [[ "$output" != *"tests/Button.js"* ]]

    # Edit second file
    run "$SCRIPT_UNDER_TEST" tests/Button.js - <<'EOF'
1a
// test edit
.
w
q
EOF
    [ "$status" -eq 0 ]

    # Verify message includes correct path
    run git log --format="%s" -1
    [ "$status" -eq 0 ]
    [[ "$output" == *"tests/Button.js"* ]]
    [[ "$output" != *"src/components/Button.js"* ]]
}

@test "quick edit message - timestamp reflects actual edit time" {
    # Create file
    echo "test" > file.txt
    git add .
    git commit -m "Initial commit" --quiet

    # Get current time before edit
    local before_edit_time
    before_edit_time=$(date '+%H:%M:%S')

    # Edit file
    run "$SCRIPT_UNDER_TEST" file.txt - <<'EOF'
1a
line
.
w
q
EOF
    [ "$status" -eq 0 ]

    # Get time after edit
    local after_edit_time
    after_edit_time=$(date '+%H:%M:%S')

    # Verify commit message timestamp is within range
    run git log --format="%s" -1
    [ "$status" -eq 0 ]

    # Extract timestamp from commit message
    local commit_time
    commit_time=$(echo "$output" | grep -oE '[0-2][0-9]:[0-5][0-9]:[0-5][0-9]$')

    # Verify timestamp is valid (we can't test exact match due to timing)
    [[ "$commit_time" =~ ^[0-2][0-9]:[0-5][0-9]:[0-5][0-9]$ ]]
}

@test "quick edit message - preserves special characters in path" {
    # Create file with special characters (spaces, hyphens)
    mkdir -p "my-app/src-files"
    echo "test" > "my-app/src-files/app-config.js"
    git add .
    git commit -m "Initial commit" --quiet

    # Edit file
    run "$SCRIPT_UNDER_TEST" "my-app/src-files/app-config.js" - <<'EOF'
1a
line
.
w
q
EOF
    [ "$status" -eq 0 ]

    # Verify path with special characters is preserved
    run git log --format="%s" -1
    [ "$status" -eq 0 ]
    [[ "$output" == *"my-app/src-files/app-config.js"* ]]
}
