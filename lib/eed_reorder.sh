#!/bin/bash
# eed_reorder.sh - Ed script reordering functions

# Source guard to prevent multiple inclusion
if [ "${EED_REORDER_LOADED:-}" = "1" ]; then
    return 0
fi
EED_REORDER_LOADED=1

# Source the shared regex patterns
source "$(dirname "${BASH_SOURCE[0]}")/eed_regex_patterns.sh"

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