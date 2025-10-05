# Enhanced Ed (eed) - Comprehensive Guide

This is the complete reference for using `eed` effectively. Read this file to understand `eed`'s full capabilities.

## CRITICAL REMINDER FOR CLAUDE

STOP BEFORE EDITING: When you need to modify a file, your first instinct will be to use Edit/MultiEdit. RESIST THIS URGE.

ALWAYS ASK YOURSELF: Am I about to use Edit/MultiEdit/Write? If yes, STOP and use `eed` instead.

MENTAL CHECKLIST:
1. Need to modify a file? Use `eed` via Bash tool
2. About to call Edit tool? STOP, use `eed` instead
3. Complex multi-line changes? `eed` handles it better
4. Simple one-line change? Still use `eed` for consistency

CORRECT PATTERN - always use this via Bash tool:
```bash
eed /unix/style/path/to/file - <<'EOF'  # <-- Single quotes are CRITICAL!
# ed commands
w
q
EOF
```

CRITICAL PATH RULE: Always use Unix-style paths with forward slashes.
NEVER use Windows paths (C:\path\to\file). Always use forward slashes (/), as backslashes will break shell commands.

MEMORY AID: Think "forward slashes" not "backslashes".

NEW WORKFLOW: Smart Git Integration
Git repositories (always auto-commit):
- With custom message: `eed -m "message" file.js ...` → direct edit + commit with custom message
- Quick edit: `eed file.js ...` → direct edit + commit as "Quick edit on file.js at HH:MM"

Non-git directories:
- Preview mode: `eed file.txt ...` → creates .eed.preview → manual apply

Features:
- Automatic WIP saves before new edits
- All edits auto-commit in git repos (no manual commit needed)
- Use `eed --undo` to revert last eed-history commit
- All commits use "eed-history:" prefix for easy management

## Overview

`eed` is a non-interactive wrapper around `ed` that makes programmatic editing safe: preview changes, back up atomically, then apply.

**Key Features:**
- **Preview-Confirm** — preview diffs before applying
- **Atomic** — all-or-nothing edits
- **Backup** — edits written to `<file>.eed.preview` in preview mode (or moved into place in `--force`)
- **Smart** — classifies view vs modify commands
- **Auto-reorder** — reorders simple line-number edits to avoid conflicts
- **Forgiving stdin mode** if a user pipes a script but omits the `-` argument, `eed` will read stdin, proceed, and after success print a friendly, educational tip rather than failing

## Usage Syntax (preferred examples first)

```bash
eed [OPTIONS] <file> {SCRIPT|-}

OPTIONS:
  -m, --message <msg>  Auto-commit with custom message (default: "Quick edit on <file> at HH:MM")
  --debug              Show detailed debugging information
  --disable-auto-reorder  Disable automatic command reordering
  --undo               Undo last eed-history commit
  --help               Show help message
```

Important: `SCRIPT` may be provided as an explicit string, `-` to force reading from stdin, or via a pipe/quoted heredoc.

Recommended usage patterns (priority order):

1) Git repo with custom message (descriptive commits) **← RECOMMENDED FOR GIT**
```bash
eed -m "Remove first line" path/to/file - <<'EOF'
1d
w
q
EOF
```

2) Git repo with quick edit (fast iterations) **← FAST WORKFLOW**
```bash
eed path/to/file - <<'EOF'
1d
w
q
EOF
# Auto-commits as "eed-history: Quick edit on path/to/file at HH:MM"
```

3) Non-git with preview mode (safe experimentation) **← PREFERRED FOR NON-GIT**
```bash
eed path/to/file - <<'EOF'
1d
w
q
EOF
# Creates .eed.preview file for manual review
```

4) Pipe (quick & script-friendly)
```bash
printf '1d\nw\nq\n' | eed path/to/file -        # explicit stdin with '-'
```
Note: `eed` also supports a forgiving mode — if you pipe but omit the `-`, eed will still read stdin and proceed, and will append a friendly tip on success. For clarity and reproducibility, prefer the explicit `-` when scripting.

**Options:**
- `--debug` — Show detailed execution info, preserve temp files
- `--disable-auto-reorder` — Disable automatic script reordering (expert mode)
- `--undo` — Undo last eed-history commit (git revert)

## The Preview-Confirm Workflow

Example (canonical heredoc form):
```bash
eed sample.txt - <<'EOF'
2c
new content
.
w
q
EOF
```

✓ Edits are applied to a preview file (`sample.txt.eed.preview`); review the diff and decide to apply or discard.

```
--- sample.txt      2025-08-23 14:30:15.000000000 +1200
+++ sample.txt.eed.preview 2025-08-23 14:30:20.000000000 +1200
@@ -1,3 +1,3 @@
 line1
 new content
 line3
```

To apply these changes (non-git repos), run:
```bash
mv 'sample.txt.eed.preview' 'sample.txt'
```

To discard these changes, run:
```bash
rm 'sample.txt.eed.preview'
```

Note: In git repositories, changes are auto-committed immediately (no preview file created).

## Auto-Commit System (Git Repositories)

eed provides automatic git integration for seamless version control:

### Workflow
1. **Auto-save WIP**: Before each edit, eed automatically commits any uncommitted work
2. **Direct editing**: Changes are applied directly to files (no preview files)
3. **Auto-commit**: All changes are automatically committed with descriptive messages
4. **Easy undo**: Use `eed --undo` to revert last eed-history commit

### Example with Custom Message
```bash
# Edit with custom commit message
eed -m "add header comment" file.js - <<'EOF'
1a
// Added by eed
.
w
q
EOF
# Automatically commits as "eed-history: add header comment"

# Later, undo if needed
eed --undo
```

### Example with Quick Edit
```bash
# Quick edit without custom message
eed file.js - <<'EOF'
1a
// Quick fix
.
w
q
EOF
# Automatically commits as "eed-history: Quick edit on file.js at HH:MM"

# Undo if needed
eed --undo
```

### Features
- **Fast**: No manual commit steps required
- **Safe**: Original files protected by git
- **Atomic**: All-or-nothing commits with "eed-history:" prefix
- **Reversible**: Easy undo with `--undo` flag
- **Flexible**: Use custom messages or auto-generated quick edit messages

### View Operations Execute Directly

Read-only operations run immediately; still prefer quoted heredoc for safety:
```bash
eed file.txt - <<'EOF'
,p
q
EOF
```

## Forgiving stdin mode

Behavior:
- If `eed` is invoked with a single non-flag positional argument (the target `FILE`) and there is data on stdin (pipeline), `eed` will assume the user intended to pass the script via stdin (they may have forgotten the `-` argument).
- `eed` will read stdin into the script, proceed normally (validation, reorder, preview/force), and — on *successful completion* — will print a friendly, non-blaming, educational tip to stdout indicating it handled stdin for this run.

Tip wording (recommended):
- `💡 Tip: The '-' argument for stdin mode was missing. I handled it for you this time, but it's best practice to include it for clarity (e.g., '... | eed path/to/file -').`

Notes:
- `eed` does NOT silently mutate behavior — it explicitly reports when the auto-read occurred.
- The tip is printed only after a successful operation (view or edit), so users learn in a positive context.
- For scripting and CI, prefer the explicit `-` to avoid relying on forgiving behavior.

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

`eed` provides intelligent safety features that work behind the scenes.

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
Always use a quoted heredoc (`<<'EOF'`) so the shell doesn't expand variables or backticks.

### Nested Heredoc Naming Convention (and why to avoid nesting)
Every heredoc marker must be unique within the entire command. In practice we've observed AIs repeatedly make mistakes with nested heredocs even after warnings — the safest rule is: avoid nesting heredocs whenever possible.
### Heredoc nesting trap detection

- eed includes a validation check that detects *standalone heredoc delimiters* (e.g. a line with only `EOF`) inside the final ED script. This typically indicates a nested-heredoc parsing mistake where the shell closed an inner heredoc early, truncating the script passed to eed.
- When detected, eed halts the run and prints an explanatory, AI-friendly message with suggested fixes.

Why this matters:
- A truncated ED script can cause `ed` to silently perform no edits (or behave unexpectedly) while returning success, producing confusing "silent failures".
- This validation prevents those silent failures and provides actionable guidance.

Example (what the validator catches):
```bash
# BAD: leftover EOF inside the script indicates a nested-heredoc mistake
eed file.txt "$(cat <<'OUTER'
10a
Some text
EOF    # <-- stray EOF left in the final script
.
w
q
OUTER
)"
```

Suggested fixes:
- Use unique delimiters for nested heredocs (e.g. `INNER` / `OUTER`) or avoid nesting entirely.
- Prefer piping commands or using an explicit stdin `-` instead of nesting, for example:
```bash
# Pipe example
printf '1,$s/old/new/g\nw\nq\n' | eed path/to/file -

# Or heredoc to stdin (no nesting)
eed path/to/file - <<'EOF'
1,$s/old/new/g
w
q
EOF
```

Implementation notes:
- The detection logic is implemented in [`lib/eed_validator.sh`](lib/eed_validator.sh:40) and integrated into the pre-validation step of the main script [`eed`](eed:103).
- You can adjust the list of markers (`EOF`, `EOT`, `HEREDOC`) in the validator if you need to support other project-specific markers.

Why avoid nesting
- Nested heredocs are fragile: it's easy to reuse the same marker by accident, causing silent parsing errors or truncated input.
- Debugging nested heredocs is time-consuming for humans and brittle for automated agents.
- Multiple simple edits are clearer, safer, and easier to review than one deeply nested command.

Recommended alternatives (safer, easier for AIs)

1) Perform multiple sequential edits (preferred)
Break complex transformations into discrete steps and run `eed` for each step. This is simple and auditable:
```bash
# Step 1: update imports
eed file.js - <<'EOF'
1i
import newModule from 'library';
.
w
q
EOF

# Step 2: rename usages
eed file.js - <<'EOF'
1,$s/oldName/newName/g
w
q
EOF
```
Staging and committing between steps (e.g., `git add` / `git commit`) makes changes easy to review and revert.

2) Use a temporary ed script file and read via stdin (no nesting)
Write the ed commands to a separate file and feed it to `eed` with an explicit `-`:
```bash
cat > edits.ed <<'EOF'
1,$s/oldName/newName/g
w
q
EOF

# Run eed reading edits.ed via stdin
eed path/to/file - < edits.ed
```
Or pipe the commands:
```bash
printf '1,$s/oldName/newName/g\nw\nq\n' | eed path/to/file -
```

3) Use a single heredoc (no nested heredocs)
If you must include other commands, prefer separating concerns so only one heredoc is needed for `eed`:
```bash
# Clean, single heredoc approach
eed path/to/file - <<'EOF'
/pattern/
c
replacement
.
w
q
EOF
```

Practical tips
- **For git repositories**: Use auto-commit mode (`-m "message"`) for quick iterations
- **For non-git directories**: Use option (2) or (3) for reliable preview workflows
- When using multiple edits, leverage git's automatic WIP saves and undo functionality
- If you must nest, ensure all markers are unique and simple (e.g., `EOF1`, `EOF2`) and run the command locally once to verify parsing.
- For reproducibility in CI, prefer explicit `-` (stdin) or temp script files rather than relying on the forgiving stdin auto-detection.

This guidance reduces brittle failures and makes AI-driven edits far more reliable.

### Always end with `w` and `q`
- For editing operations: always finish with `w` and `q`.
- For view-only operations: `q` is sufficient.

### Use `--debug` for development
`--debug` preserves temp files and prints the temporary command file and ed output.

## Common Patterns

### Adding Import Statements
```bash
eed file.js - <<'EOF'
1i
import newModule from 'library';
.
w
q
EOF
```

### Global Find and Replace
```bash
eed file.txt - <<'EOF'
1,$s/oldFunction/newFunction/g
w
q
EOF
```

### Remove Debug Statements
```bash
eed file.js - <<'EOF'
g/console\.log/d
w
q
EOF
```

### Multi-Step Editing
```bash
eed file.txt - <<'EOF'
/TODO/
c
DONE: Task completed
.
/FIXME/
d
w
q
EOF
```

## Exit Codes

- `0` — Success (view or applied edit)
- `1` — Usage error or general `ed`-level error
- `2` — File I/O error
- `3` — Internal `ed` error

## Error Recovery

If something goes wrong:
```bash
# Check for preview/backup
ls -la yourfile.eed.preview

# Restore if needed
mv yourfile.eed.preview yourfile.txt

# Or revert using git
git checkout -- yourfile.txt
```

**Best practice**: In git repositories, eed automatically commits all changes. Use `eed --undo` to revert if needed.

## Advanced Usage

### Auto-Commit Mode (Git Repositories)
```bash
# Quick edit - fast iterations
eed file.txt - <<'EOF'
1,$s/old/new/g
w
q
EOF
# Auto-commits as "eed-history: Quick edit on file.txt at HH:MM"

# Or with custom message
eed -m "replace old with new" file.txt - <<'EOF'
1,$s/old/new/g
w
q
EOF
# Auto-commits as "eed-history: replace old with new"

# Undo if needed
eed --undo
```

### Preview Mode (Non-Git Directories)
```bash
# Creates .eed.preview file for manual review
eed file.txt - <<'EOF'
1,$s/old/new/g
w
q
EOF

# Apply changes manually
mv file.txt.eed.preview file.txt
```

### Combining with Other Tools
```bash
# First examine the file
cat file.txt | head -20

# Then edit with eed
eed file.txt - <<'EOF'
10,15d
w
q
EOF

# Verify results
git diff file.txt
```

## Tests & CI

A dedicated test covering the forgiving stdin mode was added:
- `tests/test_eed_stdin.bats` — verifies auto-read when `-` is omitted and that the post-success tip is printed.
Run the full test suite locally:
```bash
bats tests
```

## Troubleshooting

### Common Issues
1. **Unexpected shell expansion** — Use single-quoted heredoc markers.
2. **Missing terminator** — Ensure the lone `.` ends multi-line insert/change blocks.
3. **Complex pattern warnings** — `eed` detected unsafe patterns; review or use `--disable-auto-reorder`.
4. **Preview files left behind** — Normal in preview mode; clean up manually if needed.

### Getting Help
Use `--debug` to see the temp command file and ed output:
```bash
eed --debug file.txt 'your commands here'
```

---

**Remember:** The forgiving stdin mode and post-success tip are meant to reduce friction without hiding behavior. Prefer explicit `-` in scripts; enjoy safe, previewable edits with `eed`.

## Git Integration and Safety

eed provides automatic git integration with multiple safety layers:

### Auto-Save Work in Progress
Before each edit, eed automatically commits any uncommitted changes:
```bash
# Auto-saving work in progress...
# [master 543c56d] eed-history: WIP auto-save before new edit
```

### Automatic Commits
All edits in git repositories are automatically committed:
```bash
# With custom message
eed -m "add validation logic" file.js - <<'EOF'
...
EOF
# [master 140822e] eed-history: add validation logic

# Without message (quick edit)
eed file.js - <<'EOF'
...
EOF
# [master 67f3a21] eed-history: Quick edit on file.js at 18:12
```

### Easy Recovery
Multiple options for undoing changes:
```bash
# Undo last eed-history commit (recommended)
eed --undo

# Or use git directly
git revert <commit-hash>
```

### Best Practices
- Use `-m` for descriptive commits when the change is intentional
- Use quick edit (without `-m`) for rapid iterations and experiments
- Each commit is atomic and reversible
- All eed commits use "eed-history:" prefix for easy identification
- Safe for later squashing or rebasing
- No manual staging or commit commands needed
- Quick edit messages include file path and timestamp for easy reference

