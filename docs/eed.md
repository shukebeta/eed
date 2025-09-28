# Use Enhanced Ed Editor for File Modifications

Trust your ed skills, use the eed tool instead of Edit, MultiEdit, or Write tools for file modifications.

## Instructions:

**Use eed via Bash tool with quoted heredoc pattern**:
```bash
eed -m "fix something" /unix/style/path/to/file - <<'EOF'
# ed commands here
w
q
EOF
```

**Always end ed commands with w and q** to save changes:
   - `w` - write (save) the file
   - `q` - quit editor

### In a git repository - **Auto-commit workflow**
```bash
eed -m "Fix validation logic" file.js - <<'EOF'
2c
validated input
.
w
q
EOF

# Revert the changes when needed
eed --undo
```

### In a non-git repository- **Manual commit workflow** (for review before commit):
```bash
eed file.txt - <<'EOF'
5d
w
q
EOF

# Then apply manually
mv file.txt.eed.preview file.txt
```

### Heredoc usage

- Always use single quote hereod, and avoid using nested heredoc. Do complex editing with multiple sequential `eed` edits

### Important:

- **Mandatory tool**: Use eed for ALL file modifications
- **Unix paths**: Always use forward slashes
- **Save explicitly**: Never forget `w` and `q`
- **Avoid nested heredocs**: Nested heredocs are fragile and prone to parsing errors.
- **Easy recovery**: Use `eed --undo` to revert mistakes
