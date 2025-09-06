#!/bin/bash
# lib/eed_auto_fix.sh - Auto-fixing functionality for eed
# Provides intelligent syntax correction for common ed script errors

# Source required dependencies
# Note: eed_validator.sh is already sourced by main script, contains detect_unescaped_slashes and fix_unescaped_slashes

# --- Smart Auto-fixing for AI Users ---
# Pre-process script to fix common syntax errors before validation
# Process script and set global variables, matching original behavior exactly
process_and_fix_script() {
    local script="$1"
    FIXED_SCRIPT=""
    FIXED_ANY_LINES=false
    local -a script_lines=()
    local line

    while IFS= read -r line; do
        if [ -z "$line" ]; then
            script_lines+=("")
            FIXED_SCRIPT+=$'\n'
            continue
        fi
        
        if detect_unescaped_slashes "$line"; then
            local FIXED_LINE
            FIXED_LINE=$(fix_unescaped_slashes "$line")
            if [ $? -eq 0 ]; then
                echo "🔧 Auto-fixed unescaped slashes: $line → $FIXED_LINE" >&2
                script_lines+=("$FIXED_LINE")
                FIXED_SCRIPT+="$FIXED_LINE"$'\n'
                FIXED_ANY_LINES=true
            else
                script_lines+=("$line")
                FIXED_SCRIPT+="$line"$'\n'
            fi
        else
            script_lines+=("$line")
            FIXED_SCRIPT+="$line"$'\n'
        fi
    done <<< "$script"
}

# Legacy implementation using string concatenation (kept for performance comparison)
# This exactly matches the original main script logic before refactoring
process_and_fix_script_legacy() {
    local script="$1"
    local result=""
    local fixed_any=false

    while IFS= read -r line; do
        [ -z "$line" ] && { result+=$'\n'; continue; }

        if detect_unescaped_slashes "$line"; then
            local FIXED_LINE
            FIXED_LINE=$(fix_unescaped_slashes "$line")
            if [ $? -eq 0 ]; then
                echo "🔧 Auto-fixed unescaped slashes: $line → $FIXED_LINE" >&2
                result+="$FIXED_LINE"$'\n'
                fixed_any=true
            else
                result+="$line"$'\n'
            fi
        else
            result+="$line"$'\n'
        fi
    done <<< "$script"

    # Match original behavior: only output if fixes applied, and remove trailing newline
    if [ "$fixed_any" = true ]; then
        echo -n "${result%$'\n'}"
    fi

    # Return status: 0 if fixes were applied, 1 if no fixes needed
    [ "$fixed_any" = true ]
}

