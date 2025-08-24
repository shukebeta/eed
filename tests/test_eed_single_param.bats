#!/usr/bin/env bats

# TDD Tests for Single-Parameter Mode Eed
# These tests should FAIL initially (RED phase)
# Implementation will make them pass (GREEN phase)

setup() {
    TEST_DIR="$(mktemp -d)"
    cd "$TEST_DIR"
    export PATH="/home/davidwei/Projects/pkb/bin:$PATH"
    EED_PATH="/home/davidwei/Projects/pkb/b"
    
    # Prevent logging during tests
    export EED_TESTING=1
}

teardown() {
    cd /
    rm -rf "$TEST_DIR"
}

@test "single parameter with simple ed script" {
    cat > test.txt << 'EOF'
line1
line2
line3
EOF

    # Single parameter containing complete ed script
    run /home/davidwei/Projects/pkb/bin/eed --force test.txt "3a
new line
.
w
q"
    [ "$status" -eq 0 ]
    run grep -q "new line" test.txt
    [ "$status" -eq 0 ]
}

@test "single parameter with heredoc syntax" {
    cat > test.txt << 'EOF'
line1
line2
line3
EOF

    # Test heredoc integration
    run /home/davidwei/Projects/pkb/bin/eed --force test.txt "$(cat <<'EOF'
2c
replaced line
.
w
q
EOF
)"
    [ "$status" -eq 0 ]
    run grep -q "replaced line" test.txt
    [ "$status" -eq 0 ]
    run grep -q "line2" test.txt
    [ "$status" -ne 0 ]
}

@test "manual w/q control - save and exit" {
    cat > test.txt << 'EOF'
original
EOF

    # User manually controls w/q
    run /home/davidwei/Projects/pkb/bin/eed --force test.txt "1c
modified
.
w
q"
    [ "$status" -eq 0 ]
    run grep -q "modified" test.txt
    [ "$status" -eq 0 ]
}

@test "manual w/q control - save without exit (complex workflow)" {
    cat > test.txt << 'EOF'
line1
line2
line3
EOF

    # Multi-step workflow with intermediate save
    run /home/davidwei/Projects/pkb/bin/eed --force test.txt "1c
changed1
.
w
2c
changed2
.
w
q"
    [ "$status" -eq 0 ]
    run grep -q "changed1" test.txt
    [ "$status" -eq 0 ]
    run grep -q "changed2" test.txt
    [ "$status" -eq 0 ]
}

@test "error handling - missing w causes data loss warning" {
    cat > test.txt << 'EOF'
original
EOF

    # Script without w should warn but not fail
    run /home/davidwei/Projects/pkb/bin/eed --force test.txt "1c
modified
.
Q"
    # Should complete successfully but warn
    [ "$status" -eq 0 ]
    # Content should be unchanged (no w command)
    run grep -q "original" test.txt
    [ "$status" -eq 0 ]
    run grep -q "modified" test.txt
    [ "$status" -ne 0 ]
}

@test "error handling - missing q should not hang" {
    cat > test.txt << 'EOF'
original
EOF

    # Script without q should still complete
    run /home/davidwei/Projects/pkb/bin/eed --force test.txt "1c
modified
.
w"
    [ "$status" -eq 0 ]
    run grep -q "modified" test.txt
    [ "$status" -eq 0 ]
}

@test "complex heredoc with nested quotes and special chars" {
    cat > test.txt << 'EOF'
placeholder
EOF

    # Test complex content with quotes and special characters
    run /home/davidwei/Projects/pkb/bin/eed --force test.txt "$(cat <<'OUTER'
1c
Content with 'single' and "double" quotes
Line with $dollar and `backticks`
Line with \ backslashes and | pipes
.
w
q
OUTER
)"
    [ "$status" -eq 0 ]
    run grep -q "single.*double" test.txt
    [ "$status" -eq 0 ]
    run grep -q "dollar.*backticks" test.txt
    [ "$status" -eq 0 ]
    run grep -q "backslashes.*pipes" test.txt
    [ "$status" -eq 0 ]
}

@test "single parameter rejects multi-parameter syntax" {
    cat > test.txt << 'EOF'
original
EOF

    # Old multi-parameter syntax should fail with helpful error
    run /home/davidwei/Projects/pkb/bin/eed --force test.txt "1c" "new content" "."
    [ "$status" -ne 0 ]
    [[ "$output" == *"single parameter"* ]] || [[ "$output" == *"heredoc"* ]]
}

@test "empty script should not modify file" {
    cat > test.txt << 'EOF'
original content
EOF

    # Empty ed script should do nothing
    run /home/davidwei/Projects/pkb/bin/eed --force test.txt ""
    [ "$status" -eq 0 ]
    run grep -q "original content" test.txt
    [ "$status" -eq 0 ]
}
