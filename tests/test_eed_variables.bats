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
    run "$SCRIPT_UNDER_TEST" --debug --force test.txt - << 'EOF'
1a
test content
.
w
q
EOF
    
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Debug mode: executing ed" ]]
}

@test "variables: CLI --force flag works" {
    run "$SCRIPT_UNDER_TEST" --debug --force test.txt - << 'EOF'
1a
test content
.
w
q
EOF
    
    
    [ "$status" -eq 0 ]
    [[ "$output" =~ "--force mode enabled" ]]
    [[ "$output" =~ "Changes applied successfully" ]]
}

@test "variables: environment variable EED_DEBUG works" {
    run env EED_DEBUG=true "$SCRIPT_UNDER_TEST" --force test.txt - << 'EOF'
1a
test content
.
w
q
EOF
    
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Debug mode: executing ed" ]]
}

@test "variables: environment variable EED_FORCE works" {
    run env EED_FORCE=true EED_DEBUG=true "$SCRIPT_UNDER_TEST" test.txt - << 'EOF'
1a
test content
.
w
q
EOF
    
    [ "$status" -eq 0 ]
    [[ "$output" =~ "--force mode enabled" ]]
    [[ "$output" =~ "Changes applied successfully" ]]
}

@test "variables: CLI flag overrides environment variable" {
    # Set EED_DEBUG=false but use CLI --debug flag
    run env EED_DEBUG=false "$SCRIPT_UNDER_TEST" --debug --force test.txt - << 'EOF'
1a
test content
.
w
q
EOF
    
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Debug mode: executing ed" ]]  # CLI flag should win
}

@test "variables: FORCE_OVERRIDE bypasses complex pattern detection" {
    # Create a complex script that would normally disable --force
    run env EED_FORCE_OVERRIDE=true EED_DEBUG=true "$SCRIPT_UNDER_TEST" --force test.txt - << 'EOF'
1,$s/test/replaced/g
w
q
EOF
    
    [ "$status" -eq 0 ]
    [[ "$output" =~ "FORCE_OVERRIDE enabled - bypassing all safety checks" ]]
    [[ "$output" =~ "Changes applied successfully" ]]
}


@test "variables: disable auto reorder flag works" {
    # Create a multi-line file for this test
    echo -e "line1\nline2\nline3" > multi_test.txt
    
    run env EED_DEBUG=true "$SCRIPT_UNDER_TEST" --disable-auto-reorder --force multi_test.txt - << 'EOF'
3d
1a
new content
.
w
q
EOF
    
    [ "$status" -eq 0 ]
    # Should not see reordering messages since it's disabled
    [[ ! "$output" =~ "Script reordered for safety" ]]
}