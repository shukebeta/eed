#!/bin/bash
# eed_common.sh - Common utility functions for eed

# Source guard to prevent multiple inclusion
if [ "${EED_COMMON_LOADED:-}" = "1" ]; then
    return 0
fi
EED_COMMON_LOADED=1

# Ed command logging configuration
EED_LOG_FILE="$HOME/.eed_command_log.txt"

# Show usage information
show_usage() {
    echo "Usage: eed [--debug] <file> <ed_script>"
    echo ""
    echo "Single-parameter mode with heredoc support for complex operations."
    echo ""
    echo "Options:"
    echo "  --debug    Enable debug mode (preserve temp files, verbose errors)"
    echo ""
    echo "Common ed commands:"
    echo "  Nd             - Delete line N"
    echo "  N,Md           - Delete lines N through M"
    echo "  Nc <text> .    - Replace line N with <text>"
    echo "  Na <text> .    - Insert <text> after line N"
    echo "  Ni <text> .    - Insert <text> before line N"
    echo "  ,p             - Print all lines (view file)"
    echo "  N,Mp           - Print lines N through M"
    echo "  /pattern/p     - Print lines matching pattern"
    echo "  s/old/new/g    - Replace all 'old' with 'new' on current line"
    echo "  1,\$s/old/new/g - Replace all 'old' with 'new' in entire file"
    echo ""
    echo "Examples:"
    echo '  eed file.txt "5d\nw\nq"                    # Delete line 5'
    echo '  eed file.txt ",p\nq"                       # View entire file'
    echo '  eed file.txt "$(cat <<'\''EOF'\''            # Complex operations'
    echo '  3c'
    echo '  new content'
    echo '  .'
    echo '  w'
    echo '  q'
    echo '  EOF'
    echo '  )"'
}

# Log ed commands for analysis and debugging
log_ed_commands() {
    local script_content="$1"
    
    # Skip logging during tests
    if [[ "${EED_TESTING:-}" == "1" ]]; then
        return 0
    fi
    
    local timestamp
    timestamp=$(date --iso-8601=seconds)

    local in_input_mode=false
    while IFS= read -r line; do
        # Trim whitespace for accurate parsing
        line="${line#"${line%%[![:space:]]*}"}"
        line="${line%"${line##*[![:space:]]}"}"

        # --- Rule 1: Skip boilerplate ---
        # If the line is exactly '.', 'w', 'q', or 'Q', ignore it.
        if [[ "$line" == "." || "$line" == "w" || "$line" == "q" || "$line" == "Q" ]]; then
            continue
        fi

        # --- Rule 2: Skip data lines (for a, c, i) ---
        if [ "$in_input_mode" = true ]; then
            if [[ "$line" == "." ]]; then
                in_input_mode=false
            fi
            continue # Don't log the content being inserted
        fi

        # Check for commands that enter input mode *after* trying to log the command itself
        if [[ "$line" =~ ^(\.|[0-9]+)?,?(\$|[0-9]+)?[aAcCiI]$ ]]; then
            in_input_mode=true
        fi

        # --- Rule 3: Log the command if it's not empty and hasn't been skipped ---
        if [ -n "$line" ]; then
            # Log format: TIMESTAMP | COMMAND
            echo "$timestamp | $line" >> "$EED_LOG_FILE"
        fi
    done <<< "$script_content"
}