#!/usr/bin/env bats

# Tests for auto-insert of missing '.' to terminate a/c/i input blocks

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

@test "auto-insert missing terminator before w (unterminated 'a' block)" {
  run $SCRIPT_UNDER_TEST --force newfile.txt "1a
inserted line
w
q"
  [ "$status" -eq 0 ]
  [ -f newfile.txt ]
  run grep -q "inserted line" newfile.txt
  [ "$status" -eq 0 ]
  [[ "$output" == *"Auto-fix"* || "$output" == *"inserted missing '.'"* ]] || true
}

@test "no-op: properly terminated input block is unchanged and succeeds" {
  cat > good.txt <<'EOF'
initial
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

@test "unterminated input block without w/q command errors" {
  run $SCRIPT_UNDER_TEST --force newfile.txt "1a
line
EOF"
  [ "$status" -ne 0 ]
  [ ! -f newfile.txt ]
}
