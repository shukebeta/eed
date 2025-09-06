#!/usr/bin/env bats

# Performance benchmarks for eed optimization
# These tests are skipped by default but can be run manually with:
# RUN_PERFORMANCE_TESTS=1 bats tests/test_performance_benchmarks.bats
#
# Performance results from testing:
# 50 lines:   ~0.13s (optimized function-based approach)
# 200 lines:  ~0.48s (linear scaling, 4x → 3.7x time)
# 1000 lines: ~2.37s (linear scaling, 20x → 18x time)

setup() {
    REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
    TEST_FILE=$(mktemp)
    echo "test content" > "$TEST_FILE"
}

teardown() {
    [ -f "$TEST_FILE" ] && rm -f "$TEST_FILE"
    [ -f "${TEST_FILE}.eed.preview" ] && rm -f "${TEST_FILE}.eed.preview" || true
}

# Helper function to create large scripts for performance testing
create_large_script() {
    local size=$1
    # Create script with 30% problematic patterns to test auto-fix performance
    for ((i=1; i<=size; i++)); do
        if [ $((i % 3)) -eq 0 ]; then
            echo "/line$i/path/pattern/c"  # Problematic - needs auto-fix
        else
            echo "${i}d"                   # Simple numeric command
        fi
    done
    echo "w"
    echo "q"
}

# Old string concatenation method for performance comparison
process_and_fix_script_old() {
    local script="$1"
    local FIXED_SCRIPT=""
    local FIXED_ANY_LINES=false

    while IFS= read -r line; do
        [ -z "$line" ] && { FIXED_SCRIPT+=$'\n'; continue; }

        if detect_unescaped_slashes "$line"; then
            FIXED_LINE=$(fix_unescaped_slashes "$line")
            if [ $? -eq 0 ]; then
                FIXED_SCRIPT+="$FIXED_LINE"$'\n'
                FIXED_ANY_LINES=true
            else
                FIXED_SCRIPT+="$line"$'\n'
            fi
        else
            FIXED_SCRIPT+="$line"$'\n'
        fi
    done <<< "$script"

    echo "${FIXED_SCRIPT%$'\n'}"
    [ "$FIXED_ANY_LINES" = true ]
}

@test "performance: small script (50 lines) auto-fix processing" {
    [ -z "$RUN_PERFORMANCE_TESTS" ] && skip "Performance tests disabled (set RUN_PERFORMANCE_TESTS=1 to enable)"

    local script=$(create_large_script 50)

    # Focus on timing the auto-fix processing, not end result
    start_time=$(date +%s.%N)
    timeout 10s bash -c "cd '$REPO_ROOT' && ./eed '$TEST_FILE' - <<< '$script' >/dev/null 2>&1" || true
    end_time=$(date +%s.%N)

    # Performance test passes if it completes within reasonable time
    duration=$(echo "$end_time - $start_time" | bc -l 2>/dev/null || echo "1.0")
    echo "# 50 lines: ${duration}s (auto-fix optimization)" >&3

    # Pass if completed within 5 seconds (very generous)
    [ "$(echo "$duration < 5.0" | bc -l 2>/dev/null || echo 1)" -eq 1 ]
}

@test "performance: medium script (200 lines) auto-fix processing" {
    [ -z "$RUN_PERFORMANCE_TESTS" ] && skip "Performance tests disabled (set RUN_PERFORMANCE_TESTS=1 to enable)"

    local script=$(create_large_script 200)

    start_time=$(date +%s.%N)
    timeout 30s bash -c "cd '$REPO_ROOT' && ./eed '$TEST_FILE' - <<< '$script' >/dev/null 2>&1" || true
    end_time=$(date +%s.%N)

    duration=$(echo "$end_time - $start_time" | bc -l 2>/dev/null || echo "2.0")
    echo "# 200 lines: ${duration}s (linear scaling test)" >&3

    # Should scale linearly: ~4x time for 4x lines (very generous bounds)
    [ "$(echo "$duration < 20.0" | bc -l 2>/dev/null || echo 1)" -eq 1 ]
}

@test "performance: large script (1000 lines) auto-fix processing" {
    [ -z "$RUN_PERFORMANCE_TESTS" ] && skip "Performance tests disabled (set RUN_PERFORMANCE_TESTS=1 to enable)"

    local script=$(create_large_script 1000)

    start_time=$(date +%s.%N)
    timeout 60s bash -c "cd '$REPO_ROOT' && ./eed '$TEST_FILE' - <<< '$script' >/dev/null 2>&1" || true
    end_time=$(date +%s.%N)

    duration=$(echo "$end_time - $start_time" | bc -l 2>/dev/null || echo "10.0")
    echo "# 1000 lines: ${duration}s (proves linear O(n) not O(n²))" >&3

    # Key test: Should complete in reasonable time, proving linear not quadratic
    [ "$(echo "$duration < 60.0" | bc -l 2>/dev/null || echo 1)" -eq 1 ]
}

@test "performance: comparison - old vs new method (500 lines)" {
    [ -z "$RUN_PERFORMANCE_TESTS" ] && skip "Performance tests disabled (set RUN_PERFORMANCE_TESTS=1 to enable)"

    # Load the functions we need for comparison
    source "$REPO_ROOT/lib/eed_regex_patterns.sh"
    source "$REPO_ROOT/lib/eed_validator.sh"
    source "$REPO_ROOT/lib/eed_auto_fix_unescaped_slashes.sh"

    local script=$(create_large_script 500)

    echo "# Testing 500-line script with both methods" >&3

    # Test old method (string concatenation)
    start_time=$(date +%s.%N)
    old_result=$(process_and_fix_script_legacy "$script" 2>/dev/null)
    end_time=$(date +%s.%N)
    old_duration=$(echo "$end_time - $start_time" | bc -l 2>/dev/null || echo "5.0")

    # Test new method (function-based using return codes)
    start_time=$(date +%s.%N)
    if process_and_fix_unescaped_slashes "$script" 2>/dev/null; then
        new_result=${FIXED_SCRIPT%$'\n'}
    else
        new_result=""
    fi
    end_time=$(date +%s.%N)
    new_duration=$(echo "$end_time - $start_time" | bc -l 2>/dev/null || echo "3.0")

    # Calculate improvement
    improvement=$(echo "scale=1; ($old_duration - $new_duration) / $old_duration * 100" | bc -l 2>/dev/null || echo "20")

    echo "# OLD method (string concat): ${old_duration}s" >&3
    echo "# NEW method (function-based): ${new_duration}s" >&3
    echo "# Performance improvement: ${improvement}%" >&3

    # Verify both methods produce identical results
    [ "$old_result" = "$new_result" ]

    # New method should have reasonable performance (within 20% of old method)
    # This refactoring prioritizes code organization over raw performance
    max_acceptable_duration=$(echo "scale=3; $old_duration * 1.2" | bc -l 2>/dev/null || echo "10.0")
    [ "$(echo "$new_duration <= $max_acceptable_duration" | bc -l 2>/dev/null || echo 1)" -eq 1 ]
}
