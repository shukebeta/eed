#!/bin/bash
# eed_validator.sh - Ed script validation functions

# Source guard to prevent multiple inclusion
if [ "${EED_VALIDATOR_LOADED:-}" = "1" ]; then
    return 0
fi
EED_VALIDATOR_LOADED=1
# Source the shared regex patterns
source "$(dirname "${BASH_SOURCE[0]}")/eed_regex_patterns.sh"
# Source smart dot protection functionality
source "$(dirname "${BASH_SOURCE[0]}")/eed_smart_dot_protection.sh"
# Source reordering functionality
source "$(dirname "${BASH_SOURCE[0]}")/eed_reorder.sh"
# Source input handling functionality
source "$(dirname "${BASH_SOURCE[0]}")/eed_input_handler.sh"


# Disable history expansion to prevent ! character escaping
set +H

# Validate ed script for basic requirements
is_ed_script_valid() {
    local script="$1"

    # Check for empty script - treat as no-op, not error
    if [ -z "$script" ] || [ "$script" = "" ]; then
        echo "Warning: Empty ed script provided - no operations to perform" >&2
        return 0  # Success but no operations
    fi

    # Check if script ends with 'q' or 'Q' command
    if ! echo "$script" | grep -q '[qQ]$'; then
        echo "Warning: Ed script does not end with 'q' or 'Q' command" >&2
        # Don't fail - just warn, as user might intentionally want this
    fi

    return 0
}



# TODO: Implement enhanced validator with parsing stack
# is_ed_script_valid_enhanced() {
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
    local -a lines
    local -a suspicious_line_numbers=()
    local is_confirmed_tutorial=false
    local line_count=0

    # Parse script into array
    readarray -t lines <<< "$script"

    # Helper function to check if a line is a valid ed command
    is_valid_ed_command() {
        local cmd="$1"
        [[ -z "$cmd" ]] && return 1

        # Match common ed commands: addresses, operations, combinations
        [[ "$cmd" =~ ^[0-9]*[aicdspmtjklnpwqQ=].*$ ]] || \
        [[ "$cmd" =~ ^\$[aicdspmtjklnpwqQ=].*$ ]] || \
        [[ "$cmd" =~ ^/.*/.* ]] || \
        [[ "$cmd" =~ ^[0-9]*,[0-9]*[aicdspmtjklnpwqQ=] ]] || \
        [[ "$cmd" =~ ^g/.*/[dps] ]] || \
        [[ "$cmd" =~ ^[wqQ]$ ]]
    }

    for i in "${!lines[@]}"; do
        local line="${lines[i]}"
        line_count=$((line_count + 1))

        if [[ "$line" == "." ]]; then
            local next_line="${lines[$((i+1))]:-}"

            if [[ "$is_confirmed_tutorial" == true ]]; then
                # Already confirmed tutorial - this dot is suspicious
                suspicious_line_numbers+=($i)
            elif is_valid_ed_command "$next_line"; then
                # Dot followed by valid ed command - potentially suspicious
                suspicious_line_numbers+=($i)
            else
                # Dot not followed by valid ed command - immediately suspicious
                suspicious_line_numbers+=($i)
            fi
        fi

        if [[ "$line" =~ ^[qQ]$ ]] && [[ "$is_confirmed_tutorial" == false ]]; then
            # Found quit command, check if there's content after it
            local has_content_after_q=false
            for ((j=i+1; j<${#lines[@]}; j++)); do
                local remaining_line="${lines[j]}"
                # Skip empty lines and whitespace-only lines
                if [[ -n "${remaining_line// /}" ]]; then
                    has_content_after_q=true
                    break
                fi
            done

            if [[ "$has_content_after_q" == true ]]; then
                # Confirmed tutorial scenario - q followed by content
                is_confirmed_tutorial=true
            else
                # Normal script ending - BUT keep suspicious dots if there are many
                # This handles legitimate complex scripts that should still be flagged
                if [ ${#suspicious_line_numbers[@]} -gt 2 ]; then
                    # Keep the suspicious dots - this might be a complex script worth warning about
                    break
                else
                    # Few dots in normal script ending - clear them
                    suspicious_line_numbers=()
                    break
                fi
            fi
        fi
    done

    # Handle case where script ends without q command
    if [[ "$is_confirmed_tutorial" == false ]] && [ ${#suspicious_line_numbers[@]} -gt 0 ]; then
        # Script ended without q/Q - decide based on number of suspicious dots
        if [ ${#suspicious_line_numbers[@]} -gt 2 ]; then
            # Many suspicious dots without proper ending - likely complex script needing warning
            is_confirmed_tutorial=false  # Keep as potential complex script, not tutorial
        else
            # Few dots in script without q - probably normal, clear them
            suspicious_line_numbers=()
        fi
    fi

    # If we found suspicious dots (either confirmed tutorial or immediate suspicious cases)
    if [ ${#suspicious_line_numbers[@]} -gt 0 ]; then
        echo "POTENTIAL_DOT_TRAP:$line_count:${#suspicious_line_numbers[@]}:tutorial=$is_confirmed_tutorial"
        return 1
    fi

    return 0
}


# Smart dot protection integration
# Attempts to intelligently handle multiple dots in ed tutorial/documentation contexts
# Returns the (possibly transformed) script on stdout
apply_smart_dot_handling() {
    local script="$1"
    local file_path="$2"

    # First check if we should attempt smart protection
    local confidence
    confidence=$(detect_ed_tutorial_context "$script" "$file_path")
    local detection_result=$?

    if [ "$detection_result" -eq 0 ]; then
        # High confidence - attempt transformation
        local transformed_script
        if transformed_script=$(transform_content_dots "$script"); then
            echo "✨ Smart dot protection applied for ed tutorial editing (confidence: ${confidence}%)" >&2
            echo "$transformed_script"
            return 0
        else
            echo "⚠️  Smart dot protection failed, falling back to standard guidance" >&2
        fi
    elif [ "$confidence" -ge 40 ]; then
        # Medium confidence - provide enhanced guidance
        echo "🤔 Detected possible ed tutorial editing (confidence: ${confidence}%)" >&2
        echo "   For complex cases with multiple dots, consider using Edit/Write tools instead" >&2
    fi

    # Default: return original script unchanged
    echo "$script"
    return 1
}

# Detect complex patterns that are unsafe for automatic reordering
no_complex_patterns() {
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
        addr_count[$addr]=$((${addr_count[$addr]:-0} + 1))
        if (( addr_count[$addr] > 1 )); then
            echo "COMPLEX: Multiple operations on same address: $addr" >&2
            return 1
        fi
    done

    return 0  # No complex patterns detected
}
# Validate line number ranges in ed script
validate_line_ranges() {
    local script="$1"
    local file_path="$2"
    local max_lines
    local line

    # Get file line count (handle case where file doesn't exist yet)
    if [ -f "$file_path" ]; then
        max_lines=$(wc -l < "$file_path")
        # Handle empty files: ed treats them as having 1 empty line
        [ "$max_lines" -eq 0 ] && max_lines=1
    else
        # File doesn't exist yet - assume it will be created as empty (1 line)
        max_lines=1
    fi

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
