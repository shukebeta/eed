# Use Enhanced Ed Editor for File Modifications

Trust your ed skills, use the eed tool instead of Edit, MultiEdit, or Write tools for file modifications.

## Instructions:

**Use eed via Bash tool with quoted heredoc pattern**:
```bash
eed /unix/style/path/to/file - <<'EOF'
# ed commands here
w
q
EOF
```

3. **Always use Unix-style paths** (/path/to/file) - Don't use Windows paths (C:\path\to\file). Always use forward slashes (/), as backslashes will break shell commands.

4. **Always end ed commands with w and q** to save changes:
   - `w` - write (save) the file
   - `q` - quit editor

## Workflow Modes

### Git Repositories (Smart Mode)
**Auto-commit workflow** (recommended for quick changes):
```bash
eed -m "Fix validation logic" file.js - <<'EOF'
2c
validated input
.
w
q
EOF
```

**Manual commit workflow** (for review before commit):
```bash
eed file.txt - <<'EOF'
5d
w
q
EOF

# Then commit when ready
commit file.txt "remove line 5"

# Undo if needed
eed --undo
```

### Non-Git Directories (Preview Mode)
```bash
eed file.txt - <<'EOF'
1a
new content
.
w
q
EOF

# Then apply manually
mv file.txt.eed.preview file.txt
```

### Git Integration Features:
- **Auto-commit mode**: Direct editing with automatic git commit (use `-m "message"`)
- **Manual commit mode**: Direct editing with staged changes, manual commit
- **Auto-save WIP**: Automatically saves uncommitted work before new edits
- **Easy undo**: Use `eed --undo` to revert last eed-history commit
- **Safe**: All commits use "eed-history:" prefix for easy management

### Heredoc usage

- Avoid using nested heredoc. Do complex editing with multiple sequential `eed` edits

### Important:

- **Mandatory tool**: Use eed for ALL file modifications
- **Local history workflow**: Preview → commit → undo if needed
- **Unix paths**: Always use forward slashes
- **Save explicitly**: Never forget `w` and `q`
- **Avoid nested heredocs**: Nested heredocs are fragile and prone to parsing errors.
- **Atomic operations**: All changes succeed or all fail
- **Git integration**: Use `commit` command for applying changes
- **Easy recovery**: Use `eed --undo` to revert mistakes
