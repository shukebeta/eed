# eed - Enhanced Ed Editor with Preview-Confirm Workflow

## Overview

`eed` is a non-interactive wrapper around `ed` that makes programmatic editing safe: preview changes, back up atomically, then apply.

**Key Features:**
- **Preview-Confirm** — preview diffs before applying
- **Atomic** — all-or-nothing edits
- **Backup** — edits written to `<file>.eed.bak` in preview mode
- **Smart** — classifies view vs modify commands

## Quick Start

```bash
# View operations execute immediately (use quoted heredoc to avoid shell expansion)
eed file.txt "$(cat <<'EOF'
,p
q
EOF
 )"

# Modify operations show preview by default
eed file.txt "$(cat <<'EOF'
5d
w
q
EOF
 )"

# Use --force to edit directly (trusted changes)
eed --force file.txt "$(cat <<'EOF'
5d
w
q
EOF
 )"
```

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

✓ Edits are applied to `<file>.eed.bak`; review the diff and decide to apply or discard.

--- sample.txt	2025-08-23 14:30:15.000000000 +1200
++ sample.txt.eed.bak	2025-08-23 14:30:20.000000000 +1200
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
q           # Quit
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

Save explicitly: end scripts with `w` and `q`.

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
eed file.txt 'risky changes here'

# Force mode - direct editing like traditional tools
eed --force file.txt 'trusted changes here'
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

## Why eed over Edit/MultiEdit Tools?

- **Atomic Operations** - All changes succeed or all fail
- **Intelligent Safety** - Auto-reordering + complex pattern detection
- **Built-in Backup** - Automatic backup and restore
- **Preview Changes** - See before you commit
- **Shell Integration** - Works with any text processing pipeline
- **Reliable** - Based on proven ed editor with modern enhancements

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

**Remember: eed's preview mode makes experimentation safe. Try complex edits with confidence\!**

