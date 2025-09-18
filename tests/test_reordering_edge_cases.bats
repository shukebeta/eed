#!/usr/bin/env bats

# Tests for reordering edge cases that were discovered but not originally covered

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  TEST_DIR="$(mktemp -d)"
  cd "$TEST_DIR"

  source "$REPO_ROOT/lib/eed_reorder.sh"
  export EED_TESTING=true
}

teardown() {
  cd /
  rm -rf "$TEST_DIR"
}

@test "reorder_script: substitute commands with colons are preserved correctly" {
  # This test catches the original colon parsing bug
  local script='13s/configsetting:/configsettings:/g
14s/old:value/new:value/g
17s/url:http:/url:https:/g
w
q'

  run reorder_script "$script"
  
  # Should always succeed (API contract)
  [ "$status" -eq 0 ]
  
  # Should contain complete substitute commands, not truncated ones
  [[ "$output" =~ "13s/configsetting:/configsettings:/g" ]]
  [[ "$output" =~ "14s/old:value/new:value/g" ]]
  [[ "$output" =~ "17s/url:http:/url:https:/g" ]]
  
  # Should not contain truncated commands like just "/g"
  ! [[ "$output" =~ $'\n/g\n' ]]
  ! [[ "$output" =~ $'^/g$' ]]
}

@test "reorder_script: mixed substitute and delete commands" {
  # Test reordering with both substitute and delete commands
  local script='1d
5s/old/new/g
10d
15s/foo:bar/baz:qux/g
w
q'

  run reorder_script "$script"
  
  [ "$status" -eq 0 ]
  
  # Should contain all commands
  [[ "$output" =~ "1d" ]]
  [[ "$output" =~ "5s/old/new/g" ]]
  [[ "$output" =~ "10d" ]]
  [[ "$output" =~ "15s/foo:bar/baz:qux/g" ]]
  
  # Should be reordered (descending line numbers)
  local lines=()
  while IFS= read -r line; do
    if [[ "$line" =~ ^[0-9]+[ds] ]]; then
      lines+=("$line")
    fi
  done <<< "$output"
  
  # First modifying command should have higher line number than last
  local first_num="${lines[0]%%[ds]*}"
  local last_num="${lines[-1]%%[ds]*}"
  [ "$first_num" -gt "$last_num" ]
}

@test "reorder_script: substitute with special characters in replacement" {
  # Test substitute commands with shell special characters
  local script='1s/old/"quoted $VAR"/g
2s|path|/new/path with spaces|g
3s@old@replacement with `backticks`@g
w
q'

  run reorder_script "$script"
  
  [ "$status" -eq 0 ]
  
  # Should preserve special characters exactly
  [[ "$output" =~ 's/old/"quoted $VAR"/g' ]]
  [[ "$output" =~ 's|path|/new/path with spaces|g' ]]
  [[ "$output" =~ 's@old@replacement with `backticks`@g' ]]
}

@test "reorder_script: content length validation works with substitute commands" {
  # Test that the content length validation catches issues correctly
  local script='1s/short/much_longer_replacement_text/g
2s/another/replacement/g
w
q'

  run reorder_script "$script"
  
  # Should succeed (no length mismatch expected for normal substitute commands)
  [ "$status" -eq 0 ]
  
  # Should contain both substitute commands
  [[ "$output" =~ "1s/short/much_longer_replacement_text/g" ]]
  [[ "$output" =~ "2s/another/replacement/g" ]]
}

@test "reorder_script: log function is called with safe escaping" {
  # This test would require mocking, but we can at least test that 
  # the function doesn't crash with problematic messages
  
  # Source the common library to get the log function
  source "$REPO_ROOT/lib/eed_common.sh"
  
  # Test the log function directly with problematic input
  local problematic_message='Message with "quotes", $VAR, newline\nand tab\there'
  
  run eed_debug_log "ERROR" "$problematic_message" "false"
  
  # Should succeed
  [ "$status" -eq 0 ]
  
  # Check that the log file contains escaped content
  if [ -f ~/.eed/debug.log ]; then
    # Should contain escaped newlines, not actual newlines in middle of log entry
    run grep -c "\\\\n" ~/.eed/debug.log
    [ "$status" -eq 0 ]  # Found escaped newlines
  fi
}