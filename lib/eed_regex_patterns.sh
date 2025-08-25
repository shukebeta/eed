#!/bin/bash
# eed_regex_patterns.sh - Shared regex constants for eed complex pattern detection

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

# Address patterns
readonly EED_ADDR='(\.|[0-9]+|\$)'
readonly EED_RANGE="${EED_ADDR},${EED_ADDR}"

# Command character classes
readonly EED_VIEW_CMDS='[pPnNlL=]'
readonly EED_MODIFY_CMDS='[dDmMtTjJsSuU]' 
readonly EED_INPUT_CMDS='[aAcCiI]'

# --- COMMAND MATCHING FUNCTIONS ---

# Check if line is a view command (p, P, n, N, l, L, =)
is_view_command() {
    local line="$1"
    # No address: p, P, n, etc
    [[ "$line" =~ ^${EED_VIEW_CMDS}$ ]] || \
    # Single address: 5p, .n, $l
    [[ "$line" =~ ^${EED_ADDR}${EED_VIEW_CMDS}$ ]] || \
    # Range: 1,5p, .,/end/n
    [[ "$line" =~ ^${EED_RANGE}${EED_VIEW_CMDS}$ ]] || \
    # All lines: ,p (equivalent to 1,$p)
    [[ "$line" =~ ^,${EED_VIEW_CMDS}$ ]]
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
    local line="$1"
    # s/old/new/ or 1,$s/old/new/g
    [[ "$line" =~ ^s/.*/.*/[gp]*$ ]] || \
    [[ "$line" =~ ^${EED_ADDR}s/.*/.*/[gp]*$ ]] || \
    [[ "$line" =~ ^${EED_RANGE}s/.*/.*/[gp]*$ ]]
}

# Check if line is write command
is_write_command() {
    local line="$1"
    [[ "$line" =~ ^w( .*)?$ ]]
}

# Check if line is quit command
is_quit_command() {
    local line="$1" 
    [[ "$line" =~ ^[qQ]$ ]]
}

# Check if line is address-only (navigation)
is_address_only() {
    local line="$1"
    [[ "$line" =~ ^${EED_ADDR}$ ]]
}

# Check if line is global command
is_global_command() {
    local line="$1"
    [[ "$line" =~ ^[gv]/.*/[pPnNdDsS]?$ ]]
}

# Check if line is search command
is_search_command() {
    local line="$1"
    # Forward search: /pattern/ or /pattern/p
    [[ "$line" =~ ^/[^/]*/[pPnNlL=]?$ ]] || \
    # Backward search: ?pattern? or ?pattern?p  
    [[ "$line" =~ ^\?.*\?[pP]?$ ]] || \
    # Range search: /start/,/end/p
    [[ "$line" =~ ^/.*/([+-][0-9]+)?,/.*/([+-][0-9]+)?[pP]?$ ]]
}