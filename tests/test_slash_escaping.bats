#!/usr/bin/env bats

# Test slash escaping detection functionality

setup() {
    # Determine repository root using BATS_TEST_DIRNAME
    REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
    
    # Source the required functions
    source "$REPO_ROOT/lib/eed_regex_patterns.sh"
    source "$REPO_ROOT/lib/eed_validator.sh"
    source "$REPO_ROOT/lib/eed_auto_fix_unescaped_slashes.sh"
}

# Test detect_unescaped_slashes function - positive cases
@test "detect_unescaped_slashes: should detect problematic single patterns" {
    run detect_unescaped_slashes "/foo/bar/c"
    [ "$status" -eq 0 ]
    
    run detect_unescaped_slashes "////c"
    [ "$status" -eq 0 ]
    
    run detect_unescaped_slashes "/path/to/file/d"
    [ "$status" -eq 0 ]
    
    run detect_unescaped_slashes "/start/end/i"
    [ "$status" -eq 0 ]
    
    run detect_unescaped_slashes "/a/b/a"
    [ "$status" -eq 0 ]
}

@test "detect_unescaped_slashes: should detect problematic range patterns" {
    run detect_unescaped_slashes "/start/foo/,/end/bar/c"
    [ "$status" -eq 0 ]
    
    run detect_unescaped_slashes "/a/b/,/c/d/i"  
    [ "$status" -eq 0 ]
    
    run detect_unescaped_slashes "//start/,//end/d"
    [ "$status" -eq 0 ]
}

@test "detect_unescaped_slashes: should NOT detect valid patterns" {
    run detect_unescaped_slashes "/pattern/c"
    [ "$status" -eq 1 ]
    
    run detect_unescaped_slashes "/foo\/bar/c"
    [ "$status" -eq 1 ]
    
    run detect_unescaped_slashes "/simple/d"
    [ "$status" -eq 1 ]
    
    run detect_unescaped_slashes "/pat1/,/pat2/c"
    [ "$status" -eq 1 ]
}

@test "detect_unescaped_slashes: should NOT detect non-search commands" {
    run detect_unescaped_slashes "5d"
    [ "$status" -eq 1 ]
    
    run detect_unescaped_slashes "s/old/new/g"
    [ "$status" -eq 1 ]
    
    run detect_unescaped_slashes "1,5p"
    [ "$status" -eq 1 ]
    
    run detect_unescaped_slashes "w"
    [ "$status" -eq 1 ]
}

@test "detect_unescaped_slashes: original user case should be detected" {
    # This is the actual case from the user that triggered this feature request
    run detect_unescaped_slashes "//// Gets the earliest value date acceptable to two TRM's after a specified minimum value date/c"
    [ "$status" -eq 0 ]
    
    run detect_unescaped_slashes "//// This is value date to use for the broker contracts/c"
    [ "$status" -eq 0 ]
    
    run detect_unescaped_slashes "//// <param name=\"liquidityManager\">Whether or not this is for Ria Rails<\/param>/d"
    [ "$status" -eq 0 ]
}

# Test fix_unescaped_slashes function
@test "fix_unescaped_slashes: should fix single patterns" {
    run fix_unescaped_slashes "/foo/bar/c"
    [ "$status" -eq 0 ]
    [ "$output" = "/foo\/bar/c" ]
    
    run fix_unescaped_slashes "/path/to/file/d"
    [ "$status" -eq 0 ]
    [ "$output" = "/path\/to\/file/d" ]
    
    run fix_unescaped_slashes "////a"
    [ "$status" -eq 0 ]
    [ "$output" = "/\/\//a" ]
}

@test "fix_unescaped_slashes: should fix range patterns" {
    run fix_unescaped_slashes "/start/foo/,/end/bar/c"
    [ "$status" -eq 0 ]
    [ "$output" = "/start\/foo/,/end\/bar/c" ]
    
    run fix_unescaped_slashes "/a/b/,/c/d/i"
    [ "$status" -eq 0 ]
    [ "$output" = "/a\/b/,/c\/d/i" ]
}

@test "fix_unescaped_slashes: should not modify valid patterns" {
    run fix_unescaped_slashes "/pattern/c"
    [ "$status" -eq 1 ]  # No fix needed
    [ "$output" = "/pattern/c" ]
    
    run fix_unescaped_slashes "/foo\/bar/c"  
    [ "$status" -eq 1 ]  # Already escaped
    [ "$output" = "/foo\/bar/c" ]
    
    run fix_unescaped_slashes "/pat1/,/pat2/c"
    [ "$status" -eq 1 ]  # Valid range pattern
    [ "$output" = "/pat1/,/pat2/c" ]
}

@test "fix_unescaped_slashes: original user cases should be fixed" {
    run fix_unescaped_slashes "//// Gets the earliest value date acceptable to two TRM's after a specified minimum value date/c"
    [ "$status" -eq 0 ]
    [ "$output" = "/\/\/\/ Gets the earliest value date acceptable to two TRM's after a specified minimum value date/c" ]
    
    run fix_unescaped_slashes "//// This is value date to use for the broker contracts/c"
    [ "$status" -eq 0 ]
    [ "$output" = "/\/\/\/ This is value date to use for the broker contracts/c" ]
}
