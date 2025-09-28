#!/bin/bash
# eed_common.sh - Common utility functions for eed

# Source guard to prevent multiple inclusion
if [ "${EED_COMMON_LOADED:-}" = "1" ]; then
    return 0
fi
EED_COMMON_LOADED=1

# Source regex patterns
source "$(dirname "${BASH_SOURCE[0]}")/eed_regex_patterns.sh"

# Ed command logging configuration
EED_LOG_FILE="$HOME/.eed_command_log.txt"

# Debug logging configuration
EED_DEBUG_LOG_DIR="$HOME/.eed"
EED_DEBUG_LOG_FILE="$EED_DEBUG_LOG_DIR/debug.log"

# Debug logging function - always logs to file, optionally shows to user
# Usage: eed_debug_log "level" "message" [show_to_user]
eed_debug_log() {
    local level="$1"
    local message="$2"
    local show_to_user="${3:-false}"
    
    # Ensure log directory exists
    if [ ! -d "$EED_DEBUG_LOG_DIR" ]; then
        mkdir -p "$EED_DEBUG_LOG_DIR" 2>/dev/null || return 1
    fi
    
    # Format: [timestamp] [level] message
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    # Escape newlines and tabs in message for single-line log entries
    local safe_message="${message//$'\n'/\\n}"
    safe_message="${safe_message//$'\t'/\\t}"
    
    # Always log to file (append mode) - use printf for safe handling of special characters
    if printf '[%s] [%s] %s\n' "$timestamp" "$level" "$safe_message" >> "$EED_DEBUG_LOG_FILE" 2>/dev/null; then
        # Keep log file size reasonable (last 1000 lines)
        if [ -f "$EED_DEBUG_LOG_FILE" ]; then
            local line_count=$(wc -l < "$EED_DEBUG_LOG_FILE" 2>/dev/null || echo "0")
            if [ "$line_count" -gt 1000 ]; then
                tail -n 800 "$EED_DEBUG_LOG_FILE" > "$EED_DEBUG_LOG_FILE.tmp" 2>/dev/null && \
                mv "$EED_DEBUG_LOG_FILE.tmp" "$EED_DEBUG_LOG_FILE" 2>/dev/null
            fi
        fi
    fi
    
    # Optionally show to user (for debug mode or important warnings)
    if [ "$show_to_user" = "true" ]; then
        echo "$message" >&2
    fi
}

# Show help information
show_help() {
    cat << 'EOF'
Usage: eed [OPTIONS] <file> [ed_script | -]

AI-oriented text editor with bulletproof safety guarantees

OPTIONS:
  -m, --message <msg>  Auto-commit changes with specified message (git repos only)
  --debug         Show detailed debugging information
  --disable-auto-reorder  Disable automatic command reordering
  --undo          Undo last eed-history commit (git reset --hard HEAD~1)
  --help          Show this help message

ARGUMENTS:
  file            Target file to edit (will be created if it doesn't exist)
  ed_script       Ed commands as string, or '-' to read from stdin
  -               Read ed script from stdin (alternative to ed_script)

WORKFLOW MODES:
  Git repositories:
    With -m: Auto-commit mode (edit file → stage → commit automatically)
    Without -m: Manual commit mode (edit file → stage → show commit instructions)

  Non-git directories:
    Preview mode (edit → create .eed.preview → show apply instructions)

EXAMPLES:
  # Auto-commit mode (git repos)
  eed -m "Fix validation logic" file.js $'2c\nvalidated input\n.\nw\nq'

  # Manual commit mode (git repos)
  eed file.js $'2c\nvalidated input\n.\nw\nq'
  # Then: commit file.js "Fix validation logic"

  # Preview mode (non-git)
  eed file.txt $'1a\nHello\n.\nw\nq'
  # Then: mv file.txt.eed.preview file.txt

  # Read from stdin with heredoc (recommended for complex scripts)
  eed /unix/style/path/to/file - <<'EOF'
  # ed commands here
  w
  q
  EOF

SAFETY FEATURES:
  - Original files never corrupted
  - Auto-saves uncommitted work before edits
  - Automatic command reordering
  - Line number validation
  - Git integration with undo support
EOF
}

# Cross-platform line normalization for Git Bash/Windows compatibility
# Removes trailing \r characters that cause CRLF issues
normalize_line() {
    local line="$1"
    # Remove trailing \r if present (CRLF -> LF)
    echo "${line%$'\r'}"
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
# Unified error reporting function
# Usage: error_exit "message" [exit_code] [show_usage_or_custom_message]
error_exit() {
    local message="$1"
    local exit_code="${2:-1}"
    local second_message="${3:-}"
    
    # Standardized error format
    echo "✗ Error: $message" >&2
    
    # Debug mode: show basic stack info
    if [ "${DEBUG_MODE:-}" = "true" ]; then
        echo "  Location: ${BASH_SOURCE[1]##*/}:${BASH_LINENO[0]} in ${FUNCNAME[1]}()" >&2
    fi
    
    # Handle second message (usage hint or custom message)
    if [ "$second_message" = "true" ]; then
        echo "Use 'eed --help' for usage information" >&2
    elif [ -n "$second_message" ] && [ "$second_message" != "false" ]; then
        echo "$second_message" >&2
    fi
    
    exit "$exit_code"
}

