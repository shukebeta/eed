#!/usr/bin/env bats

# TDD Tests for Unified File Operations
# Tests eed as a unified tool for viewing, searching, and editing
# These tests should FAIL initially (RED phase)

setup() {
    # Determine repository root using BATS_TEST_DIRNAME
    REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"

    # Create unique test directory and switch into it
    TEST_DIR="$(mktemp -d)"
    cd "$TEST_DIR" || exit

    # Use the repository eed executable directly
    SCRIPT_UNDER_TEST="$REPO_ROOT/eed"

    # Prevent logging during tests
    export EED_TESTING=true

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
    run "$SCRIPT_UNDER_TEST" sample.txt ",p
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
    run "$SCRIPT_UNDER_TEST" sample.txt ",n
q"
    [ "$status" -eq 0 ]
    [[ "$output" == *"1"*"first line"* ]]
    [[ "$output" == *"2"*"second line"* ]]
}

@test "file viewing - display specific line range (replaces sed -n)" {
    # View lines 2-4 only
    run "$SCRIPT_UNDER_TEST" sample.txt "2,4p
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
    run "$SCRIPT_UNDER_TEST" sample.txt "g/pattern/p
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
    run "$SCRIPT_UNDER_TEST" sample.txt "/second/-1,/second/+1p
q"
    [ "$status" -eq 0 ]
    [[ "$output" == *"first line"* ]]
    [[ "$output" == *"second line with pattern"* ]]
    [[ "$output" == *"third line"* ]]
}

@test "mixed workflow - view then edit then verify" {
    # Complex workflow: search, edit, verify, save
    run "$SCRIPT_UNDER_TEST" sample.txt "$(cat <<'EOF'
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
    [[ "$output" =~ "Edits applied to a temporary preview" ]]

    run grep -q "replaced pattern line" sample.txt.eed.preview
    [ "$status" -eq 0 ]
    run grep -q "second line with pattern" sample.txt.eed.preview
    [ "$status" -ne 0 ]
}

@test "mixed workflow - conditional save based on verification" {
    # Edit, verify, decide whether to save
    run "$SCRIPT_UNDER_TEST" sample.txt "$(cat <<'EOF'
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
    [[ "$output" =~ "Edits applied to a temporary preview" ]]

    # Should show the test change during verification
    [[ "$output" == *"TEST CHANGE"* ]]

    # Preview file should have final change
    run grep -q "FINAL CHANGE" sample.txt.eed.preview
    [ "$status" -eq 0 ]
    run grep -q "first line" sample.txt.eed.preview
    [ "$status" -ne 0 ]
}

@test "file inspection - count lines and patterns" {
    # Show file statistics
    run "$SCRIPT_UNDER_TEST" sample.txt "=
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

    run "$SCRIPT_UNDER_TEST" sample.txt "$(cat <<'EOF'
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
    run "$SCRIPT_UNDER_TEST" sample.txt "$(cat <<'EOF'
/nonexistent/p
q
EOF
)"
    [ "$status" -eq 0 ]
    # Should complete successfully even if pattern not found
}

@test "advanced viewing - multiple pattern searches" {
    # Search for multiple patterns in sequence
    run "$SCRIPT_UNDER_TEST" sample.txt "$(cat <<'EOF'
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

@test "debug: simple integration test (moved from debug_integration.bats)" {
  cat > test_file.bats <<'EOF'
#!/usr/bin/env bats
# Test: existing test
function existing_test() {
  run echo "hello"
  [ "$status" -eq 0 ]
}
EOF

  script='3a
content line
.
w
q'

  run "$SCRIPT_UNDER_TEST" --debug test_file.bats "$script"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "Edits applied to a temporary preview" ]]

  # Check if content was inserted in preview file
  run grep -q "content line" test_file.bats.eed.preview
  [ "$status" -eq 0 ]
}

@test "debug: complex ed examples case (moved from debug_integration.bats)" {
  cat > docs.txt <<'EOF'
Documentation file
line2
line3
line4
line5
EOF

  # Complex case with multiple input blocks - from integration tests
  script='1a
Example 1:
  1a
  content.
  .
  w

Example 2:
  5c
  other content.
  .
  w
  q
.
w
q'

  run "$SCRIPT_UNDER_TEST" docs.txt "$script"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "Edits applied to a temporary preview" ]]

  # Check if content was inserted in preview file
  run grep -q "content." docs.txt.eed.preview
  [ "$status" -eq 0 ]
}

@test "debug: direct ed execution test (moved from debug_integration.bats)" {
  cat > test_file.txt <<'EOF'
line1
line2
line3
EOF

  # Test eed's handling of ed-like commands
  script='3a
content line
.
w
q'

  run "$SCRIPT_UNDER_TEST" test_file.txt "$script"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "Edits applied to a temporary preview" ]]

  # Check if content was inserted in preview file
  run grep -q "content line" test_file.txt.eed.preview
  [ "$status" -eq 0 ]
  
  # Original file should remain unchanged
  run grep -q "content line" test_file.txt
  [ "$status" -ne 0 ]
}
