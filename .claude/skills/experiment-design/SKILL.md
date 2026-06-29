---
name: experiment-design
description: Experiment methodology including hypothesis formulation, config management, hyperparameter sweeps, ablation studies, and controlled experiment design. Use when designing experiments, creating configs, or planning ablations.
---

# Experiment Design

## When to Use

- Designing a new experiment or ablation study
- Creating or modifying experiment configs
- Setting up hyperparameter sweeps
- Planning controlled comparisons between approaches

## Core Patterns

### Config-Driven Experiments

All experiments must be fully reproducible from a config file. Never hardcode hyperparameters.

```python
from dataclasses import dataclass, field
from pathlib import Path
import yaml

@dataclass
class ModelConfig:
    hidden_size: int = 768
    num_layers: int = 12
    num_heads: int = 12
    dropout: float = 0.1

@dataclass
class TrainingConfig:
    learning_rate: float = 3e-4
    batch_size: int = 32
    max_steps: int = 100_000
    warmup_steps: int = 1000
    seed: int = 42
    gradient_accumulation_steps: int = 1

@dataclass
class ExperimentConfig:
    name: str = "default"
    model: ModelConfig = field(default_factory=ModelConfig)
    training: TrainingConfig = field(default_factory=TrainingConfig)
    output_dir: Path = Path("results")

    @classmethod
    def from_yaml(cls, path: Path) -> "ExperimentConfig":
        with open(path) as f:
            data = yaml.safe_load(f)
        return cls(**data)
```

### YAML Config Structure

```yaml
# configs/base.yaml
name: baseline-v1
model:
  hidden_size: 768
  num_layers: 12
  num_heads: 12
  dropout: 0.1

training:
  learning_rate: 3e-4
  batch_size: 32
  max_steps: 100000
  warmup_steps: 1000
  seed: 42

data:
  train_path: data/train.jsonl
  val_path: data/val.jsonl
  max_seq_length: 512

evaluation:
  metrics: [perplexity, accuracy]
  eval_every_steps: 1000
```

### Config Inheritance for Ablations

```yaml
# configs/ablation_heads_8.yaml
_base_: configs/base.yaml
name: ablation-heads-8
model:
  num_heads: 8
```

### Experiment Metadata Logging

```python
import json
import subprocess
from datetime import datetime

def log_experiment_metadata(config: ExperimentConfig, output_dir: Path):
    metadata = {
        "config": vars(config),
        "git_hash": subprocess.check_output(
            ["git", "rev-parse", "HEAD"]
        ).decode().strip(),
        "timestamp": datetime.now().isoformat(),
        "python_version": sys.version,
        "torch_version": torch.__version__,
    }
    (output_dir / "metadata.json").write_text(json.dumps(metadata, indent=2))
```

### Hyperparameter Sweep Pattern

```python
import itertools

def generate_sweep_configs(
    base_config: dict,
    sweep_params: dict[str, list],
) -> list[dict]:
    keys = list(sweep_params.keys())
    values = list(sweep_params.values())
    configs = []
    for combo in itertools.product(*values):
        cfg = copy.deepcopy(base_config)
        for key, val in zip(keys, combo):
            set_nested(cfg, key, val)
        cfg["name"] = "_".join(f"{k.split('.')[-1]}-{v}" for k, v in zip(keys, combo))
        configs.append(cfg)
    return configs

# Usage
sweep = generate_sweep_configs(
    base_config=base,
    sweep_params={
        "training.learning_rate": [1e-4, 3e-4, 1e-3],
        "model.num_layers": [6, 12],
    },
)
```

### Ablation Study Structure

For each ablation, change exactly ONE variable from the baseline:

```
experiments/
  ablation_study_name/
    base.yaml              # Baseline config
    no_dropout.yaml        # dropout: 0.0
    large_lr.yaml          # learning_rate: 1e-3
    fewer_layers.yaml      # num_layers: 6
    run_all.sh             # Script to launch all variants
```

### Experiment Journal

Maintain a living index of all experiments in `experiments/JOURNAL.md`:

```markdown
# Experiment Journal

| ID | Date | Hypothesis | Status | Result | Branch |
|----|------|-----------|--------|--------|--------|
| E001 | 2026-06-24 | Rotary embeddings improve long-context perf | done | +2.3% acc at 4k ctx | exp/rotary-pos |
| E002 | 2026-06-25 | Cosine LR outperforms linear decay | running | — | exp/lr-cosine |
| E003 | 2026-06-25 | Dropout 0.2 reduces overfitting on small data | planned | — | — |
```

**Lifecycle**: `planned` -> `running` -> `done` | `abandoned`

For each experiment, create a design note in `experiments/{id}_{name}/DESIGN.md`:

```markdown
# E001: Rotary Position Embeddings

## Hypothesis
Rotary position embeddings will improve accuracy on sequences >2048 tokens
compared to learned absolute positions.

## Variables
- **Independent**: Position embedding type (absolute vs rotary)
- **Dependent**: Accuracy, perplexity at context lengths [512, 1024, 2048, 4096]
- **Controlled**: Model size, learning rate, data, all other hyperparameters

## Method
1. Train baseline with absolute position embeddings (configs/base.yaml)
2. Train variant with rotary embeddings (configs/e001_rotary.yaml)
3. Evaluate both at each context length

## Decision
[Filled in after results] Keep rotary embeddings; adopt as new baseline.
```

**Rule**: Every experiment that modifies model behavior must have a JOURNAL entry and a DESIGN.md before implementation begins.

### Pre-Flight Checklist

Before declaring an experiment implementation complete, verify:

- [ ] Config file exists and is self-contained (no hardcoded values in code)
- [ ] Baseline config identified and validated (runs successfully)
- [ ] Only ONE independent variable differs from baseline
- [ ] Seeds are set via `set_all_seeds()` before any random operations
- [ ] All metrics from success criteria are logged
- [ ] JOURNAL.md updated with experiment entry
- [ ] Branch created following naming convention

## Forbidden Shortcuts

| Shortcut | Why It Fails |
|----------|-------------|
| Changing 2+ variables at once | Cannot attribute results to any single change |
| Skipping the baseline run | No comparison point; "85% accuracy" is meaningless alone |
| Running only the "promising" configs | Selection bias; failures are data too |
| Copying results from a different seed | Seeds measure variance; cherry-picking defeats the purpose |
| Eyeballing "looks better" without metrics | Subjective, irreproducible, and wrong more often than not |

## Anti-Patterns

### Hardcoded Values

```python
# Bad - hardcoded, not reproducible
model = Transformer(hidden_size=768, num_layers=12)
optimizer = Adam(model.parameters(), lr=3e-4)

# Good - config-driven
model = Transformer(**cfg.model.__dict__)
optimizer = Adam(model.parameters(), lr=cfg.training.learning_rate)
```

### Uncontrolled Experiments

```python
# Bad - changing multiple variables at once
# "Let's try bigger model AND different learning rate"

# Good - change one thing at a time
# Experiment 1: bigger model, same LR
# Experiment 2: same model, different LR
```

### Missing Baselines

```python
# Bad - no comparison point
# "Our model gets 85% accuracy"

# Good - always compare
# "Our model gets 85% accuracy vs 82% baseline (+3%)"
```

## Integration with Other Skills

- **reproducibility**: Seed management and environment pinning
- **evaluation-metrics**: Defining success criteria and metrics
- **model-development**: Implementing the model changes being tested
- **data-pipeline**: Ensuring data setup is consistent across experiments
