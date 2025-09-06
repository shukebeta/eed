#!/bin/bash
# lib/eed_auto_fix_unescaped_slashes.sh - Auto-fixing functionality for eed
# Provides intelligent syntax correction for common ed script errors

# Source required dependencies  
# Note: eed_validator.sh is already sourced by main script, contains detect_unescaped_slashes

# --- Helper Functions ---

# Fix unescaped slashes in ed commands
# Takes a line with unescaped slashes and returns the fixed version
fix_unescaped_slashes() {
    local line="$1"
    
    # Helper function to escape unescaped slashes in a pattern
    escape_slashes() {
        local text="$1"
        # Use a different approach: replace all / with \/, then fix double escaping
        
        # First, replace all slashes with escaped slashes
        text=$(echo "$text" | sed 's|/|\\/|g')
        
        # Then fix cases where we double-escaped (\\/ -> \/)
        text=$(echo "$text" | sed 's|\\\\\/|\\/|g')
        
        echo "$text"
    }
    
    # Handle range patterns first: /pattern1/,/pattern2/command
    if [[ "$line" =~ ^/.*/,/.*/[acdi]$ ]]; then
        # Use a more careful approach to extract patterns
        # Match the entire structure and extract components
        if [[ "$line" =~ ^/(.*)/,/(.*)/([acdi])$ ]]; then
            local first_pattern="${BASH_REMATCH[1]}"
            local second_pattern="${BASH_REMATCH[2]}"
            local command="${BASH_REMATCH[3]}"
            
            # Escape slashes in both patterns
            local escaped_first=$(escape_slashes "$first_pattern")
            local escaped_second=$(escape_slashes "$second_pattern")
            
            # Only return 0 (success) if we actually made changes
            if [ "$first_pattern" != "$escaped_first" ] || [ "$second_pattern" != "$escaped_second" ]; then
                echo "/${escaped_first}/,/${escaped_second}/${command}"
                return 0
            else
                echo "$line"
                return 1  # No changes needed
            fi
        fi
    fi
    
    # Handle single patterns: /pattern/command
    if [[ "$line" =~ ^/.*/[acdi]$ ]]; then
        # Extract pattern by removing first and last slash+command
        local pattern="${line#/}"        # Remove leading /
        local command="${pattern##*/}"   # Extract command (last / to end)
        pattern="${pattern%/*}"          # Remove trailing /command
        
        # Escape slashes in pattern
        local escaped_pattern=$(escape_slashes "$pattern")
        
        # Only return 0 (success) if we actually made changes
        if [ "$pattern" != "$escaped_pattern" ]; then
            echo "/${escaped_pattern}/${command}"
            return 0
        else
            echo "$line"
            return 1  # No changes needed
        fi
    fi
    
    # If no patterns matched, return original line unchanged
    echo "$line"
    return 1
}

# --- Smart Auto-fixing for AI Users ---
# Pre-process script to fix unescaped slash syntax errors before validation
# Uses return code to indicate if fixes were applied
process_and_fix_unescaped_slashes() {
    local script="$1"
    FIXED_SCRIPT=""
    local -a script_lines=()
    local line
    local return_code=1

    while IFS= read -r line; do
        if [ -z "$line" ]; then
            script_lines+=("")
            FIXED_SCRIPT+=$'\n'
            continue
        fi

        if detect_unescaped_slashes "$line"; then
            local FIXED_LINE
            if FIXED_LINE=$(fix_unescaped_slashes "$line"); then
                echo "🔧 Auto-fixed unescaped slashes: $line → $FIXED_LINE" >&2
                script_lines+=("$FIXED_LINE")
                FIXED_SCRIPT+="$FIXED_LINE"$'\n'
                return_code=0
            else
                script_lines+=("$line")
                FIXED_SCRIPT+="$line"$'\n'
            fi
        else
            script_lines+=("$line")
            FIXED_SCRIPT+="$line"$'\n'
        fi
    done <<< "$script"
    return $return_code
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
            if FIXED_LINE=$(fix_unescaped_slashes "$line"); then
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

