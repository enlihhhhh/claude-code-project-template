---
name: evaluation-metrics
description: Evaluation methodology, metrics computation, benchmarking, statistical significance testing, and result reporting. Use when evaluating models, computing metrics, running benchmarks, or analyzing experiment results.
---

# Evaluation & Metrics

## When to Use

- Implementing or modifying evaluation pipelines
- Adding new metrics to experiments
- Running benchmark comparisons
- Assessing statistical significance of results
- Reporting experiment results

## Core Patterns

### Metric Computation

```python
import torch
import numpy as np
from collections import defaultdict

class MetricTracker:
    def __init__(self):
        self.metrics: dict[str, list[float]] = defaultdict(list)

    def update(self, **kwargs: float):
        for name, value in kwargs.items():
            self.metrics[name].append(value)

    def compute(self) -> dict[str, float]:
        return {
            name: np.mean(values)
            for name, values in self.metrics.items()
        }

    def reset(self):
        self.metrics.clear()
```

### Standard NLP Metrics

```python
from torchmetrics.text import Perplexity, BLEUScore
from sklearn.metrics import accuracy_score, f1_score, precision_recall_fscore_support

def compute_classification_metrics(predictions: list, references: list) -> dict:
    precision, recall, f1, _ = precision_recall_fscore_support(
        references, predictions, average="macro"
    )
    accuracy = accuracy_score(references, predictions)
    return {
        "accuracy": accuracy,
        "precision": precision,
        "recall": recall,
        "f1": f1,
    }

def compute_generation_metrics(
    predictions: list[str], references: list[str]
) -> dict:
    bleu = BLEUScore()
    return {
        "bleu": bleu(predictions, [[r] for r in references]).item(),
    }
```

### Evaluation Harness

```python
@torch.no_grad()
def run_evaluation(
    model: nn.Module,
    eval_loader: DataLoader,
    metrics: list[str],
    device: str = "cuda",
) -> dict[str, float]:
    model.eval()
    tracker = MetricTracker()
    all_predictions = []
    all_references = []

    for batch in eval_loader:
        batch = {k: v.to(device) for k, v in batch.items()}
        outputs = model(**batch)

        if "loss" in outputs:
            tracker.update(loss=outputs.loss.item())

        if "logits" in outputs:
            preds = outputs.logits.argmax(dim=-1).cpu().tolist()
            refs = batch["labels"].cpu().tolist()
            all_predictions.extend(preds)
            all_references.extend(refs)

    results = tracker.compute()

    if all_predictions:
        results.update(
            compute_classification_metrics(all_predictions, all_references)
        )

    return results
```

### Multi-Seed Evaluation

```python
def evaluate_multi_seed(
    run_fn,
    config: dict,
    seeds: list[int] = [42, 123, 456],
) -> dict[str, dict[str, float]]:
    all_results = defaultdict(list)

    for seed in seeds:
        config["training"]["seed"] = seed
        results = run_fn(config)
        for metric, value in results.items():
            all_results[metric].append(value)

    # Use at least 3 seeds; 5+ recommended for publication (NeurIPS checklist)
    summary = {}
    for metric, values in all_results.items():
        std = np.std(values)
        summary[metric] = {
            "mean": np.mean(values),
            "std": std,
            "ci_95": 1.96 * std / np.sqrt(len(values)),
            "min": np.min(values),
            "max": np.max(values),
            "n_seeds": len(values),
            "values": values,
        }
    return summary
```

### Statistical Significance

```python
from scipy import stats

def compare_runs(
    baseline_scores: list[float],
    experiment_scores: list[float],
    alpha: float = 0.05,
) -> dict:
    t_stat, p_value = stats.ttest_ind(baseline_scores, experiment_scores)
    significant = p_value < alpha

    return {
        "baseline_mean": np.mean(baseline_scores),
        "experiment_mean": np.mean(experiment_scores),
        "delta": np.mean(experiment_scores) - np.mean(baseline_scores),
        "t_statistic": t_stat,
        "p_value": p_value,
        "significant": significant,
        "alpha": alpha,
    }
```

### Results Table Generation

```python
def format_results_table(
    results: dict[str, dict[str, dict]],
    metrics: list[str],
) -> str:
    header = "| Variant | " + " | ".join(metrics) + " |"
    separator = "|" + "|".join(["---"] * (len(metrics) + 1)) + "|"
    rows = [header, separator]

    for variant, variant_results in results.items():
        cells = [variant]
        for metric in metrics:
            m = variant_results.get(metric, {})
            if "ci_95" in m:
                cells.append(f"{m['mean']:.4f} +/- {m['ci_95']:.4f}")
            elif "std" in m:
                cells.append(f"{m['mean']:.4f} +/- {m['std']:.4f}")
            else:
                cells.append(f"{m.get('mean', m.get('value', 'N/A')):.4f}")
        rows.append("| " + " | ".join(cells) + " |")

    return "\n".join(rows)
```

## Anti-Patterns

### Single-Seed Conclusions

```python
# Bad - drawing conclusions from one run
# "Our method achieves 85.2% accuracy"

# Good - report across seeds with confidence intervals
# "Our method achieves 85.2 +/- 0.3% accuracy (95% CI, n=5 seeds)"
```

### Optimizing Across Seeds

```python
# Bad - selecting hyperparameters based on best mean across seeds
# This turns seeds into a hyperparameter, inflating reported performance
best_config = max(configs, key=lambda c: mean_score_across_seeds(c))

# Good - fix hyperparameters FIRST (using validation set with one seed),
# THEN evaluate the final configuration across multiple seeds
best_config = select_on_validation(configs, seed=42)
final_results = evaluate_multi_seed(best_config, seeds=[42, 123, 456, 789, 0])
```

**Rule**: Seeds exist to measure variance, not to optimize over. Select hyperparameters on a single seed using validation performance, then report final numbers across seeds.

### Metric Cherry-Picking

```python
# Bad - reporting only the metric that improved
# results = {"accuracy": 0.85, "f1": 0.72, "latency_ms": 450}
# Report: "Accuracy improved to 85%!"

# Good - report all pre-defined metrics, including regressions
# Report: "Accuracy: 85% (+3%), F1: 72% (-1%), Latency: 450ms (+50ms)"
```

### Incorrect Averaging

```python
# Bad - averaging metrics that shouldn't be averaged
perplexity = np.mean(batch_perplexities)  # Perplexity is not additive

# Good - compute perplexity from total cross-entropy
total_loss = sum(batch_losses)
total_tokens = sum(batch_token_counts)
perplexity = np.exp(total_loss / total_tokens)
```

### Compute Resource Reporting

Always document computational cost alongside results:

```python
import time

def log_compute_resources(output_dir: Path, start_time: float):
    resources = {
        "wall_time_hours": (time.time() - start_time) / 3600,
        "gpu_type": (
            torch.cuda.get_device_name(0) if torch.cuda.is_available() else "CPU"
        ),
        "gpu_count": torch.cuda.device_count(),
        "peak_gpu_memory_gb": (
            torch.cuda.max_memory_allocated() / 1e9
            if torch.cuda.is_available() else 0
        ),
    }
    (output_dir / "compute.json").write_text(json.dumps(resources, indent=2))
```

**Convention**: Report GPU type, count, wall-clock time, and peak memory for every experiment. Required by NeurIPS and essential for cost-benefit analysis of methods.

## Integration with Other Skills

- **experiment-design**: Defining success criteria and metrics upfront
- **data-pipeline**: Ensuring eval data is correctly prepared
- **model-development**: Evaluation loop integration
- **reproducibility**: Multi-seed evaluation for reliable results
