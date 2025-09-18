#!/bin/bash
# eed_smart_dot_protection.sh - Smart dot protection for ed tutorial/documentation editing

# Source guard to prevent multiple inclusion
if [ "${EED_SMART_DOT_LOADED:-}" = "1" ]; then
    return 0
fi
EED_SMART_DOT_LOADED=1


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

# Simplified integration function - applies smart dot protection when no_dot_trap indicates need
# Returns: 0 if transformation applied, 1 if not applied
apply_smart_dot_protection() {
    local script="$1"
    local file_path="$2"
    
    # Only apply transformation if no_dot_trap signals a potential trap.
    # Note: `no_dot_trap` returns non-zero when a potential dot-trap is detected,
    # so check the exit status and apply protection when it's non-zero.
    no_dot_trap "$script" >/dev/null
    local detect_rc=$?

    if [ "$detect_rc" -ne 0 ]; then
        local transformed_script
        if transformed_script=$(transform_content_dots "$script"); then
            echo "Smart dot protection applied" >&2
            echo "$transformed_script"
            return 0
        else
            # Transformation failed, return original
            echo "$script"
            return 1
        fi
    else
        # No protection needed, passthrough
        echo "$script"
        return 1
    fi
}

# Backwards-compatible wrapper for older callers
apply_smart_dot_handling() {
    apply_smart_dot_protection "$@"
}
