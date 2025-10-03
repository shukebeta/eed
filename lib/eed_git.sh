#!/bin/bash
# eed_git.sh - Git-specific operations for eed

# Source guard to prevent multiple inclusion
if [ "${EED_GIT_LOADED:-}" = "1" ]; then
    return 0
fi
EED_GIT_LOADED=1

# Normalize git repository root path for cross-platform compatibility
# On Windows/gitbash, git returns Windows-style paths but other commands use Unix-style
normalize_git_root() {
    local git_root="$1"
    if [ -z "$git_root" ]; then
        echo ""
        return
    fi

    # On Windows with gitbash, convert Windows path to Unix format
    if command -v cygpath >/dev/null 2>&1; then
        cygpath -u "$git_root"
    else
        echo "$git_root"
    fi
}

# Auto-save any uncommitted work in progress before making new edits
# Assumes we're already in a git repository
auto_save_work_in_progress() {
    local file_path="$1"

    # Find the git repository root containing the target file
    local repo_root
    repo_root=$(git -C "$(dirname "$file_path")" rev-parse --show-toplevel 2>/dev/null)
    if [ -z "$repo_root" ]; then return 0; fi # Not in a git repository
    repo_root=$(normalize_git_root "$repo_root")

    # Normalize repo_root to match file_path format (resolve symlinks)
    # Use pwd -P to resolve symlinks (more reliable than realpath on GitBash)
    repo_root=$(cd "$repo_root" && pwd -P)

    # Auto-save if there are ANY uncommitted changes (working directory OR index)
    # Critical fix: Check both unstaged (working directory) AND staged (index) changes
    if ! git -C "$repo_root" diff --quiet || ! git -C "$repo_root" diff --cached --quiet; then
        echo "Auto-saving work in progress..." >&2
        # Add ALL changes from repo root, commit from repo root
        git -C "$repo_root" add -A && git -C "$repo_root" commit -m "eed-history: WIP auto-save before new edit" --no-verify --quiet
    fi
}

# Handle --undo command: Revert last eed-history commit
handle_undo_command() {
    # Find git repository root from current directory
    local repo_root=""
    if ! repo_root=$(git rev-parse --show-toplevel 2>/dev/null); then
        echo "Error: Not in a git repository" >&2
        exit 1
    fi
    repo_root=$(normalize_git_root "$repo_root")

    # Find the most recent eed-history commit
    local last_eed_commit_hash=""
    last_eed_commit_hash=$(git -C "$repo_root" log --grep="eed-history:" --format=%H -n 1)

    if [ -z "$last_eed_commit_hash" ]; then
        echo "Error: No eed-history commit found to undo" >&2
        echo "Use 'git log --grep=\"eed-history:\"' to see all eed commits" >&2
        exit 1
    fi

    # Show what will be reverted
    echo "Found eed-history commit to revert:"
    git -C "$repo_root" log --oneline -1 "$last_eed_commit_hash"
    echo

    # Perform the revert
    if git -C "$repo_root" revert --no-edit "$last_eed_commit_hash"; then
        echo "Last eed-history commit undone"
        echo "   Original commit preserved in history for audit trail."
        echo "   To undo this revert (restore the changes), run:"
        echo "     git revert HEAD"
    else
        echo "❌ git revert failed. This may be due to merge conflicts." >&2
        echo "   Please resolve conflicts manually and complete the revert:" >&2
        echo "     git revert --continue  (after resolving conflicts)" >&2
        echo "     git revert --abort     (to cancel the revert)" >&2
        exit 1
    fi
    exit 0
}

# Execute git mode: Direct file editing with auto-commit or manual commit
# Parameters: file_path, ed_script, repo_root, auto_commit_mode, commit_message, debug_mode
execute_git_mode() {
    local file_path="$1"
    local ed_script="$2"
    local repo_root="$3"
    local auto_commit_mode="$4"
    local commit_message="$5"
    local debug_mode="$6"

    # Normalize file path to absolute path FIRST (resolve symlinks like /tmp)
    # This must happen before any git operations to ensure consistent paths
    # Use pwd -P to resolve symlinks (more reliable than realpath on GitBash)
    if [ -e "$file_path" ]; then
        file_path=$(cd "$(dirname "$file_path")" && pwd -P)/$(basename "$file_path")
    elif [ -e "$(dirname "$file_path")" ]; then
        file_path=$(cd "$(dirname "$file_path")" && pwd -P)/$(basename "$file_path")
    fi
    repo_root=$(cd "$repo_root" && pwd -P)

    # Create file if it doesn't exist (after path normalization)
    if [ ! -f "$file_path" ]; then
        mkdir -p "$(dirname "$file_path")"
        echo "" > "$file_path"
        echo "Creating new file: $file_path" >&2
    fi

    # Auto-save work in progress if there are uncommitted changes
    auto_save_work_in_progress "$file_path"

    # Store original content for rollback if needed
    local original_content
    original_content=$(cat "$file_path")

    # Execute ed commands directly on the file
    if [ "$debug_mode" = true ]; then
        echo "Debug mode: executing ed on file directly" >&2
    fi

    if ! printf '%s\n' "$ed_script" | ed -s "$file_path"; then
        echo "✗ Edit command failed" >&2
        echo "  Restoring original file content." >&2
        echo "$original_content" > "$file_path"
        exit 1
    fi

    # Check if any changes were made
    if diff -q <(echo "$original_content") "$file_path" >/dev/null 2>&1; then
        echo "No changes were made to the file content."
        exit 0
    fi

    # Handle auto-commit vs manual commit
    if [ "$auto_commit_mode" = true ]; then
        # Auto-commit mode: commit and show result
        # Get relative path from repo root (cross-platform compatible)
        local relative_path
        relative_path=$(get_relative_path "$file_path" "$repo_root")

        git -C "$repo_root" add "$relative_path"

        # Check for other staged files (for transparency, not blocking)
        local other_staged_files
        other_staged_files=$(git -C "$repo_root" diff --cached --name-only | grep -v "^$relative_path$" || true)

        git -C "$repo_root" commit -m "eed-history: $commit_message" --no-verify

        echo "✅ Changes successfully committed. Details below:"
        echo
        git -C "$repo_root" show HEAD

        # Transparency notice: inform about other files if present
        if [ -n "$other_staged_files" ]; then
            echo
            echo "💡 Note: This commit also included other staged files:"
            echo "$other_staged_files" | sed 's/^/   /'
            echo "   (This may indicate external tools modified the staging area)"
        fi

        echo
        echo "To undo these changes, run: eed --undo"
    else
        # Manual commit mode: stage changes and show instructions
        local relative_path
        relative_path=$(get_relative_path "$file_path" "$repo_root")

        git -C "$repo_root" add "$relative_path"
        echo "⚠️ You have made the following uncommitted changes:"
        echo
        git -C "$repo_root" diff HEAD "$relative_path"
        echo
        echo "To commit: commit \"$file_path\" \"commit message\""
        echo "To discard: git checkout HEAD \"$file_path\""
    fi
}
