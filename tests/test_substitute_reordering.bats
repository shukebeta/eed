#!/usr/bin/env bats

# Test to verify that substitute commands are correctly reordered without losing content

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

@test "substitute commands: reordering preserves full command content" {
  # Create a file with enough lines for the test
  cat > config.txt <<'EOF'
line1
line2
line3
line4
line5
line6
line7
line8
line9
line10
line11
line12
line13
setting:value1
line15
line16
setting:value2
line18
EOF

  # This script should trigger reordering (ascending line numbers)
  # and should preserve the full substitute commands including colons
  script='13s/line13/modified_line13/g
14s/setting:/configsetting:/g
17s/setting:/configsetting:/g
w
q'

  run "$SCRIPT_UNDER_TEST" config.txt "$script"
  echo "Exit status: $status"
  echo "Output: $output"
  
  # Should succeed (not fail with content mismatch)
  [ "$status" -eq 0 ]
  
  # Should show reordering message
  [[ "$output" =~ "Auto-reordering script" ]]
  
  # Should have correct content in preview
  [ -f config.txt.eed.preview ]
  
  # Verify the substitutions actually worked
  run grep -q "modified_line13" config.txt.eed.preview
  [ "$status" -eq 0 ]
  
  run grep -q "configsetting:value1" config.txt.eed.preview  
  [ "$status" -eq 0 ]
  
  run grep -q "configsetting:value2" config.txt.eed.preview  
  [ "$status" -eq 0 ]
}

@test "substitute commands: complex patterns with multiple colons" {
  echo "url:http://example.com:8080/path" > urls.txt
  
  # Test substitute command with multiple colons in the pattern
  script='1s/url:http:/url:https:/g
w
q'

  run "$SCRIPT_UNDER_TEST" urls.txt "$script"
  
  [ "$status" -eq 0 ]
  
  # Verify the substitution worked correctly
  run grep -q "url:https://example.com:8080/path" urls.txt.eed.preview
  [ "$status" -eq 0 ]
}