#!/usr/bin/env bats

# Integration tests focusing on auto-fix functionality in eed workflow

setup() {
    # Determine repository root using BATS_TEST_DIRNAME
    REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"

    # Create temporary test file
    TEST_FILE=$(mktemp)
    echo "test content" > "$TEST_FILE"
}

teardown() {
    # Clean up temporary files
    [ -f "$TEST_FILE" ] && rm -f "$TEST_FILE"
    [ -f "${TEST_FILE}.eed.preview" ] && rm -f "${TEST_FILE}.eed.preview" || true
}

@test "integration: auto-fix triggers for single unescaped slash pattern" {
    # Test that eed detects and auto-fixes single pattern
    run bash -c "cd '$REPO_ROOT' && timeout 5s ./eed '$TEST_FILE' - <<'EOF' || true
/foo/bar/c
content
.
q
EOF"

    # Verify auto-fix messages appear (core functionality)
    [[ "$output" == *"🔧 Auto-fixed unescaped slashes: /foo/bar/c → /foo\/bar/c"* ]]
    [[ "$output" == *"✅ Successfully auto-fixed ed script syntax"* ]]
}

@test "integration: auto-fix triggers for range unescaped slash pattern" {
    # Test that eed detects and auto-fixes range pattern
    run bash -c "cd '$REPO_ROOT' && timeout 5s ./eed '$TEST_FILE' - <<'EOF' || true
/start/path/,/end/path/c
content
.
q
EOF"

    # Verify auto-fix messages appear (core functionality)
    [[ "$output" == *"🔧 Auto-fixed unescaped slashes: /start/path/,/end/path/c → /start\/path/,/end\/path/c"* ]]
    [[ "$output" == *"✅ Successfully auto-fixed ed script syntax"* ]]
}

@test "integration: no auto-fix for valid patterns" {
    # Test that valid patterns don't trigger auto-fix
    run bash -c "cd '$REPO_ROOT' && timeout 5s ./eed '$TEST_FILE' - <<'EOF' || true
/valid/c
content
.
q
EOF"

    # Should NOT contain auto-fix messages
    [[ "$output" != *"🔧 Auto-fixed unescaped slashes"* ]]
    [[ "$output" != *"✅ Successfully auto-fixed ed script syntax"* ]]
}

@test "integration: multiple patterns get fixed in one script" {
    # Test multiple fixes in single script
    run bash -c "cd '$REPO_ROOT' && timeout 5s ./eed '$TEST_FILE' - <<'EOF' || true
/first/pattern/c
content1
.
/second/pattern/d
q
EOF"

    # Should show multiple fix messages
    [[ "$output" == *"🔧 Auto-fixed unescaped slashes: /first/pattern/c"* ]]
    [[ "$output" == *"🔧 Auto-fixed unescaped slashes: /second/pattern/d"* ]]
    [[ "$output" == *"✅ Successfully auto-fixed ed script syntax"* ]]
}

@test "integration: original user case auto-fixes correctly" {
    # Test the exact problematic case from user
    run bash -c "cd '$REPO_ROOT' && timeout 5s ./eed '$TEST_FILE' - <<'EOF' || true
//// Gets the earliest value date acceptable to two TRM's after a specified minimum value date/c
replacement
.
q
EOF"

    # Verify the specific fix
    [[ "$output" == *"🔧 Auto-fixed unescaped slashes"* ]]
    [[ "$output" == *"/\/\/\/ Gets the earliest value date acceptable to two TRM's after a specified minimum value date/c"* ]]
    [[ "$output" == *"✅ Successfully auto-fixed ed script syntax"* ]]
}