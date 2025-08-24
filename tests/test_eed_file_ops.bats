#!/usr/bin/env bats

# TDD Tests for Unified File Operations
# Tests eed as a unified tool for viewing, searching, and editing
# These tests should FAIL initially (RED phase)

setup() {
    TEST_DIR="$(mktemp -d)"
    cd "$TEST_DIR"
    export PATH="/home/davidwei/Projects/pkb/bin:$PATH"
    
    # Prevent logging during tests
    export EED_TESTING=1

    # Create sample file for testing
    cat > sample.txt << 'EOF'
first line
second line with pattern
third line
fourth line with pattern
fifth line
EOF
}

teardown() {
    cd /
    rm -rf "$TEST_DIR"
}

@test "file viewing - display entire file (replaces cat)" {
    # View entire file without modification
    run /home/davidwei/Projects/pkb/bin/eed sample.txt ",p
q"
    [ "$status" -eq 0 ]
    [[ "$output" == *"first line"* ]]
    [[ "$output" == *"second line"* ]]
    [[ "$output" == *"fifth line"* ]]

    # File should be unchanged
    run grep -c "line" sample.txt
    [ "$output" = "5" ]
}

@test "file viewing - display with line numbers (replaces cat -n)" {
    # View with line numbers
    run /home/davidwei/Projects/pkb/bin/eed sample.txt ",n
q"
    [ "$status" -eq 0 ]
    [[ "$output" == *"1"*"first line"* ]]
    [[ "$output" == *"2"*"second line"* ]]
}

@test "file viewing - display specific line range (replaces sed -n)" {
    # View lines 2-4 only
    run /home/davidwei/Projects/pkb/bin/eed sample.txt "2,4p
q"
    [ "$status" -eq 0 ]
    [[ "$output" == *"second line"* ]]
    [[ "$output" == *"third line"* ]]
    [[ "$output" == *"fourth line"* ]]
    # Should not contain first or fifth line
    [[ "$output" != *"first line"* ]]
    [[ "$output" != *"fifth line"* ]]
}

@test "file viewing - search and display (replaces grep)" {
    # Find and display lines containing pattern
    run /home/davidwei/Projects/pkb/bin/eed sample.txt "g/pattern/p
q"
    [ "$status" -eq 0 ]
    [[ "$output" == *"second line with pattern"* ]]
    [[ "$output" == *"fourth line with pattern"* ]]
    # Should not contain lines without pattern
    [[ "$output" != *"first line"* ]]
    [[ "$output" != *"third line"* ]]
    [[ "$output" != *"fifth line"* ]]
}

@test "file viewing - search with context display" {
    # Display pattern line plus one line before and after
    run /home/davidwei/Projects/pkb/bin/eed sample.txt "/second/-1,/second/+1p
q"
    [ "$status" -eq 0 ]
    [[ "$output" == *"first line"* ]]
    [[ "$output" == *"second line with pattern"* ]]
    [[ "$output" == *"third line"* ]]
}

@test "mixed workflow - view then edit then verify" {
    # Complex workflow: search, edit, verify, save
    run /home/davidwei/Projects/pkb/bin/eed --force sample.txt "$(cat <<'EOF'
/pattern/p
.c
replaced pattern line
.
.p
w
q
EOF
)"
    [ "$status" -eq 0 ]

    # Should show original pattern line in output
    [[ "$output" == *"second line with pattern"* ]]
    # Should show replaced line in output
    [[ "$output" == *"replaced pattern line"* ]]

    # File should be modified
    run grep -q "replaced pattern line" sample.txt
    [ "$status" -eq 0 ]
    run grep -q "second line with pattern" sample.txt
    [ "$status" -ne 0 ]
}

@test "mixed workflow - conditional save based on verification" {
    # Edit, verify, decide whether to save
    run /home/davidwei/Projects/pkb/bin/eed --force sample.txt "$(cat <<'EOF'
1c
TEST CHANGE
.
.p
1c
FINAL CHANGE
.
w
q
EOF
)"
    [ "$status" -eq 0 ]

    # Should show the test change during verification
    [[ "$output" == *"TEST CHANGE"* ]]

    # File should have final change
    run grep -q "FINAL CHANGE" sample.txt
    [ "$status" -eq 0 ]
    run grep -q "first line" sample.txt
    [ "$status" -ne 0 ]
}

@test "file inspection - count lines and patterns" {
    # Show file statistics
    run /home/davidwei/Projects/pkb/bin/eed sample.txt "=
g/pattern/n
q"
    [ "$status" -eq 0 ]

    # Should show line count (5) and pattern lines with numbers
    [[ "$output" == *"5"* ]]  # Total lines
    [[ "$output" == *"2"* ]]  # First pattern line number
    [[ "$output" == *"4"* ]]  # Second pattern line number
}

@test "read-only operations preserve file integrity" {
    # Multiple read operations should not change file
    original_content=$(cat sample.txt)

    run /home/davidwei/Projects/pkb/bin/eed sample.txt "$(cat <<'EOF'
,p
1,3n
/pattern/p
=
q
EOF
)"
    [ "$status" -eq 0 ]

    # File should be identical
    current_content=$(cat sample.txt)
    [ "$original_content" = "$current_content" ]
}

@test "error handling - graceful handling of search failures" {
    # Search for non-existent pattern should not crash
    run /home/davidwei/Projects/pkb/bin/eed --force sample.txt "$(cat <<'EOF'
/nonexistent/p
q
EOF
)"
    [ "$status" -eq 0 ]
    # Should complete successfully even if pattern not found
}

@test "advanced viewing - multiple pattern searches" {
    # Search for multiple patterns in sequence
    run /home/davidwei/Projects/pkb/bin/eed --force sample.txt "$(cat <<'EOF'
/first/p
g/pattern/p
q
EOF
)"
    [ "$status" -eq 0 ]
    [[ "$output" == *"first line"* ]]
    [[ "$output" == *"second line with pattern"* ]]
    [[ "$output" == *"fourth line with pattern"* ]]
}
