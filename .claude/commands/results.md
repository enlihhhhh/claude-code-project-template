---
description: Analyze and summarize experiment results
allowed-tools: Read, Glob, Grep, Bash(python:*), Bash(find:*), Bash(cat:*), Bash(ls:*)
---

# Results Analysis

Analyze results for: $ARGUMENTS

## Instructions

### 1. Locate Results

- Search `results/`, `outputs/`, or `wandb/` for relevant experiment outputs
- Identify log files, metrics CSVs, TensorBoard events, or W&B run data
- Find the config used for each run

### 2. Extract Key Metrics

For each run or experiment variant:
- Training loss curve (final, best, convergence speed)
- Validation metrics at key checkpoints
- Evaluation metrics on test set (if available)
- Training time and resource usage

### 3. Compare Against Baseline

- Identify the baseline run and its metrics
- Compute deltas for all metrics
- Note which improvements are meaningful vs noise

### 4. Statistical Analysis

If multiple seeds were run:
- Compute mean and standard deviation across seeds
- Note if variance is high (results may not be reliable)
- Flag if only a single seed was run (insufficient for conclusions)

### 5. Generate Summary

```markdown
## Results: {experiment name}

### Configuration
- Baseline: {config/run ID}
- Variants: {list of variants tested}
- Seeds: {number of seeds per variant}

### Key Metrics
| Variant | Metric A | Metric B | Metric C |
|---------|----------|----------|----------|
| Baseline | x.xx ± y.yy | ... | ... |
| Variant 1 | ... | ... | ... |

### Observations
- {What improved}
- {What regressed}
- {Unexpected findings}

### Recommendations
- {What to pursue further}
- {What to abandon}
- {Suggested next experiments}
```

### 6. Visualizations (if requested)

Offer to create comparison plots using matplotlib:
- Training curves overlay
- Bar charts for final metrics
- Scatter plots for hyperparameter sensitivity
