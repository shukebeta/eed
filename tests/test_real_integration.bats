#!/usr/bin/env bats

# Real integration tests for intelligent slash escaping
# These test the complete workflow from problematic input to successful file editing

setup() {
    REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
    TEST_FILE=$(mktemp)
}

teardown() {
    [ -f "$TEST_FILE" ] && rm -f "$TEST_FILE" || true
    [ -f "${TEST_FILE}.eed.preview" ] && rm -f "${TEST_FILE}.eed.preview" || true
}

@test "real integration: single pattern auto-fix works end-to-end" {
    # Create test file with content that will match after fixing
    echo "//123" > "$TEST_FILE"
    
    # Use problematic command that should be auto-fixed and then work
    run bash -c "cd '$REPO_ROOT' && ./eed '$TEST_FILE' <<'EOF'
///123/c
//124
.
wq
EOF"
    
    [ "$status" -eq 0 ]
    
    # Verify auto-fix occurred
    [[ "$output" == *"🔧 Auto-fixed unescaped slashes: ///123/c → /\/\/123/c"* ]]
    [[ "$output" == *"✅ Successfully auto-fixed ed script syntax"* ]]
    
    # Verify the edit actually worked - preview file should exist
    [ -f "${TEST_FILE}.eed.preview" ]
    
    # Verify the content was correctly changed
    grep -q "//124" "${TEST_FILE}.eed.preview"
    ! grep -q "//123" "${TEST_FILE}.eed.preview"
}

@test "real integration: range pattern auto-fix works end-to-end" {
    # Create test file with range content (matching the fixed pattern)
    cat > "$TEST_FILE" << 'EOF'
start: ////path
middle content
end: ////path
other content
EOF

    # Use problematic range command
    run bash -c "cd '$REPO_ROOT' && ./eed '$TEST_FILE' <<'EOF'
/start: ////path/,/end: ////path/c
RANGE REPLACED
.
wq
EOF"
    
    [ "$status" -eq 0 ]
    
    # Verify auto-fix occurred for range pattern
    [[ "$output" == *"🔧 Auto-fixed unescaped slashes"* ]]
    [[ "$output" == *"/start: \/\/\/\/path/,/end: \/\/\/\/path/c"* ]]
    [[ "$output" == *"✅ Successfully auto-fixed ed script syntax"* ]]
    
    # Verify the range edit worked
    [ -f "${TEST_FILE}.eed.preview" ]
    grep -q "RANGE REPLACED" "${TEST_FILE}.eed.preview"
    ! grep -q "middle content" "${TEST_FILE}.eed.preview"
    grep -q "other content" "${TEST_FILE}.eed.preview"
}

@test "real integration: multiple auto-fixes in one script work end-to-end" {
    # Create test file with multiple targets
    cat > "$TEST_FILE" << 'EOF'
first: ///target
some content
second: ///target  
more content
EOF

    # Use script with multiple problematic patterns
    run bash -c "cd '$REPO_ROOT' && ./eed '$TEST_FILE' <<'EOF'
/first: ///target/c
FIRST REPLACED
.
/second: ///target/c
SECOND REPLACED
.
wq
EOF"
    
    [ "$status" -eq 0 ]
    
    # Verify both auto-fixes occurred
    [[ "$output" == *"🔧 Auto-fixed unescaped slashes: /first: ///target/c"* ]]
    [[ "$output" == *"🔧 Auto-fixed unescaped slashes: /second: ///target/c"* ]]
    [[ "$output" == *"✅ Successfully auto-fixed ed script syntax"* ]]
    
    # Verify both edits worked
    [ -f "${TEST_FILE}.eed.preview" ]
    grep -q "FIRST REPLACED" "${TEST_FILE}.eed.preview"
    grep -q "SECOND REPLACED" "${TEST_FILE}.eed.preview"
    ! grep -q "first: //target" "${TEST_FILE}.eed.preview"
    ! grep -q "second: //target" "${TEST_FILE}.eed.preview"
}

@test "real integration: force mode with auto-fix works end-to-end" {
    # Test auto-fix with direct file modification
    echo "///test" > "$TEST_FILE"
    
    run bash -c "cd '$REPO_ROOT' && ./eed --force '$TEST_FILE' <<'EOF'
///test/c
//modified
.
wq
EOF"
    
    [ "$status" -eq 0 ]
    
    # Verify auto-fix occurred
    [[ "$output" == *"🔧 Auto-fixed unescaped slashes: ///test/c → /\/\/test/c"* ]]
    [[ "$output" == *"✅ Successfully auto-fixed ed script syntax"* ]]
    
    # Single search pattern is not complex, so force mode should work
    # Force mode creates preview then auto-moves it, so file is directly modified
    [ ! -f "${TEST_FILE}.eed.preview" ]  # Preview file should be auto-moved
    grep -q "//modified" "$TEST_FILE"    # Changes should be in the real file
    ! grep -q "///test" "$TEST_FILE"     # Original content should be gone
}

@test "real integration: original user case works completely" {
    # Recreate the exact original user scenario
    cat > "$TEST_FILE" << 'EOF'
/// Gets the earliest value date acceptable to two TRM's after a specified minimum value date
public DateTime GetEarliestValueDate()
{
    return DateTime.Today;
}

/// This is value date to use for the broker contracts
public DateTime GetBrokerValueDate()
{
    return DateTime.Today.AddDays(1);
}

/// <param name="liquidityManager">Whether or not this is for Ria Rails</param>
public void ProcessLiquidity(bool liquidityManager)
{
    // Implementation here
}
EOF

    # Use the exact original failing command
    run bash -c "cd '$REPO_ROOT' && ./eed '$TEST_FILE' <<'EOF'
//// Gets the earliest value date acceptable to two TRM's after a specified minimum value date/c
        /// Calculate the AIB2B broker-ticket value date acceptable to two TRMs after a specified minimum date.
.
//// This is value date to use for the broker contracts/c
        /// For AIB2B broker contracts: always uses TRM cut-offs (never Ria) ensuring fund-flow safety.
.
//// <param name=\"liquidityManager\">Whether or not this is for Ria Rails<\/param>/d
wq
EOF"
    
    [ "$status" -eq 0 ]
    
    # Verify all three auto-fixes occurred
    [[ "$output" == *"🔧 Auto-fixed unescaped slashes"* ]]
    [[ "$output" == *"✅ Successfully auto-fixed ed script syntax"* ]]
    
    # Verify the complete editing worked
    [ -f "${TEST_FILE}.eed.preview" ]
    
    # Check all three changes were applied
    grep -q "Calculate the AIB2B broker-ticket" "${TEST_FILE}.eed.preview"
    grep -q "For AIB2B broker contracts" "${TEST_FILE}.eed.preview" 
    ! grep -q "liquidityManager.*Ria Rails" "${TEST_FILE}.eed.preview"
    
    # Verify the structure is preserved
    grep -q "public DateTime GetEarliestValueDate" "${TEST_FILE}.eed.preview"
    grep -q "public DateTime GetBrokerValueDate" "${TEST_FILE}.eed.preview"
    grep -q "public void ProcessLiquidity" "${TEST_FILE}.eed.preview"
}