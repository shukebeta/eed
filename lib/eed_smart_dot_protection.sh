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

    # Empty script => no confidence
    if [ -z "$script" ]; then
        echo 0
        return 1
    fi

    local filename
    filename=$(basename "$file_path")

    # Immediately reject obvious source files to avoid false positives
    if [[ "$filename" =~ \.(c|cpp|h|hpp|py|js|ts|go|java|rs|swift|kt|m|mm)$ ]]; then
        echo 0
        return 1
    fi

    # Count standalone terminator dots (only lines that are exactly ".")
    local dot_count
    dot_count=$(printf '%s\n' "$script" | grep -c '^\.$' || true)
    if [ "$dot_count" -eq 0 ]; then
        # No terminator dots -> not the dot-trap scenario
        echo 0
        return 1
    fi

    # Require at least one strong contextual indicator (filename/path OR content markers)
    local has_strong_indicator=0

    # filename-level signals (include markdown/tutorial hints)
    if [[ "$filename" == *.bats ]] || [[ "$filename" == test_* ]] || [[ "$filename" == *.md ]] || [[ "$filename" == *tutorial* ]] || [[ "$filename" == *ed* ]]; then
        has_strong_indicator=1
    fi

    # path-level signals
    if [[ "$file_path" == tests/* ]] || [[ "$file_path" == */tests/* ]] || [[ "$file_path" == docs/* ]] || [[ "$file_path" == */docs/* ]]; then
        has_strong_indicator=1
    fi

    # script content signals (explicit bats/tutorial markers)
    if printf '%s\n' "$script" | grep -q -E 'run[[:space:]].*SCRIPT_UNDER_TEST|@test|#!/usr/bin/env bats|```bash|ed[[:space:]]+[[:alnum:]._/~-]+'; then
        has_strong_indicator=1
    fi

    # input-mode or write/quit lines are strong signals too (makes ambiguous . cases count)
    if printf '%s\n' "$script" | grep -q -E '^[[:space:]]*[0-9,]*[[:space:]]*[aciACI][[:space:]]*$' || printf '%s\n' "$script" | grep -q -E '^[[:space:]]*[wqQ][[:space:]]*$'; then
        has_strong_indicator=1
    fi

    # heredoc indicators
    if printf '%s\n' "$script" | grep -q '<<' || printf '%s\n' "$script" | grep -q 'EOF'; then
        has_strong_indicator=1
    fi

    if [ "$has_strong_indicator" -eq 0 ]; then
        # No contextual signals beyond dots -> avoid auto-transform
        echo 0
        return 1
    fi

    # Calculate confidence with conservative weights
    local confidence=0

    # File/path signals
    if [[ "$filename" == *.bats ]] || [[ "$filename" == test_* ]]; then
        confidence=$((confidence + 50))
    elif [[ "$filename" == *.md ]] || [[ "$filename" == *tutorial* ]] || [[ "$filename" == *ed* ]]; then
        confidence=$((confidence + 35))
    fi

    if [[ "$file_path" == tests/* ]] || [[ "$file_path" == */tests/* ]]; then
        confidence=$((confidence + 20))
    elif [[ "$file_path" == docs/* ]] || [[ "$file_path" == */docs/* ]]; then
        confidence=$((confidence + 15))
    fi

    # Content signals
    confidence=$((confidence + dot_count * 5))

    if printf '%s\n' "$script" | grep -q -E '^[[:space:]]*[wqQ][[:space:]]*$'; then
        confidence=$((confidence + 20))
    fi

    if printf '%s\n' "$script" | grep -q -E '^[[:space:]]*[0-9,]*[[:space:]]*[aciACI][[:space:]]*$'; then
        confidence=$((confidence + 10))
    fi

    if printf '%s\n' "$script" | grep -q -E 'run[[:space:]].*SCRIPT_UNDER_TEST|@test|#!/usr/bin/env bats|```bash|ed[[:space:]]+[[:alnum:]._/~-]+'; then
        confidence=$((confidence + 20))
    fi

    if printf '%s\n' "$script" | grep -q '<<' || printf '%s\n' "$script" | grep -q 'EOF'; then
        confidence=$((confidence + 5))
    fi

    # Penalize extremely short scripts
    local line_count
    line_count=$(printf '%s\n' "$script" | wc -l)
    if [ "$line_count" -lt 2 ]; then
        confidence=$((confidence - 10))
    fi

    # Clamp
    [ "$confidence" -gt 100 ] && confidence=100
    [ "$confidence" -lt 0 ] && confidence=0

    echo "$confidence"
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
    
    local -i idx=0
    local -i last_w_index=-1
    local -i first_q_index=-1

    while IFS= read -r line; do
        # Handle input mode state transitions first
        if [ "$in_input_mode" = false ]; then
            # Check if this line starts input mode (a, c, i commands)
            if [[ "$line" =~ ^[[:space:]]*[0-9,\$]*[[:space:]]*[aAcCiI]([[:space:]]|$) ]]; then
                in_input_mode=true
                output_lines+=("$line")
                idx=$((idx + 1))
                continue
            else
                # We're not in input mode -> this is a command line.
                # Record write/quit indices based on the current output length
                if [[ "$line" =~ ^[[:space:]]*w([[:space:]]|$) ]]; then
                    last_w_index=${#output_lines[@]}
                fi
                if [[ "$line" =~ ^[[:space:]]*[qQ]([[:space:]]|$) ]] && (( first_q_index == -1 )); then
                    first_q_index=${#output_lines[@]}
                fi

                output_lines+=("$line")
                idx=$((idx + 1))
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
        idx=$((idx + 1))
    done <<< "$script"

    # Only add substitution if the marker was actually used in content.
    # This avoids inserting a noop substitution for empty input blocks.
    local marker_used=0
    for l in "${output_lines[@]}"; do
        if [[ "$l" == *"$marker"* ]]; then
            marker_used=1
            break
        fi
    done

    # If no marker was used (no content dots were replaced), return the original script
    # unchanged to avoid inserting any substitution lines or altering structure.
    if [ "$marker_used" -eq 0 ]; then
        printf '%s\n' "${output_lines[@]}"
        return 0
    fi

    # Decide best insertion point for the substitution command:
    # 1) before the last 'w' if present
    # 2) else before the first 'q'/'Q' if present
    # 3) else append at end
    if (( last_w_index >= 0 )); then
        local -a final_output=()
        for i in "${!output_lines[@]}"; do
            if [ "$i" -eq "$last_w_index" ]; then
                final_output+=("s/$marker/./g")
            fi
            final_output+=("${output_lines[$i]}")
        done
        output_lines=("${final_output[@]}")
    elif (( first_q_index >= 0 )); then
        local -a final_output=()
        for i in "${!output_lines[@]}"; do
            if [ "$i" -eq "$first_q_index" ]; then
                final_output+=("s/$marker/./g")
            fi
            final_output+=("${output_lines[$i]}")
        done
        output_lines=("${final_output[@]}")
    else
        output_lines+=("s/$marker/./g")
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