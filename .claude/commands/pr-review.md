---
description: Review a pull request using research project standards
allowed-tools: Read, Glob, Grep, Bash(git:*), Bash(gh:*)
---

# PR Review

Review the pull request: $ARGUMENTS

## Instructions

1. **Get PR information**:
   - Run `gh pr view $ARGUMENTS` to get PR details
   - Run `gh pr diff $ARGUMENTS` to see changes

2. **Read review standards**:
   - Read `.claude/agents/research-reviewer.md` for the review checklist

3. **Apply the checklist** to all changed files:
   - Numerical correctness (shapes, dtypes, loss order)
   - Reproducibility (seeds, configs, determinism)
   - Data integrity (no leakage, consistent preprocessing)
   - Training loop correctness (eval mode, gradient handling)
   - Python quality (type hints, pathlib, logging)
   - Test coverage for new components

4. **Provide structured feedback**:
   - **Critical**: Must fix before merge (correctness bugs, data leakage, reproducibility failures)
   - **Warning**: Should fix (missing validation, hardcoded values, performance)
   - **Suggestion**: Nice to have (naming, docs, efficiency)

5. **Post review comments** using `gh pr comment`
