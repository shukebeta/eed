#!/bin/bash
# eed_input_handler.sh - Ed script input block detection and repair functions

# Source guard to prevent multiple inclusion
if [ "${EED_INPUT_HANDLER_LOADED:-}" = "1" ]; then
    return 0
fi
EED_INPUT_HANDLER_LOADED=1

# Source the shared regex patterns
source "$(dirname "${BASH_SOURCE[0]}")/eed_regex_patterns.sh"


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
# Note: Auto-completion ensures w/q commands are always present, so we can safely auto-fix
detect_and_fix_unterminated_input() {
    local script="$1"

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
                # Only insert dot if previous line wasn't already a dot
                if [ "${out_lines[-1]}" != "." ]; then
                    out_lines+=(".")
                    changed=1
                fi
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

    # If file ended while still in input mode, auto-insert terminator
    if [ "$in_input" = true ]; then
        out_lines+=(".")
        changed=1
    fi

    # Report any changes made to user
    _report_auto_fix_warnings "$changed"

    # Output the processed script
    printf '%s\n' "${out_lines[@]}"
    return 0
}