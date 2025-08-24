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