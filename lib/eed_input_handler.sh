#!/bin/bash
# eed_input_handler.sh - Ed script input block detection and repair functions

# Source guard to prevent multiple inclusion
if [ "${EED_INPUT_HANDLER_LOADED:-}" = "1" ]; then
    return 0
fi
EED_INPUT_HANDLER_LOADED=1

# Source the shared regex patterns
source "$(dirname "${BASH_SOURCE[0]}")/eed_regex_patterns.sh"

# Check if script contains write/quit commands (helper for main function)
_has_write_or_quit_commands() {
    local script="$1"
    
    # Return 0 if has w/q commands, 1 if not found
    if echo "$script" | grep -q -E '^[[:space:]]*[0-9,]*[[:space:]]*[wqQ]([[:space:]]|$)'; then
        return 0  # Found w/q commands
    else
        return 1  # No w/q commands found
    fi
}

# Report auto-fix changes to user (helper for main function)  
_report_auto_fix_warnings() {
    local changed="$1"
    
    # If we made a change, warn the user (stderr)
    if [ "$changed" -eq 1 ]; then
        echo "⚠️  Auto-fix: inserted missing '.' to terminate unterminated input block(s)." >&2
        echo "   Reason: detected an 'a', 'c' or 'i' command without a terminating '.' before write/quit or end of script." >&2
        echo "   The script was adjusted to avoid silent 'ed' no-op behavior." >&2
        echo "" >&2
    fi
}

# Detect and auto-fix unterminated input blocks (a/c/i) by inserting a '.' where needed.
# Rules:
#  - Only auto-insert '.' when there is a write/quit (w or q) somewhere in the script
#  - If no w/q is present, refuse to auto-fix to avoid masking script truncation errors
detect_and_fix_unterminated_input() {
    local script="$1"

    # Pre-scan: does the script contain any write/quit commands?
    local has_wq=0
    if _has_write_or_quit_commands "$script"; then
        has_wq=1  # Found w/q commands
    else
        has_wq=0  # No w/q commands
    fi

    local in_input=false
    local changed=0
    local -a out_lines=()

    # Main processing loop - single pass through the script
    while IFS= read -r line; do
        # If currently inside an input block, look for terminator or premature w/q
        if [ "$in_input" = true ]; then
            if [ "$line" = "." ]; then
                in_input=false
                out_lines+=("$line")
                continue
            fi

            # If a write/quit appears before '.', insert a '.' to close input first.
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

    # Report any changes made to user
    _report_auto_fix_warnings "$changed"

    # Output the processed script
    printf '%s\n' "${out_lines[@]}"
    return 0
}