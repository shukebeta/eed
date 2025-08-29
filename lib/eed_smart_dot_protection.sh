#!/bin/bash
# eed_smart_dot_protection.sh - Smart dot protection for ed tutorial/documentation editing

# Source guard to prevent multiple inclusion
if [ "${EED_SMART_DOT_LOADED:-}" = "1" ]; then
    return 0
fi
EED_SMART_DOT_LOADED=1

# Detect if the current context suggests ed tutorial/documentation editing
# Returns: 0 if high confidence (>=70), 1 if low confidence
# Outputs: confidence score (0-100) to stdout
detect_ed_tutorial_context() {
    local script="$1"
    local file_path="$2"
    local confidence=0
    
    # === FILE-BASED HEURISTICS (0-30 points) ===
    
    # Test files and documentation are strong indicators
    local filename
    filename=$(basename "$file_path")
    
    if [[ "$filename" == *test*.bats ]] || [[ "$filename" == test_*.* ]]; then
        confidence=$((confidence + 25))
    elif [[ "$filename" == *ed*.* ]] || [[ "$filename" == *tutorial*.* ]]; then
        confidence=$((confidence + 20))
    elif [[ "$filename" == *.md ]] || [[ "$filename" == *doc*.* ]]; then
        confidence=$((confidence + 15))
    fi
    
    # Path-based indicators
    if [[ "$file_path" == tests/* ]] || [[ "$file_path" == */tests/* ]]; then
        confidence=$((confidence + 20))
    elif [[ "$file_path" == docs/* ]] || [[ "$file_path" == */docs/* ]]; then
        confidence=$((confidence + 15))
    elif [[ "$file_path" == examples/* ]] || [[ "$file_path" == */examples/* ]]; then
        confidence=$((confidence + 10))
    fi
    
    # === CONTENT-BASED HEURISTICS (0-40 points) ===
    
    # Check for bats test patterns
    if echo "$script" | grep -q "run.*SCRIPT_UNDER_TEST"; then
        confidence=$((confidence + 20))
    fi
    
    if echo "$script" | grep -q "@test\\|#!/usr/bin/env bats"; then
        confidence=$((confidence + 15))
    fi
    
    # Look for ed command patterns in content (tutorial/documentation style)
    if echo "$script" | grep -qE "ed [a-zA-Z_./]+|1a\\\\n.*\\\\n\\."; then
        confidence=$((confidence + 15))
    fi
    
    # Check for shell/bash context indicators  
    if echo "$script" | grep -qE "\\$\\(|\\\\n|EOF|heredoc"; then
        confidence=$((confidence + 10))
    fi
    
    # === CONTEXT-BASED HEURISTICS (0-30 points) ===
    
    # Multiple dots is necessary but not sufficient
    local dot_count
    dot_count=$(echo "$script" | grep -c "^\\.$")
    if [ "$dot_count" -gt 1 ]; then
        confidence=$((confidence + 10))
    elif [ "$dot_count" -eq 0 ]; then
        # No dots means this is not the scenario we're designed for
        confidence=0
    fi
    
    # Presence of w/q commands suggests complete ed scripts (tutorials often have these)
    if echo "$script" | grep -qE "^[wqQ]$"; then
        confidence=$((confidence + 15))
    fi
    
    # Very short scripts are less likely to be tutorials
    local line_count
    line_count=$(echo "$script" | wc -l)
    if [ "$line_count" -lt 3 ]; then
        confidence=$((confidence - 10))
    elif [ "$line_count" -gt 10 ]; then
        confidence=$((confidence + 5))
    fi
    
    # Cap confidence at 100
    [ "$confidence" -gt 100 ] && confidence=100
    [ "$confidence" -lt 0 ] && confidence=0
    
    echo "$confidence"
    
    # Return success if confidence >= 70
    return $([ "$confidence" -ge 70 ] && echo 0 || echo 1)
}

# Transform content dots to unique markers while preserving ed terminator dots
# Input: ed script with potentially problematic dots
# Output: transformed script with substitution command
# Returns: 0 on success, 1 on failure
transform_content_dots() {
    local script="$1"
    
    # Generate unique marker to avoid conflicts
    local timestamp
    local random_suffix
    timestamp=$(date +%s)
    random_suffix=$(( RANDOM % 1000 ))
    local base_marker="~~DOT_${timestamp}_${random_suffix}~~"
    
    # Ensure marker is truly unique by checking against script content
    local marker="$base_marker"
    local counter=1
    while echo "$script" | grep -qF "$marker"; do
        marker="${base_marker}_${counter}"
        ((counter++))
        # Safety limit to prevent infinite loop
        if [ "$counter" -gt 100 ]; then
            echo "Error: Cannot generate unique marker" >&2
            return 1
        fi
    done
    
    # Parse script and identify input blocks
    local -a output_lines=()
    local in_input_mode=false
    local has_w_command=false
    local substitution_added=false
    
    while IFS= read -r line; do
        # Check if this is a write command (we'll add substitution before first w)
        if [[ "$line" =~ ^[[:space:]]*w([[:space:]]|$) ]] && [ "$substitution_added" = false ]; then
            output_lines+=("s/$marker/./g")
            substitution_added=true
            has_w_command=true
        fi
        
        # Handle input mode state transitions
        if [ "$in_input_mode" = false ]; then
            # Check if this line starts input mode (a, c, i commands)
            if [[ "$line" =~ ^[[:space:]]*[0-9,\$]*[[:space:]]*[aAcCiI]([[:space:]]|$) ]]; then
                in_input_mode=true
                output_lines+=("$line")
                continue
            else
                # Regular command line
                output_lines+=("$line")
                continue
            fi
        else
            # We're in input mode
            if [[ "$line" == "." ]]; then
                # This is the terminator - keep it as-is and exit input mode
                in_input_mode=false
                output_lines+=("$line")
            else
                # This is content - check for dots to replace
                local transformed_line
                transformed_line="${line//\./${marker}}"
                output_lines+=("$transformed_line")
            fi
        fi
    done <<< "$script"
    
    # Handle case where w command comes at the end or is missing
    if [ "$has_w_command" = false ]; then
        # Look for q command to add substitution before it
        local -a final_output=()
        local q_found=false
        
        for line in "${output_lines[@]}"; do
            if [[ "$line" =~ ^[[:space:]]*[qQ]([[:space:]]|$) ]] && [ "$q_found" = false ]; then
                final_output+=("s/$marker/./g")
                final_output+=("$line")
                q_found=true
            else
                final_output+=("$line")
            fi
        done
        
        output_lines=("${final_output[@]}")
    fi
    
    # Output the transformed script
    printf '%s\n' "${output_lines[@]}"
    return 0
}

# Main integration function - applies smart dot protection when appropriate  
# Returns: 0 if transformation applied, 1 if not applied
apply_smart_dot_protection() {
    local script="$1"
    local file_path="$2"
    
    # First check if we have the right context
    local confidence
    confidence=$(detect_ed_tutorial_context "$script" "$file_path")
    
    if [ "$confidence" -ge 70 ]; then
        # High confidence - apply transformation
        local transformed_script
        transformed_script=$(transform_content_dots "$script")
        if [ $? -eq 0 ]; then
            echo "✨ Smart dot protection applied for ed tutorial editing (confidence: ${confidence}%)" >&2
            echo "$transformed_script"
            return 0
        else
            echo "⚠️  Smart dot protection failed, falling back to standard handling" >&2
            echo "$script"
            return 1
        fi
    elif [ "$confidence" -ge 40 ]; then
        # Medium confidence - provide guidance but don't auto-transform
        echo "🤔 Detected possible ed tutorial editing (confidence: ${confidence}%)" >&2
        echo "   Consider using Edit/Write tools for complex cases or breaking into smaller operations" >&2
        echo "$script"
        return 1
    else
        # Low confidence - no action
        echo "$script"
        return 1
    fi
}