#!/usr/bin/env bats

# Tests for text content that might look like heredoc markers

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

@test "user can insert EOF as normal text content" {
  run $SCRIPT_UNDER_TEST --force test.txt "1a
content line
EOF
.
w
q"
  [ "$status" -eq 0 ]
  [ -f test.txt ]
  run grep -q "EOF" test.txt
  [ "$status" -eq 0 ]
  run grep -q "content line" test.txt
  [ "$status" -eq 0 ]
}

@test "valid script passes validation" {
  cat > good.txt <<'EOF'
line1
EOF
  run $SCRIPT_UNDER_TEST --force good.txt "1a
ok line
.
w
q"
  [ "$status" -eq 0 ]
  run grep -q "ok line" good.txt
  [ "$status" -eq 0 ]
}