#!/bin/bash
# eed_common.sh - Common utility functions for eed

# Source guard to prevent multiple inclusion
if [ "${EED_COMMON_LOADED:-}" = "1" ]; then
    return 0
fi
EED_COMMON_LOADED=1

# Ed command logging configuration
EED_LOG_FILE="$HOME/.eed_command_log.txt"

# Show help information
show_help() {
    cat << 'EOF'
Usage: eed [OPTIONS] <file> [ed_script | -]

AI-oriented text editor with bulletproof safety guarantees

OPTIONS:
  --force         Apply changes directly (skip preview mode)
  --debug         Show detailed debugging information
  --disable-auto-reorder  Disable automatic command reordering
  --help          Show this help message

ARGUMENTS:
  file            Target file to edit (will be created if it doesn't exist)
  ed_script       Ed commands as string, or '-' to read from stdin
  -               Read ed script from stdin (alternative to ed_script)

EXAMPLES:
  # Preview mode (default - safe)
  eed file.txt $'1a\nHello\n.\nw\nq'

  # Direct mode (skip preview)
  eed --force file.txt $'1d\nw\nq'

  # Read from stdin
  echo $'1a\nContent\n.\nw\nq' | eed file.txt -

  # For complex scripts, use heredoc syntax - avoid nested heredocs
  # (this prevents shell interpretation of the script content)
  eed /unix/style/path/to/file - <<'EOF'
  # ed commands here
  w
  q
  EOF

WORKFLOW:
  1. Validates ed commands for safety
  2. Automatically creates preview in file.eed.preview
  3. Shows diff and instructions (unless --force)
  4. Provides clear next steps

SAFETY FEATURES:
  - Original files never corrupted
  - Preview-first workflow
  - Automatic command reordering
  - Line number validation
  - Git integration
EOF
}

# Log ed commands for analysis and debugging
log_ed_commands() {
    local script_content="$1"
    local log_file="${2:-$EED_LOG_FILE}"  # Optional log file parameter, defaults to global setting

    # Skip logging to the default user log during tests unless an explicit log file is provided.
    # This prevents tests from polluting the user's home directory when EED_TESTING is set.
    if { [ "${EED_TESTING:-}" = "1" ] || [ "${EED_TESTING:-}" = "true" ]; } && [ $# -lt 2 ]; then
        return 0
    fi

    local timestamp
    timestamp=$(date --iso-8601=seconds)

    local in_input_mode=false
    while IFS= read -r line; do
        # Trim whitespace for accurate parsing
        line="${line#"${line%%[![:space:]]*}"}"
        line="${line%"${line##*[![:space:]]}"}"

        # --- Rule 2: Handle input mode FIRST (before boilerplate filtering) ---
        if [ "$in_input_mode" = true ]; then
            if [[ "$line" == "." ]]; then
                in_input_mode=false
            fi
            continue # Don't log the content being inserted or terminators
        fi

        # --- Rule 1: Skip boilerplate (after input mode handling) ---
        # If the line is exactly '.', 'w', 'q', or 'Q', ignore it.
        if [[ "$line" == "." || "$line" == "w" || "$line" == "q" || "$line" == "Q" ]]; then
            continue
        fi

        # Check for commands that enter input mode *after* trying to log the command itself
        if [[ "$line" =~ ${EED_REGEX_INPUT_MODE} ]]; then
            in_input_mode=true
        fi

        # --- Rule 3: Log the command if it's not empty and hasn't been skipped ---
        if [ -n "$line" ]; then
            # Log format: TIMESTAMP | COMMAND
            echo "$timestamp | $line" >> "$log_file"
        fi
    done <<< "$script_content"
}
