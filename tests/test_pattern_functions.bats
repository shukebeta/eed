#!/usr/bin/env bats
# Unit tests for new pattern matching functions

setup() {
    # Create test directory
    TEST_DIR="${BATS_TMPDIR}/eed_pattern_test"
    mkdir -p "$TEST_DIR"
    cd "$TEST_DIR"

    # Load functions
    source "$BATS_TEST_DIRNAME/../lib/eed_regex_patterns.sh"
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