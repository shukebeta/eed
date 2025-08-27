#!/usr/bin/env bats

# Unit tests for eed validator functions
# Direct testing of classify_ed_script and validate_ed_script

setup() {
    # Determine repository root using BATS_TEST_DIRNAME
    REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"

    # Create unique test directory and switch into it
    TEST_DIR="$(mktemp -d)"
    cd "$TEST_DIR"

    # Load validator functions using absolute paths
    source "$REPO_ROOT/lib/eed_regex_patterns.sh"
    source "$REPO_ROOT/lib/eed_validator.sh"

    # Use the repository eed executable directly
    SCRIPT_UNDER_TEST="$REPO_ROOT/eed"

    # Prevent logging during tests
    export EED_TESTING=1
}

teardown() {
    cd /
    rm -rf "$TEST_DIR"
}

# Test classify_ed_script function directly

@test "classifier: simple view commands" {
    run classify_ed_script "p"
    [ "$status" -eq 0 ]
    [ "$output" = "view_only" ]

    run classify_ed_script ",p"
    [ "$status" -eq 0 ]
    [ "$output" = "view_only" ]

    run classify_ed_script "1,5p"
    [ "$status" -eq 0 ]
    [ "$output" = "view_only" ]
}

@test "classifier: search commands" {
    run classify_ed_script "/pattern/p"
    [ "$status" -eq 0 ]
    [ "$output" = "view_only" ]

    run classify_ed_script "g/test/p"
    [ "$status" -eq 0 ]
    [ "$output" = "view_only" ]

    run classify_ed_script "?backward?p"
    [ "$status" -eq 0 ]
    [ "$output" = "view_only" ]
}

@test "classifier: address arithmetic" {
    run classify_ed_script "/pattern/-1,/pattern/+1p"
    [ "$status" -eq 0 ]
    [ "$output" = "view_only" ]

    run classify_ed_script "/start/+2,/end/-1p"
    [ "$status" -eq 0 ]
    [ "$output" = "view_only" ]
}

@test "classifier: current line commands" {
    run classify_ed_script ".c"
    [ "$status" -eq 0 ]
    [ "$output" = "has_modifying" ]

    run classify_ed_script ".p"
    [ "$status" -eq 0 ]
    [ "$output" = "view_only" ]

    run classify_ed_script ".d"
    [ "$status" -eq 0 ]
    [ "$output" = "has_modifying" ]
}

@test "classifier: insert/append commands" {
    run classify_ed_script "3i"
    [ "$status" -eq 0 ]
    [ "$output" = "has_modifying" ]

    run classify_ed_script "5a"
    [ "$status" -eq 0 ]
    [ "$output" = "has_modifying" ]

    run classify_ed_script "a"
    [ "$status" -eq 0 ]
    [ "$output" = "has_modifying" ]
}

@test "classifier: delete commands" {
    run classify_ed_script "5d"
    [ "$status" -eq 0 ]
    [ "$output" = "has_modifying" ]

    run classify_ed_script "1,5d"
    [ "$status" -eq 0 ]
    [ "$output" = "has_modifying" ]

    run classify_ed_script ",d"
    [ "$status" -eq 0 ]
    [ "$output" = "has_modifying" ]
}

@test "classifier: substitute commands" {
    run classify_ed_script "s/old/new/"
    [ "$status" -eq 0 ]
    [ "$output" = "has_modifying" ]

    run classify_ed_script '1,$s/old/new/g'
    [ "$status" -eq 0 ]
    [ "$output" = "has_modifying" ]

    run classify_ed_script ".s/test/replacement/"
    [ "$status" -eq 0 ]
    [ "$output" = "has_modifying" ]
}

@test "classifier: write commands" {
    run classify_ed_script "w"
    [ "$status" -eq 0 ]
    [ "$output" = "has_modifying" ]

    run classify_ed_script "w filename"
    [ "$status" -eq 0 ]
    [ "$output" = "has_modifying" ]
}

@test "classifier: mixed scripts" {
    local mixed_script="$(cat <<'EOF'
/pattern/p
.c
new content
.
.p
w
q
EOF
)"
    run classify_ed_script "$mixed_script"
    [ "$status" -eq 0 ]
    [ "$output" = "has_modifying" ]
}

@test "classifier: complex view-only script" {
    local view_script="$(cat <<'EOF'
,p
1,5n
/test/p
g/pattern/p
=
q
EOF
)"
    run classify_ed_script "$view_script"
    [ "$status" -eq 0 ]
    [ "$output" = "view_only" ]
}

@test "classifier: invalid commands" {
    run classify_ed_script "invalid_command"
    [ "$status" -eq 0 ]
    [ "$output" = "invalid_command" ]

    run classify_ed_script "xyz123"
    [ "$status" -eq 0 ]
    [ "$output" = "invalid_command" ]

    # Test invalid multi-slash pattern (should not match search regex)
    run classify_ed_script "/abc/def/ghi/"
    [ "$status" -eq 0 ]
    [ "$output" = "invalid_command" ]
}

@test "classifier: script with input mode parsing" {
    local script_with_input="$(cat <<'EOF'
3a
inserted line 1
inserted line 2
.
w
q
EOF
)"
    run classify_ed_script "$script_with_input"
    [ "$status" -eq 0 ]
    [ "$output" = "has_modifying" ]
}

@test "classifier: empty script" {
    run classify_ed_script ""
    [ "$status" -eq 0 ]
    [ "$output" = "view_only" ]
}

# Test validate_ed_script function directly

@test "validator: valid script with q terminator" {
    run validate_ed_script "5d
w
q"
    [ "$status" -eq 0 ]
}

@test "validator: valid script with Q terminator" {
    run validate_ed_script "5d
Q"
    [ "$status" -eq 0 ]
}

@test "validator: script without terminator shows warning" {
    run validate_ed_script "5d
w"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Warning"* ]]
    [[ "$output" == *"does not end with 'q' or 'Q'"* ]]
}

@test "validator: empty script" {
    run validate_ed_script ""
    [ "$status" -eq 0 ]
    [[ "$output" == *"Warning: Empty ed script"* ]]
}

# Integration tests for edge cases

@test "classifier edge case: dollar sign in ranges" {
    run classify_ed_script '1,$s/old/new/g'
    [ "$status" -eq 0 ]
    [ "$output" = "has_modifying" ]

    run classify_ed_script '5,$p'
    [ "$status" -eq 0 ]
    [ "$output" = "view_only" ]
}

@test "classifier edge case: number-only ranges" {
    run classify_ed_script "1,10p"
    [ "$status" -eq 0 ]
    [ "$output" = "view_only" ]

    run classify_ed_script "5,20d"
    [ "$status" -eq 0 ]
    [ "$output" = "has_modifying" ]
}

@test "classifier robustness: whitespace and edge cases" {
    # Test with trailing spaces (shouldn't affect classification)
    run classify_ed_script "p "
    [ "$status" -eq 0 ]
    [ "$output" = "view_only" ]
}

@test "dot trap detection: normal ed commands not affected" {
    # Normal ed script with single dot should not trigger detection
    run detect_dot_trap "3c
new content
.
w
q"
    [ "$status" -eq 0 ]
}

@test "dot trap detection: simple script not flagged" {
    # Short script with normal ed operations should pass
    run detect_dot_trap "5d
w
q"
    [ "$status" -eq 0 ]
}

@test "dot trap detection: suspicious pattern detected" {
    # Complex script with multiple dots should trigger warning
    local script="3c
content line 1
.
5a
more content
.
7c
final content
.
w
q"
    run detect_dot_trap "$script"
    [ "$status" -ne 0 ]
    [[ "$output" == *"POTENTIAL_DOT_TRAP"* ]]
}

@test "dot trap guidance: provides helpful suggestions" {
    # Should provide clear guidance about heredoc usage
    local script="test script with multiple dots"
    # suggest_dot_fix is already loaded via setup(); call it directly
    run suggest_dot_fix "$script"
    [ "$status" -eq 0 ]
    [[ "$output" == *"consider using heredoc syntax"* ]]
    [[ "$output" == *". (dot) for content"* ]]
}

# --- Tests for detect_line_order_issue ---

@test "line order: ascending deletions should warn" {
    local script="$(printf '10d\n20d\n30d')"
    run detect_line_order_issue "$script"
    [ "$status" -eq 1 ]
    [[ "$output" == *"Detected operations on ascending line numbers (10,20,30)"* ]]
    [[ "$output" == *"Consider reordering: start from line (30,20,10)"* ]]
}

@test "line order: descending deletions should NOT warn" {
    local script="$(printf '30d\n20d\n10d')"
    run detect_line_order_issue "$script"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "line order: mixed operations with ascending modifying commands should warn" {
    local script="$(printf '5p\n10d\n15p\n20c\ncontent\n.\n25p')"
    run detect_line_order_issue "$script"
    [ "$status" -eq 1 ]
    [[ "$output" == *"ascending line numbers (10,20)"* ]]
    [[ "$output" == *"reordering: start from line (20,10)"* ]]
}

@test "line order: view-only commands should NOT warn" {
    local script="$(printf '10p\n20n\n30=')"
    run detect_line_order_issue "$script"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "line order: single modifying operation should NOT warn" {
    local script="$(printf '10d')"
    run detect_line_order_issue "$script"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "line order: ascending range operations should warn" {
    local script="$(printf '1,5d\n10,15s/old/new/')"
    run detect_line_order_issue "$script"
    [ "$status" -eq 1 ]
    [[ "$output" == *"ascending line numbers (1,10)"* ]]
    [[ "$output" == *"reordering: start from line (10,1)"* ]]
}

@test "line order: identical line numbers should NOT warn" {
    local script="$(printf '10d\n10i\nnew line\n.')"
    run detect_line_order_issue "$script"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "line order: unordered modifying commands should NOT warn" {
    local script="$(printf '10d\n30d\n20d')"
    run detect_line_order_issue "$script"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

# --- Tests for automatic reordering functionality ---

@test "auto reorder: ascending deletions get automatically reordered" {
    local script="$(printf '2d\n4d\nw\nq')"
    run reorder_script "$script"
    [ "$status" -eq 1 ]  # Signal that reordering was performed
    # Verify the reordered output contains commands in correct order
    [[ "$output" == *"4d"* ]]
    [[ "$output" == *"2d"* ]]
    [[ "$output" == *"w"* ]]
    [[ "$output" == *"q"* ]]
    # Check that 4d appears before 2d in the output
    local output_lines=()
    while IFS= read -r line; do output_lines+=("$line"); done <<< "$output"
    local pos_4d=-1 pos_2d=-1
    for i in "${!output_lines[@]}"; do
        [[ "${output_lines[$i]}" == "4d" ]] && pos_4d=$i
        [[ "${output_lines[$i]}" == "2d" ]] && pos_2d=$i
    done
    [ "$pos_4d" -lt "$pos_2d" ]  # 4d should come before 2d
}

@test "auto reorder: complex mixed operations (1d, 5a, 9c)" {
    # Test ascending line numbers that need reordering: 1d, 5a, 9c → 9c, 5a, 1d
    local script="$(printf '1d\n5a\nappended line\n.\n9c\nnew content\n.\nw\nq')"
    run reorder_script "$script"
    [ "$status" -eq 1 ]  # Reordering performed
    # Should reorder modifying commands by line number descending: 9c, 5a, 1d
    local output_lines=()
    while IFS= read -r line; do output_lines+=("$line"); done <<< "$output"
    local pos_9c=-1 pos_5a=-1 pos_1d=-1
    for i in "${!output_lines[@]}"; do
        [[ "${output_lines[$i]}" == "9c" ]] && pos_9c=$i
        [[ "${output_lines[$i]}" == "5a" ]] && pos_5a=$i
        [[ "${output_lines[$i]}" == "1d" ]] && pos_1d=$i
    done
    [ "$pos_9c" -lt "$pos_5a" ]  # 9c should come before 5a
    [ "$pos_5a" -lt "$pos_1d" ]  # 5a should come before 1d

    # Verify content preservation for input commands
    [[ "$output" == *"appended line"* ]]
    [[ "$output" == *"new content"* ]]
}

@test "auto reorder: no reordering needed for descending commands" {
    local script="$(printf '4d\n2d\nw\nq')"
    run reorder_script "$script"
    [ "$status" -eq 0 ]  # No reordering needed
    # Output should be identical to input
    [ "$output" = "$script" ]
}

@test "auto reorder: preserve non-modifying commands in original positions" {
    local script="$(printf '1p\n2d\n3p\n4d\n5p\nw\nq')"
    run reorder_script "$script"
    [ "$status" -eq 1 ]  # Reordering performed
    # Should contain all original commands
    [[ "$output" == *"1p"* ]]
    [[ "$output" == *"3p"* ]]
    [[ "$output" == *"5p"* ]]
    [[ "$output" == *"4d"* ]]
    [[ "$output" == *"2d"* ]]
    [[ "$output" == *"w"* ]]
    [[ "$output" == *"q"* ]]
}

@test "auto reorder: complex multiline operations - append and delete ranges" {
    # Complex scenario: 15,20d (delete 6 lines), 8a (append 3 lines), 3,5d (delete 3 lines)
    # Should reorder to: 15,20d, 8a, 3,5d to prevent line shifting issues
    local script="$(printf '3,5d\n8a\nline 1 added\nline 2 added\nline 3 added\n.\n15,20d\nw\nq')"
    run reorder_script "$script"
    [ "$status" -eq 1 ]  # Reordering performed

    # Parse output to verify command order
    local output_lines=()
    while IFS= read -r line; do output_lines+=("$line"); done <<< "$output"

    # Find positions of key commands
    local pos_15_20d=-1 pos_8a=-1 pos_3_5d=-1
    for i in "${!output_lines[@]}"; do
        [[ "${output_lines[$i]}" == "15,20d" ]] && pos_15_20d=$i
        [[ "${output_lines[$i]}" == "8a" ]] && pos_8a=$i
        [[ "${output_lines[$i]}" == "3,5d" ]] && pos_3_5d=$i
    done

    # Verify correct ordering: higher line numbers first
    [ "$pos_15_20d" -lt "$pos_8a" ]  # 15,20d before 8a
    [ "$pos_8a" -lt "$pos_3_5d" ]    # 8a before 3,5d

    # Verify multiline append content is preserved with command
    [[ "$output" == *"8a"* ]]
    [[ "$output" == *"line 1 added"* ]]
    [[ "$output" == *"line 2 added"* ]]
    [[ "$output" == *"line 3 added"* ]]
}

@test "auto reorder: mixed operations with range deletes and single inserts" {
    # Scenario: 1,3d (delete range), 7c (change single), 10,15d (delete range), 20i (insert)
    # Expected order: 20i, 10,15d, 7c, 1,3d
    local script="$(printf '1,3d\n7c\nnew line 7\n.\n10,15d\n20i\ninserted at 20\n.\nw\nq')"
    run reorder_script "$script"
    [ "$status" -eq 1 ]  # Reordering performed

    local output_lines=()
    while IFS= read -r line; do output_lines+=("$line"); done <<< "$output"

    local pos_20i=-1 pos_10_15d=-1 pos_7c=-1 pos_1_3d=-1
    for i in "${!output_lines[@]}"; do
        [[ "${output_lines[$i]}" == "20i" ]] && pos_20i=$i
        [[ "${output_lines[$i]}" == "10,15d" ]] && pos_10_15d=$i
        [[ "${output_lines[$i]}" == "7c" ]] && pos_7c=$i
        [[ "${output_lines[$i]}" == "1,3d" ]] && pos_1_3d=$i
    done

    # Verify descending line number order
    [ "$pos_20i" -lt "$pos_10_15d" ]
    [ "$pos_10_15d" -lt "$pos_7c" ]
    [ "$pos_7c" -lt "$pos_1_3d" ]

    # Verify content preservation
    [[ "$output" == *"new line 7"* ]]
    [[ "$output" == *"inserted at 20"* ]]
}


# Note: Complex pattern detection tests removed - behavior moved to unified architecture
# End-to-end complex pattern handling is tested in test_safety_override_integration.bats


@test "complex pattern detection: simple numeric patterns still allow reordering" {
    local script="$(printf '1d\n3d\n5d\nw\nq')"
    run reorder_script "$script"
    [ "$status" -eq 1 ]  # Reordering performed - no complex patterns detected
    # Should be reordered to 5d, 3d, 1d
    local output_lines=()
    while IFS= read -r line; do output_lines+=("$line"); done <<< "$output"
    local pos_5d=-1 pos_3d=-1 pos_1d=-1
    for i in "${!output_lines[@]}"; do
        [[ "${output_lines[$i]}" == "5d" ]] && pos_5d=$i
        [[ "${output_lines[$i]}" == "3d" ]] && pos_3d=$i
        [[ "${output_lines[$i]}" == "1d" ]] && pos_1d=$i
    done
    [ "$pos_5d" -lt "$pos_3d" ]
    [ "$pos_3d" -lt "$pos_1d" ]
}

@test "exclamation mark preservation: bash array syntax should not be escaped" {
    # Test that exclamation marks in bash array syntax are preserved correctly
    set +H  # Ensure history expansion is disabled in test
    local script=$(cat <<'EOF'
3a
echo "Array indices: ${!arr[@]}"
.
w
q
EOF
)
    run reorder_script "$script"
    [ "$status" -eq 0 ]  # No reordering needed for single command
    # Verify the exclamation mark is preserved (literal ${!arr[@]}) and not escaped like '\!'
    [[ "$output" == *'${!arr[@]}'* ]]
    [[ "$output" != *'\\!'* ]]
}

# Regex validation tests for complex pattern detection
@test "regex validation: g/v pattern matching" {
    # Should match (complex): g/v with modifying commands
    [[ "g/pattern/d" =~ $EED_REGEX_GV_MODIFYING ]]
    [[ "v/test/c" =~ $EED_REGEX_GV_MODIFYING ]]
    [[ "g/func/s" =~ $EED_REGEX_GV_MODIFYING ]]

    # Should NOT match (safe): g/v with view commands
    ! [[ "g/pattern/p" =~ $EED_REGEX_GV_MODIFYING ]]
    ! [[ "g/test/n" =~ $EED_REGEX_GV_MODIFYING ]]
    ! [[ "v/func/" =~ $EED_REGEX_GV_MODIFYING ]]
}

@test "regex validation: non-numeric address matching" {
    # Should match (complex): non-numeric with modifying commands
    [[ "/pattern/d" =~ $EED_REGEX_NON_NUMERIC_MODIFYING ]]
    [[ ".d" =~ $EED_REGEX_NON_NUMERIC_MODIFYING ]]
    [[ "?search?c" =~ $EED_REGEX_NON_NUMERIC_MODIFYING ]]

    # Should NOT match (safe): non-numeric with view commands
    ! [[ "/pattern/p" =~ $EED_REGEX_NON_NUMERIC_MODIFYING ]]
    ! [[ ".p" =~ $EED_REGEX_NON_NUMERIC_MODIFYING ]]
    ! [[ "?search?" =~ $EED_REGEX_NON_NUMERIC_MODIFYING ]]
}

@test "regex validation: offset address matching" {
    # Should match (complex): offset with modifying commands
    [[ ".-5d" =~ $EED_REGEX_OFFSET_MODIFYING ]]
    [[ "$+3c" =~ $EED_REGEX_OFFSET_MODIFYING ]]
    [[ ".-2,.+2s" =~ $EED_REGEX_OFFSET_MODIFYING ]]

    # Should NOT match (safe): offset with view commands
    ! [[ ".-5p" =~ $EED_REGEX_OFFSET_MODIFYING ]]
    ! [[ "$-3,$p" =~ $EED_REGEX_OFFSET_MODIFYING ]]
    ! [[ ".+5" =~ $EED_REGEX_OFFSET_MODIFYING ]]
}

# Improved complex pattern detection tests
@test "improved detection: g/pattern/p with simple deletes should allow reordering" {
    local script="$(printf 'g/function/p\n1d\n5d\nw\nq')"
    run reorder_script "$script"
    [ "$status" -eq 1 ]  # Reordering performed - g/pattern/p is safe
    # Should be reordered to 5d, 1d
    local output_lines=()
    while IFS= read -r line; do output_lines+=("$line"); done <<< "$output"
    local pos_5d=-1 pos_1d=-1
    for i in "${!output_lines[@]}"; do
        [[ "${output_lines[$i]}" == "5d" ]] && pos_5d=$i
        [[ "${output_lines[$i]}" == "1d" ]] && pos_1d=$i
    done
    [ "$pos_5d" -lt "$pos_1d" ]
}

@test "improved detection: /pattern/p with simple deletes should allow reordering" {
    local script="$(printf '/function/p\n1d\n5d\nw\nq')"
    run reorder_script "$script"
    [ "$status" -eq 1 ]  # Reordering performed - /pattern/p is safe
    # Should be reordered to 5d, 1d
    local output_lines=()
    while IFS= read -r line; do output_lines+=("$line"); done <<< "$output"
    local pos_5d=-1 pos_1d=-1
    for i in "${!output_lines[@]}"; do
        [[ "${output_lines[$i]}" == "5d" ]] && pos_5d=$i
        [[ "${output_lines[$i]}" == "1d" ]] && pos_1d=$i
    done
    [ "$pos_5d" -lt "$pos_1d" ]
}

@test "improved detection: offset address print with simple deletes should allow reordering" {
    local script="$(printf '$-5,$p\n1d\n5d\nw\nq')"
    run reorder_script "$script"
    [ "$status" -eq 1 ]  # Reordering performed - $-5,$p is safe
    # Should be reordered to 5d, 1d
    local output_lines=()
    while IFS= read -r line; do output_lines+=("$line"); done <<< "$output"
    local pos_5d=-1 pos_1d=-1
    for i in "${!output_lines[@]}"; do
        [[ "${output_lines[$i]}" == "5d" ]] && pos_5d=$i
        [[ "${output_lines[$i]}" == "1d" ]] && pos_1d=$i
    done
    [ "$pos_5d" -lt "$pos_1d" ]
}

@test "improved detection: g/pattern/d should still be detected as complex" {
    local script="$(printf 'g/function/d\n1d\n5d\nw\nq')"
    # Test the unified architecture: detect_complex_patterns should identify this as complex
    run detect_complex_patterns "$script" 2>/dev/null
    [ "$status" -ne 0 ]  # Complex pattern detected (returns non-zero)
}

@test "improved detection: non-numeric address with delete should still be detected as complex" {
    local script="$(printf '/pattern/d\n1d\n5d\nw\nq')"
    # Test the unified architecture: detect_complex_patterns should identify this as complex
    run detect_complex_patterns "$script" 2>/dev/null
    [ "$status" -ne 0 ]  # Complex pattern detected (returns non-zero)
}

@test "improved detection: offset address with delete should still be detected as complex" {
    local script="$(printf '.-5,.+5d\n1d\n5d\nw\nq')"
    run detect_complex_patterns "$script" 2>/dev/null
    [ "$status" -ne 0 ]  # Complex pattern detected (returns non-zero)
    
    # Verify reorder_script still reorders the numeric parts (that's its job)
    run reorder_script "$script"
    [ "$status" -eq 1 ]  # Reordering was performed (1d,5d -> 5d,1d)
    [[ "$output" == *".-5,.+5d"* ]]
    [[ "$output" == *"1d"* ]]
    [[ "$output" == *"5d"* ]]
}


# Git add reminder tests
@test "git add reminder: --force mode shows git add suggestion" {
    local test_file="$TEST_DIR/reminder_test.txt"
    echo "original content" > "$test_file"

    # Ensure this temp directory is a git working tree so eed prints the git add suggestion
    git init >/dev/null 2>&1 || true

    run $SCRIPT_UNDER_TEST --force "$test_file" "1c
new content
.
w
q"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Successfully edited"* ]]
    # Match any git add suggestion text produced by eed
    [[ "$output" == *"git add"* ]]
    [[ "$output" == *"reminder_test.txt"* ]]
}

@test "classifier: G老师's edge case concerns verification" {
    # Verify that the exact cases G老师 was worried about work correctly
    run classify_ed_script "5p"
    [ "$status" -eq 0 ]
    [ "$output" = "view_only" ]

    run classify_ed_script "5d"
    [ "$status" -eq 0 ]
    [ "$output" = "has_modifying" ]

    run classify_ed_script "1,5p"
    [ "$status" -eq 0 ]
    [ "$output" = "view_only" ]

    run classify_ed_script "1,5d"
    [ "$status" -eq 0 ]
    [ "$output" = "has_modifying" ]

    # Test substitute commands that were concerns
    run classify_ed_script "1,\$s/old/new/g"
    [ "$status" -eq 0 ]
    [ "$output" = "has_modifying" ]
}

@test "git add reminder: preview mode does not show git add suggestion" {
    local test_file="$TEST_DIR/preview_test.txt"
    echo "original content" > "$test_file"

    run $SCRIPT_UNDER_TEST "$test_file" "1c
new content
.
w
q"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Edits applied to a temporary preview"* ]]
    [[ "$output" != *"git add"* ]]
}
