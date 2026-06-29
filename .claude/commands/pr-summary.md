---
description: Generate a summary for the current branch changes
allowed-tools: Bash(git:*)
---

# PR Summary

Generate a pull request summary for the current branch.

## Instructions

1. **Analyze changes**:
   ```bash
   git log main..HEAD --oneline
   git diff main...HEAD --stat
   ```

2. **Generate summary** with:
   - Brief description of what changed and why
   - List of files modified
   - Whether this is a feature, experiment, fix, or refactor
   - Any experiment results or motivation (if applicable)
   - Breaking changes or migration notes (if any)

3. **Format as PR body**:
   ```markdown
   ## Summary
   [1-3 bullet points describing the changes]

   ## Motivation
   [Why this change is needed — hypothesis, bug report, or improvement goal]

   ## Changes
   - [List of significant changes]

   ## Test Plan
   - [ ] `pytest` passes
   - [ ] `ruff check .` clean
   - [ ] Verified on sample data
   - [ ] [Additional testing items specific to the change]
   ```
