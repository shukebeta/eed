# eed — Enhanced ed with Preview-Confirm workflow

eed is an AI-oriented text editor designed for programmatic collaboration with AI: preview diffs, smart git integration, atomic apply semantics, and bulletproof safety.

## Key Features

- **Preview-Confirm Workflow (default)**: Edits are written to `<file>.eed.preview` for review. In git repositories prefer auto-commit mode using `-m "message"` which applies edits and creates an atomic git commit.
- **Local History & Atomic Commits**: Auto-saves WIP, provides a `commit` command to apply preview files and create commits prefixed with `eed-history:`, and supports `--undo` to revert the last eed-history commit safely.
- **Automatic Safety & Reordering**: Intelligently reorders line operations to avoid conflicts and detects unsafe patterns.
- **Auto-completion & Auto-fix**: Auto-completes missing `w`/`q` commands and auto-fixes common issues (such as unescaped slashes and unterminated input blocks).
- **Cross-platform Compatibility**: Normalizes paths and improves Git Bash/Windows support.
- **Smart Git Integration**: Auto-stages changes when using auto-commit and provides clear apply instructions in preview mode.
- **Bulletproof Error Handling**: Original files are never corrupted, even when edit operations fail.
- **Intelligent Diff Display**: Uses `git diff --no-index` for superior code movement visualization.
- **Shell-Safe Invocation**: Use quoted heredocs to prevent shell expansion and preserve literal ed scripts

Quick usage
```
eed [OPTIONS] <file> {SCRIPT|-}

# Examples (preferred order):

# 1) Auto-commit mode for git repositories (recommended for git)
# Use -m to apply edits and create an atomic commit
# Example:
eed -m "Remove first line" path/to/file - <<'EOF'
1d
w
q
EOF

# 2) Quoted heredoc with explicit `-` (preferred for non-git preview workflows)
# Example:
eed path/to/file - <<'EOF'
1d
w
q
EOF

# 3) Pipe (explicit stdin - script-friendly)
# Example:
printf '1d\nw\nq\n' | eed path/to/file -

# Note: eed supports a forgiving stdin mode if '-' is omitted when piping, but prefer explicit '-' in scripts for clarity.
```

## Recent Improvements (v2.1)

### 🛡️ Bulletproof Safety (Critical Bug Fix)
- **Fixed data corruption bug**: Original files are now never corrupted when edit operations fail
- **Simplified error handling**: Failed edits just remove the corrupted preview file, original stays untouched
- **Enhanced testing**: Added comprehensive tests to ensure file safety under all failure scenarios

### 🎯 Unified Editing Strategy
Both preview and force modes use a consistent workflow:
- **Preview mode**: Edit preview file → Show intelligent diff → Manual apply with git staging guidance
- **Force mode**: Edit preview file → Auto-apply → Automatic git staging in repos

### 🚀 Proactive Git Integration
- **Force mode**: Automatically executes `git add` after successful edits in git repositories
- **Preview mode**: Shows complete apply command including git staging when in repos
- **Smart detection**: Only activates git features when actually inside a git repository

### 🧠 Intelligent Script Processing
- **Auto-reordering**: Automatically reorders ascending line operations to prevent conflicts
- **Complex pattern detection**: Identifies potentially unsafe scripts and provides safety guidance
- **Override support**: Use `EED_FORCE_OVERRIDE=true` to bypass safety checks when needed

### 📊 Enhanced Preview Experience
- **Intelligent diff**: Uses `git diff --no-index` for superior code movement visualization
- **Semantic naming**: `.eed.preview` files with clear apply/discard instructions
- **Fallback support**: Gracefully degrades to `delta` or standard `diff` when git unavailable

### 🔧 Under the Hood
- **Simplified output**: Force mode shows elegant ✨ instead of verbose messages
- **Debug mode**: Detailed technical information available with `--debug` flag
- **Robust patterns**: Comprehensive regex validation for all ed command types

## Installation
- Copy `eed` and `lib/` into a directory on your PATH (for example, `~/bin`).
