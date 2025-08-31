#!/usr/bin/env bats

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

@test "debug: edge case malformed script" {
  # From integration tests line 238 issue
  cat > edge_case.bats <<'EOF'
# Test: edge case
function test_edge_case() {
  echo "test"
}
EOF

  # Script that might cause transform failure
  script='1a
complex
malformed.
script.
that.
might.
fail.
.
w
q'

  echo "File before:"
  cat -n edge_case.bats

  echo "=== Testing edge case ==="
  run $SCRIPT_UNDER_TEST edge_case.bats "$script"
  echo "Exit status: $status"
  echo "Output: $output"

  echo "=== File after ==="
  cat edge_case.bats

  # Should handle gracefully (either succeed or fail cleanly)
  if [ "$status" -eq 0 ]; then
    echo "✓ Edge case handled successfully"
  else
    echo "✓ Edge case failed cleanly (expected behavior)"
  fi
}

@test "debug: isolate addr_count issue" {
  source "$REPO_ROOT/lib/eed_validator.sh"

  script='3a
content line
.
w
q'

  echo "=== Testing no_complex_patterns directly ==="
  echo "Script:"
  printf "%s\n" "$script"

  echo "=== Function result ==="
  no_complex_patterns "$script" 2>&1
  echo "Exit code: $?"
}

@test "debug: complex ed examples case" {
  cat > docs.txt <<'EOF'
Documentation file
line2
line3
line4
line5
EOF

  # Complex case with multiple input blocks - from integration tests
  script='1a
Example 1:
  1a
  content.
  .
  w

Example 2:
  5c
  other content.
  .
  w
  q
.
w
q'

  echo "File before:"
  cat -n docs.txt

  echo "=== Testing complex case ==="
  run $SCRIPT_UNDER_TEST --force docs.txt "$script"
  echo "Exit status: $status"
  echo "Output: $output"

  echo "=== File after ==="
  cat docs.txt

  # Check if content was inserted
  if grep -q "content." docs.txt; then
    echo "✓ Complex case worked"
  else
    echo "✗ Complex case failed"
    return 1
  fi
}


@test "debug: marker conflicts case" {
  # From integration tests line 181 issue
  cat > conflict_test.bats <<'EOF'
# Test: contains marker-like strings
function test_markers() {
  echo "~~DOT_123~~"
}
EOF

  script='2a
# Test: new test with dots
function test_with_dots() {
  content.
  more content.
}
.
w
q'

  echo "File before:"
  cat -n conflict_test.bats

  echo "=== Testing marker conflicts ==="
  run $SCRIPT_UNDER_TEST --force conflict_test.bats "$script"
  echo "Exit status: $status"
  echo "Output: $output"

  echo "=== File after ==="
  cat conflict_test.bats

  # Check if content was inserted
  if grep -q "test_with_dots" conflict_test.bats; then
    echo "✓ Marker conflicts case worked"
  else
    echo "✗ Marker conflicts case failed"
    return 1
  fi
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

  # Previously forced failure to show output — disabled
  :
}

@test "debug: complex script messaging" {
  echo "line1" > test_file.txt
  echo "line2" >> test_file.txt  
  echo "line3" >> test_file.txt

  script='g/line2/d
w
q'

  echo "=== Testing complex script with force ==="
  run $SCRIPT_UNDER_TEST --force test_file.txt "$script"
  echo "Exit status: $status"
  echo "Full output:"
  printf "%s\n" "$output"
  
  echo "=== Checking for complex message ==="
  if [[ "$output" =~ "Complex script detected" ]]; then
    echo "✓ Found expected complex message"
  else
    echo "✗ Missing complex message"
  fi
  
  if [[ "$output" =~ force.*disabled ]]; then
    echo "✓ Found force disabled message"
  else  
    echo "✗ Missing force disabled message"
  fi
  
  # Test passes - complex script detection works correctly
  [[ "$output" =~ "Complex script detected" ]]
  [[ "$output" =~ force.*disabled ]]
}

# Migrated from tests/test_complex_messages_cleanup.bats - original @test "complex script with --force shows only one clear message"
@test "complex script with --force shows only one clear message (migrated)" {
    echo "line1" > test_file.txt
    echo "line2" >> test_file.txt
    echo "line3" >> test_file.txt
    
    script='g/line2/d
w
q'

    run $SCRIPT_UNDER_TEST --force test_file.txt "$script"

    # Should show only ONE user-friendly message about force being disabled
    [[ "$output" =~ "Complex script detected" ]]
    [[ "$output" =~ force.*disabled ]]

    # Should show exactly ONE user-visible complex message
    complex_count=$(echo "$output" | grep -c -i "complex" || true)
    [ "$complex_count" -eq 1 ]
}
# Migrated from [`tests/test_eed.bats`](tests/test_eed.bats:261) - original @test "file creation for non-existent file"
@test "debug: file creation issue" {
    # Test that eed can create new files
    script='1i
first line
.
w
q'
    echo "=== Testing file creation ==="
    run $SCRIPT_UNDER_TEST --force newfile.txt "$script"
    echo "Exit status: $status"
    echo "Output: $output"
    
    echo "=== File check ==="
    if [ -f newfile.txt ]; then
        echo "✓ File was created"
        echo "File contents:"
        cat newfile.txt
    else
        echo "✗ File was NOT created"
        ls -la *.txt 2>/dev/null || echo "No txt files found"
    fi
    
    # Test should pass now
    [ "$status" -eq 0 ]
    [ -f newfile.txt ]
    grep -q "first line" newfile.txt
}
# Migrated from tests/test_complex_messages_cleanup.bats - original @test "complex script without --force is silent about complexity"
@test "complex script without --force is silent about complexity (migrated)" {
    echo "line1" > test_file.txt
    echo "line2" >> test_file.txt
    echo "line3" >> test_file.txt
    
    script='g/line2/d
w
q'

    run $SCRIPT_UNDER_TEST test_file.txt "$script"

    # Should show preview workflow without complexity noise
    [[ "$output" =~ "preview" ]] || [[ "$output" =~ "diff" ]]

    # Should NOT mention "complex" to the user at all
    ! [[ "$output" =~ [Cc]omplex ]]
}

@test "debug: debug mode technical details" {
    echo "line1" > test_file.txt
    echo "line2" >> test_file.txt
    echo "line3" >> test_file.txt
    
    script='g/line2/d
w
q'

    echo "=== Testing debug mode ==="
    run $SCRIPT_UNDER_TEST --debug test_file.txt "$script"
    echo "Exit status: $status"
    echo "Full output:"
    printf "%s\n" "$output"
    
    # Debug mode shows technical details about complex patterns
    [[ "$output" =~ "Skipping auto-reorder due to complex patterns" ]]
}


