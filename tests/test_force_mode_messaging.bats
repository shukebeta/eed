#!/usr/bin/env bats

# Test for force mode clear messaging (our UX improvement)

setup() {
    # Create unique test directory and switch into it
    TEST_DIR="$(mktemp -d)"
    cd "$TEST_DIR"

    # Use the repository eed executable directly
    REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
    SCRIPT_UNDER_TEST="$REPO_ROOT/eed"

    # Create sample file for testing
    cat > sample.txt << 'EOF'
line1
line2
line3
EOF
}

teardown() {
    cd /
    rm -rf "$TEST_DIR"
}

@test "force mode shows clear success message without confusing mv command" {
    # Test that --force mode shows clear message instead of confusing mv instruction
    run "$SCRIPT_UNDER_TEST" --force sample.txt "2c
new line2
.
w
q"
    [ "$status" -eq 0 ]

    # Should show clear force mode success message
    [[ "$output" == *"✨"* ]]

    # Should NOT show confusing mv command instruction
    [[ "$output" != *"💡 Applying changes: mv"* ]]
    [[ "$output" != *"mv 'sample.txt.eed.preview' 'sample.txt'"* ]]

    # File should be modified directly
    [[ "$(cat sample.txt)" == $'line1\nnew line2\nline3' ]]

    # Should not leave preview file
    [ ! -f sample.txt.eed.preview ]
}
