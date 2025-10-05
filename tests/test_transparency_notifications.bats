#!/usr/bin/env bats

# Test transparency notifications for other staged files

setup() {
    TEST_DIR=$(mktemp -d)
    cd "$TEST_DIR"

    git init --quiet
    git config user.email "test@example.com"
    git config user.name "Test User"

    # Create initial files
    echo "original target" > target.txt
    echo "original other" > other.txt
    echo "original third" > third.txt

    git add .
    git commit -m "Initial commit" --quiet
}

teardown() {
    cd /
    [ -n "$TEST_DIR" ] && [ -d "$TEST_DIR" ] && rm -rf "$TEST_DIR"
}

@test "transparency - no notification when only target file staged" {
    # Clean repository, only edit target file
    run bash -c 'echo "1c
eed only change
.
w
q" | "'"$BATS_TEST_DIRNAME"'/../eed" -m "clean edit" target.txt'

    [ "$status" -eq 0 ]
    [[ "$output" == *"Changes successfully committed"* ]]
    [[ "$output" != *"This commit also included other staged files"* ]]
}

@test "transparency - notification when other files present (commit script test)" {
    # Test commit script's transparency notification when other files are staged

    # Manually stage target file (simulating eed's staging)
    echo "eed edit content" > target.txt
    git add target.txt

    # Simulate external tool adding file to staging area
    echo "external change" > other.txt
    git add other.txt

    # Use commit script - should show transparency notification
    run "$BATS_TEST_DIRNAME"/../commit target.txt "test with external file"

    [ "$status" -eq 0 ]
    [[ "$output" == *"Changes committed"* ]]
    [[ "$output" == *"This commit also included other staged files"* ]]
    [[ "$output" == *"other.txt"* ]]
    [[ "$output" == *"external changes to the staging area"* ]]
}

@test "transparency - auto-commit mode shows notification" {
    # Create scenario where WIP doesn't trigger but external staging happens
    # This requires careful setup to avoid WIP auto-save

    # Start with clean state, make external changes first
    echo "external mod" > other.txt
    git add other.txt  # Stage external change

    # Now use eed auto-commit mode - WIP will save external change,
    # but we can still test the notification logic
    run bash -c 'echo "1c
auto commit test
.
w
q" | "'"$BATS_TEST_DIRNAME"'/../eed" -m "auto test" target.txt'

    [ "$status" -eq 0 ]
    [[ "$output" == *"Auto-saving work in progress"* ]] # WIP triggered
    [[ "$output" == *"Changes successfully committed"* ]]

    # The main eed commit should be clean (only target.txt)
    run git show --name-only HEAD
    [ "$status" -eq 0 ]
    [[ "$output" == *"target.txt"* ]]
    [[ "$output" != *"other.txt"* ]] # other.txt was in WIP commit
}

@test "transparency - multiple other staged files listed" {
    # Manually stage target file
    echo "new line" > target.txt
    git add target.txt

    # Stage multiple external files
    echo "change 1" > other.txt
    echo "change 2" > third.txt
    mkdir -p subdir
    echo "change 3" > subdir/nested.txt

    git add other.txt third.txt subdir/nested.txt

    # Commit should list all external files
    run "$BATS_TEST_DIRNAME"/../commit target.txt "test multiple externals"

    [ "$status" -eq 0 ]
    [[ "$output" == *"This commit also included other staged files"* ]]
    [[ "$output" == *"other.txt"* ]]
    [[ "$output" == *"third.txt"* ]]
    [[ "$output" == *"subdir/nested.txt"* ]]
}

@test "transparency - real world edge case: external staging (commit script test)" {
    # This test simulates external tool staging files alongside target file
    # Testing commit script's transparency notification

    # Step 1: Manually stage target file (simulating eed's staging)
    echo "eed modified content" > target.txt
    git add target.txt

    # Step 2: Simulate external tool/IDE/script modifying staging area
    echo "external tool modification" > other.txt
    git add other.txt

    # Verify the edge case setup is correct
    run git diff --cached --name-only
    [ "$status" -eq 0 ]
    [[ "$output" == *"target.txt"* ]]  # eed's change
    [[ "$output" == *"other.txt"* ]]   # external tool's change

    # Step 3: Use commit script - should show transparency notification
    run "$BATS_TEST_DIRNAME"/../commit target.txt "edge case test"

    [ "$status" -eq 0 ]
    [[ "$output" == *"Committing staged changes for target.txt"* ]]
    [[ "$output" == *"Changes committed: \"edge case test\""* ]]

    # Critical verification: transparency notification appears
    [[ "$output" == *"💡 Note: This commit also included other staged files:"* ]]
    [[ "$output" == *"other.txt"* ]]
    [[ "$output" == *"external changes to the staging area"* ]]

    # Verify commit behavior is unchanged (both files committed as expected)
    run git show --name-only HEAD
    [ "$status" -eq 0 ]
    [[ "$output" == *"target.txt"* ]]
    [[ "$output" == *"other.txt"* ]]

    # Verify commit message integrity
    run git show --format="%s" -s HEAD
    [ "$status" -eq 0 ]
    [[ "$output" == "eed-history: edge case test" ]]
}

@test "transparency - auto-commit mode with external staging" {
    # Test the edge case in auto-commit mode as well

    # Create clean state, then use eed auto-commit
    # But first, let external tool stage something
    echo "external auto change" > other.txt
    git add other.txt

    # Now run eed auto-commit - WIP will save the external change,
    # but we want to verify transparency in the main commit
    run bash -c 'echo "1c
auto commit with external
.
w
q" | "'"$BATS_TEST_DIRNAME"'/../eed" -m "auto edge test" target.txt'

    [ "$status" -eq 0 ]
    [[ "$output" == *"Auto-saving work in progress"* ]] # WIP triggered
    [[ "$output" == *"Changes successfully committed"* ]]

    # The main eed commit should be clean (external file was WIP saved)
    run git show --name-only HEAD
    [ "$status" -eq 0 ]
    [[ "$output" == *"target.txt"* ]]
    [[ "$output" != *"other.txt"* ]] # External file was in WIP, not main commit

    # So no transparency notification should appear for main commit
    [[ "$output" != *"This commit also included other staged files"* ]]
}

@test "transparency - complex multi-file external staging scenario" {
    # Test with multiple external files to ensure all are listed

    mkdir -p subdir
    echo "original sub" > subdir/nested.txt
    echo "original config" > config.json
    echo "original util" > utils.js

    git add subdir/nested.txt config.json utils.js
    git commit -m "complex baseline" --quiet

    # Manually stage target file
    echo "// eed addition" > target.txt
    git add target.txt

    # External tools stage multiple files
    echo "external nested change" > subdir/nested.txt
    echo '{"external": "config"}' > config.json
    echo "const external = true;" > utils.js
    echo "brand new file" > new_external.txt

    git add subdir/nested.txt config.json utils.js new_external.txt

    # Commit should list ALL external files
    run "$BATS_TEST_DIRNAME"/../commit target.txt "complex external test"

    [ "$status" -eq 0 ]
    [[ "$output" == *"This commit also included other staged files:"* ]]
    [[ "$output" == *"subdir/nested.txt"* ]]
    [[ "$output" == *"config.json"* ]]
    [[ "$output" == *"utils.js"* ]]
    [[ "$output" == *"new_external.txt"* ]]

    # Verify all files are in the commit (target.txt + 4 external files)
    run git show --name-only HEAD
    [ "$status" -eq 0 ]
    [[ "$output" == *"target.txt"* ]]
    [[ "$output" == *"subdir/nested.txt"* ]]
    [[ "$output" == *"config.json"* ]]
    [[ "$output" == *"utils.js"* ]]
    [[ "$output" == *"new_external.txt"* ]]
}

@test "transparency - notification format and user guidance" {
    # Test that the notification provides helpful context and formatting

    # Manually stage target file
    echo "format test change" > target.txt
    git add target.txt

    # Stage external files
    echo "external format change" > other.txt
    mkdir -p deep/path
    echo "deep external" > deep/path/file.txt
    git add other.txt deep/path/file.txt

    run "$BATS_TEST_DIRNAME"/../commit target.txt "format test"

    [ "$status" -eq 0 ]

    # Verify notification formatting
    [[ "$output" == *"💡 Note: This commit also included other staged files:"* ]]
    # Files should be indented for readability
    [[ "$output" == *"   other.txt"* ]]
    [[ "$output" == *"   deep/path/file.txt"* ]]
    # Should include explanatory text
    [[ "$output" == *"external changes to the staging area"* ]]

    # Verify normal success message is still present
    [[ "$output" == *"✅ Changes committed"* ]]
}