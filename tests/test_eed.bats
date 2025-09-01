#!/usr/bin/env bats

# Comprehensive eed Test Suite - Converted to Bats Format
# Tests the eed tool with all existing functionality
#
# Test categories:
# - Basic functionality (insert, delete, replace)
# - Special character handling (quotes, dollar signs)
# - Windows path compatibility
# - Error handling and preview/restore
# - Complex multi-command operations
# - Security validation (command injection prevention)

setup() {
    # Determine repository root before changing to a temporary working directory.
    # Prefer BATS_TEST_DIRNAME (set by bats). If not present, fall back to script heuristics.
    if [ -n "${BATS_TEST_DIRNAME:-}" ]; then
        REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
    else
        # Fallback: derive from this test file's location
        SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
        REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
    fi

    # Create unique test directory for this test run and switch into it
    TEST_DIR="$(mktemp -d)"
    cd "$TEST_DIR"

    # Use the repository eed executable directly (ensures libs resolve correctly)
    SCRIPT_UNDER_TEST="$REPO_ROOT/eed"
    chmod +x "$SCRIPT_UNDER_TEST" 2>/dev/null || truet st -s

    # Expose repo root on PATH for helper tools
    export PATH="$REPO_ROOT:$PATH"

    # Prevent logging during tests
    export EED_TESTING=true
}

teardown() {
    # Clean up test directory
    cd /
    rm -rf "$TEST_DIR"
}

@test "basic insert operation with terminator" {
    cat > test1.txt << 'EOF'
line1
line2
line3
line4
line5
EOF

    run "$SCRIPT_UNDER_TEST" --force test1.txt "3a
inserted_line
.
w
q"
    [ "$status" -eq 0 ]
    run grep -q "inserted_line" test1.txt
    [ "$status" -eq 0 ]
}

@test "basic delete operation" {
    cat > test1.txt << 'EOF'
line1
line2
line3
line4
line5
EOF

    run "$SCRIPT_UNDER_TEST" --force test1.txt "2d
w
q"
    [ "$status" -eq 0 ]
    run grep -q "line2" test1.txt
    [ "$status" -ne 0 ]
}

@test "basic replace operation (global)" {
    cat > test1.txt << 'EOF'
line1
line2
line3
line4
line5
EOF

    run "$SCRIPT_UNDER_TEST" --force test1.txt "1,\$s/line1/replaced_line1/
w
q"
    [ "$status" -eq 0 ]
    run grep -q "replaced_line1" test1.txt
    [ "$status" -eq 0 ]
}

@test "special characters - single quotes" {
    cat > test2.txt << 'EOF'
normal line
EOF

    run "$SCRIPT_UNDER_TEST" --force test2.txt "1a
line with 'single quotes'
.
w
q"
    [ "$status" -eq 0 ]
    run grep -q "line with 'single quotes'" test2.txt
    [ "$status" -eq 0 ]
}

@test "special characters - double quotes" {
    cat > test2.txt << 'EOF'
normal line
EOF

    run "$SCRIPT_UNDER_TEST" --force test2.txt "$(cat <<'EOF'
1a
line with "double quotes"
.
w
q
EOF
)"
    [ "$status" -eq 0 ]
    run grep -q 'line with "double quotes"' test2.txt
    [ "$status" -eq 0 ]
}

@test "special characters - backslashes" {
    cat > test2.txt << 'EOF'
normal line
EOF

    run "$SCRIPT_UNDER_TEST" --force test2.txt "$(cat <<'EOF'
1a
line with \backslash
.
w
q
EOF
)"
    [ "$status" -eq 0 ]
    run grep -q "backslash" test2.txt
    [ "$status" -eq 0 ]
}

@test "special characters - dollar signs" {
    cat > test2.txt << 'EOF'
normal line
EOF

    run "$SCRIPT_UNDER_TEST" --force test2.txt "$(cat <<'EOF'
1a
line with $dollar sign
.
w
q
EOF
)"
    [ "$status" -eq 0 ]
    run grep -q "dollar sign" test2.txt
    [ "$status" -eq 0 ]
}

@test "windows path compatibility" {
    cat > test3.txt << 'EOF'
old_path=/usr/local/bin
EOF

    run "$SCRIPT_UNDER_TEST" --force test3.txt "s|old_path=.*|new_path=C:\\Users\\Test\$User\\Documents|
w
q"
    [ "$status" -eq 0 ]
    run grep -q "C:" test3.txt
    [ "$status" -eq 0 ]
}

@test "error handling - invalid command rejected" {
    cat > test4.txt << 'EOF'
original content
EOF

    # Invalid command should be detected and rejected before execution
    run "$SCRIPT_UNDER_TEST" --force test4.txt "invalid_command"
    [ "$status" -ne 0 ]

    # Original content should be preserved (file never modified)
    run grep -q "original content" test4.txt
    [ "$status" -eq 0 ]
}

@test "complex operations - console.log removal" {
    cat > test5.txt << 'EOF'
function newName() {
    console.log("debug");
    return result;
}
EOF

    run "$SCRIPT_UNDER_TEST" --force test5.txt "1,\$s/.*console\.log.*;//
w
q"
    [ "$status" -eq 0 ]
    run grep -q "console.log" test5.txt
    [ "$status" -ne 0 ]
}

@test "complex operations - comment insertion" {
    cat > test5.txt << 'EOF'
function newName() {
    return result;
}
EOF

    run "$SCRIPT_UNDER_TEST" --force test5.txt "2a
    // Added comment
.
w
q"
    [ "$status" -eq 0 ]
    run grep -q "Added comment" test5.txt
    [ "$status" -eq 0 ]
}

@test "security validation - command injection resistance" {
    cat > test6.txt << 'EOF'
safe content
EOF

    # Attempt command injection - should be treated as literal text
    run "$SCRIPT_UNDER_TEST" --force test6.txt "1a
; rm -rf /tmp; echo malicious
.
w
q"
    # File should still exist (injection was prevented)
    [ -f test6.txt ]
    # Content should include the "malicious" text as literal content
    run grep -q "malicious" test6.txt
    [ "$status" -eq 0 ]
}

@test "security validation - shell metacharacters" {
    cat > test6.txt << 'EOF'
safe content
EOF

    run "$SCRIPT_UNDER_TEST" --force test6.txt "1a
line with | & ; < > characters
.
w
q"
    [ "$status" -eq 0 ]
    run grep -q "characters" test6.txt
    [ "$status" -eq 0 ]
}


@test "debug: edge case malformed script (moved from debug_integration.bats)" {
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
  run "$SCRIPT_UNDER_TEST" edge_case.bats "$script"
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

@test "debug: reproduce original failing scenario (moved from debug_integration.bats)" {
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

@test "debug: step by step execution trace (moved from debug_integration.bats)" {
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

@test "debug: file creation issue (moved from debug_integration.bats)" {
    # Test that eed can create new files
    script='1i
first line
.
w
q'
    echo "=== Testing file creation ==="
    run "$SCRIPT_UNDER_TEST" --force newfile.txt "$script"
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
