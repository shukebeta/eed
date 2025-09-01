#!/usr/bin/env bats

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














# Marker file for migrated debug tests.
# The detailed debug/integration tests were moved into specific test files:
# - tests/test_eed.bats
# - tests/test_eed_file_ops.bats
# - tests/test_eed_preview.bats
# - tests/test_eed_validator.bats
# - tests/test_smart_dot_integration.bats
# - tests/test_complex_messages_cleanup.bats
#
# Original debug_integration.bats has been split; remaining tests were migrated.


