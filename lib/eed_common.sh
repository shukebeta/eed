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
  -m, --message <msg>  Auto-commit with custom message (default: "Quick edit on <file> at HH:MM")
  --debug              Show detailed debugging information
  --disable-auto-reorder  Disable automatic command reordering
  --help               Show this help message

ARGUMENTS:
  file            Target file to edit (will be created if it doesn't exist)
  ed_script       Ed commands as string, or '-' to read from stdin
  -               Read ed script from stdin (alternative to ed_script)

WORKFLOW MODES:
  Git repositories:
    Always auto-commit mode (edit file → stage → commit automatically)
    Use -m to provide custom commit message (default: quick edit with file path and time)

  Non-git directories:
    Preview mode (edit → create .eed.preview → show apply instructions)

EXAMPLES:
  # Auto-commit with custom message (git repos)
  eed -m "Fix validation logic" file.js $'2c\nvalidated input\n.\nw\nq'

  # Auto-commit with quick edit message (git repos)
  eed file.js $'2c\nvalidated input\n.\nw\nq'
  # Commits as "eed-history: Quick edit on file.js at HH:MM"
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

# Cross-platform relative path calculation (pure Bash)
# Works on all Unix-like systems without external dependencies
# Usage: get_relative_path <target_path> <base_path>
# Returns the relative path from base_path to target_path
get_relative_path() {
    if [ $# -ne 2 ]; then
        echo "usage: get_relative_path <target> <base>" >&2
        return 1
    fi
    local target="$1"
    local base="$2"

    _normalize_path() {
        # Converts arbitrary path to an absolute, lexically normalized form (no symlink resolution)
        # Removes '.', processes '..', collapses multiple slashes
        local p="$1"
        local cwd
        cwd=$(pwd)

        # If empty → treat as "."
        [ -z "$p" ] && p="."

        # If not absolute, prepend current working directory
        case "$p" in
            /*) ;;  # already absolute
            *) p="$cwd/$p" ;;
        esac

        # Collapse multiple slashes
        while [[ "$p" == *'//'* ]]; do p="${p//\/\//\/}"; done

        # Split into components
        local IFS='/'
        read -r -a parts <<< "$p"

        local -a stack=()
        local comp
        for comp in "${parts[@]}"; do
            case "$comp" in
                ''|'.')  # ignore empty (leading slash gives first empty) and '.'
                    continue
                    ;;
                '..')
                    if [ "${#stack[@]}" -gt 0 ]; then
                        unset 'stack[${#stack[@]}-1]'
                    fi
                    # If stack empty → we are at root; keep ignoring extra ..
                    ;;
                *)
                    stack+=("$comp")
                    ;;
            esac
        done

        # Reconstruct
        local out="/"
        if [ "${#stack[@]}" -gt 0 ]; then
            local joined
            local IFS='/'
            joined="${stack[*]}"
            out="/$joined"
        fi
        printf '%s\n' "$out"
    }

    local norm_target norm_base
    norm_target=$(_normalize_path "$target")
    norm_base=$(_normalize_path "$base")

    # Quick identical check
    if [ "$norm_target" = "$norm_base" ]; then
        printf '.\n'
        return 0
    fi

    # Split paths into component arrays
    _split_components() {
        local path="$1"
        local IFS='/'
        read -r -a _out <<< "${path#/}"   # strip leading '/'
    }

    local -a tgt_parts base_parts
    _split_components "$norm_target"
    tgt_parts=("${_out[@]}")
    _split_components "$norm_base"
    base_parts=("${_out[@]}")

    # Find common prefix length
    local i max common_len=0
    local max_t=${#tgt_parts[@]}
    local max_b=${#base_parts[@]}
    if [ $max_t -lt $max_b ]; then
        max=$max_t
    else
        max=$max_b
    fi

    for (( i=0; i<max; i++ )); do
        if [ "${tgt_parts[i]}" = "${base_parts[i]}" ]; then
            common_len=$((common_len+1))
        else
            break
        fi
    done

    # How many levels to go up from base to common
    local up_count=$(( ${#base_parts[@]} - common_len ))
    local rel=""
    local j
    for (( j=0; j<up_count; j++ )); do
        if [ -z "$rel" ]; then
            rel=".."
        else
            rel="$rel/.."
        fi
    done

    # Append remaining target components
    local k
    for (( k=common_len; k<${#tgt_parts[@]}; k++ )); do
        if [ -z "$rel" ]; then
            rel="${tgt_parts[k]}"
        else
            rel="$rel/${tgt_parts[k]}"
        fi
    done

    [ -z "$rel" ] && rel="."   # Defensive fallback
    printf '%s\n' "$rel"
}


# Robust boolean parsing: accepts true/false (recommended) and 1/0 (compatibility)
parse_boolean() {
    local value="$1"
    if [ "$value" = "true" ] || [ "$value" = "1" ]; then
        echo "true"
    else
        echo "false"
    fi
}


# Execute preview mode: Create preview file and show diff
# Parameters: file_path, preview_file, ed_script, is_git_repo, debug_mode
execute_preview_mode() {
    local file_path="$1"
    local preview_file="$2"
    local ed_script="$3"
    local is_git_repo="$4"
    local debug_mode="$5"

    # Create file if it doesn't exist (after all validation passes)
    if [ ! -f "$file_path" ]; then
        mkdir -p "$(dirname "$file_path")"
        echo "" > "$file_path"
        echo "Creating new file: $file_path" >&2
    fi

    # Copy file and execute ed
    cp "$file_path" "$preview_file"

    if [ "$debug_mode" = true ]; then
        echo "Debug mode: executing ed" >&2
    fi

    if ! printf '%s\n' "$ed_script" | ed -s "$preview_file"; then
        echo "✗ Edit command failed" >&2
        echo "  No changes were made to the original file." >&2
        echo "Commands attempted:" >&2
        printf '%s\n' "$ed_script" >&2
        rm -f "$preview_file"
        exit 1
    fi

    # Show preview results
    echo "✨ Edits applied to a temporary preview. Review the changes below:"
    echo

    if diff -q "$file_path" "$preview_file" >/dev/null 2>&1; then
        echo "No changes were made to the file content."
        # Don't remove preview file, keep it around for test verification
        if [ "$debug_mode" = true ]; then
            echo "Debug mode: No changes needed, preview file kept" >&2
        fi
    else
        # Show the diff using git diff for better formatting
        if command -v git >/dev/null 2>&1; then
            # Show diff and ignore status since finding changes returns 1
            git diff --no-index --no-prefix "$file_path" "$preview_file" || true
        else
            # Show diff and ignore exit status since differences cause non-zero
            diff -u "$file_path" "$preview_file" || true
        fi

        echo
        echo "To apply these changes, run:"
        # Check if we're in a git repository for enhanced suggestions
        if [ "$is_git_repo" = true ]; then
            echo "  commit '$file_path' \"your commit message\""
        else
            echo "  mv '$preview_file' '$file_path'"
        fi

        echo
        echo "To discard these changes, run:"
        echo "  rm '$preview_file'"
    fi
}
