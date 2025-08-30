#!/usr/bin/env bats

# Rich unit test for transform_content_dots focusing on a markdown tutorial block
# Ensures:
#  - content '.' inside code fences are replaced with a marker
#  - a substitution command is inserted outside input blocks and before 'w'
#  - the final terminator '.' is preserved

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  TEST_DIR="$(mktemp -d)"
  cd "$TEST_DIR"

  # Source the validator to test transform functions directly
  source "$REPO_ROOT/lib/eed_validator.sh"
}

teardown() {
  cd /
  rm -rf "$TEST_DIR"
}

@test "dot transform: markdown tutorial block insertion order" {
  local input="2a
Here's how to add multiple lines:

\`\`\`bash
ed file.txt
1a
First line.
Second line.
.
w
q
\`\`\`
.
w
q"

  local output
  output=$(transform_content_dots "$input")
  [ "$?" -eq 0 ]

  # Should contain substitution command
  [[ "$output" == *"s@"*"@.@g"* ]]

  # The substitution line must appear before the final 'w'
  local w_line_num
  w_line_num=$(echo "$output" | grep -n "^w$" | cut -d: -f1 | tail -n1 || true)
  local subst_line_num
  # accept optional address form like "1,$s@marker@.@g" or "s@marker@.@g"
  subst_line_num=$(echo "$output" | grep -nE '^(1,\$)?s@' | cut -d: -f1 | head -n1 || true)
  [ -n "$subst_line_num" ]
  [ -n "$w_line_num" ]
  [ "$subst_line_num" -lt "$w_line_num" ]

  # Ensure final terminator dot remains exactly once (the final one)
  local terminator_count
  terminator_count=$(echo "$output" | grep -c "^\\.$" || true)
  [ "$terminator_count" -eq 1 ]

  # Ensure inner content dots (inside code fence) were replaced by a marker (not literal '.')
  # e.g. lines "First line." or "Second line." should remain, but the standalone '.' inside the code block (terminator) is only the one for the inner block and should have been replaced
  # Confirm there is at least one marker occurrence referenced by the substitution command
  local marker
  # extract marker using grep-only approach (avoid sed escaping issues)
  marker=$(echo "$output" | grep -oE 's@~~DOT_[^@]+~~@' | sed 's/s@//;s/@//' | head -n1 || true)
  [ -n "$marker" ]
  echo "$output" | grep -qF "$marker"
}
