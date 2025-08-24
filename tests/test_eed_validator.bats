#!/usr/bin/env bats

# Unit tests for eed validator functions
# Direct testing of classify_ed_script and validate_ed_script

setup() {
    TEST_DIR="$(mktemp -d)"
    cd "$TEST_DIR"

    # Load validator functions
    source "/home/davidwei/Projects/pkb/bin/lib/eed_validator.sh"

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

    run classify_ed_script "1,\$s/old/new/g"
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
    run classify_ed_script "1,\$s/old/new/g"
    [ "$status" -eq 0 ]
    [ "$output" = "has_modifying" ]

    run classify_ed_script "5,\$p"
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
    run bash -c 'source /home/davidwei/Projects/pkb/bin/lib/eed_validator.sh && suggest_dot_fix "$1"' _ "$script"
    [ "$status" -eq 0 ]
    [[ "$output" == *"consider using heredoc syntax"* ]]
    [[ "$output" == *"[DOT] for content"* ]]
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
    run reorder_script_if_needed "$script"
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
    run reorder_script_if_needed "$script"
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
    run reorder_script_if_needed "$script"
    [ "$status" -eq 0 ]  # No reordering needed
    # Output should be identical to input
    [ "$output" = "$script" ]
}

@test "auto reorder: preserve non-modifying commands in original positions" {
    local script="$(printf '1p\n2d\n3p\n4d\n5p\nw\nq')"
    run reorder_script_if_needed "$script"
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
    run reorder_script_if_needed "$script"
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
    run reorder_script_if_needed "$script"
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


# Complex pattern detection tests
@test "complex pattern detection: g/v blocks are detected" {
    local script="$(printf '1d\ng/pattern/d\n2d\nw\nq')"
    run reorder_script_if_needed "$script"
    [ "$status" -eq 0 ]  # No reordering due to complex pattern
    [[ "$output" == *"1d"* ]]
    [[ "$output" == *"g/pattern/d"* ]]
    [[ "$output" == *"2d"* ]]
}

@test "complex pattern detection: non-numeric addresses are detected" {
    local script="$(printf '1d\n./pattern/d\n3d\nw\nq')"
    run reorder_script_if_needed "$script"
    [ "$status" -eq 0 ]  # No reordering due to complex pattern
    [[ "$output" == *"1d"* ]]
    [[ "$output" == *"./pattern/d"* ]]
    [[ "$output" == *"3d"* ]]
}

@test "complex pattern detection: overlapping intervals are detected" {
    local script="$(printf '5a\nappended line\n.\n3,5d\nw\nq')"
    run reorder_script_if_needed "$script"
    [ "$status" -eq 0 ]  # No reordering due to complex pattern (5a overlaps with 3,5d)
    [[ "$output" == *"5a"* ]]
    [[ "$output" == *"3,5d"* ]]
}

@test "complex pattern detection: move/transfer commands are detected" {
    local script="$(printf '1d\n2m4\n3d\nw\nq')"
    run reorder_script_if_needed "$script"
    [ "$status" -eq 0 ]  # No reordering due to complex pattern
    [[ "$output" == *"1d"* ]]
    [[ "$output" == *"2m4"* ]]
    [[ "$output" == *"3d"* ]]
}

@test "complex pattern detection: multiple operations on same address are detected" {
    local script="$(printf '1d\n1i\nnew line\n.\nw\nq')"
    run reorder_script_if_needed "$script"
    [ "$status" -eq 0 ]  # No reordering due to complex pattern
    [[ "$output" == *"1d"* ]]
    [[ "$output" == *"1i"* ]]
}

@test "complex pattern detection: simple numeric patterns still allow reordering" {
    local script="$(printf '1d\n3d\n5d\nw\nq')"
    run reorder_script_if_needed "$script"
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
    local script="$(set +H; printf '3a\necho \"Array indices: \${!arr[@]}\"\n.\nw\nq')"
    run reorder_script_if_needed "$script"
    [ "$status" -eq 0 ]  # No reordering needed for single command
    # Verify the exclamation mark is preserved (not escaped as \!)
    [[ "$output" == *'${!arr[@]}'* ]]
    [[ "$output" != *'${\\!arr[@]}'* ]]
}

# Regex validation tests for complex pattern detection
@test "regex validation: g/v pattern matching" {
    # Should match (complex): g/v with modifying commands
    [[ "g/pattern/d" =~ ^[[:space:]]*[gvGV]/.*[/][dDcCbBiIaAsSjJmMtT]$ ]]
    [[ "v/test/c" =~ ^[[:space:]]*[gvGV]/.*[/][dDcCbBiIaAsSjJmMtT]$ ]]
    [[ "g/func/s" =~ ^[[:space:]]*[gvGV]/.*[/][dDcCbBiIaAsSjJmMtT]$ ]]

    # Should NOT match (safe): g/v with view commands
    ! [[ "g/pattern/p" =~ ^[[:space:]]*[gvGV]/.*[/][dDcCbBiIaAsSjJmMtT]$ ]]
    ! [[ "g/test/n" =~ ^[[:space:]]*[gvGV]/.*[/][dDcCbBiIaAsSjJmMtT]$ ]]
    ! [[ "v/func/" =~ ^[[:space:]]*[gvGV]/.*[/][dDcCbBiIaAsSjJmMtT]$ ]]
}

@test "regex validation: non-numeric address matching" {
    # Should match (complex): non-numeric with modifying commands
    [[ "/pattern/d" =~ ^[[:space:]]*[\./\?].*[dDcCbBiIaAsSjJmMtT]$ ]]
    [[ ".d" =~ ^[[:space:]]*[\./\?].*[dDcCbBiIaAsSjJmMtT]$ ]]
    [[ "?search?c" =~ ^[[:space:]]*[\./\?].*[dDcCbBiIaAsSjJmMtT]$ ]]

    # Should NOT match (safe): non-numeric with view commands
    ! [[ "/pattern/p" =~ ^[[:space:]]*[\./\?].*[dDcCbBiIaAsSjJmMtT]$ ]]
    ! [[ ".p" =~ ^[[:space:]]*[\./\?].*[dDcCbBiIaAsSjJmMtT]$ ]]
    ! [[ "?search?" =~ ^[[:space:]]*[\./\?].*[dDcCbBiIaAsSjJmMtT]$ ]]
}

@test "regex validation: offset address matching" {
    # Should match (complex): offset with modifying commands
    [[ ".-5d" =~ ^[[:space:]]*[\.\$][+-][0-9].*[dDcCbBiIaAsSjJmMtT]$ ]]
    [[ "$+3c" =~ ^[[:space:]]*[\.\$][+-][0-9].*[dDcCbBiIaAsSjJmMtT]$ ]]
    [[ ".-2,.+2s" =~ ^[[:space:]]*[\.\$][+-][0-9].*[dDcCbBiIaAsSjJmMtT]$ ]]

    # Should NOT match (safe): offset with view commands
    ! [[ ".-5p" =~ ^[[:space:]]*[\.\$][+-][0-9].*[dDcCbBiIaAsSjJmMtT]$ ]]
    ! [[ "$-3,$p" =~ ^[[:space:]]*[\.\$][+-][0-9].*[dDcCbBiIaAsSjJmMtT]$ ]]
    ! [[ ".+5" =~ ^[[:space:]]*[\.\$][+-][0-9].*[dDcCbBiIaAsSjJmMtT]$ ]]
}

# Improved complex pattern detection tests
@test "improved detection: g/pattern/p with simple deletes should allow reordering" {
    local script="$(printf 'g/function/p\n1d\n5d\nw\nq')"
    run reorder_script_if_needed "$script"
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
    run reorder_script_if_needed "$script"
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
    run reorder_script_if_needed "$script"
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
    run reorder_script_if_needed "$script"
    [ "$status" -eq 0 ]  # No reordering due to complex pattern
    [[ "$output" == *"g/function/d"* ]]
    [[ "$output" == *"1d"* ]]
    [[ "$output" == *"5d"* ]]
}

@test "improved detection: non-numeric address with delete should still be detected as complex" {
    local script="$(printf '/pattern/d\n1d\n5d\nw\nq')"
    run reorder_script_if_needed "$script"
    [ "$status" -eq 0 ]  # No reordering due to complex pattern
    [[ "$output" == *"/pattern/d"* ]]
    [[ "$output" == *"1d"* ]]
    [[ "$output" == *"5d"* ]]
}

@test "improved detection: offset address with delete should still be detected as complex" {
    local script="$(printf '.-5,.+5d\n1d\n5d\nw\nq')"
    run reorder_script_if_needed "$script"
    [ "$status" -eq 0 ]  # No reordering due to complex pattern
    [[ "$output" == *".-5,.+5d"* ]]
    [[ "$output" == *"1d"* ]]
    [[ "$output" == *"5d"* ]]
}

