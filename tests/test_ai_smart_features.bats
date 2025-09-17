#!/usr/bin/env bats

# AI-Oriented Integration Tests: Smart Features
# Tests auto-reordering, smart dot protection, and complex pattern detection

setup() {
    # Determine repository root using BATS_TEST_DIRNAME
    REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"

    # Create unique test directory and switch into it
    TEST_DIR="$(mktemp -d)"
    cd "$TEST_DIR"

    # Use the repository eed executable directly
    SCRIPT_UNDER_TEST="$REPO_ROOT/eed"

    # Prevent logging during tests
    export EED_TESTING=true

    # Create sample files for testing
    cat > code.js << 'EOF'
function example() {
    console.log("line 1");
    console.log("line 2"); 
    console.log("line 3");
    return true;
}
EOF

    cat > tutorial.md << 'EOF'
# Ed Tutorial

Here's how to use ed:

```
ed myfile.txt
1a
Hello World
.
w
q
```

The dot (.) terminates input mode.
EOF
}

teardown() {
    cd /
    rm -rf "$TEST_DIR"
}

@test "auto-reordering - ascending line numbers get reordered" {
    # AI provides commands in ascending order (dangerous)
    run "$SCRIPT_UNDER_TEST" code.js "2d
3d
4d
w
q"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Edits applied to a temporary preview" ]]
    
    # Should show reordering message
    [[ "$output" == *"Auto-reordering script to prevent line numbering conflicts"* ]]
    [[ "$output" == *"Original: (2,3,4) → Reordered: (4,3,2)"* ]]
    
    # Preview file created
    [ -f code.js.eed.preview ]
    
    # Preview file should contain the changes (lines 2,3,4 deleted)
    run grep -q "line 2" code.js.eed.preview
    [ "$status" -ne 0 ]
    run grep -q "line 3" code.js.eed.preview  
    [ "$status" -ne 0 ]
    
    # Original file remains unchanged (preview mode)
    run grep -q "line 2" code.js
    [ "$status" -eq 0 ]
    run grep -q "line 3" code.js
    [ "$status" -eq 0 ]
}

@test "auto-reordering - reordering occurs in preview mode" {
    # AI provides commands in ascending order that need reordering
    run "$SCRIPT_UNDER_TEST" code.js "1d
2d
3d
w
q"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Edits applied to a temporary preview" ]]
    
    # Should show reordering message
    [[ "$output" == *"Auto-reordering script to prevent line numbering conflicts"* ]]
    
    # Should create preview file
    [ -f code.js.eed.preview ]
    
    # Original file should be unchanged (preview mode)
    run grep -q "line 1" code.js
    [ "$status" -eq 0 ]
    run grep -q "line 2" code.js
    [ "$status" -eq 0 ]
}

@test "auto-reordering - correct order requires no reordering" {
    # AI provides commands in descending order (safe)
    run "$SCRIPT_UNDER_TEST" code.js "4d
3d
2d
w
q"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Edits applied to a temporary preview" ]]
    
    # Should NOT show reordering message
    [[ "$output" != *"Auto-reordering script"* ]]
    
    # Changes should be applied in preview file (no reordering needed)
    run grep -q "line 2" code.js.eed.preview
    [ "$status" -ne 0 ]
    run grep -q "line 3" code.js.eed.preview  
    [ "$status" -ne 0 ]
    
    # Original file unchanged
    run grep -q "line 2" code.js
    [ "$status" -eq 0 ]
    run grep -q "line 3" code.js
    [ "$status" -eq 0 ]
}

@test "smart dot protection - tutorial content editing" {
    # AI edits tutorial content with multiple dots
    run "$SCRIPT_UNDER_TEST" tutorial.md "7a
2a
New content
.
3i
More content
.
.
w
q"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Edits applied to a temporary preview" ]]
    
    # Should show smart protection message
    [[ "$output" == *"Smart dot protection applied"* ]]
    
    # Should process successfully despite multiple dots
    [ -f tutorial.md.eed.preview ]
}

