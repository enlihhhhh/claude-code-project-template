---
description: Design and run an experiment end-to-end
allowed-tools: Read, Write, Edit, Glob, Grep, Bash(python:*), Bash(pytest:*), Bash(git:*), Bash(gh:*)
---

# Experiment Workflow

Experiment: $ARGUMENTS

## Instructions

### 1. Define the Experiment

Before writing any code:
- State the **hypothesis** clearly
- Define the **independent variable** (what you're changing)
- Define the **dependent variables** (what you're measuring)
- Identify **controls** (baseline to compare against)
- Determine **success criteria** (how to decide if the hypothesis holds)

### 1.5. Register in Journal

Add an entry to `experiments/JOURNAL.md` (create the file if it doesn't exist) with status `planned`:

| ID | Date | Hypothesis | Status | Result | Branch |
|----|------|-----------|--------|--------|--------|
| E00X | {today} | {hypothesis from step 1} | planned | — | — |

Create `experiments/{id}_{name}/DESIGN.md` with the hypothesis, variables, and method from step 1.

### 2. Create the Config

Create a YAML config in `configs/` or `experiments/`:

```yaml
experiment:
  name: descriptive-experiment-name
  hypothesis: "Brief hypothesis statement"
  baseline: "path/to/baseline/config"

model:
  # Model parameters

training:
  # Training parameters
  seed: 42

data:
  # Data parameters

evaluation:
  metrics: [metric1, metric2]
```

### 3. Create a Branch

```bash
git checkout -b exp/{experiment-name}
```

### 4. Implement Changes

- Follow project patterns (check relevant skills)
- Keep changes minimal and focused on the variable being tested
- Add assertions for tensor shapes and data types
- Log all relevant metrics to the experiment tracker

### 5. Run and Monitor

- Run the experiment with the config
- Monitor training curves for anomalies (NaN, divergence, plateaus)
- Save checkpoints at regular intervals
- Log GPU memory and throughput

### 6. Analyze Results

- Compare against baseline on all metrics
- Check statistical significance if running multiple seeds
- Look for unexpected side effects (e.g., metric A improved but metric B regressed)
- Document findings

### 7. Record Results

Update the JOURNAL.md entry: set status to `done` or `abandoned`, fill in the Result column, and add the branch name.

Create a summary in the experiment's results directory:

```markdown
## Experiment: {name}
### Hypothesis
{hypothesis}

### Setup
- Baseline: {baseline config}
- Change: {what was changed}
- Seeds: {list of seeds}

### Results
| Metric | Baseline | Experiment | Delta |
|--------|----------|------------|-------|
| ...    | ...      | ...        | ...   |

### Conclusion
{Did the hypothesis hold? What was learned?}

### Next Steps
{What to try next based on these results}
```
