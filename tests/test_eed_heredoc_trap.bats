#!/usr/bin/env bats

# Tests for heredoc trap detection in eed

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

@test "detect heredoc trap - standalone EOF in script" {
  run $SCRIPT_UNDER_TEST test.txt "1a
content line
EOF
.
w
q"
  [ "$status" -ne 0 ]
  [[ "$output" == *"heredoc"* ]]
}

@test "heredoc leftover with w/q still errors" {
  # Even if write/quit commands are present, a standalone heredoc marker should cause an error
  run $SCRIPT_UNDER_TEST test.txt "1a
content line
EOF
w
q"
  [ "$status" -ne 0 ]
  [[ "$output" == *"heredoc"* ]]
  [ ! -f test.txt ]
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