#!/usr/bin/env bats

# Regression test for the specific bug reported by user:
# substitute commands with reordering were returning exit code 1 instead of 0

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

@test "regression: substitute commands with reordering return exit code 0" {
  # This is the exact scenario reported by the user
  cat > NLog.config <<'EOF'
line1
line2
line3
line4
line5
line6
line7
line8
line9
line10
line11
line12
configsetting:value1
configsetting:value2
line15
line16
configsetting:value3
line18
EOF

  # This is the exact command that was failing
  run "$SCRIPT_UNDER_TEST" NLog.config - <<'EOF'
13s/configsetting:/configsettings:/g
14s/configsetting:/configsettings:/g
17s/configsetting:/configsettings:/g
w
q
EOF

  # The critical assertion: should return exit code 0, not 1
  [ "$status" -eq 0 ]
  
  # Should show reordering message
  [[ "$output" =~ "Auto-reordering script" ]]
  
  # Should create preview file
  [ -f NLog.config.eed.preview ]
  
  # Should perform correct substitutions
  run grep -q "configsettings:value1" NLog.config.eed.preview
  [ "$status" -eq 0 ]
  
  run grep -q "configsettings:value2" NLog.config.eed.preview
  [ "$status" -eq 0 ]
  
  run grep -q "configsettings:value3" NLog.config.eed.preview
  [ "$status" -eq 0 ]
  
  # Original file should be unchanged
  run grep -q "configsetting:value1" NLog.config
  [ "$status" -eq 0 ]
}

@test "regression: multiple substitute commands with various colon patterns" {
  # Test various patterns that could trigger the colon parsing bug
  cat > urls.txt <<'EOF'
http://example.com:8080/path
https://api.example.com:443/endpoint
ftp://files.example.com:21/data
database:user:password:host:port
config:setting:value
EOF

  run "$SCRIPT_UNDER_TEST" urls.txt <<'EOF'
1s/http:/https:/g
2s/:443/:8443/g
4s/database:/db:/g
5s/config:/configuration:/g
w
q
EOF

  # Should succeed
  [ "$status" -eq 0 ]
  
  # Should show reordering (ascending line numbers)
  [[ "$output" =~ "Auto-reordering script" ]]
  
  # Verify substitutions worked
  run grep -q "https://example.com:8080/path" urls.txt.eed.preview
  [ "$status" -eq 0 ]
  
  run grep -q "https://api.example.com:8443/endpoint" urls.txt.eed.preview
  [ "$status" -eq 0 ]
  
  run grep -q "db:user:password:host:port" urls.txt.eed.preview
  [ "$status" -eq 0 ]
  
  run grep -q "configuration:setting:value" urls.txt.eed.preview
  [ "$status" -eq 0 ]
}

@test "regression: substitute commands do not trigger false content length errors" {
  # Test that substitute commands don't trigger the content length validation incorrectly
  cat > test.txt <<'EOF'
short
line
here
EOF

  # Substitute with much longer replacement
  run "$SCRIPT_UNDER_TEST" test.txt <<'EOF'
1s/short/this_is_a_much_longer_replacement_text_that_changes_content_length/g
2s/line/another_long_replacement_string/g
w
q
EOF

  # Should succeed (content length change is expected with substitutions)
  [ "$status" -eq 0 ]
  
  # Should perform substitutions
  run grep -q "this_is_a_much_longer_replacement_text_that_changes_content_length" test.txt.eed.preview
  [ "$status" -eq 0 ]
  
  run grep -q "another_long_replacement_string" test.txt.eed.preview
  [ "$status" -eq 0 ]
}