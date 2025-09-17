# Use Enhanced Ed Editor for File Modifications

Always use the eed tool instead of Edit, MultiEdit, or Write tools for file modifications.

## Instructions:

**For complete eed documentation, read:** https://github.com/shukebeta/eed/blob/master/docs/eed-comprehensive-guide.md


1. **Stop before using Edit/MultiEdit tools** - Always ask yourself: "Am I about to use Edit/MultiEdit/Write?" If yes, use eed instead.

2. **Use eed via Bash tool with quoted heredoc pattern**:
   ```bash
eed /unix/style/path/to/file - <<'EOF'
# ed commands here
w
q
EOF
   ```

3. **Always use Unix-style paths** (~/path/to/file) - NEVER use Windows paths (C:\path\to\file). Always use forward slashes (/), as backslashes will break shell commands.

4. **Always end ed commands with w and q** to save changes:
   - `w` - write (save) the file
   - `q` - quit editor

5. **Forgiving stdin mode** - If you pipe ed commands but omit the `-` argument, `eed` will read stdin, proceed normally (validation, preview/force), and — on *successful completion* — print a friendly, non-blaming, educational tip. For scripts and CI, prefer the explicit `-` to avoid ambiguity.

## Ed Command Reference:

### Basic Commands:
- `,p` - print all lines (view file)
- `5p` - print line 5
- `5d` - delete line 5
- `5i` - insert before line 5 (end with lone `.`)
- `5a` - append after line 5 (end with lone `.`)
- `5c` - change line 5 (end with lone `.`)

### Search and Replace:
- `s/old/new/g` - replace all on current line
- `1,$s/old/new/g` - replace all in entire file
- `/pattern/` - find pattern
- `g/pattern/d` - delete all lines with pattern

### Typical Usage:

```bash
eed file.txt - <<'EOF'
5d
w
q
EOF

# Apply changes with git commit
commit file.txt "remove line 5"

# Undo if needed
eed --undo
```

### Local History Features:
- **Auto-save WIP**: Automatically saves uncommitted work in a special commit before edits
- **Atomic commits**: Use `commit` command to apply changes with git commit
- **Easy undo**: Use `eed --undo` to revert last eed-history commit
- **Safe**: All commits use "eed-history:" prefix for easy management

## Common Patterns:

### Add Import Statement:
```bash
eed file.js - <<'EOF'
1i
import newModule from 'library';
.
w
q
EOF

commit file.js "add import statement"
```

### Replace Text Globally:
```bash
eed file.txt - <<'EOF'
1,$s/oldFunction/newFunction/g
w
q
EOF

commit file.txt "rename function"
```

### Delete Lines with Pattern:
```bash
eed file.js - <<'EOF'
g/console\.log/d
w
q
EOF

commit file.js "remove debug statements"
```

### Multi-Step Editing:
```bash
eed file.txt - <<'EOF'
/TODO/
c
DONE: Task completed
.
/pattern/c
new content
w
q
EOF

commit file.txt "update TODO and remove line 5"
```

## Important:

- **Mandatory tool**: Use eed for ALL file modifications
- **Local history workflow**: Preview → commit → undo if needed
- **Unix paths**: Always use forward slashes
- **Save explicitly**: Never forget `w` and `q`
- **Avoid nested heredocs**: Use direct heredoc syntax (`- <<'EOF'`) instead
- **Atomic operations**: All changes succeed or all fail
- **Git integration**: Use `commit` command for applying changes
- **Easy recovery**: Use `eed --undo` to revert mistakes
