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

    # Check for strong contextual indicators using short-circuit evaluation
    if [[ "$filename" == *.bats ]] || [[ "$filename" == test_* ]] || [[ "$filename" == *.md ]] || [[ "$filename" == *tutorial* ]] || [[ "$filename" == *ed* ]]; then
        # filename-level signals (include markdown/tutorial hints)
        has_strong_indicator=1
    elif [[ "$file_path" == tests/* ]] || [[ "$file_path" == */tests/* ]] || [[ "$file_path" == docs/* ]] || [[ "$file_path" == */docs/* ]]; then
        # path-level signals
        has_strong_indicator=1
    elif printf '%s\n' "$script" | grep -q -E 'run[[:space:]].*SCRIPT_UNDER_TEST|@test|#!/usr/bin/env bats|```bash|ed[[:space:]]+[[:alnum:]._/~-]+'; then
        # script content signals (explicit bats/tutorial markers) - expensive check last
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

    # Content signals - be more conservative with dot scoring
    confidence=$((confidence + dot_count * 3))

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
    return 0
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
    
    # First pass: find the line number of the last standalone dot
    local -i last_dot_line=-1
    local -i line_num=0
    while IFS= read -r line; do
        line_num=$((line_num + 1))
        if [[ "$line" == "." ]]; then
            last_dot_line=$line_num
        fi
    done <<< "$script"
    
    # Parse script and identify input blocks, while tracking whether each output line
    # is a command (1) or input/content (0). This allows safe insertion of substitution
    # commands outside input blocks.
    local -a output_lines=()
    local -a line_is_command=()
    local in_input_mode=false

    local -i current_line=0
    local -i last_w_index=-1
    local -i first_q_index=-1
    local marker_used=0

    while IFS= read -r line; do
        current_line=$((current_line + 1))

        if [ "$in_input_mode" = false ]; then
            # Check if this line starts input mode (a, c, i commands)
            if [[ "$line" =~ ^[[:space:]]*[0-9,\$]*[[:space:]]*[aAcCiI]([[:space:]]|$) ]]; then
                in_input_mode=true
                output_lines+=("$line")
                line_is_command+=("1")
                continue
            fi

            # We're not in input mode -> this is a command line.
            # Record write/quit indices based on the current output length
            if [[ "$line" =~ ^[[:space:]]*w([[:space:]]|$) ]]; then
                last_w_index=${#output_lines[@]}
            fi
            if [[ "$line" =~ ^[[:space:]]*[qQ]([[:space:]]|$) ]] && (( first_q_index == -1 )); then
                first_q_index=${#output_lines[@]}
            fi

            output_lines+=("$line")
            line_is_command+=("1")
            continue
        else
            # We're in input mode (and not inside quoted blocks)
            if [[ "$line" == "." ]]; then
                if [ "$current_line" -eq "$last_dot_line" ]; then
                    # This is the final dot - preserve as terminator and exit input mode
                    output_lines+=("$line")
                    line_is_command+=("1")
                    in_input_mode=false
                else
                    # This is a content dot - replace with marker but stay in input mode
                    output_lines+=("${marker}")
                    line_is_command+=("0")
                    marker_used=1
                fi
            else
                # Regular content lines - preserve as-is (content)
                output_lines+=("$line")
                line_is_command+=("0")
            fi
        fi
    done <<< "$script"

    # Only add substitution if the marker was actually used in content.
    # This avoids inserting a noop substitution for empty input blocks.
    for idx in "${!output_lines[@]}"; do
        if [[ "${output_lines[$idx]}" == *"$marker"* ]]; then
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

    # Decide best insertion point for the substitution command.
    # Ensure the substitution is placed outside any input (a/c/i) blocks so ed
    # treats it as a command and not as text content.
    local safe_insert_idx=-1
    local in_input_state=false

    for i in "${!output_lines[@]}"; do
        line="${output_lines[$i]}"

        # Detect start of input mode when not already in one
        if [ "$in_input_state" = false ]; then
            if [[ "$line" =~ ^[[:space:]]*[0-9,\$]*[[:space:]]*[aAcCiI]([[:space:]]|$) ]]; then
                in_input_state=true
                continue
            fi
        else
            # Inside input mode; look for terminator
            if [[ "$line" == "." ]]; then
                in_input_state=false
            fi
            continue
        fi

        # Only consider candidate command lines when not in input mode
        if [ "$in_input_state" = false ]; then
            if [[ "$line" =~ ^[[:space:]]*w([[:space:]]|$) ]] && [[ "${line_is_command[$i]}" == "1" ]]; then
                safe_insert_idx=$i
                break
            fi
            if [[ "$line" =~ ^[[:space:]]*[qQ]([[:space:]]|$) ]] && [ "$safe_insert_idx" -eq -1 ] && [[ "${line_is_command[$i]}" == "1" ]]; then
                safe_insert_idx=$i
            fi
        fi
    done

        if [ "$safe_insert_idx" -ge 0 ]; then
        local -a final_output=()
        for i in "${!output_lines[@]}"; do
                if [ "$i" -eq "$safe_insert_idx" ]; then
                final_output+=("1,\$s@${marker}@.@g")
            fi
            final_output+=("${output_lines[$i]}")
        done
        output_lines=("${final_output[@]}")
    else
        # No safe command position found; attempt to insert after the last terminating '.'
        local -i insert_at_index=${#output_lines[@]}
        for (( j=${#output_lines[@]}-1; j>=0; j-- )); do
            if [[ "${output_lines[$j]}" == "." ]]; then
                insert_at_index=$((j+1))
                break
            fi
        done

        if [ "$insert_at_index" -lt ${#output_lines[@]} ]; then
            local -a final_output=()
            for i in "${!output_lines[@]}"; do
                if [ "$i" -eq "$insert_at_index" ]; then
                    final_output+=("1,\$s@${marker}@.@g")
                fi
                final_output+=("${output_lines[$i]}")
            done
            output_lines=("${final_output[@]}")
        else
            output_lines+=("1,\$s@${marker}@.@g")
        fi
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
        if transformed_script=$(transform_content_dots "$script"); then
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

# Backwards-compatible wrapper for older callers
apply_smart_dot_handling() {
    apply_smart_dot_protection "$@"
}
