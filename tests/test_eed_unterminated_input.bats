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
  run "$SCRIPT_UNDER_TEST" newfile.txt "1a
inserted line
w
q"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "Edits applied to a temporary preview" ]]
  [ -f newfile.txt.eed.preview ]
  run grep -q "inserted line" newfile.txt.eed.preview
  [ "$status" -eq 0 ]
}

@test "no-op: properly terminated input block is unchanged and succeeds" {
  cat > good.txt <<'EOF'
initial
EOF

  run "$SCRIPT_UNDER_TEST" good.txt "1a
ok line
.
w
q"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "Edits applied to a temporary preview" ]]
  run grep -q "ok line" good.txt.eed.preview
  [ "$status" -eq 0 ]
}

@test "unterminated input block without w/q auto-completed and fixed" {
  # With new architecture, auto-completion adds q and auto-fix adds dot
  run "$SCRIPT_UNDER_TEST" --debug newfile.txt "1a
line"
  [ "$status" -eq 0 ]
  # Should have auto-completion message (modifying script needs w and q)
  [[ "$output" == *"Auto-completed missing ed commands: w and q"* ]]
  # Should have auto-fix message
  [[ "$output" == *"Auto-fix: inserted missing '.'"* ]]
  [ -f newfile.txt.eed.preview ]
}
