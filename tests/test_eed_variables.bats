#!/usr/bin/env bats
# Test suite for eed variable precedence and naming

setup() {
    REPO_ROOT="$BATS_TEST_DIRNAME/.."
    SCRIPT_UNDER_TEST="$REPO_ROOT/eed"
    TEMP_DIR=$(mktemp -d)
    cd "$TEMP_DIR" || exit
    echo "test file" > test.txt
}

teardown() {
    cd /
    rm -rf "$TEMP_DIR"
}

@test "variables: CLI --debug flag works" {
    run "$SCRIPT_UNDER_TEST" --debug test.txt - << 'EOF'
1a
test content
.
w
q
EOF
    
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Edits applied to a temporary preview" ]]
    [[ "$output" =~ "Debug mode: executing ed" ]]
    [[ "$output" =~ "Edits applied to a temporary preview" ]]
}


@test "variables: environment variable EED_DEBUG works" {
    run env EED_DEBUG=true "$SCRIPT_UNDER_TEST" test.txt - << 'EOF'
1a
test content
.
w
q
EOF
    
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Edits applied to a temporary preview" ]]
    [[ "$output" =~ "Debug mode: executing ed" ]]
    [[ "$output" =~ "Edits applied to a temporary preview" ]]
}


@test "variables: CLI flag overrides environment variable" {
    # Set EED_DEBUG=false but use CLI --debug flag
    run env EED_DEBUG=false "$SCRIPT_UNDER_TEST" --debug test.txt - << 'EOF'
1a
test content
.
w
q
EOF
    
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Edits applied to a temporary preview" ]]
    [[ "$output" =~ "Debug mode: executing ed" ]]  # CLI flag should win
    [[ "$output" =~ "Edits applied to a temporary preview" ]]
}



@test "variables: disable auto reorder flag works" {
    # Create a multi-line file for this test
    echo -e "line1\nline2\nline3" > multi_test.txt
    
    run env EED_DEBUG=true "$SCRIPT_UNDER_TEST" --disable-auto-reorder multi_test.txt - << 'EOF'
3d
1a
new content
.
w
q
EOF
    
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Edits applied to a temporary preview" ]]
    # Should not see reordering messages since it's disabled
    [[ ! "$output" =~ "Script reordered for safety" ]]
    [[ "$output" =~ "Edits applied to a temporary preview" ]]
}