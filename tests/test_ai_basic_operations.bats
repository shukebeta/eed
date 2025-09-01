#!/usr/bin/env bats

# AI-Oriented Integration Tests: Basic CRUD Operations
# Tests the most common operations that AI systems perform with eed

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
    cat > code.js << 'EOF'
function hello() {
    console.log("Hello World");
    return true;
}
EOF

    cat > config.json << 'EOF'
{
    "name": "test-app",
    "version": "1.0.0",
    "dependencies": {}
}
EOF
}

teardown() {
    cd /
    rm -rf "$TEST_DIR"
}

@test "basic insert - append line to end of file" {
    # AI commonly adds new lines at the end of files
    run "$SCRIPT_UNDER_TEST" --force code.js "\$a
// New function added by AI
function newFeature() {
    return 'feature';
}
.
w
q"
    [ "$status" -eq 0 ]
    
    # Verify the addition
    run grep -q "New function added by AI" code.js
    [ "$status" -eq 0 ]
    run grep -q "function newFeature" code.js
    [ "$status" -eq 0 ]
}

@test "basic insert - insert line at specific position" {
    # AI often inserts imports or comments at specific lines
    run "$SCRIPT_UNDER_TEST" --force code.js "1i
// Added import statement
const util = require('util');

.
w
q"
    [ "$status" -eq 0 ]
    
    # Verify the insertion at the top
    run head -n 1 code.js
    [ "$output" = "// Added import statement" ]
    run grep -q "const util" code.js
    [ "$status" -eq 0 ]
}

@test "basic insert - insert after specific line" {
    # AI frequently adds code after existing lines
    run "$SCRIPT_UNDER_TEST" --force code.js "2a
    // Debug output
    console.log('Function called');
.
w
q"
    [ "$status" -eq 0 ]
    
    # Verify insertion after line 2
    run grep -q "Debug output" code.js
    [ "$status" -eq 0 ]
    run grep -q "Function called" code.js
    [ "$status" -eq 0 ]
}

@test "basic delete - remove single line" {
    # AI often removes specific lines (like console.log statements)
    run "$SCRIPT_UNDER_TEST" --force code.js "2d
w
q"
    [ "$status" -eq 0 ]
    
    # Verify the console.log line was removed
    run grep -q "console.log" code.js
    [ "$status" -ne 0 ]
    # But function structure should remain
    run grep -q "function hello" code.js
    [ "$status" -eq 0 ]
}

@test "basic delete - remove range of lines" {
    # AI sometimes removes entire blocks
    run "$SCRIPT_UNDER_TEST" --force code.js "2,3d
w
q"
    [ "$status" -eq 0 ]
    
    # Verify multiple lines removed
    run grep -q "console.log" code.js
    [ "$status" -ne 0 ]
    run grep -q "return true" code.js
    [ "$status" -ne 0 ]
    # Function declaration should remain
    run grep -q "function hello" code.js
    [ "$status" -eq 0 ]
}

@test "basic replace - change entire line" {
    # AI frequently replaces lines with improved versions
    run "$SCRIPT_UNDER_TEST" --force code.js "2c
    console.log('Hello, improved world!');
.
w
q"
    [ "$status" -eq 0 ]
    
    # Verify replacement
    run grep -q "improved world" code.js
    [ "$status" -eq 0 ]
    run grep -q "Hello World" code.js
    [ "$status" -ne 0 ]
}

@test "basic substitute - pattern replacement" {
    # AI commonly does find-and-replace operations
    run "$SCRIPT_UNDER_TEST" --force code.js "1,\$s/Hello World/Greetings, Universe/g
w
q"
    [ "$status" -eq 0 ]
    
    # Verify substitution
    run grep -q "Greetings, Universe" code.js
    [ "$status" -eq 0 ]
    run grep -q "Hello World" code.js
    [ "$status" -ne 0 ]
}