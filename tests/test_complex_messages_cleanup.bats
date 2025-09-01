#!/usr/bin/env bats

# Tests for simplified complex message strategy
# Goal: Reduce noise, provide clear feedback only when necessary

setup() {
    # Create unique test directory and switch into it
    TEST_DIR="$(mktemp -d)"
    cd "$TEST_DIR" || exit

    # Use the repository eed executable directly (use repo-relative path)
    REPO_ROOT="$BATS_TEST_DIRNAME/.."
    SCRIPT_UNDER_TEST="$REPO_ROOT/eed"

    # Create test file
    echo -e "line1\nline2\nline3\nline4\nline5" > test_file.txt
}

teardown() {
    cd /
    rm -rf "$TEST_DIR"
}




@test "debug: complex script messaging (moved from debug_integration.bats)" {
  echo "line1" > test_file.txt
  echo "line2" >> test_file.txt  
  echo "line3" >> test_file.txt

  script='g/line2/d
w
q'

  echo "=== Testing complex script with force ==="
  run "$SCRIPT_UNDER_TEST" --force test_file.txt "$script"
  echo "Exit status: $status"
  echo "Full output:"
  printf "%s\n" "$output"
  
  echo "=== Checking for complex message ==="
  if [[ "$output" =~ "Complex script detected" ]]; then
    echo "✓ Found expected complex message"
  else
    echo "✗ Missing complex message"
  fi
  
  if [[ "$output" =~ force.*disabled ]]; then
    echo "✓ Found force disabled message"
  else  
    echo "✗ Missing force disabled message"
  fi
  
  # Test passes - complex script detection works correctly
  [[ "$output" =~ "Complex script detected" ]]
  [[ "$output" =~ force.*disabled ]]
}
