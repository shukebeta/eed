#!/usr/bin/env bats
# Unit tests for new pattern matching functions

setup() {
    # Determine repository root using BATS_TEST_DIRNAME
    REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"

    # Create unique test directory and switch into it
    TEST_DIR="$(mktemp -d)"
    cd "$TEST_DIR" || exit

    # Load functions using absolute paths
    source "$REPO_ROOT/lib/eed_regex_patterns.sh"
}

teardown() {
    cd /
    rm -rf "$TEST_DIR"
}

# Test is_view_command function
@test "is_view_command: basic cases" {
    run is_view_command "p"
    [ "$status" -eq 0 ]

    run is_view_command "5p"
    [ "$status" -eq 0 ]

    run is_view_command "1,5p"
    [ "$status" -eq 0 ]

    run is_view_command ",p"
    [ "$status" -eq 0 ]

    run is_view_command "1,\$n"
    [ "$status" -eq 0 ]
}

@test "is_view_command: negative cases" {
    run is_view_command "d"
    [ "$status" -ne 0 ]

    run is_view_command "s/a/b/"
    [ "$status" -ne 0 ]
}

# Test is_substitute_command function
@test "is_substitute_command: various formats" {
    run is_substitute_command "s/old/new/"
    [ "$status" -eq 0 ]

    run is_substitute_command "1,\$s/old/new/g"
    [ "$status" -eq 0 ]

    run is_substitute_command "5s/old/new/p"
    [ "$status" -eq 0 ]

    run is_substitute_command "s/old/new/gp"
    [ "$status" -eq 0 ]
}

@test "is_substitute_command: negative cases" {
    run is_substitute_command "p"
    [ "$status" -ne 0 ]

    run is_substitute_command "5d"
    [ "$status" -ne 0 ]
}

# Security tests for substitute command regex fixes
@test "is_substitute_command: security fixes - invalid patterns should fail" {
    # These should fail with the fixed regex (prevent greedy matching issues)
    run is_substitute_command "s/a/b/c/d"
    [ "$status" -ne 0 ]

    run is_substitute_command "s/old/new/extra/stuff"
    [ "$status" -ne 0 ]

    run is_substitute_command "1,5s/pattern/replacement/invalid/extra"
    [ "$status" -ne 0 ]
}


# Test unified regex pattern
@test "test unified EED_REGEX_SUBSTITUTE_CORE" {
    # Load the patterns
    source "$REPO_ROOT/lib/eed_regex_patterns.sh"

    # Test the unified pattern directly
    [[ "s/old/new/" =~ $EED_REGEX_SUBSTITUTE_CORE ]]
    [ "$?" -eq 0 ]

    [[ "s#old#new#" =~ $EED_REGEX_SUBSTITUTE_CORE ]]
    [ "$?" -eq 0 ]

    [[ "1,5s|old|new|g" =~ $EED_REGEX_SUBSTITUTE_CORE ]]
    [ "$?" -eq 0 ]

    # Test function calls
    is_substitute_command "s/old/new/"
    [ "$?" -eq 0 ]

    is_substitute_command "s#old#new#"
    [ "$?" -eq 0 ]
}

# Critical: Test alternative delimiters (key concern from code review)
@test "is_substitute_command: alternative delimiters must work" {
    # ed allows any non-space character as delimiter - this is CRITICAL functionality
    run is_substitute_command "s#old#new#"
    [ "$status" -eq 0 ]

    run is_substitute_command "s|old|new|"
    [ "$status" -eq 0 ]

    run is_substitute_command "s:old:new:"
    [ "$status" -eq 0 ]

    run is_substitute_command "s@old@new@g"
    [ "$status" -eq 0 ]

    # With addresses
    run is_substitute_command "1,\$s#path/file#newpath/file#g"
    [ "$status" -eq 0 ]
}

# Test is_modifying_command function
@test "is_modifying_command: basic cases" {
    run is_modifying_command "5d"
    [ "$status" -eq 0 ]

    run is_modifying_command "1,5d"
    [ "$status" -eq 0 ]

    run is_modifying_command ",d"
    [ "$status" -eq 0 ]

    run is_modifying_command "5m10"
    [ "$status" -eq 0 ]
}

# Test is_input_command function
@test "is_input_command: basic cases" {
    run is_input_command "i"
    [ "$status" -eq 0 ]

    run is_input_command "5i"
    [ "$status" -eq 0 ]

    run is_input_command "1,5c"
    [ "$status" -eq 0 ]
}

# Test is_write_command function
@test "is_write_command: basic cases" {
    run is_write_command "w"
    [ "$status" -eq 0 ]

    run is_write_command "w filename.txt"
    [ "$status" -eq 0 ]
}

# Test is_quit_command function
@test "is_quit_command: basic cases" {
    run is_quit_command "q"
    [ "$status" -eq 0 ]

    run is_quit_command "Q"
    [ "$status" -eq 0 ]
}

# Edge case tests addressing code review concerns
@test "pattern functions: edge cases that code review was concerned about" {
    # These are the exact scenarios that were thought would fail
    run is_view_command "5p"
    [ "$status" -eq 0 ]

    run is_view_command "1,5p"
    [ "$status" -eq 0 ]

    run is_modifying_command "5d"
    [ "$status" -eq 0 ]

    run is_modifying_command "1,5d"
    [ "$status" -eq 0 ]

    # Test the range vs single address distinction works correctly
    run is_view_command ",p"
    [ "$status" -eq 0 ]

    run is_modifying_command ",d"
    [ "$status" -eq 0 ]
}

# Test search pattern ranges - /pat1/,/pat2/ commands
@test "is_view_command: search pattern ranges" {
    run is_view_command "/pattern1/,/pattern2/p"
    [ "$status" -eq 0 ]

    run is_view_command "/start/,/end/n"
    [ "$status" -eq 0 ]

    run is_view_command "?backward?,?end?p"
    [ "$status" -eq 0 ]
}

@test "is_modifying_command: search pattern ranges" {
    run is_modifying_command "/pattern1/,/pattern2/d"
    [ "$status" -eq 0 ]

    run is_modifying_command "?start?,?end?d"
    [ "$status" -eq 0 ]
}

@test "is_input_command: search pattern ranges" {
    run is_input_command "/pattern1/,/pattern2/c"
    [ "$status" -eq 0 ]

    run is_input_command "/start/,/end/a"
    [ "$status" -eq 0 ]

    run is_input_command "?backward?,?forward?i"
    [ "$status" -eq 0 ]
}

# Mixed address types (numeric + search pattern)
@test "mixed address ranges work correctly" {
    run is_view_command "5,/pattern/p"
    [ "$status" -eq 0 ]

    run is_modifying_command "/start/,10d"
    [ "$status" -eq 0 ]

    run is_input_command "1,/end/c"
    [ "$status" -eq 0 ]
}

@test "simple substitute passes" {
  run is_substitute_command "s/foo/bar/g"
  [ "$status" -eq 0 ]
}

@test "substitute with escaped delimiter passes" {
  run is_substitute_command "s/\/a\/b/c/g"
  [ "$status" -eq 0 ]
}

@test "substitute with number flag" {
  run is_substitute_command "s/x/y/42"
  [ "$status" -eq 0 ]
}

@test "substitute missing closing delimiter fails" {
  run is_substitute_command "s/foo/bar"
  [ "$status" -ne 0 ]
}

@test "global simple" {
  run is_global_command "g/foo/p"
  [ "$status" -eq 0 ]
}

@test "global with substitute" {
  run is_global_command "g/foo/s/x/y/g"
  [ "$status" -eq 0 ]
}

@test "address range with numbers" {
  run is_address_only "1,10"
  [ "$status" -ne 0 ]
}

@test "address range with search and dot" {
  run is_address_only "/foo/,. "
  [ "$status" -ne 0 ]
}

@test "address with escaped delimiter" {
  run is_address_only "/a\/b/"
  [ "$status" -eq 0 ]
}

@test "invalid address should fail" {
  run is_address_only "/unterminated"
  [ "$status" -ne 0 ]
}
