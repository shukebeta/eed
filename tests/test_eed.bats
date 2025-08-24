#!/usr/bin/env bats

# Comprehensive eed Test Suite - Converted to Bats Format
# Tests the eed tool with all existing functionality
#
# Test categories:
# - Basic functionality (insert, delete, replace)
# - Special character handling (quotes, dollar signs)
# - Windows path compatibility
# - Error handling and backup/restore
# - Complex multi-command operations
# - Security validation (command injection prevention)

setup() {
    # Create unique test directory for this test run
    TEST_DIR="$(mktemp -d)"
    cd "$TEST_DIR"

    # Ensure we're using the local eed from bin/
    export PATH="/home/davidwei/Projects/pkb/bin:$PATH"
    
    # Prevent logging during tests
    export EED_TESTING=1
}

teardown() {
    # Clean up test directory
    cd /
    rm -rf "$TEST_DIR"
}

@test "basic insert operation with terminator" {
    cat > test1.txt << 'EOF'
line1
line2
line3
line4
line5
EOF

    run /home/davidwei/Projects/pkb/bin/eed --force test1.txt "3a
inserted_line
.
w
q"
    [ "$status" -eq 0 ]
    run grep -q "inserted_line" test1.txt
    [ "$status" -eq 0 ]
}

@test "basic delete operation" {
    cat > test1.txt << 'EOF'
line1
line2
line3
line4
line5
EOF

    run /home/davidwei/Projects/pkb/bin/eed --force test1.txt "2d
w
q"
    [ "$status" -eq 0 ]
    run grep -q "line2" test1.txt
    [ "$status" -ne 0 ]
}

@test "basic replace operation (global)" {
    cat > test1.txt << 'EOF'
line1
line2
line3
line4
line5
EOF

    run /home/davidwei/Projects/pkb/bin/eed --force test1.txt "1,\$s/line1/replaced_line1/
w
q"
    [ "$status" -eq 0 ]
    run grep -q "replaced_line1" test1.txt
    [ "$status" -eq 0 ]
}

@test "special characters - single quotes" {
    cat > test2.txt << 'EOF'
normal line
EOF

    run /home/davidwei/Projects/pkb/bin/eed --force test2.txt "1a
line with 'single quotes'
.
w
q"
    [ "$status" -eq 0 ]
    run grep -q "line with 'single quotes'" test2.txt
    [ "$status" -eq 0 ]
}

@test "special characters - double quotes" {
    cat > test2.txt << 'EOF'
normal line
EOF

    run /home/davidwei/Projects/pkb/bin/eed --force test2.txt "$(cat <<'EOF'
1a
line with "double quotes"
.
w
q
EOF
)"
    [ "$status" -eq 0 ]
    run grep -q 'line with "double quotes"' test2.txt
    [ "$status" -eq 0 ]
}

@test "special characters - backslashes" {
    cat > test2.txt << 'EOF'
normal line
EOF

    run /home/davidwei/Projects/pkb/bin/eed --force test2.txt "$(cat <<'EOF'
1a
line with \backslash
.
w
q
EOF
)"
    [ "$status" -eq 0 ]
    run grep -q "backslash" test2.txt
    [ "$status" -eq 0 ]
}

@test "special characters - dollar signs" {
    cat > test2.txt << 'EOF'
normal line
EOF

    run /home/davidwei/Projects/pkb/bin/eed --force test2.txt "$(cat <<'EOF'
1a
line with $dollar sign
.
w
q
EOF
)"
    [ "$status" -eq 0 ]
    run grep -q "dollar sign" test2.txt
    [ "$status" -eq 0 ]
}

@test "windows path compatibility" {
    cat > test3.txt << 'EOF'
old_path=/usr/local/bin
EOF

    run /home/davidwei/Projects/pkb/bin/eed --force test3.txt "s|old_path=.*|new_path=C:\\Users\\Test\$User\\Documents|
w
q"
    [ "$status" -eq 0 ]
    run grep -q "C:" test3.txt
    [ "$status" -eq 0 ]
}

@test "error handling - invalid command rejected" {
    cat > test4.txt << 'EOF'
original content
EOF

    # Invalid command should be detected and rejected before execution
    run /home/davidwei/Projects/pkb/bin/eed --force test4.txt "invalid_command"
    [ "$status" -ne 0 ]

    # Original content should be preserved (file never modified)
    run grep -q "original content" test4.txt
    [ "$status" -eq 0 ]
}

@test "complex operations - console.log removal" {
    cat > test5.txt << 'EOF'
function newName() {
    console.log("debug");
    return result;
}
EOF

    run /home/davidwei/Projects/pkb/bin/eed --force test5.txt "1,\$s/.*console\.log.*;//
w
q"
    [ "$status" -eq 0 ]
    run grep -q "console.log" test5.txt
    [ "$status" -ne 0 ]
}

@test "complex operations - comment insertion" {
    cat > test5.txt << 'EOF'
function newName() {
    return result;
}
EOF

    run /home/davidwei/Projects/pkb/bin/eed --force test5.txt "2a
    // Added comment
.
w
q"
    [ "$status" -eq 0 ]
    run grep -q "Added comment" test5.txt
    [ "$status" -eq 0 ]
}

@test "security validation - command injection resistance" {
    cat > test6.txt << 'EOF'
safe content
EOF

    # Attempt command injection - should be treated as literal text
    run /home/davidwei/Projects/pkb/bin/eed --force test6.txt "1a
; rm -rf /tmp; echo malicious
.
w
q"
    # File should still exist (injection was prevented)
    [ -f test6.txt ]
    # Content should include the "malicious" text as literal content
    run grep -q "malicious" test6.txt
    [ "$status" -eq 0 ]
}

@test "security validation - shell metacharacters" {
    cat > test6.txt << 'EOF'
safe content
EOF

    run /home/davidwei/Projects/pkb/bin/eed --force test6.txt "1a
line with | & ; < > characters
.
w
q"
    [ "$status" -eq 0 ]
    run grep -q "characters" test6.txt
    [ "$status" -eq 0 ]
}

@test "file creation for non-existent file" {
    # Test that eed can create new files
    run /home/davidwei/Projects/pkb/bin/eed --force newfile.txt "1i
first line
.
w
q"
    [ "$status" -eq 0 ]
    [ -f newfile.txt ]
    run grep -q "first line" newfile.txt
    [ "$status" -eq 0 ]
}
