#!/usr/bin/env bats

# Tests for smart dot protection - scene detection
# This tests whether we correctly identify when to apply smart dot transformation

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  TEST_DIR="$(mktemp -d)"
  cd "$TEST_DIR"

  # Source the validator to test detection functions directly
  source "$REPO_ROOT/lib/eed_validator.sh"
}

teardown() {
  cd /
  rm -rf "$TEST_DIR"
}

# === POSITIVE CASES: Should detect as ed tutorial/test editing ===

@test "scene detection: bats test file with ed commands should trigger" {
  # Create a typical bats test file
  cat > test_eed_example.bats <<'EOF'
#!/usr/bin/env bats

@test "example ed operation" {
  run $SCRIPT_UNDER_TEST file.txt "1a
content line
EOF
.
w
q"
  [ "$status" -eq 0 ]
}
EOF

  local script="1a
content line
EOF
.
w
q"
  
  run detect_ed_tutorial_context "$script" "test_eed_example.bats"
  [ "$status" -eq 0 ]  # Should return success (high confidence)
  
  # Should return high confidence score
  confidence=$(detect_ed_tutorial_context "$script" "test_eed_example.bats")
  [ "$confidence" -ge 70 ]
}

@test "scene detection: markdown tutorial with ed examples should trigger" {
  cat > ed_tutorial.md <<'EOF'
# Ed Tutorial

Here's how to use ed:

```bash
ed file.txt
1a
Insert text here.
More text.
.
w
q
```
EOF

  local script="1a
Insert text here.
More text.
.
w
q"

  run detect_ed_tutorial_context "$script" "ed_tutorial.md"
  [ "$status" -eq 0 ]
  
  confidence=$(detect_ed_tutorial_context "$script" "ed_tutorial.md")
  [ "$confidence" -ge 60 ]
}

@test "scene detection: test file in tests directory should have high confidence" {
  mkdir -p tests
  local script="2a
test content.
.
w
q"

  run detect_ed_tutorial_context "$script" "tests/test_something.bats"
  [ "$status" -eq 0 ]
  
  confidence=$(detect_ed_tutorial_context "$script" "tests/test_something.bats")
  [ "$confidence" -ge 70 ]
}

@test "scene detection: documentation file with multiple ed blocks" {
  local script="1a
content.
.
5c
replacement.
.
w
q"

  run detect_ed_tutorial_context "$script" "docs/ed_usage.md"
  [ "$status" -eq 0 ]
  
  confidence=$(detect_ed_tutorial_context "$script" "docs/ed_usage.md")
  [ "$confidence" -ge 60 ]
}

# === NEGATIVE CASES: Should NOT trigger smart dot protection ===

@test "scene detection: regular source file should not trigger" {
  local script="1a
regular code content.
.
w
q"

  run detect_ed_tutorial_context "$script" "src/main.c"
  [ "$status" -ne 0 ]  # Should return failure (low confidence)
  
  confidence=$(detect_ed_tutorial_context "$script" "src/main.c")
  [ "$confidence" -lt 50 ]
}

@test "scene detection: legitimate multi-step ed operation should not trigger" {
  # This represents a real multi-step editing workflow
  local script="1d
2d  
3a
replacement text
.
w
q"

  run detect_ed_tutorial_context "$script" "data.txt"
  [ "$status" -ne 0 ]
  
  confidence=$(detect_ed_tutorial_context "$script" "data.txt")
  [ "$confidence" -lt 50 ]
}

@test "scene detection: simple single dot script should not trigger" {
  local script="1a
simple content
.
w
q"

  run detect_ed_tutorial_context "$script" "regular_file.txt"
  [ "$status" -ne 0 ]
  
  confidence=$(detect_ed_tutorial_context "$script" "regular_file.txt")
  [ "$confidence" -lt 50 ]
}

# === EDGE CASES: Boundary conditions ===

@test "scene detection: ambiguous case should return medium confidence" {
  # File could be tutorial or real editing
  local script="1a
content.
other content.
.
w
q"

  confidence=$(detect_ed_tutorial_context "$script" "example.txt")
  [ "$confidence" -ge 30 ]
  [ "$confidence" -le 70 ]
}

@test "scene detection: empty script should not trigger" {
  local script=""

  run detect_ed_tutorial_context "$script" "test.bats"
  [ "$status" -ne 0 ]
  
  confidence=$(detect_ed_tutorial_context "$script" "test.bats")
  [ "$confidence" -eq 0 ]
}

@test "scene detection: script with no dots should not trigger" {
  local script="1d
2d
w
q"

  run detect_ed_tutorial_context "$script" "test.bats"
  [ "$status" -ne 0 ]
  
  confidence=$(detect_ed_tutorial_context "$script" "test.bats")
  [ "$confidence" -lt 30 ]
}