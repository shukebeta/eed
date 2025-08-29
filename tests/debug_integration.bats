#!/usr/bin/env bats

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

@test "debug: simple integration test" {
  cat > test_file.bats <<'EOF'
#!/usr/bin/env bats
# Test: existing test
function existing_test() {
  run echo "hello"  
  [ "$status" -eq 0 ]
}
EOF

  script='3a
content line
.
w
q'

  echo "File before eed:"
  cat -n test_file.bats
  
  echo "=== Running eed with full bash trace ==="
  bash -x "$SCRIPT_UNDER_TEST" --debug --force test_file.bats "$script"
  local eed_exit=$?
  echo "Direct eed exit code: $eed_exit"
  
  echo "=== File after eed ==="
  cat -n test_file.bats
  
  # Check if content was inserted
  if grep -q "content line" test_file.bats; then
    echo "✓ Content was inserted"
  else
    echo "✗ Content was NOT inserted"
    return 1
  fi
}

@test "debug: isolate addr_count issue" {
  source "$REPO_ROOT/lib/eed_validator.sh"
  
  script='3a
content line  
.
w
q'
  
  echo "=== Testing detect_complex_patterns directly ==="
  echo "Script:"
  printf "%s\n" "$script"
  
  echo "=== Function result ==="
  detect_complex_patterns "$script" 2>&1
  echo "Exit code: $?"
}

@test "debug: reproduce original failing scenario" {
  # Exact copy of original test but with clean @test definitions
  cat > test_example.bats <<'EOF'
#!/usr/bin/env bats

# Test: existing test (cleaned from @test)
function existing_test() {
  run echo "hello"
  [ "$status" -eq 0 ]
}
EOF

  script='3a
# Test case demonstrates ed command usage  
# Example: eed file.txt with multiple dots
content line
.
w
q'

  echo "Current directory: $(pwd)"
  echo "Test files in directory:"
  ls -la
  echo "File before eed:"
  cat test_example.bats
  echo "Script to apply:"
  printf "%q\n" "$script"
  
  echo "Running eed with bash trace:"  
  bash -x "$SCRIPT_UNDER_TEST" --debug --force test_example.bats "$script" 2>&1
  local eed_status=$?
  echo "Direct eed exit status: $eed_status"
  
  echo "File after (if exists):"
  cat test_example.bats 2>/dev/null || echo "File not found"
  
  # Check if content was inserted
  if grep -q "content line" test_example.bats; then
    echo "✓ Content was inserted successfully"
  else
    echo "✗ Content was NOT inserted"
  fi
}

@test "debug: step by step execution trace" {
  cat > simple_file.txt <<'EOF'
line1
line2
line3
EOF

  echo "=== Simple script test ==="
  script='3a
simple content
.
w
q'
  
  echo "Script to test:"
  printf "%s\n" "$script"
  
  echo "=== Full bash trace ==="
  bash -x "$SCRIPT_UNDER_TEST" --debug --force simple_file.txt "$script" 2>&1 | tail -50
  local exit_code=$?
  echo "Exit code: $exit_code"
  
  echo "=== File result ==="
  cat simple_file.txt
  
  # Check if content was actually inserted
  if grep -q "simple content" simple_file.txt; then
    echo "✓ Simple content was inserted"
  else
    echo "✗ Simple content was NOT inserted - eed succeeded but did nothing!"
  fi
}

@test "debug: direct ed execution test" {
  cat > test_file.txt <<'EOF'
line1
line2
line3
EOF

  echo "File before ed:"
  cat -n test_file.txt
  
  # Prepare instruction stream like our smart dot protection would
  script='3a
content line
.
w
q'
  
  echo "=== Testing direct ed execution ==="
  echo "Script to execute:"
  printf "%s\n" "$script"
  
  echo "=== Running ed directly ==="
  printf '%s\n' "$script" | ed -s test_file.txt
  local ed_exit_code=$?
  echo "Direct ed exit code: $ed_exit_code"
  
  echo "=== File after ed ==="
  cat -n test_file.txt
  
  # Check result
  if [ $ed_exit_code -eq 0 ]; then
    echo "✓ Ed command succeeded"
    if grep -q "content line" test_file.txt; then
      echo "✓ Content was inserted correctly"
    else
      echo "✗ Ed succeeded but content missing!"
    fi
  else
    echo "✗ Ed command failed with code $ed_exit_code"
  fi
  
  # Force failure to see output
  [ 1 -eq 2 ]
}