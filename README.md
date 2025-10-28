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
Consistent workflows simplify both safe experimentation and fast iterations:
- **Preview mode (default / non-git or explicit preview)**: Edits are written to a preview file (`<file>.eed.preview`) for review; inspect the diff and apply with the `commit` helper or discard the preview file.
- **Auto-commit mode (recommended inside git repos)**: Use `-m "message"` (or `--message`) to apply edits and create an atomic git commit; eed will auto-stage the changed file(s) and run `git commit` with the provided message.

### 🚀 Proactive Git Integration
- **Auto-commit (-m)**: When inside a git repository and `-m` is provided, eed auto-stages and commits edits in an atomic `eed-history:` commit.
- **Preview mode (in repos)**: eed still creates a preview file and prints an explicit `commit <file> "message"` command to apply changes; this preserves the preview-confirm workflow even in repos.
- **Smart detection**: Git behaviors only activate when eed detects a git repository for the target file.

### 🧠 Intelligent Script Processing
- **Auto-reordering**: Automatically reorders ascending line-number edits to prevent positional conflicts when safe to do so.
- **Complex pattern detection**: Identifies potentially unsafe scripts (global commands, overlapping ranges, move operations) and disables automatic reordering with guidance for the user.
- **Emergency override (use with extreme caution)**: An environment variable `EED_FORCE_OVERRIDE` exists for emergency situations to bypass safety checks; this is not recommended for normal workflows.

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

## Development

### Running Tests

This project has comprehensive test coverage with 342+ bats tests. For faster test execution, enable parallel job execution:

```bash
# Detect available CPU cores and run tests in parallel
bats --jobs $(nproc) tests/

# Or set up a persistent alias (add to ~/.bashrc or ~/.zshrc)
alias bats='bats --jobs $(nproc)'

# Then simply run:
bats tests/
```

**Performance impact**: On an 8-core machine, parallel execution reduces test time from ~3 minutes to ~10-15 seconds.

**Note**: All tests are designed to be parallel-safe with isolated temporary directories.
