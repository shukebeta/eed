# eed — Enhanced ed with Preview-Confirm workflow

eed is an AI-oriented text editor designed for programmatic collaboration with AI: preview diffs, automatic previews, and atomic apply semantics.

Key features
- Preview-confirm workflow (default): edits are written to `<file>.eed.bak` for review; use `--force` to edit in-place.
- Automatic safety: reorders numeric line operations to avoid conflicts and warns on unsafe/complex patterns.
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
- Copy `eed` and `lib/` into a directory on your PATH (for example, `~/bin`).
