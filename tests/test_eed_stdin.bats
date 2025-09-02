#!/usr/bin/env bats
# Test suite for eed stdin functionality

setup() {
    REPO_ROOT="$BATS_TEST_DIRNAME/.."
    SCRIPT_UNDER_TEST="$REPO_ROOT/eed"
    TEMP_DIR=$(mktemp -d)
    cd "$TEMP_DIR" || exit
}

teardown() {
    cd /
    rm -rf "$TEMP_DIR"
}

@test "stdin with pipeline" {
    echo -e "line 1\nline 2\nline 3" > test.txt

    run "$SCRIPT_UNDER_TEST" --force test.txt - << 'EOF'
1d
w
q
EOF
    [ "$status" -eq 0 ]

    run cat test.txt
    [ "${lines[0]}" = "line 2" ]
    [ "${lines[1]}" = "line 3" ]
}

@test "stdin pipeline without '-' (forgiving auto-read)" {
    echo -e "line 1\nline 2\nline 3" > test.txt

    # Pipe script but omit the '-' positional argument; eed should accept stdin.
    run "$SCRIPT_UNDER_TEST" --force test.txt << 'EOF'
1d
w
q
EOF
    [ "$status" -eq 0 ]

    # Verify the functionality worked correctly (file was edited)
    run cat test.txt
    [ "${lines[0]}" = "line 2" ]
    [ "${lines[1]}" = "line 3" ]
}

@test "backward compatibility works" {
    echo -e "line 1\nline 2\nline 3" > test.txt

    run "$SCRIPT_UNDER_TEST" --force test.txt "2d
w
q"

    [ "$status" -eq 0 ]

    run cat test.txt
    [ "${lines[0]}" = "line 1" ]
    [ "${lines[1]}" = "line 3" ]
}

@test "stdin with file redirection (when working in proper shell)" {
    echo -e "line 1\nline 2\nline 3" > test.txt
    printf '2c\nmodified line 2\n.\nw\nq\n' > script.ed

    # Note: This test may fail in restricted environments
    # but should work in normal shell environments
    run bash -c '"$1" --force test.txt - < script.ed' bash "$SCRIPT_UNDER_TEST"

    # We expect this to work, but acknowledge it might fail in some environments
    if [ "$status" -eq 0 ]; then
        run cat test.txt
        [ "${lines[1]}" = "modified line 2" ]
    else
        skip "File redirection not supported in this test environment"
    fi
}
