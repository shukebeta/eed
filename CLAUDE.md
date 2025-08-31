# eed Project Documentation

## Project Overview

eed is an AI-oriented text editor built for programmatic collaboration with AI systems. It provides a preview-confirm workflow with bulletproof safety guarantees.

## Testing & Development

### Running Tests
```bash
# Run all tests
bats tests/

# Run specific test files
bats tests/test_eed_preview.bats
bats tests/test_eed_validator.bats

# Debug failing tests (shows detailed output)
bats --tap tests/test_eed_preview.bats
```

### Code Architecture

**Main executable**: `eed` - The main script that handles argument parsing, workflow orchestration, and safety checks

**Library modules** (`lib/`):
- `eed_regex_patterns.sh` - Core regex patterns for ed command classification
- `eed_validator.sh` - Script validation, reordering, and safety analysis

**Key workflows**:
1. **Preview mode** (default): Create preview → Show diff → Manual apply
2. **Force mode** (`--force`): Create preview → Auto-apply → Git integration

### Safety Architecture

- **Preview-first approach**: All edits go to `.eed.preview` files first
- **Original file protection**: Original files are never touched during editing
- **Error isolation**: Failed edits only affect preview files, never originals
- **Git integration**: Automatic staging in force mode, guidance in preview mode

### Testing Philosophy

- **Safety-first**: Critical tests ensure original files are never corrupted
- **Real scenarios**: Tests use actual file operations, not mocks
- **Edge cases**: Comprehensive coverage of error conditions and complex patterns
- **Regression prevention**: Each bug fix includes tests to prevent reoccurrence

## Code Style & Conventions

### Bash Scripting Standards
- Use `set -euo pipefail` for strict error handling
- Quote all variables: `"$var"` not `$var`
- Use `[[ ]]` for conditionals, not `[ ]`
- Prefer `local` variables in functions
- Use descriptive function and variable names

### Testing Standards
- Test names should be descriptive: `"preview mode - error handling preserves original file"`
- Use setup/teardown for clean test isolation
- Verify both positive and negative outcomes
- Include file content verification in file operation tests

## Common Development Tasks

### Adding New Features
1. Write tests first (TDD approach)
2. Implement in main `eed` script or appropriate library
3. Update documentation if user-facing
4. Verify all tests pass: `bats tests/`

### Debugging Issues
- Use `--debug` flag to see detailed execution steps
- Check test output with `bats --tap tests/`
- Use `EED_TESTING=true` to prevent log file creation during tests

### Safety Considerations
- Never modify original files directly
- Always work through preview files
- Test error scenarios thoroughly
- Verify git integration works in both git/non-git environments

## Project History

### Critical Bug Fixes
- **v2.1**: Fixed data corruption bug where failed edits could overwrite original files
- **v2.0**: Added preview-confirm workflow and smart git integration
- **v1.x**: Basic ed wrapper functionality

### Architecture Evolution
- **Early**: Direct file editing (unsafe)
- **v2.0**: Backup-then-restore approach
- **v2.1**: Preview-first approach (current, safest)

## Troubleshooting

### Common Issues
- **"Edit command failed"**: Check ed script syntax, use `--debug` for details
- **Git integration not working**: Verify you're in a git repository
- **Tests failing**: Check if file permissions or temp directory issues

### Debug Mode
Use `--debug` to see:
- Exact ed commands being executed
- File operation details
- Git repository detection results
- Detailed error messages

## Release Process

1. Verify all tests pass: `bats tests/`
2. Update version in README.md "Recent Improvements"
3. Document breaking changes or new features
4. Test manually with real-world scenarios
5. Commit with descriptive message including 🤖 Claude signature

---
*This document is maintained for AI assistants working on the eed project*