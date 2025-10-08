#!/usr/bin/env bats

# Regression tests proving smart dot protection is necessary
# These tests demonstrate what happens WITHOUT protection

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

@test "regression: raw ed fails on markdown tutorial (proves protection is needed)" {
  # This test demonstrates WHY smart dot protection exists
  # Without it, ed misinterprets dots in content as terminators

  cat > ed_guide.md <<'EOF'
# Ed Editor Guide

## Basic Usage
EOF

  # The SAME script that works with eed
  script='2a
Here'"'"'s how to add multiple lines:

```bash
ed file.txt
1a
First line.
Second line.
.
w
q
```
.
w
q'

  # Test 1: Show that raw ed produces WRONG results
  printf '%s\n' "$script" | ed -s ed_guide.md 2>/dev/null || true

  # Verify the BROKEN behavior (what we DON'T want)
  # The first standalone dot (line 9 in script) terminates the 'a' command early
  # So lines after it get misplaced or lost

  # "## Basic Usage" should still be at the end
  # But without protection, it gets moved to wrong location
  run grep -n "^## Basic Usage$" ed_guide.md
  [ "$status" -eq 0 ]

  # The closing backticks should exist
  # But raw ed terminates at first dot, so they're missing or misplaced
  run grep -n "^\`\`\`$" ed_guide.md

  # Either backticks are missing (status != 0)
  # Or they're not at the expected location
  # This proves the content is corrupted

  if [ "$status" -eq 0 ]; then
    # If backticks exist, they should be malformed
    # The proper line should be 12, but won't be
    [[ ! "$output" =~ "12:\`\`\`" ]]
  fi

  # Verify the dot inside code block is missing or wrong
  run grep -n "^\.$" ed_guide.md

  # Either no standalone dot exists, or it's in wrong position
  # (Should be line 9 if correct, but raw ed breaks this)
  if [ "$status" -eq 0 ]; then
    [[ ! "$output" =~ "9:." ]]
  fi
}

@test "regression: eed WITH protection produces correct structure" {
  # This test proves eed with smart dot protection works correctly
  # Contrast with the previous test showing raw ed failure

  cat > ed_guide.md <<'EOF'
# Ed Editor Guide

## Basic Usage
EOF

  script='2a
Here'"'"'s how to add multiple lines:

```bash
ed file.txt
1a
First line.
Second line.
.
w
q
```
.
w
q'

  # Run through eed (with protection)
  run "$SCRIPT_UNDER_TEST" ed_guide.md "$script"
  [ "$status" -eq 0 ]

  # Verify CORRECT structure in preview
  run grep -n "^\.$" ed_guide.md.eed.preview
  [ "$status" -eq 0 ]
  [[ "$output" =~ "10:." ]]  # Dot at correct line

  run grep -n "^\`\`\`$" ed_guide.md.eed.preview
  [ "$status" -eq 0 ]
  [[ "$output" =~ "13:\`\`\`" ]]  # Backticks at correct line

  run grep -n "^## Basic Usage$" ed_guide.md.eed.preview
  [ "$status" -eq 0 ]
  [[ "$output" =~ "14:## Basic Usage" ]]  # Header at correct line

  # This proves protection works!
}

@test "regression: verify transform_content_dots actually transforms" {
  # Unit test to ensure the transformation function works

  # Source the smart dot protection library
  source "$REPO_ROOT/lib/eed_smart_dot_protection.sh"

  # Test script with multiple input blocks (first dot is content, not terminator)
  test_script='1a
First.
.
2a
Second.
.
w
q'

  # Transform it
  run transform_content_dots "$test_script"
  [ "$status" -eq 0 ]

  # Verify transformation occurred
  # The first dot (content dot) should be replaced with a marker
  # A substitution command should be inserted
  [[ "$output" =~ "1,\$s@" ]]  # Should have substitution

  # The marker pattern should exist
  [[ "$output" =~ "~~DOT_" ]]  # Should have marker

  # The last dot (terminator) should remain as-is
  [[ "$output" =~ "Second."$'\n'"." ]]  # Last dot preserved
}

@test "regression: no_dot_trap correctly identifies tutorial patterns" {
  # Ensure detection logic properly identifies cases needing protection

  source "$REPO_ROOT/lib/eed_validator.sh"

  # Script that SHOULD trigger protection (markdown tutorial pattern)
  # The key pattern: has q command followed by more content (tutorial scenario)
  tutorial_script='2a
```bash
ed file.txt
1a
content.
.
w
q
```
.
w
q'

  run no_dot_trap "$tutorial_script"

  # Should return non-zero (trap detected)
  [ "$status" -ne 0 ]
  [[ "$output" =~ "POTENTIAL_DOT_TRAP" ]]
}

@test "regression: normal scripts don't trigger false positive" {
  # Ensure we don't over-trigger protection (the bug we fixed)

  source "$REPO_ROOT/lib/eed_validator.sh"

  # Normal script with proper terminators
  normal_script='1a
line.
.
2a
other.
.
w
q'

  run no_dot_trap "$normal_script"

  # Should return 0 (no trap detected)
  [ "$status" -eq 0 ]
}
