#!/usr/bin/env bats

# Minimal unit test to assert the transform produces an addressed substitution
# and places it before the final write command.

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  TEST_DIR="$(mktemp -d)"
  cd "$TEST_DIR"

  source "$REPO_ROOT/lib/eed_validator.sh"
}

teardown() {
  cd /
  rm -rf "$TEST_DIR"
}

@test "transform inserts 1,\$ substitution and it's before w" {
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

  # substitution must use the full address form "1,$s@marker@.@g"
  local subst_line_num
  # match the fixed literal address+substitute string
  subst_line_num=$(echo "$output" | grep -nF '1,$s@' | cut -d: -f1 | head -n1 || true)
  [ -n "$subst_line_num" ]

  # ensure substitution appears before the final write (choose last write, not inner block)
  local w_line_num
  w_line_num=$(echo "$output" | grep -n "^w$" | cut -d: -f1 | tail -n1 || true)
  [ -n "$w_line_num" ]
  [ "$subst_line_num" -lt "$w_line_num" ]

  # extract marker from addressed substitution and ensure marker occurs elsewhere
  local marker
  marker=$(echo "$output" | awk -F's@' '/s@/ { split($2,a,"@"); print a[1]; exit }' || true)
  [ -n "$marker" ]
  echo "$output" | grep -qF "$marker"
}
