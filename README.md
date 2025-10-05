# eed — Enhanced ed with Preview-Confirm workflow

eed is an AI-oriented text editor designed for programmatic collaboration with AI: preview diffs, smart git integration, atomic apply semantics, and bulletproof safety.

## Key Features

- **Preview-Confirm Workflow (default)**: Edits are written to `<file>.eed.preview` for review; use `--force` to apply directly
- **Automatic Safety & Reordering**: Intelligently reorders line operations to avoid conflicts and detects unsafe patterns
- **Smart Git Integration**: Auto-stages changes in force mode, suggests staging commands in preview mode
- **Bulletproof Error Handling**: Original files are never corrupted, even when edit operations fail
- **Intelligent Diff Display**: Uses `git diff --no-index` for superior code movement visualization
- **Shell-Safe Invocation**: Use quoted heredocs to prevent shell expansion and preserve literal ed scripts

Quick usage
```
eed <file> <ed_script>

# Example (quoted heredoc, recommended)
eed file.txt - <<'EOF'
5d
w
q
EOF
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


### 🔒 WIP Auto-save Policy
- **Tracked files only**: `git add -u` ensures only already-tracked modifications are saved
- **Untracked files ignored**: New files (.env, temp files, etc.) are never auto-committed
- **Safe by default**: Prevents accidental inclusion of sensitive or temporary content
## Installation
- Copy `eed` and `lib/` into a directory on your PATH (for example, `~/bin`).
