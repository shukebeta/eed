#!/bin/bash
# eed_validator.sh - Ed script validation functions

# Source guard to prevent multiple inclusion
if [ "${EED_VALIDATOR_LOADED:-}" = "1" ]; then
    return 0
fi
EED_VALIDATOR_LOADED=1
# Source the shared regex patterns
source "$(dirname "${BASH_SOURCE[0]}")/eed_regex_patterns.sh"


# Disable history expansion to prevent ! character escaping
set +H

# Validate ed script for basic requirements
validate_ed_script() {
    local script="$1"

    # Check for empty script - treat as no-op, not error
    if [ -z "$script" ] || [ "$script" = "" ]; then
        echo "Warning: Empty ed script provided - no operations to perform" >&2
        return 0  # Success but no operations
    fi

    # Check if script ends with 'q' or 'Q' command
    if ! echo "$script" | grep -q '[qQ]$'; then
        echo "Warning: Ed script does not end with 'q' or 'Q' command" >&2
        echo "This may cause ed to wait for input or hang" >&2
        echo "Consider adding 'q' (save and quit) or 'Q' (quit without save) at the end" >&2
        # Don't fail - just warn, as user might intentionally want this
    fi

    return 0
}


# Detect and auto-fix unterminated input blocks (a/c/i) by inserting a '.' where needed.
# Rules:
#  - Only auto-insert '.' when there is a write/quit (w or q) somewhere in the script
#  - If no w/q is present, refuse to auto-fix to avoid masking script truncation errors
detect_and_fix_unterminated_input() {
    local script="$1"


    # Pre-scan: does the script contain any write/quit commands? If not, we won't auto-fix a
    # trailing unterminated input block (it's likely a script truncation issue).
    local has_wq=0
    if echo "$script" | grep -q -E '^[[:space:]]*[0-9,]*[[:space:]]*[wqQ]([[:space:]]|$)'; then
        has_wq=1
    fi

    local in_input=false
    local changed=0
    local -a out_lines=()

    while IFS= read -r line; do
        # If currently inside an input block, look for terminator or premature w/q
        if [ "$in_input" = true ]; then
            if [ "$line" = "." ]; then
                in_input=false
                out_lines+=("$line")
                continue
            fi

            # If a write/quit appears before '.', insert a '.' to close input first.
            # This is a high-confidence auto-fix because the presence of w/q indicates the
            # user intended to terminate and then write/quit.
            if is_write_command "$line" || is_quit_command "$line"; then
                out_lines+=(".")
                changed=1
                in_input=false
                out_lines+=("$line")
                continue
            fi

            out_lines+=("$line")
            continue
        fi

        # Not in input mode: record line and detect start of input mode
        out_lines+=("$line")
        if is_input_command "$line"; then
            in_input=true
        fi
    done <<< "$script"

    # If file ended while still in input mode:
    if [ "$in_input" = true ]; then
        # Only auto-insert terminator if there is a write/quit somewhere in the script.
        if [ "$has_wq" -eq 1 ]; then
            out_lines+=(".")
            changed=1
        else
            echo "✗ Unterminated input block detected and no write/quit command present — refusing to auto-fix." >&2
            echo "   This often indicates heredoc truncation or mis-nested heredocs. Please add a terminating '.'" >&2
            echo "   or include an explicit write/quit command if you intend to save/quit." >&2
            return 1
        fi
    fi

    # If we made a change, warn the user (stderr) and output the fixed script
    if [ "$changed" -eq 1 ]; then
        echo "⚠️  Auto-fix: inserted missing '.' to terminate unterminated input block(s)." >&2
        echo "   Reason: detected an 'a', 'c' or 'i' command without a terminating '.' before write/quit or end of script." >&2
        echo "   The script was adjusted to avoid silent 'ed' no-op behavior." >&2
        echo "" >&2
    fi

    printf '%s\n' "${out_lines[@]}"
    return 0
}

# TODO: Implement enhanced validator with parsing stack
# validate_ed_script_enhanced() {
#     # The enhanced validator from user's example will go here
# }

# Classify ed script and validate commands
# Small, focused helpers make the main classifier logic clearer.
__cs_is_input_line() {
    local line="$1"
    is_input_command "$line"
    return $?
}

__cs_is_modifying_line() {
    local line="$1"
    # Any of these indicate a modifying operation
    is_modifying_command "$line" && return 0
    is_substitute_command "$line" && return 0
    is_write_command "$line" && return 0
    return 1
}

__cs_is_view_line() {
    local line="$1"
    is_view_command "$line" && return 0
    is_quit_command "$line" && return 0
    is_address_only "$line" && return 0
    is_global_command "$line" && return 0
    is_search_command "$line" && return 0
    return 1
}

classify_ed_script() {
    local script="$1"
    local line
    local -a parsing_stack=()

    while IFS= read -r line; do
        # Trim whitespace and skip empty lines
        line="${line#"${line%%[![:space:]]*}"}"  # ltrim
        line="${line%"${line##*[![:space:]]}"}"  # rtrim
        [ -z "$line" ] && continue

        # Current context (INPUT when inside a/c/i block)
        local current_context=""
        if [ ${#parsing_stack[@]} -gt 0 ]; then
            current_context="${parsing_stack[${#parsing_stack[@]}-1]}"
        fi

        if [ "$current_context" = "INPUT" ]; then
            # Inside input mode - only look for terminator
            if [[ "$line" == "." ]]; then
                unset 'parsing_stack[${#parsing_stack[@]}-1]' 2>/dev/null || true
            fi
            continue
        fi

        # Input-mode starters are modifying operations
        if __cs_is_input_line "$line"; then
            parsing_stack+=("INPUT")
            echo "has_modifying"
            return 0
        fi

        # Other modifying commands (delete, move, substitute, write)
        if __cs_is_modifying_line "$line"; then
            echo "has_modifying"
            return 0
        fi

        # Valid view-only commands and navigational commands
        if __cs_is_view_line "$line"; then
            continue
        fi

        # If none matched, it's an invalid/unknown command
        echo "invalid_command"
        return 0
    done <<< "$script"

    # All lines validated as view-only / navigational
    echo "view_only"
    return 0
}

# Detect potential dot trap in ed scripts
# This detects patterns that might indicate a user intended to use heredoc
# but the dots got interpreted as ed terminators instead
detect_dot_trap() {
    local script="$1"
    local line_count=0
    local dot_count=0
    local suspicious_pattern=false

    # Count lines and standalone dots
    while IFS= read -r line; do
        ((line_count++))
        if [[ "$line" = "." ]]; then
            ((dot_count++))
        fi

        # Look for patterns suggesting heredoc usage attempt
        if [[ "$line" =~ ${EED_REGEX_INPUT_BASIC} ]] || [[ "$line" =~ ${EED_REGEX_WRITE_BASIC} ]] || [[ "$line" =~ ${EED_REGEX_QUIT_BASIC} ]]; then
            suspicious_pattern=true
        fi
    done <<< "$script"

    # Heuristic: if we have multiple standalone dots and ed commands,
    # this might be a case where heredoc wasn't used properly
    if [ $dot_count -gt 1 ] && [ "$suspicious_pattern" = true ] && [ $line_count -gt 5 ]; then
        echo "POTENTIAL_DOT_TRAP:$line_count:$dot_count"
        return 1
    fi

    return 0
}

# Provide helpful guidance about dot usage
suggest_dot_fix() {
    local script="$1"

    echo "⚠️  Detected multiple standalone dots in ed script" >&2
    echo "   If you're using complex ed commands, consider using heredoc syntax:" >&2
    echo "   eed file.txt \"\$(cat <<'EOF'" >&2
    echo "   your ed commands here" >&2
    echo "   use actual . (dot) for content termination in ed commands" >&2
    echo "   EOF" >&2
    echo "   )\"" >&2
    echo "" >&2
    echo "   Proceeding with current script..." >&2

    return 0
}

# Detect complex patterns that are unsafe for automatic reordering
detect_complex_patterns() {
    local script="$1"
    local line
    local -a addresses=()
    local -a intervals=()
    local in_input_mode=false

    while IFS= read -r line; do
        # Skip empty lines and comments
        [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue

        # Handle input mode context (after a/c/i commands)
        if [ "$in_input_mode" = true ]; then
            # In input mode, only look for terminator
            if [[ "$line" == "." ]]; then
                in_input_mode=false
            fi
            # Skip all other lines in input mode as they are text content
            continue
        fi

        # Check if this line starts input mode
        if is_input_command "$line"; then
            in_input_mode=true
            # Continue to process this command line normally
        fi

        # Detect g/v blocks with modifying commands
        if [[ "$line" =~ $EED_REGEX_GV_MODIFYING ]]; then
            [ "$DEBUG_MODE" = true ] && echo "COMPLEX: g/v block with modifying command detected: $line" >&2
            return 1
        fi

        # Detect non-numeric addresses with modifying commands
        if [[ "$line" =~ $EED_REGEX_NON_NUMERIC_MODIFYING ]]; then
            [ "$DEBUG_MODE" = true ] && echo "COMPLEX: Non-numeric address with modifying command detected: $line" >&2
            return 1
        fi

        # Detect offset addresses with modifying commands
        if [[ "$line" =~ $EED_REGEX_OFFSET_MODIFYING ]]; then
            [ "$DEBUG_MODE" = true ] && echo "COMPLEX: Offset address with modifying command detected: $line" >&2
            return 1
        fi

        # Detect move/transfer/read commands
        if [[ "$line" =~ ${EED_REGEX_MOVE_TRANSFER} ]]; then
            [ "$DEBUG_MODE" = true ] && echo "COMPLEX: Move/transfer/read command detected: $line" >&2
            return 1
        fi

        # Extract numeric addresses and check for overlaps
        if [[ "$line" =~ ${EED_REGEX_ADDR_CMD} ]]; then
            local start="${BASH_REMATCH[1]}"
            local end="${BASH_REMATCH[3]:-$start}"
            local cmd="${BASH_REMATCH[4]}"

            # Convert $ to a high number for comparison
            [[ "$end" == "\$" ]] && end="999999"

            # Check for interval overlaps with existing ranges
            for existing in "${intervals[@]}"; do
                local ex_start="${existing%%:*}"
                local ex_end="${existing##*:}"

                # Check if intervals overlap
                if (( start <= ex_end && end >= ex_start )); then
                    echo "COMPLEX: Overlapping intervals detected: $start-$end vs $ex_start-$ex_end" >&2
                    return 1
                fi
            done

            intervals+=("$start:$end")
            addresses+=("$start")
        fi
    done <<< "$script"

    # Check for same-address conflicts
    local -A addr_count
    for addr in "${addresses[@]}"; do
        ((addr_count[$addr]++))
        if (( addr_count[$addr] > 1 )); then
            echo "COMPLEX: Multiple operations on same address: $addr" >&2
            return 1
        fi
    done

    return 0  # No complex patterns detected
}

# Automatically reorder ed script commands to prevent line number conflicts
# Refactored into focused helper functions for clarity and testability.
# Public API preserved: reorder_script <script> => writes script to stdout and
# returns 1 if reordering was performed, 0 otherwise.
_get_modifying_command_info() {
    local script="$1"
    local line
    local line_index=0

    # Output NUL-delimited records for safe parsing of arbitrary content
    while IFS= read -r line; do
        printf '%s\0' "SCRIPT_LINE:$line"
        if [[ "$line" =~ ${EED_REGEX_ADDR_CMD} ]]; then
            printf '%s\0' "MODIFYING_CMD:$line_index:${BASH_REMATCH[1]}:$line"
        fi
        ((line_index++))
    done <<< "$script"
}

_is_reordering_needed() {
    local -a modifying_line_numbers=("$@")

    # Returns 0 when reordering is needed, non-zero otherwise.
    if [ ${#modifying_line_numbers[@]} -lt 2 ]; then
        return 1
    fi

    local original_sequence="${modifying_line_numbers[*]}"
    local sorted_line_numbers
    mapfile -t sorted_line_numbers < <(printf '%s\n' "${modifying_line_numbers[@]}" | sort -n)
    local sorted_sequence_str="${sorted_line_numbers[*]}"

    if [ "$original_sequence" != "$sorted_sequence_str" ]; then
        return 1
    fi

    local unique_count
    unique_count=$(printf '%s\n' "${modifying_line_numbers[@]}" | uniq | wc -l)
    if [ "$unique_count" -le 1 ]; then
        return 1
    fi

    return 0
}

_perform_reordering_from_records() {
    local -a records=("$@")
    local -a script_lines=()
    local -a modifying_commands=()
    local -a modifying_line_numbers=()

    # Parse the pre-captured NUL-delimited records
    for record in "${records[@]}"; do
        # Skip empty records (from trailing NUL)
        [ -z "$record" ] && continue

        if [[ "$record" =~ ^SCRIPT_LINE:(.*)$ ]]; then
            script_lines+=("${BASH_REMATCH[1]}")
        elif [[ "$record" =~ ^MODIFYING_CMD:([0-9]+):([0-9]+):(.*)$ ]]; then
            local idx="${BASH_REMATCH[1]}"
            local line_num="${BASH_REMATCH[2]}"
            local cmd="${BASH_REMATCH[3]}"
            modifying_commands+=("$idx:$line_num:$cmd")
            modifying_line_numbers+=("$line_num")
        fi
    done

    # Produces reordered script on stdout and returns 1 to indicate reordering.
    local -a modifying_commands_sorted
    mapfile -t modifying_commands_sorted < <(printf '%s\n' "${modifying_commands[@]}" | sort -s -t: -k2,2nr -k1,1n)

    # Informative messaging, kept to match previous UX
    echo "✓ Auto-reordering script to prevent line numbering conflicts:" >&2
    local original_formatted="($(IFS=, ; echo "${modifying_line_numbers[*]}"))"
    local -a reverse_sorted_line_numbers
    mapfile -t reverse_sorted_line_numbers < <(printf '%s\n' "${modifying_line_numbers[@]}" | sort -nr)
    local suggested_formatted="($(IFS=, ; echo "${reverse_sorted_line_numbers[*]}"))"
    echo "   Original: ${original_formatted} → Reordered: ${suggested_formatted}" >&2
    echo "" >&2

    local -a reordered_script=()
    local -a processed_indices=()

    for cmd_info in "${modifying_commands_sorted[@]}"; do
        local old_index="${cmd_info%%:*}"
        local cmd_line="${cmd_info##*:}"

        reordered_script+=("$cmd_line")
        processed_indices+=("$old_index")

        # If input-mode command, include following content until terminating "."
        if [[ "$cmd_line" =~ [aAcCiI]$ ]]; then
            local content_idx=$((old_index + 1))
            while [ "$content_idx" -lt "${#script_lines[@]}" ]; do
                local content_line="${script_lines[$content_idx]}"
                reordered_script+=("$content_line")
                processed_indices+=("$content_idx")
                if [ "$content_line" = "." ]; then
                    break
                fi
                ((content_idx++))
            done
        fi
    done

    # Append remaining lines in original order
    for i in "${!script_lines[@]}"; do
        local is_processed=false
        for proc_idx in "${processed_indices[@]}"; do
            if [ "$i" = "$proc_idx" ]; then
                is_processed=true
                break
            fi
        done
        if [ "$is_processed" = false ]; then
            reordered_script+=("${script_lines[$i]}")
        fi
    done

    printf '%s\n' "${reordered_script[@]}"
    return 1
}

reorder_script() {
    local script="$1"
    local -a script_lines=()
    local -a modifying_line_numbers=()

    # Capture records once to avoid double parsing (NUL-delimited)
    local -a records=()
    mapfile -t -d '' records < <(_get_modifying_command_info "$script")

    # Parse records to extract what we need for decision making
    for record in "${records[@]}"; do
        # Skip empty records (from trailing NUL)
        [ -z "$record" ] && continue

        if [[ "$record" =~ ^SCRIPT_LINE:(.*)$ ]]; then
            script_lines+=("${BASH_REMATCH[1]}")
        elif [[ "$record" =~ ^MODIFYING_CMD:[0-9]+:([0-9]+):.*$ ]]; then
            modifying_line_numbers+=("${BASH_REMATCH[1]}")
        fi
    done

    # Decide whether to reorder
    if ! _is_reordering_needed "${modifying_line_numbers[@]}"; then
        # Output original script unchanged
        printf '%s\n' "${script_lines[@]}"
        return 0
    fi

    # Perform reordering using pre-captured records
    _perform_reordering_from_records "${records[@]}"
    return $?
}

# Legacy function for backward compatibility with existing tests
# Detects line order issues but doesn't reorder (just warns)
detect_line_order_issue() {
    local script="$1"
    local line
    local -a modifying_line_numbers=()

    # Parse script to extract line numbers from modifying commands
    while IFS= read -r line; do
        if [[ "$line" =~ ${EED_REGEX_ADDR_CMD} ]]; then
            modifying_line_numbers+=("${BASH_REMATCH[1]}")
        fi
    done <<< "$script"

    if [ ${#modifying_line_numbers[@]} -lt 2 ]; then
        return 0
    fi

    local original_sequence="${modifying_line_numbers[*]}"
    local sorted_line_numbers
    mapfile -t sorted_line_numbers < <(printf '%s\n' "${modifying_line_numbers[@]}" | sort -n)
    local sorted_sequence_str="${sorted_line_numbers[*]}"

    if [ "$original_sequence" = "$sorted_sequence_str" ]; then
        local unique_count
        unique_count=$(printf '%s\n' "${modifying_line_numbers[@]}" | uniq | wc -l)

        if [ "$unique_count" -gt 1 ]; then
            local reverse_sorted_line_numbers
            mapfile -t reverse_sorted_line_numbers < <(printf '%s\n' "${modifying_line_numbers[@]}" | sort -nr)

            local original_formatted="($(IFS=, ; echo "${modifying_line_numbers[*]}"))"
            local suggested_formatted="($(IFS=, ; echo "${reverse_sorted_line_numbers[*]}"))"

            echo "⚠️  Detected operations on ascending line numbers ${original_formatted}" >&2
            echo "💡 Consider reordering: start from line ${suggested_formatted}" >&2
            echo "   Reason: Earlier deletions shift line numbers, affecting later operations" >&2
            echo "" >&2
            return 1
        fi
    fi

    return 0
}

# Validate line number ranges in ed script
validate_line_ranges() {
    local script="$1"
    local file_path="$2"
    local max_lines
    local line

    # Get file line count (file should exist by now due to creation logic)
    max_lines=$(wc -l < "$file_path")
    # Handle empty files: ed treats them as having 1 empty line
    [ "$max_lines" -eq 0 ] && max_lines=1

    while IFS= read -r line; do
        # Trim whitespace and skip empty lines
        line="${line#"${line%%[![:space:]]*}"}"  # ltrim
        line="${line%"${line##*[![:space:]]}"}"  # rtrim
        [ -z "$line" ] && continue

        # Skip input mode content (between commands like 'a' and '.')
        if [[ "$line" == "." ]]; then
            continue
        fi

        # Check line number ranges using existing regex
        if [[ "$line" =~ ${EED_REGEX_ADDR_CMD} ]]; then
            local start_line="${BASH_REMATCH[1]}"
            local end_line="${BASH_REMATCH[3]}"

            # Check start line number
            if [ "$start_line" -gt "$max_lines" ]; then
                echo "✗ Line number error in command '$line'" >&2
                echo "  Line $start_line does not exist (file has only $max_lines lines)" >&2
                return 1
            fi

            # Check end line number (if it's not $ and not empty)
            if [ -n "$end_line" ] && [ "$end_line" != "\$" ] && [ "$end_line" -gt "$max_lines" ]; then
                echo "✗ Line number error in command '$line'" >&2
                echo "  Line $end_line does not exist (file has only $max_lines lines)" >&2
                return 1
            fi
        fi
    done <<< "$script"

    return 0
}

# --- COMPLEX PATTERN DETECTION FUNCTIONS ---

# Check if script contains complex patterns that make it unpredictable
has_complex_patterns() {
    local script="$1"
    local line

    while IFS= read -r line; do
        line=$(echo "$line" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        [ -z "$line" ] && continue

        # Detect global/visual commands
        if [[ "$line" =~ ^[gvGV]/ ]]; then
            return 0
        fi

        # Detect move/transfer commands
        if [[ "$line" =~ [mMtT] ]]; then
            return 0
        fi

    done <<< "$script"

    return 1
}

# Determine ordering pattern of line numbers
determine_ordering() {
    local script="$1"
    local line
    local -a numbers=()

    while IFS= read -r line; do
        line=$(echo "$line" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        [ -z "$line" ] && continue

        if [[ "$line" =~ ^([0-9]+) ]]; then
            numbers+=("${BASH_REMATCH[1]}")
        fi
    done <<< "$script"

    if [ ${#numbers[@]} -lt 2 ]; then
        echo "single"
        return 0
    fi

    local orig="${numbers[*]}"
    local sorted
    sorted=$(printf '%s\n' "${numbers[@]}" | sort -n | tr '\n' ' ')
    sorted=${sorted% }

    if [ "$orig" = "$sorted" ]; then
        echo "ascending"
    else
        echo "unordered"
    fi
}
