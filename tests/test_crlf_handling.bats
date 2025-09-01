#!/usr/bin/env bats

# Tests for CRLF handling in Git Bash/Windows environments

setup() {
    REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
    TEST_DIR="$(mktemp -d)"
    cd "$TEST_DIR"

    SCRIPT_UNDER_TEST="$REPO_ROOT/eed"
    export EED_TESTING=true
}

teardown() {
    cd /
    rm -rf "$TEST_DIR"
}

@test "CRLF handling: substitute command works" {
    cat > code.js <<'EOF'
function hello() {
    console.log("Hello World");
    return true;
}
EOF

    run "$SCRIPT_UNDER_TEST" --force code.js "1,\$s/Hello World/Greetings, Universe/g
w
q"
    [ "$status" -eq 0 ]
    
    run grep -q "Greetings, Universe" code.js
    [ "$status" -eq 0 ]
}

@test "CRLF handling: input mode with append works" {
    cat > test.txt <<'EOF'
original line
EOF

    run "$SCRIPT_UNDER_TEST" --force test.txt "1a
new content
.
w
q"
    [ "$status" -eq 0 ]
    
    run grep -q "new content" test.txt  
    [ "$status" -eq 0 ]
}