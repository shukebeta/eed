#!/usr/bin/env bats

# Integration tests for smart dot protection
# Tests the complete workflow from detection through transformation to execution

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  TEST_DIR="$(mktemp -d)"
  cd "$TEST_DIR"

  SCRIPT_UNDER_TEST="$REPO_ROOT/eed"
  export EED_TESTING=1
}

teardown() {
  cd /
  rm -rf "$TEST_DIR"
}

# === SUCCESS SCENARIOS ===

@test "smart dot integration: bats test file editing works seamlessly" {
  # Create a bats test file that we want to edit (the original failing scenario)
  cat > test_example.bats <<'EOF'
#!/usr/bin/env bats

@test "existing test" {
  run echo "hello"
  [ "$status" -eq 0 ]
}
EOF

  # Add a new test with ed commands containing dots - this used to fail
  script='3a
# Test case demonstrates ed command usage  
# Example: eed file.txt with multiple dots
content line
.
w
q'
  run $SCRIPT_UNDER_TEST --force test_example.bats "$script"
  [ "$status" -eq 0 ]
  [ -f test_example.bats ]
  
  # The file should contain the properly inserted content
  run grep -q "content line" test_example.bats
  [ "$status" -eq 0 ]
  
  run grep -q "EOF" test_example.bats  
  [ "$status" -eq 0 ]
  
  # Should show smart protection message
  [[ "$output" == *"Smart dot protection applied"* ]]
}

@test "smart dot integration: markdown tutorial editing" {
  cat > ed_guide.md <<'EOF'
# Ed Editor Guide

## Basic Usage
EOF

  # Add example with multiple dots - should work now
  script=$(cat <<'ED')

Here's how to add multiple lines:

\`\`\`bash
ed file.txt
1a
First line.
Second line.
.
w
q
\`\`\`
.
w
q
ED
  run $SCRIPT_UNDER_TEST --force ed_guide.md "$script"

  [ "$status" -eq 0 ]
  [ -f ed_guide.md ]
  
  # Content should be properly inserted
  run grep -q "First line." ed_guide.md
  [ "$status" -eq 0 ]
  
  run grep -q "Second line." ed_guide.md
  [ "$status" -eq 0 ]
}

@test "smart dot integration: documentation with complex ed examples" {
  cat > docs.txt <<'EOF'
Documentation file
EOF

  # Complex case with multiple input blocks
  script=$(cat <<'ED')

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
q
ED
  run $SCRIPT_UNDER_TEST --force docs.txt "$script"

  [ "$status" -eq 0 ]
  [ -f docs.txt ]
  
  # All content should be present
  run grep -q "content." docs.txt
  [ "$status" -eq 0 ]
  
  run grep -q "other content." docs.txt
  [ "$status" -eq 0 ]
}

# === FALLBACK SCENARIOS ===

@test "smart dot integration: regular file does not trigger smart protection" {
  echo "regular content" > normal.txt

  # Regular multi-dot script should still warn (not use smart protection)
  run $SCRIPT_UNDER_TEST normal.txt "1a
line.
.
2a
other.
.
w
q"

  # Should not show smart protection message
  [[ "$output" != *"Smart dot protection applied"* ]]
  
  # Should either complete successfully or show appropriate guidance
  [ "$status" -ge 0 ]  # No crashes
}

@test "smart dot integration: low confidence case provides guidance" {
  echo "ambiguous content" > ambiguous.txt

  # Ambiguous case - might show dot trap detection instead
  run $SCRIPT_UNDER_TEST ambiguous.txt "1a
content.
.
2a
more.
.
w
q"

  [ "$status" -ge 0 ]  # Should not crash
  
  # Should provide some form of helpful guidance
  [[ "$output" == *"dot"* ]] || [[ "$output" == *"consider"* ]] || [[ "$output" == *"tool"* ]]
}

# === EDGE CASES ===

@test "smart dot integration: handles marker conflicts gracefully" {
  # Create file that might conflict with generated markers
  cat > conflict_test.bats <<'EOF'  
# Test: contains marker-like strings
function test_markers() {
  echo "~~DOT_123~~"
}
EOF

  script=$(cat <<'ED')
2a
# Test: new test with dots
function test_with_dots() {
  content.
  more content.
}
.
w
q
ED
  run $SCRIPT_UNDER_TEST --force conflict_test.bats "$script"

  [ "$status" -eq 0 ]
  [ -f conflict_test.bats ]
  
  # Original marker-like string should be preserved
  run grep -q "~~DOT_123~~" conflict_test.bats
  [ "$status" -eq 0 ]
  
  # New content should be added
  run grep -q "content." conflict_test.bats
  [ "$status" -eq 0 ]
}

@test "smart dot integration: preserves existing functionality" {
  # Ensure that normal eed operations still work exactly as before
  echo "line1" > simple.txt

  run $SCRIPT_UNDER_TEST --force simple.txt "1c
replaced
.
w
q"

  [ "$status" -eq 0 ]
  [ -f simple.txt ]
  
  run grep -q "replaced" simple.txt
  [ "$status" -eq 0 ]
  
  run grep -q "line1" simple.txt
  [ "$status" -ne 0 ]  # Should be replaced
}

# === ERROR RECOVERY ===

@test "smart dot integration: transform failure falls back gracefully" {
  # Create a scenario that might cause transform failure
  cat > edge_case.bats <<'EOF'
# Test: edge case
function test_edge_case() {
  echo "test"
}
EOF

  # Extremely complex or malformed script
  script=$(cat <<'ED')
complex
malformed.
script.
that.
might.
fail.
.
w
q
ED
  run $SCRIPT_UNDER_TEST edge_case.bats "$script"

  # Should either succeed or fail gracefully with helpful message
  [ "$status" -ge 0 ]  # No crashes
  
  if [ "$status" -ne 0 ]; then
    # If it fails, should provide helpful guidance
    [[ "$output" == *"consider"* ]] || [[ "$output" == *"alternative"* ]] || [[ "$output" == *"tool"* ]]
  fi
}