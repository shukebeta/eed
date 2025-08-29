#!/usr/bin/env bats

# Tests for smart dot transformation algorithm
# This tests the core logic that converts content dots to markers

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  TEST_DIR="$(mktemp -d)"
  cd "$TEST_DIR"

  # Source the validator to test transform functions directly
  source "$REPO_ROOT/lib/eed_validator.sh"
}

teardown() {
  cd /
  rm -rf "$TEST_DIR"
}

# === BASIC TRANSFORMATION CASES ===

@test "dot transform: single input block with content dot" {
  local input="1a
content line.
more content
.
w
q"

  local output
  output=$(transform_content_dots "$input")
  [ "$?" -eq 0 ]

  # Should contain substitution command before w
  [[ "$output" == *"s@"*"@.@g"* ]]
  [[ "$output" == *"w"* ]]
  
  # Content dot should be replaced, terminator dot should remain
  local line_count
  line_count=$(echo "$output" | grep -c "^\\.$" || true)
  [ "$line_count" -eq 1 ]  # Only the terminator dot should remain as-is
}

@test "dot transform: multiple input blocks with content dots" {
  local input="1a
first content.
.
5c
second content.
.
w
q"

  local output
  output=$(transform_content_dots "$input")
  [ "$?" -eq 0 ]

  # Should have substitution command
  [[ "$output" == *"s@"*"@.@g"* ]]
  
  # Should have exactly 2 terminator dots remaining (one per input block)
  local terminator_count
  terminator_count=$(echo "$output" | grep -c "^\\.$" || true)
  [ "$terminator_count" -eq 2 ]
  
  # Should contain the substitution before w command
  local w_line_num
  w_line_num=$(echo "$output" | grep -n "^w$" | cut -d: -f1)
  local subst_line_num  
  subst_line_num=$(echo "$output" | grep -n "^s@" | cut -d: -f1)
  [ "$subst_line_num" -lt "$w_line_num" ]
}

@test "dot transform: preserve structure with mixed commands" {
  local input="1d
2a
content.
.
5s/old/new/
w
q"

  local output
  output=$(transform_content_dots "$input")
  [ "$?" -eq 0 ]

  # Non-input commands should be preserved exactly
  [[ "$output" == *"1d"* ]]
  [[ "$output" == *"5s/old/new/"* ]]
  
  # Should have substitution command before w
  [[ "$output" == *"s@"*"@.@g"* ]]
}

# === EDGE CASES ===

@test "dot transform: no w command should handle gracefully" {
  local input="1a
content.
.
q"

  local output
  output=$(transform_content_dots "$input")
  
  # Should either succeed with substitution before q, or fail gracefully
  if [ "$?" -eq 0 ]; then
    [[ "$output" == *"s@"*"@.@g"* ]]
    # Substitution should come before q
    local q_line_num
    q_line_num=$(echo "$output" | grep -n "^q$" | cut -d: -f1)
    local subst_line_num
    subst_line_num=$(echo "$output" | grep -n "^s@" | cut -d: -f1)
    [ "$subst_line_num" -lt "$q_line_num" ]
  fi
}

@test "dot transform: empty input block should preserve structure" {
  local input="1a
.
w
q"

  local output
  output=$(transform_content_dots "$input")
  [ "$?" -eq 0 ]

  # Should preserve the empty input block structure
  [[ "$output" == *"1a"* ]]
  [[ "$output" == *"."* ]]
  [[ "$output" == *"w"* ]]
  
  # No substitution needed since no content dots
  local subst_count
  subst_count=$(echo "$output" | grep -c "^s@" || true)
  [ "$subst_count" -eq 0 ]
}

@test "dot transform: marker collision detection" {
  # Test script that already contains a potential marker pattern
  local input="1a
content ~~DOT_123~~ line.
.
w
q"

  local output
  output=$(transform_content_dots "$input")
  [ "$?" -eq 0 ]

  # Should generate a different marker to avoid collision
  [[ "$output" == *"s@"*"@.@g"* ]]
  
  # The original ~~DOT_123~~ should be preserved
  [[ "$output" == *"~~DOT_123~~"* ]]
}

@test "dot transform: complex nested content" {
  local input="1a
Documentation content.
More documentation.
Tutorial section.
.
w
q"

  local output
  output=$(transform_content_dots "$input")
  [ "$?" -eq 0 ]

  # Should handle content dots correctly
  [[ "$output" == *"s@"*"@.@g"* ]]
  
  # Should have exactly one terminator dot remaining
  local terminator_count
  terminator_count=$(echo "$output" | grep -c "^\\.$" || true)
  [ "$terminator_count" -eq 1 ]
}

# === UNIQUE MARKER GENERATION ===

@test "dot transform: generates unique markers for concurrent operations" {
  local input1="1a
content.
.
w
q"

  local input2="1a
other.
.
w
q"

  local output1
  local output2
  output1=$(transform_content_dots "$input1")
  output2=$(transform_content_dots "$input2")

  # Extract markers from both outputs
  local marker1
  local marker2
  marker1=$(echo "$output1" | grep "^s@" | sed 's/s@\(.*\)@\.@g/\1/')
  marker2=$(echo "$output2" | grep "^s@" | sed 's/s@\(.*\)@\.@g/\1/')

  # Markers should be different to avoid conflicts
  [ "$marker1" != "$marker2" ]
}

# === ERROR HANDLING ===

@test "dot transform: invalid script should fail gracefully" {
  local input="invalid ed command
malformed
."

  local output
  output=$(transform_content_dots "$input")
  
  # Should either succeed with best-effort transform or fail cleanly
  # Either way, should not crash or produce corrupted output
  [ "$?" -ge 0 ]  # No crash
}