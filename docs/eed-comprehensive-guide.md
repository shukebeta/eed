# Enhanced Ed (eed) - Comprehensive Guide

This is the complete reference for using eed effectively. Read this file to understand eed's full capabilities.

## CRITICAL REMINDER FOR CLAUDE

STOP BEFORE EDITING: When you need to modify a file, your first instinct will be to use Edit/MultiEdit. RESIST THIS URGE.

ALWAYS ASK YOURSELF: Am I about to use Edit/MultiEdit/Write? If yes, STOP and use eed instead.

MENTAL CHECKLIST:
1. Need to modify a file? Use eed via Bash tool
2. About to call Edit tool? STOP, use eed instead
3. Complex multi-line changes? eed handles it better
4. Simple one-line change? Still use eed for consistency

CORRECT PATTERN - always use this via Bash tool:
```bash
eed --force /unix/style/path/to/file "$(cat <<'EOF'  # <-- Single quotes are CRITICAL\!
# ed commands
w
q
EOF
)"
```

CRITICAL PATH RULE: Always use Unix-style paths with forward slashes
NEVER use Windows paths (C:\path\to\file) - symlinks will fail

PATH CONVERSION EXAMPLES:
- WRONG: `C:\Users\David.Wei\davidwei\file.txt`
- RIGHT: `/home/davidwei/file.txt` or `davidwei/file.txt` or `./docs/file.txt`
- WRONG: `C:/Users/David.Wei/davidwei/docs/file.md`
- RIGHT: `./davidwei/docs/file.md` or `/full/path/to/file.md`
- WRONG: `.\docs\relative\file.txt`
- RIGHT: `docs/relative/file.txt`

MEMORY AID: Think "forward slashes" not "backslashes"

EFFICIENCY TIP: Use --force to skip preview when confident
- Preview mode: Good for learning and complex changes
- Force mode: Use when you trust your ed commands

## Overview

`eed` is a non-interactive wrapper around `ed` that makes programmatic editing safe: preview changes, back up atomically, then apply.

**Key Features:**
- **Preview-Confirm** — preview diffs before applying
- **Atomic** — all-or-nothing edits
- **Backup** — edits written to `<file>.eed.bak` in preview mode
- **Smart** — classifies view vs modify commands

## Usage Syntax

```bash
eed [--debug] [--force] [--disable-auto-reorder] <file> <ed_script>
```

**Options:**
- `--debug` - Show detailed execution info, preserve temp files
- `--force` - Skip preview mode, edit file directly
- `--disable-auto-reorder` - Disable automatic script reordering and complex pattern detection (expert mode)

## The Preview-Confirm Workflow

Example (canonical quoted heredoc form):
```bash
eed sample.txt "$(cat <<'EOF'
2c
new content
.
w
q
EOF
)"
```

✓ Edits are applied to `<file>.eed.bak`; review the diff and decide to apply or discard.

```
--- sample.txt	2025-08-23 14:30:15.000000000 +1200
+++ sample.txt.eed.bak	2025-08-23 14:30:20.000000000 +1200
@@ -1,3 +1,3 @@
 line1
new content
 line3

To apply these changes, run:
  mv 'sample.txt.eed.bak' 'sample.txt'

To discard these changes, run:
  rm 'sample.txt.eed.bak'
```

### View Operations Execute Directly

Read-only operations run immediately; still prefer quoted heredoc for safety:
```bash
eed file.txt "$(cat <<'EOF'
,p
q
EOF
)"

eed file.txt "$(cat <<'EOF'
g/pattern/p
q
EOF
)"
```

## Ed Command Reference

### Basic Line Addressing
```bash
5           # Line 5
$           # Last line
.           # Current line
1,5         # Lines 1 through 5
1,$         # Entire file
```

### Essential Commands
```bash
# View
,p          # Print all lines
1,5p        # Print lines 1-5
=           # Show line count
n           # Print with line numbers

# Edit
5d          # Delete line 5
1,5d        # Delete lines 1-5
5i          # Insert before line 5 (end with .)
5a          # Append after line 5 (end with .)
5c          # Change line 5 (end with .)

# Search & Replace
/pattern/   # Find pattern
s/old/new/g # Replace all on current line
1,$s/old/new/g  # Replace all in file

# Global Operations
g/pattern/d     # Delete all lines with pattern
g/pattern/p     # Print all lines with pattern
v/pattern/d     # Delete all lines WITHOUT pattern

# File Operations
w           # Write (save)
q           # Quit (will fail if changes are unsaved)
Q           # Force Quit (discards any unsaved changes)
```

## Automatic Safety Features

eed provides intelligent safety features that work behind the scenes:

### Smart Line Number Reordering

Automatically reorders operations to prevent line number conflicts:
- `1d; 5d; 10d` becomes `10d; 5d; 1d`
- Preserves multi-line input commands as atomic units
- Warns about complex patterns that can't be safely reordered

### Complex Pattern Detection

Detects potentially dangerous patterns and disables auto-reordering:
- Global commands (`g/pattern/d`, `v/pattern/p`)
- Overlapping address ranges (`3,5d` + `5a`)
- Non-numeric addresses (`./pattern/`, `$-5`)
- Move/transfer operations (`1,5m10`)

### Shell Safety

Prevents history expansion issues with exclamation marks in bash syntax.

## Best Practices

### Shell safety & quoting (preferred)

Always use a quoted heredoc (<<'EOF') so the shell doesn't expand variables or backticks.

### Nested Heredoc Naming Convention

**CORE PRINCIPLE**: Every heredoc marker must be unique within the entire command. Don't mechanically apply OUTER/INNER formulas.

**Safe naming strategies**:
- **By purpose**: `EED_COMMANDS`, `TOOL_CONFIG`, `EXAMPLE_CODE`
- **By number**: `EOF1`, `EOF2`, `EOF3`
- **By context**: `OUTER_EOF`, `EOF` (only when no conflicts)

**DANGER EXAMPLE** - This will break:
```bash
# WRONG - same marker used in example and actual command
eed file.md "$(cat <<'OUTER_EOF'
Example: some_command "$(cat <<'OUTER_EOF'  # CONFLICT!
content
OUTER_EOF
)"
OUTER_EOF
)"
```

**CORRECT EXAMPLES**:
```bash
# Strategy 1: Purpose-based naming
eed file.txt "$(cat <<'EED_COMMANDS'
some_tool "$(cat <<'TOOL_CONFIG'
config content
TOOL_CONFIG
)"
EED_COMMANDS
)"

# Strategy 2: Numbered markers
command "$(cat <<'EOF1'
inner "$(cat <<'EOF2'
content
EOF2
)"
EOF1
)"
```

**CRITICAL RULE**: Scan your entire command for marker conflicts before execution. The shell parser doesn't understand "nesting levels" - it only sees marker names!

Canonical heredoc pattern:
```bash
eed file.txt "$(cat <<'EOF'
/function/
a
// New comment added
.
s/oldName/newName/g
w
q
EOF
)"
```

### Always end with w and q

**For editing operations**: Always end scripts with `w` (save) and `q` (quit). Missing `w` = lost changes!

**For view-only operations**: Only `q` needed (no changes to save).

Save explicitly when modifying: end edit scripts with `w` and `q`.

```bash
eed file.txt "$(cat <<'EOF'
5d
w
q
EOF
)"
```

### Line Number Safety (Automatic)

eed automatically reorders line-number operations to prevent conflicts - write them in any order:

```bash
# These are equivalent - eed handles the ordering
eed file.txt "$(cat <<'EOF'
1d
5d
10d
w
q
EOF
)"
# Becomes: 10d, 5d, 1d automatically
```

Complex patterns (overlapping ranges, g/v blocks) are detected and warned about for safety.

### Use --debug for development

`--debug` preserves temp files and prints the temporary command file and ed output.

Example debug snippet:
```bash
eed --debug file.txt "$(cat <<'EOF'
5d
w
q
EOF
)"
# Debug shows the temp command file and ed output
```

## Shell Safety Rules

Quote or use quoted heredoc to avoid shell expansion.

```bash
# BAD: shell expands $HOME and `date`
eed file.txt "content with $HOME and `date`"

# GOOD: preserve literally
eed file.txt "$(cat <<'EOF'
1a
Content with 'quotes', $variables, and `backticks`
.
w
q
EOF
)"
```

## Common Patterns

### Adding Import Statements
```bash
eed file.js "$(cat <<'EOF'
1i
import newModule from 'library';
.
w
q
EOF
)"
```

### Global Find and Replace
```bash
eed file.txt "$(cat <<'EOF'
1,$s/oldFunction/newFunction/g
w
q
EOF
)"
```

### Remove Debug Statements
```bash
eed file.js "$(cat <<'EOF'
g/console\.log/d
w
q
EOF
)"
```

### Multi-Step Editing
```bash
eed file.txt "$(cat <<'EOF'
/TODO/
c
DONE: Task completed
.
/FIXME/
d
w
q
EOF
)"
```

### Complex Refactoring Example
```bash
# Complete workflow: Add import, rename function, update calls
eed ./project/src/main.js "$(cat <<'EOF'
1i
import { newUtility } from './utils.js';
.
/function oldUtility/c
function newUtility() {
.
1,$s/oldUtility(/newUtility(/g
w
q
EOF
)"
```

## Exit Codes

eed uses a small set of exit codes useful for automation:

- `0` - Success (view or applied edit)
- `1` - Usage error or general `ed`-level error
- `2` - File I/O error
- `3` - Internal `ed` error

## Error Recovery

If something goes wrong:

```bash
# Check for backup
ls -la yourfile.eed.bak

# Restore if needed
mv yourfile.eed.bak yourfile.txt

# Or revert just the current edit (keeps previous successful changes)
git checkout -- yourfile.txt
```

**Best practice**: After each successful edit, stage your progress with `git add yourfile.txt` to create safe restore points.

## Advanced Usage

### Preview Mode vs Force Mode

```bash
# Preview mode (default) - safe for experimentation
eed file.txt "$(cat <<'EOF'
1,$s/old/new/g
w
q
EOF
)"

# Force mode - direct editing like traditional tools
eed --force file.txt "$(cat <<'EOF'
1,$s/old/new/g
w
q
EOF
)"
```

### Combining with Other Tools

```bash
# First examine the file
cat file.txt | head -20

# Then edit with eed
eed file.txt "$(cat <<'EOF'
10,15d
w
q
EOF
)"

# Verify results
git diff file.txt
```

## Core Advantages of the eed Workflow

- **Atomic Operations** - All changes succeed or all fail
- **Intelligent Safety** - Auto-reordering + complex pattern detection
- **Built-in Backup** - Automatic backup and restore
- **Preview Changes** - See before you commit
- **Shell Integration** - Works with any text processing pipeline
- **Reliable** - Based on proven ed editor with modern enhancements

## AI-Specific Common Mistakes

### 1. Path Confusion Patterns

**MISTAKE**: Mixing Windows and Unix paths in same session
```bash
# WRONG - inconsistent paths
eed C:\Users\file.txt "$(cat <<'EOF'  # Windows path
1d
w
q
EOF
)"
```

**CORRECT**: Always use Unix-style paths with Claude Code
```bash
# RIGHT - consistent Unix paths
eed ./docs/file.txt "$(cat <<'EOF'
1d
w
q
EOF
)"
```

### 2. Tool Selection Hesitation

**MISTAKE**: Switching between Edit and eed mid-task
- "Let me use Edit for this simple change..."
- "Actually, maybe eed is better..."
- Results in inconsistent approach and confusion

**CORRECT**: Always use eed, even for single-line changes
- Builds muscle memory
- Consistent workflow
- Avoids tool-switching overhead

### 3. Heredoc Syntax Traps

**MISTAKE**: Forgetting quotes around EOF markers
```bash
# WRONG - unquoted heredoc allows shell expansion
eed file.txt "$(cat <<EOF  # Missing quotes!
content with $variables
EOF
)"
```

**CORRECT**: Always quote the EOF marker
```bash
# RIGHT - quoted heredoc preserves content literally
eed file.txt "$(cat <<'EOF'
content with $variables stays literal
EOF
)"
```

### 4. The "Forgot to Save" Anti-Pattern

**MISTAKE**: Running eed without w/q commands (especially missing `w`)
```bash
# WRONG - changes lost!
eed file.txt "$(cat <<'EOF'
1d
# Missing w and q!
EOF
)"

# ALSO WRONG - missing w means no save!
eed file.txt "$(cat <<'EOF'
1d
q  # Only quit, changes lost!
EOF
)"
```

**CORRECT**: End with w/q for edits, q only for viewing
```bash
# RIGHT - editing: save changes
eed file.txt "$(cat <<'EOF'
1d
w
q
EOF
)"

# ALSO RIGHT - viewing: no save needed
eed file.txt "$(cat <<'EOF'
,p
q
EOF
)"
```

### File permissions for AI editors

Ensure the target file is writable before attempting modifications. Minimal checks and fixes:

```bash
ls -l /path/to/file
[ -w /path/to/file ] || chmod u+w /path/to/file
# If ownership differs:
# sudo chown "$(whoami)" /path/to/file
```

Recommended workflow: edit on a feature branch, then stage and commit the change:
```bash
git checkout -b fix/eed
# run eed...
git add path/to/file
git commit -m "fix: update file via eed"
```

## Troubleshooting

### Common Issues

1. **Unexpected shell expansion** - Use single quotes or heredoc
2. **Missing terminator** - Always end input mode with lone `.`
3. **Complex pattern warnings** - eed detected unsafe patterns, review or use `--disable-auto-reorder`
4. **Backup files left behind** - Normal in preview mode, clean up manually

### Getting Help

Use `--debug` flag to see exactly what eed is doing:

```bash
eed --debug file.txt 'your commands here'
```

This shows the temporary command file contents and ed's actual output.

---

**Remember: eed's preview mode makes experimentation safe. Try complex edits with confidence!**
