#!/usr/bin/env bats

# Test to verify that normal ed commands with multiple input blocks work correctly
# This test should FAIL initially, showing the bug where normal ed terminators are protected

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

@test "normal ed commands: multiple input blocks preserve terminators" {
  echo "line1" > test.txt
  
  # This is a normal ed script with multiple input blocks
  # Each . should be preserved as a normal ed terminator, NOT replaced with markers
  script='1c
modified line1
.
1a
new line2
.
w
q'
  
  run "$SCRIPT_UNDER_TEST" test.txt "$script"
  [ "$status" -eq 0 ]
  
  # Verify the preview file was created
  [ -f test.txt.eed.preview ]
  
  # The content should be correctly modified in preview
  run grep -q "modified line1" test.txt.eed.preview
  [ "$status" -eq 0 ]
  
  run grep -q "new line2" test.txt.eed.preview
  [ "$status" -eq 0 ]
  
  # CRITICAL: There should be NO ~~DOT_ markers in the preview
  # This test will FAIL until we fix the bug
  run grep "~~DOT_" test.txt.eed.preview
  [ "$status" -ne 0 ]  # Should not find any markers
}

@test "normal ed commands: single input block works correctly" {
  echo "original content" > simple.txt
  
  # Simple case with one input block
  script='1c
replaced content
.
w
q'
  
  run "$SCRIPT_UNDER_TEST" simple.txt "$script"
  [ "$status" -eq 0 ]
  
  # Should have correct content in preview
  run grep -q "replaced content" simple.txt.eed.preview
  [ "$status" -eq 0 ]
  
  # Should not have any dot markers
  run grep "~~DOT_" simple.txt.eed.preview
  [ "$status" -ne 0 ]
}

@test "normal ed commands: append command preserves terminator" {
  cat > lines.txt <<'EOF'
line1
line2
line3
EOF
  
  # Append after line 2
  script='2a
inserted after line2
.
w
q'
  
  run "$SCRIPT_UNDER_TEST" lines.txt "$script"
  [ "$status" -eq 0 ]
  
  # Should have the inserted content
  run grep -q "inserted after line2" lines.txt.eed.preview
  [ "$status" -eq 0 ]
  
  # Should not have markers
  run grep "~~DOT_" lines.txt.eed.preview
  [ "$status" -ne 0 ]
}