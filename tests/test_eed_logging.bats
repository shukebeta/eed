#!/usr/bin/env bats
# Test suite for eed logging functionality

setup() {
    REPO_ROOT="$BATS_TEST_DIRNAME/.."
    SCRIPT_UNDER_TEST="$REPO_ROOT/eed"
    TEMP_DIR=$(mktemp -d)
    cd "$TEMP_DIR" || exit
    
    # Create a temporary log file for testing
    TEMP_LOG_FILE="$TEMP_DIR/test_log.txt"
}

teardown() {
    cd /
    rm -rf "$TEMP_DIR"
}

@test "logging: records meaningful ed commands" {
    echo "test file" > test.txt
    
    # Use heredoc to avoid shell escaping issues
    run bash -c "source '$REPO_ROOT/lib/eed_common.sh' && log_ed_commands \$'1a\\nHello\\n.\\nw\\nq' '$TEMP_LOG_FILE'"
    [ "$status" -eq 0 ]
    
    # Should record the append command but not boilerplate
    run cat "$TEMP_LOG_FILE"
    [[ "$output" =~ "1a" ]]           # Should record the append command
    [[ ! "$output" =~ "Hello" ]]      # Should NOT record content data
    [[ ! "$output" =~ " w " ]]        # Should NOT record write command
    [[ ! "$output" =~ " q " ]]        # Should NOT record quit command
    [[ ! "$output" =~ " . " ]]        # Should NOT record terminator
}

@test "logging: handles complex operations correctly" {
    # Test with a simpler approach - create the script content explicitly
    SCRIPT_CONTENT="2c
replaced line
.
1,3d
w
q"
    
    run bash -c "source '$REPO_ROOT/lib/eed_common.sh' && log_ed_commands '$SCRIPT_CONTENT' '$TEMP_LOG_FILE'"
    [ "$status" -eq 0 ]
    
    run cat "$TEMP_LOG_FILE"
    [[ "$output" =~ "2c" ]]           # Should record change command
    [[ "$output" =~ "1,3d" ]]         # Should record delete range command
    [[ ! "$output" =~ "replaced line" ]] # Should NOT record content data
}

@test "logging: uses default log file when no parameter provided" {
    # This test verifies backward compatibility but doesn't pollute user's actual log
    echo "test" > test.txt
    
    # Test that function accepts single parameter (uses default)
    run bash -c "source '$REPO_ROOT/lib/eed_common.sh' && log_ed_commands '1d'"
    [ "$status" -eq 0 ]
    
    # We can't easily test the actual default file writing without pollution
    # so we just verify the function call succeeds
}

@test "logging: detailed step by step analysis" {
    # Create the exact script that was problematic
    SCRIPT_CONTENT="2c
replaced line
.
1,3d
w
q"
    
    run bash -c "source '$REPO_ROOT/lib/eed_common.sh' && log_ed_commands '$SCRIPT_CONTENT' '$TEMP_LOG_FILE'"
    [ "$status" -eq 0 ]
    
    run cat "$TEMP_LOG_FILE"
    [[ "$output" =~ "2c" ]]           # Should record change command
    [[ "$output" =~ "1,3d" ]]         # Should record delete range command
    [[ ! "$output" =~ "replaced line" ]] # Should NOT record content data
    
    # Verify we have exactly 2 log entries
    LOG_LINE_COUNT=$(wc -l < "$TEMP_LOG_FILE")
    [ "$LOG_LINE_COUNT" -eq 2 ]
}