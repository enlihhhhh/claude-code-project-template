# Claude Code Settings Documentation

## Environment Variables

- `INSIDE_CLAUDE_CODE`: "1" - Indicates code is running inside Claude Code
- `BASH_DEFAULT_TIMEOUT_MS`: Default timeout for bash commands (10 minutes — experiments and training scripts can be long-running)
- `BASH_MAX_TIMEOUT_MS`: Maximum timeout for bash commands
- `CUBLAS_WORKSPACE_CONFIG`: ":4096:8" — Required for `torch.use_deterministic_algorithms(True)` with cuBLAS

## Hooks

### UserPromptSubmit

- **Skill Evaluation**: Analyzes prompts and suggests relevant research skills
  - **Script**: `.claude/hooks/skill-eval.sh`
  - **Behavior**: Matches keywords, file paths, and patterns to suggest skills

### PreToolUse

- **Main Branch Protection**: Prevents edits on main branch (5s timeout)
  - **Triggers**: Before editing files with Edit, MultiEdit, or Write tools
  - **Behavior**: Blocks file edits when on main branch, suggests creating feature branch

- **Enforce uv**: Blocks `pip install` commands, redirects to `uv add` (5s timeout)
  - **Triggers**: Before running Bash commands containing `pip install` or `pip3 install`
  - **Behavior**: Blocks the command, suggests the `uv add` equivalent

### PostToolUse

1. **Python Formatting**: Auto-format Python files with ruff (30s timeout)
   - **Triggers**: After editing `.py` files
   - **Command**: `ruff format` + `ruff check --fix --select I` (import sorting)
   - **Behavior**: Formats code, shows feedback if errors found

2. **Test Runner**: Run tests after test file changes (120s timeout)
   - **Triggers**: After editing `test_*.py` or `*_test.py` files
   - **Command**: `pytest <file> -x --tb=short --no-header -q`
   - **Behavior**: Runs the changed test file, shows results

3. **Lint Check**: Lint Python files with ruff (15s timeout)
   - **Triggers**: After editing `.py` files
   - **Command**: `ruff check <file>`
   - **Behavior**: Shows lint issues, non-blocking

4. **Data/Results Warning**: Warn when editing data or results directories (5s timeout)
   - **Triggers**: After editing files in `data/` or `results/`
   - **Behavior**: Shows warning that these files should typically be generated

## Hook Response Format

```json
{
  "feedback": "Message to show",
  "suppressOutput": true,
  "block": true,
  "continue": false
}
```

## Environment Variables in Hooks

- `$CLAUDE_TOOL_INPUT_FILE_PATH`: File being edited
- `$CLAUDE_TOOL_NAME`: Tool being used
- `$CLAUDE_PROJECT_DIR`: Project root directory

## Exit Codes

- `0`: Success
- `1`: Non-blocking error (shows feedback)
- `2`: Blocking error (PreToolUse only - blocks the action)
