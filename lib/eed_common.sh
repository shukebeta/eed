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
    echo "Usage: eed [--debug] [--force] [--disable-auto-reorder] FILE {SCRIPT|-}"
    echo ""
    echo "Modes (preferred examples first):"
    echo ""
    echo "  1) Pipe a simple instruction stream (quick):"
    echo "     printf '1d\nw\nq\n' | eed FILE -"
    echo ""
    echo "  2) Use heredoc with '-' to pass complex scripts via stdin:"
    echo "     eed FILE - <<'EOF'"
    echo "     3c"
    echo "     new content"
    echo "     ."
    echo "     w"
    echo "     q"
    echo "     EOF"
    echo ""
    echo "  3) Single-parameter heredoc/inline (legacy):"
    echo "     eed FILE \"\$(cat <<'EOF'"
    echo "     3c"
    echo "     new content"
    echo "     ."
    echo "     w"
    echo "     q"
    echo "     EOF"
    echo "     )\""
    echo ""
    echo "Options:"
    echo "  --debug    Enable debug mode (preserve temp files, verbose errors)"
    echo "  --force    Skip preview-confirm workflow, edit file directly"
    echo "  --disable-auto-reorder  Disable automatic script reordering"
    echo ""
    echo "Common ed commands (examples):"
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
        if [[ "$line" =~ ${EED_REGEX_INPUT_MODE} ]]; then
            in_input_mode=true
        fi

        # --- Rule 3: Log the command if it's not empty and hasn't been skipped ---
        if [ -n "$line" ]; then
            # Log format: TIMESTAMP | COMMAND
            echo "$timestamp | $line" >> "$EED_LOG_FILE"
        fi
    done <<< "$script_content"
}
