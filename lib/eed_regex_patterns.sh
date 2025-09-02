#!/bin/bash
# eed_regex_patterns.sh - Shared regex constants for eed complex pattern detection

# Disable history expansion to prevent ! from causing issues
set +H

# Source guard to prevent multiple inclusion
if [ "${EED_REGEX_PATTERNS_LOADED:-}" = "1" ]; then
    return 0
fi
EED_REGEX_PATTERNS_LOADED=1

# --- REGEX CONSTANTS ---

# Character class representing all single-letter commands that modify file content
readonly EED_MODIFYING_COMMAND_CHARS='[dDcCbBiIaAsSjJmMtT]'

# Detects g/v blocks that end with a modifying command
# Example matches: g/pattern/d, v/test/c
# Example non-matches: g/pattern/p, g/test/n
readonly EED_REGEX_GV_MODIFYING="^[[:space:]]*[gvGV]/.*[/]${EED_MODIFYING_COMMAND_CHARS}$"

# Detects non-numeric addresses (/, ?, .) combined with a modifying command
# Example matches: /pattern/d, .s/old/new/
# Example non-matches: /pattern/p, .p
readonly EED_REGEX_NON_NUMERIC_MODIFYING="^[[:space:]]*[\./\?].*${EED_MODIFYING_COMMAND_CHARS}$"

# Detects offset addresses (., $ combined with +/-) with a modifying command
# Example matches: .-5d, $+3c, .-2,.+2s
# Example non-matches: .-5p, $-3,$p, .+5
readonly EED_REGEX_OFFSET_MODIFYING="^[[:space:]]*[\.\$][+-][0-9].*${EED_MODIFYING_COMMAND_CHARS}$"

# --- BASIC PATTERNS ---

# Address patterns - clean separation between raw patterns and grouped versions
readonly EED_ADDR_NUM='[0-9]+'
readonly EED_ADDR_DOT='\.'
readonly EED_ADDR_DOLLAR='\$'
readonly EED_ADDR_SEARCH_FWD='/([^/\\]|\\.)*/'
readonly EED_ADDR_SEARCH_BWD='\?([^?\\]|\\.)*\?'

readonly EED_ADDR="(${EED_ADDR_NUM}|${EED_ADDR_DOT}|${EED_ADDR_DOLLAR}|${EED_ADDR_SEARCH_FWD}|${EED_ADDR_SEARCH_BWD})"
readonly EED_RANGE="${EED_ADDR},${EED_ADDR}"

# View command character classes
readonly EED_VIEW_CHARS='pPnNlL='
readonly EED_VIEW_CLASS="[${EED_VIEW_CHARS}]"

readonly EED_REGEX_VIEW_CMD="${EED_VIEW_CLASS}"
readonly EED_MODIFY_CMDS='[dDmMtTjJsSuU]'
readonly EED_INPUT_CMDS='[aAcCiI]'

# --- CENTRALIZED REGEX PATTERNS ---
# These patterns were previously scattered across multiple files

# Basic ed command patterns (from eed_validator.sh)
readonly EED_REGEX_INPUT_BASIC='^[0-9]*[aciACI]$'
readonly EED_REGEX_WRITE_BASIC='^w$'
readonly EED_REGEX_QUIT_BASIC='^q$'

# Address with command patterns (replaces multiple instances)
readonly EED_REGEX_ADDR_CMD='^([0-9]+)(,([0-9]+|\$))?([dDcCbBiIaAsS])'
readonly EED_REGEX_MOVE_TRANSFER='^[[:space:]]*[0-9]*,?[0-9]*[mMtTrR]'

# Input mode detection pattern (from eed_common.sh)
readonly EED_REGEX_INPUT_MODE='^(\.|[0-9]+)?,?(\$|[0-9]+)?[aAcCiI]$'

# --- Substitute command regex detection ---
# Some Bash builds (e.g. Git Bash on Windows) choke on complex alternation + backrefs.
# We auto-detect if strict regex works; otherwise fall back to a simpler version.

detect_substitute_regex() {
    local probe strict fallback

    probe="s/x/x/"
    strict='s(.)([^\\]|\\.)*\1([^\\]|\\.)*\1([0-9]+|[gp]+)?$'
    # Fallback: very permissive - allow any characters including backslashes, non-space delimiters
    fallback='s([^[:space:]]).*\1.*\1([0-9gp]*)?$'

    # Require all probes to pass
    if [[ "s/.*console\.log.*;//" =~ $strict ]]; then
        echo "$strict"
    else
        echo "$fallback"
    fi
}

readonly EED_REGEX_SUBSTITUTE_CORE="$(detect_substitute_regex)"
unset -f detect_substitute_regex

# Command-specific patterns
readonly EED_REGEX_WRITE_CMD='^w( .*)?$'
readonly EED_REGEX_QUIT_CMD='^[qQ]$'
readonly EED_REGEX_GLOBAL_CMD='^[gv]/.*/[pgPnNdDsS]?$'
readonly EED_REGEX_FORWARD_SEARCH='^/[^/]*/[pPnNlL=]?$'
readonly EED_REGEX_BACKWARD_SEARCH='^\?.*\?[pP]?$'
readonly EED_REGEX_RANGE_SEARCH='^/.*/([+-][0-9]+)?,/.*/([+-][0-9]+)?[pP]?$'


# --- COMMAND MATCHING FUNCTIONS ---

is_view_command() {
  local line="$1"
  [[ "$line" =~ ^${EED_VIEW_CLASS}$ ]] || \
  [[ "$line" =~ ^${EED_ADDR}${EED_VIEW_CLASS}$ ]] || \
  [[ "$line" =~ ^${EED_RANGE}${EED_VIEW_CLASS}$ ]] || \
  [[ "$line" =~ ^,${EED_VIEW_CLASS}$ ]]
}

# Check if line is a modifying command (d, m, t, etc)
is_modifying_command() {
    local line="$1"
    # Single address or range with modifying command (delete, etc)
    [[ "$line" =~ ^${EED_ADDR}[dDjJsSuU]$ ]] || \
    [[ "$line" =~ ^${EED_RANGE}[dDjJsSuU]$ ]] || \
    # All lines: ,d (equivalent to 1,$d)
    [[ "$line" =~ ^,[dDjJsSuU]$ ]] || \
    # Move/transfer commands: 5m10, 1,3t7
    [[ "$line" =~ ^${EED_ADDR}[mMtT]${EED_ADDR}$ ]] || \
    [[ "$line" =~ ^${EED_RANGE}[mMtT]${EED_ADDR}$ ]]
}

# Check if line is an input command (a, c, i)
is_input_command() {
    local line="$1"
    # No address: a, c, i
    [[ "$line" =~ ^${EED_INPUT_CMDS}$ ]] || \
    # Single address: 5a, .c, $i
    [[ "$line" =~ ^${EED_ADDR}${EED_INPUT_CMDS}$ ]] || \
    # Range: 1,5c
    [[ "$line" =~ ^${EED_RANGE}${EED_INPUT_CMDS}$ ]]
}

# Check if line is a substitute command
is_substitute_command() {
    local line="$1" rest="$1"

    # Strip range prefix if present
    if [[ "$line" =~ ^${EED_RANGE} ]]; then
        rest="${line:${#BASH_REMATCH[0]}}"
    # Otherwise strip single address prefix if present  
    elif [[ "$line" =~ ^${EED_ADDR} ]]; then
        rest="${line:${#BASH_REMATCH[0]}}"
    fi

    # Use fixed core regex to check s command
    [[ "$rest" =~ ^${EED_REGEX_SUBSTITUTE_CORE} ]]
}

# Check if line is write command
is_write_command() {
    local line="$1"
    [[ "$line" =~ $EED_REGEX_WRITE_CMD ]]
}

# Check if line is quit command
is_quit_command() {
    local line="$1"
    [[ "$line" =~ $EED_REGEX_QUIT_CMD ]]
}

# Check if line is address-only (navigation)
is_address_only() {
    local line="$1"
    [[ "$line" =~ ^${EED_ADDR}$ ]]
}

# Check if line is global command
is_global_command() {
    local line="$1"
    [[ "$line" =~ $EED_REGEX_GLOBAL_CMD ]]
}

# Check if line is search command
is_search_command() {
    local line="$1"
    # Forward search: /pattern/ or /pattern/p
    [[ "$line" =~ $EED_REGEX_FORWARD_SEARCH ]] || \
    # Backward search: ?pattern? or ?pattern?p
    [[ "$line" =~ $EED_REGEX_BACKWARD_SEARCH ]] || \
    # Range search: /start/,/end/p
    [[ "$line" =~ $EED_REGEX_RANGE_SEARCH ]]
}
