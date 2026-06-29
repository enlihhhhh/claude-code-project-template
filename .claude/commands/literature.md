---
description: Research and synthesize relevant literature on a topic
allowed-tools: Read, Write, Glob, Grep, Bash(git:*), WebSearch, WebFetch
---

# Literature Review

Topic: $ARGUMENTS

## Instructions

### 1. Scope the Review

- Clarify the specific research question or topic
- Identify key terms and their variants for searching
- Determine the scope: foundational papers, recent advances, or both

### 2. Search and Gather

Search for relevant papers and resources:
- Key papers in the area (highly cited, foundational)
- Recent papers (last 1-2 years) with novel approaches
- Related blog posts or technical reports if relevant
- Existing implementations or codebases

### 3. Synthesize Findings

For each relevant paper, extract:
- **Title and authors**
- **Key contribution** (1-2 sentences)
- **Method summary** (approach, architecture, training)
- **Results** (benchmarks, comparisons, ablations)
- **Relevance to our work** (what can we use or build on)

### 4. Identify Patterns

Look across the literature for:
- Common techniques or design choices
- Disagreements or open questions in the field
- Gaps that our work could address
- Practical considerations (compute, data, implementation)

### 5. Produce Summary

Write a structured summary covering:

```markdown
## Literature Review: {topic}

### Key Findings
- {Main takeaways across papers}

### Relevant Papers
1. **{Paper Title}** ({Authors}, {Year})
   - Contribution: {what they did}
   - Method: {how they did it}
   - Results: {key numbers}
   - Relevance: {how it connects to our work}

### Open Questions
- {Unresolved issues in the literature}

### Recommendations
- {Specific suggestions for our work based on the literature}
```

Save the review to `notebooks/` or a location specified by the user.
