#!/bin/bash

# Comprehensive eed Security and Functionality Test Suite
# Tests the enhanced eed tool with security improvements
# 
# This test suite validates:
# - Basic functionality (insert, delete, replace)
# - Special character handling (quotes, dollar signs)
# - Windows path compatibility  
# - Error handling and backup/restore
# - Complex multi-command operations
# - Security validation (command injection prevention)
#
# Usage: ./test_eed_comprehensive.sh
# Requirements: eed tool must be in PATH

set -e
TEST_DIR="/tmp/eed_test_$$"
FAILED_TESTS=0
TOTAL_TESTS=0

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log() {
    echo -e "${GREEN}[TEST]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
    FAILED_TESTS=$((FAILED_TESTS + 1))
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

run_test() {
    local test_name="$1"
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    log "Running: $test_name"
}

setup() {
    mkdir -p "$TEST_DIR"
    cd "$TEST_DIR"
    log "Test environment created: $TEST_DIR"
}

cleanup() {
    cd /
    rm -rf "$TEST_DIR"
    log "Test environment cleaned up"
}

# Test 1: Basic functionality
test_basic_functionality() {
    run_test "Basic insert, delete, replace operations"
    
    cat > test1.txt << 'EOF'
line1
line2
line3
line4
line5
EOF
    
    # Test insert (needs . to end insert mode)
    eed test1.txt "3a" "inserted_line" "."
    if ! rg -q "inserted_line" test1.txt; then
        error "Insert operation failed"
        return
    fi
    
    # Test delete
    eed test1.txt "2d"
    if rg -q "line2" test1.txt; then
        error "Delete operation failed"
        return
    fi
    
    # Test replace (global replace in entire file)
    eed test1.txt "1,\$s/line1/replaced_line1/"
    if ! rg -q "replaced_line1" test1.txt; then
        error "Replace operation failed"
        return
    fi
    
    log "✓ Basic functionality tests passed"
}

# Test 2: Special character handling
test_special_characters() {
    run_test "Special character handling (quotes, backslashes, dollar signs)"
    
    cat > test2.txt << 'EOF'
normal line
EOF
    
    # Test single quotes
    eed test2.txt "1a" "line with 'single quotes'" "."
    if ! rg -q "line with 'single quotes'" test2.txt; then
        error "Single quote handling failed"
        return
    fi
    
    # Test double quotes
    eed test2.txt "2a" 'line with "double quotes"' "."
    if ! rg -q 'line with "double quotes"' test2.txt; then
        error "Double quote handling failed"
        return
    fi
    
    # Test backslashes (now using rg which handles patterns better)
    eed test2.txt "3a" 'line with \backslash' "."
    if ! rg -q "backslash" test2.txt; then
        error "Backslash handling failed"
        return
    fi
    
    # Test dollar signs (using single quotes to prevent shell expansion)
    eed test2.txt "4a" 'line with $dollar sign' "."
    if ! rg -q "dollar sign" test2.txt; then
        error "Dollar sign handling failed"
        return
    fi
    
    log "✓ Special character tests passed"
}

# Test 3: Windows path compatibility
test_windows_paths() {
    run_test "Windows path compatibility"
    
    # Create file with Windows-style path in content
    cat > test3.txt << 'EOF'
old_path=/usr/local/bin
EOF
    
    # Replace with Windows path containing special chars
    eed test3.txt 's|old_path=.*|new_path=C:\\Users\\Test$User\\Documents|'
    if ! rg -q "C:" test3.txt; then
        error "Windows path handling failed"
        return
    fi
    
    log "✓ Windows path compatibility tests passed"
}

# Test 4: Error handling and backup/restore
test_error_handling() {
    run_test "Error handling and backup/restore mechanisms"
    
    # Test non-existent file
    if eed nonexistent.txt 1a "test" 2>/dev/null; then
        error "Should fail on non-existent file"
        return
    fi
    
    # Test backup/restore on invalid command
    cat > test4.txt << 'EOF'
original content
EOF
    
    cp test4.txt test4.txt.backup
    
    # This should fail and restore backup
    if eed test4.txt "invalid_command" 2>/dev/null; then
        error "Should fail on invalid ed command"
        return
    fi
    
    # Check if original content is preserved
    if ! rg -q "original content" test4.txt; then
        error "Backup/restore mechanism failed"
        return
    fi
    
    log "✓ Error handling tests passed"
}

# Test 5: Complex multi-command operations
test_complex_operations() {
    run_test "Complex multi-command operations"
    
    cat > test5.txt << 'EOF'
function oldName() {
    console.log("debug");
    return result;
}
EOF
    
    # Test function rename
    eed test5.txt "1,\$s/oldName/newName/"
    if ! rg -q "newName" test5.txt; then
        error "Function rename failed"
        return
    fi
    
    # Test console.log removal
    eed test5.txt "1,\$s/.*console\.log.*;//"
    if rg -q "console.log" test5.txt; then
        error "Console.log removal failed"
        return
    fi
    
    # Test comment insertion
    eed test5.txt "2a" "    // Added comment" "."
    if ! rg -q "Added comment" test5.txt; then
        error "Comment insertion failed"
        return
    fi
    
    log "✓ Complex operations tests passed"
}

# Test 6: Security validation
test_security_validation() {
    run_test "Security injection attempts"
    
    cat > test6.txt << 'EOF'
safe content
EOF
    
    # Attempt command injection
    eed test6.txt "1a" "; rm -rf /tmp; echo malicious" "." 2>/dev/null || true
    # Check if malicious command was executed by looking for side effects
    if [ ! -f test6.txt ]; then
        error "Potential command injection vulnerability"
        return
    fi
    
    # Test with shell metacharacters
    eed test6.txt "2a" "line with | & ; < > characters" "."
    if ! rg -q "characters" test6.txt; then
        error "Shell metacharacter handling failed"
        return
    fi
    
    log "✓ Security validation tests passed"
}

# Main test execution
main() {
    log "Starting comprehensive eed test suite"
    log "Testing enhanced eed with security improvements"
    
    setup
    
    test_basic_functionality
    test_special_characters  
    test_windows_paths
    test_error_handling
    test_complex_operations
    test_security_validation
    
    cleanup
    
    echo
    if [ $FAILED_TESTS -eq 0 ]; then
        log "🎉 All $TOTAL_TESTS tests passed!"
        exit 0
    else
        error "❌ $FAILED_TESTS out of $TOTAL_TESTS tests failed"
        exit 1
    fi
}

main "$@"
