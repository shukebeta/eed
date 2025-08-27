# Use Enhanced Ed Editor for File Modifications

Always use the eed tool instead of Edit, MultiEdit, or Write tools for file modifications.

## Instructions:

**For complete eed documentation, read:** https://github.com/shukebeta/eed/blob/master/docs/eed-comprehensive-guide.md


1. **Stop before using Edit/MultiEdit tools** - Always ask yourself: "Am I about to use Edit/MultiEdit/Write?" If yes, use eed instead.

2. **Use eed via Bash tool with quoted heredoc pattern**:
   ```bash
eed --force /unix/style/path/to/file - <<'EOF'
# ed commands here
w
q
EOF
   ```

3. **Always use Unix-style paths** (~/path/to/file) - NEVER use Windows paths (C:\path\to\file). Always use forward slashes (/), as backslashes will break shell commands.

4. **Always end ed commands with w and q** to save changes:
   - `w` - write (save) the file
   - `q` - quit editor

5. **Forgiving stdin mode (new)** - If you pipe ed commands but omit the `-` argument, `eed` will read stdin, proceed normally (validation, preview/force), and — on *successful completion* — print a friendly, non-blaming, educational tip. For scripts and CI, prefer the explicit `-` to avoid ambiguity.

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

## Usage Modes:

### Force Mode (Recommended):
```bash
eed --force file.txt - <<'EOF'
5d
w
q
EOF
```

### Preview Mode (Default):
Shows changes first, requires manual confirmation
```bash
eed file.txt - <<'EOF'
5d
w
q
EOF
```

## Common Patterns:

### Add Import Statement:
```bash
eed --force file.js - <<'EOF'
1i
import newModule from 'library';
.
w
q
EOF
```

### Replace Text Globally:
```bash
eed --force file.txt - <<'EOF'
1,$s/oldFunction/newFunction/g
w
q
EOF
```

### Delete Lines with Pattern:
```bash
eed --force file.js - <<'EOF'
g/console\.log/d
w
q
EOF
```

### Multi-Step Editing:
```bash
eed --force file.txt - <<'EOF'
/TODO/
c
DONE: Task completed
.
5d
w
q
EOF
```

## Error Handling:

- If eed command fails, check syntax of ed commands
- Always verify file exists before editing
- Use `--debug` flag to troubleshoot issues
- Backup / preview files are written as `file.eed.preview` (in preview mode)

### Heredoc nesting trap (AI users)

- When embedding ed scripts via heredoc, avoid reusing the same delimiter for nested heredocs. If a line containing only a heredoc delimiter (for example, `EOF`) appears inside the final ED script, it very likely indicates a nested-heredoc mistake where the shell terminated an inner heredoc early.
- Starting with this release, eed performs a validation check and will halt if it detects a standalone heredoc marker in the ED script. The error message will explain the issue and suggest fixes.

Example (correct — use unique delimiters):
```bash
# bash
eed file.txt "$(cat <<'OUTER'
10a
$(cat <<'INNER'
some content
INNER
)
.
OUTER
)"
```

Suggested fixes:
- Use unique delimiters for nested heredocs (e.g. INNER/OUTER).
- Or write the ed script to a temporary file and feed it via stdin (`-`) to avoid nesting entirely.
## Important:

- **Mandatory tool**: Use eed for ALL file modifications
- **Force mode**: Recommended for direct execution
- **Unix paths**: Always use forward slashes
- **Save explicitly**: Never forget `w` and `q`
- **Avoid nested heredocs**: Nested heredocs are fragile and prone to parsing errors. Prefer multiple sequential `eed` edits or write a temporary ed script and feed it via stdin with `-`.
- **Atomic operations**: All changes succeed or all fail
