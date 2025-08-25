# eed — Enhanced ed with Preview-Confirm workflow

eed is an AI-oriented text editor designed for programmatic collaboration with AI: preview diffs, smart git integration, and atomic apply semantics.

Key features
- Preview-confirm workflow (default): edits are written to `<file>.eed.preview` for review; use `--force` to apply directly.
- Automatic safety: reorders numeric line operations to avoid conflicts and warns on unsafe/complex patterns.
- Smart git integration: automatically suggests `git add` only in git repositories.
- Intelligent diff display: uses `git diff --no-index` for better code movement visualization.
- Shell-safe invocation: use a quoted heredoc to prevent shell expansion and preserve literal ed scripts.

Quick usage
```
eed [--debug] [--force] [--disable-auto-reorder] <file> <ed_script>

# Example (quoted heredoc, recommended)
eed file.txt "$(cat <<'EOF'
5d
w
q
EOF
 )"
```

Installation

## Recent Improvements (v2.0)

### 🎯 Unified Editing Strategy
Both preview and force modes now use a consistent workflow:
- **Preview mode**: Edit preview file → Show intelligent diff → Manual apply
- **Force mode**: Edit preview file → Auto-apply → Smart git integration

### 🚀 Smart Git Integration  
- Automatically detects git repositories using `git rev-parse --is-inside-work-tree`
- Only suggests `git add` when actually in a git repo
- Clear, actionable messaging: "💡 Next, stage your changes: git add 'file'"

### 📊 Enhanced Preview Experience
- **Intelligent diff**: Prioritizes `git diff --no-index` for better code movement detection
- **Semantic naming**: `.eed.preview` files replace confusing `.eed.bak` naming  
- **Fallback support**: Uses `delta` or standard `diff` when git unavailable

### 🔧 Under the Hood
- Eliminated documentation that misled AI to use invalid `[DOT]` syntax
- Unified backup-then-apply strategy across all modes
- Improved error messages and user guidance

## Installation
- Copy `eed` and `lib/` into a directory on your PATH (for example, `~/bin`).
