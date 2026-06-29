---
name: reproducibility
description: Reproducibility best practices including seed management, environment pinning, deterministic operations, artifact tracking, and experiment provenance. Use when setting up experiments for reproducibility, managing dependencies, or ensuring deterministic results.
---

# Reproducibility

## When to Use

- Setting up a new experiment or project
- Debugging non-deterministic behavior
- Preparing code for publication or sharing
- Managing dependencies and environments
- Ensuring experiments can be resumed or replicated

## Core Patterns

### Comprehensive Seed Setting

```python
import os
import random
import logging
import numpy as np
import torch

def set_all_seeds(seed: int = 42, deterministic: bool = False):
    """Set seeds for all RNG sources.

    Set deterministic=True for bitwise reproducibility (slower).
    Leave False for performance mode with cudnn.benchmark enabled.
    """
    random.seed(seed)
    np.random.seed(seed)
    torch.manual_seed(seed)
    torch.cuda.manual_seed_all(seed)
    os.environ["PYTHONHASHSEED"] = str(seed)

    if deterministic:
        torch.backends.cudnn.deterministic = True
        torch.backends.cudnn.benchmark = False
        os.environ["CUBLAS_WORKSPACE_CONFIG"] = ":4096:8"
        try:
            torch.use_deterministic_algorithms(True)
        except RuntimeError:
            logging.warning(
                "Deterministic algorithms not available for all operations. "
                "Results may vary slightly across runs."
            )
            torch.use_deterministic_algorithms(True, warn_only=True)
    else:
        # Performance mode: allow nondeterministic ops, enable cuDNN autotuner
        # Use this for fixed-shape inputs (e.g., padded batches) — ~10-30% speedup
        torch.backends.cudnn.benchmark = True
```

**Important**: Call `set_all_seeds()` BEFORE creating any model, optimizer, or data loader. Use `deterministic=True` for publication results and debugging non-determinism.

### Environment Pinning

Use `pyproject.toml` with pinned versions:

```toml
[project]
requires-python = ">=3.10"
dependencies = [
    "torch==2.4.0",
    "transformers==4.44.0",
    "datasets==2.20.0",
    "wandb==0.17.0",
    "numpy==1.26.4",
]
```

Or export exact versions:

```bash
pip freeze > requirements-frozen.txt
uv pip compile requirements.in -o requirements-frozen.txt
```

### Experiment Provenance

```python
import subprocess
import platform
from pathlib import Path
from datetime import datetime

def capture_provenance(output_dir: Path) -> dict:
    provenance = {
        "timestamp": datetime.now().isoformat(),
        "git": {
            "hash": _git("rev-parse HEAD"),
            "branch": _git("branch --show-current"),
            "dirty": bool(_git("diff --stat")),
        },
        "environment": {
            "python": platform.python_version(),
            "torch": torch.__version__,
            "cuda": torch.version.cuda,
            "gpu": (
                torch.cuda.get_device_name(0)
                if torch.cuda.is_available()
                else None
            ),
            "platform": platform.platform(),
        },
    }
    (output_dir / "provenance.json").write_text(
        json.dumps(provenance, indent=2)
    )
    return provenance

def _git(cmd: str) -> str:
    try:
        return subprocess.check_output(
            ["git"] + cmd.split(), stderr=subprocess.DEVNULL
        ).decode().strip()
    except subprocess.CalledProcessError:
        return ""
```

### Resumable Training

```python
def save_training_state(
    model, optimizer, scheduler, scaler, step, epoch, cfg, output_dir
):
    state = {
        "model": model.state_dict(),
        "optimizer": optimizer.state_dict(),
        "scheduler": scheduler.state_dict(),
        "scaler": scaler.state_dict(),
        "step": step,
        "epoch": epoch,
        "config": cfg,
        "rng_states": {
            "python": random.getstate(),
            "numpy": np.random.get_state(),
            "torch": torch.random.get_rng_state(),
            "cuda": [
                s.cpu() for s in torch.cuda.get_rng_state_all()
            ] if torch.cuda.is_available() else [],
        },
    }
    torch.save(state, output_dir / "training_state.pt")


def restore_training_state(path, model, optimizer, scheduler, scaler):
    state = torch.load(path, weights_only=False)
    model.load_state_dict(state["model"])
    optimizer.load_state_dict(state["optimizer"])
    scheduler.load_state_dict(state["scheduler"])
    scaler.load_state_dict(state["scaler"])
    random.setstate(state["rng_states"]["python"])
    np.random.set_state(state["rng_states"]["numpy"])
    torch.random.set_rng_state(state["rng_states"]["torch"])
    if torch.cuda.is_available() and state["rng_states"]["cuda"]:
        torch.cuda.set_rng_state_all(
            [s.to("cpu") for s in state["rng_states"]["cuda"]]
        )
    return state["step"], state["epoch"]
```

### Config Hashing for Deduplication

```python
import hashlib
import json

def config_hash(config: dict) -> str:
    serialized = json.dumps(config, sort_keys=True, default=str)
    return hashlib.sha256(serialized.encode()).hexdigest()[:12]
```

### Dataset Integrity Verification

```python
import hashlib
from pathlib import Path

def hash_file(path: Path, chunk_size: int = 8192) -> str:
    h = hashlib.md5()
    with open(path, "rb") as f:
        while chunk := f.read(chunk_size):
            h.update(chunk)
    return h.hexdigest()

def verify_dataset(data_dir: Path, manifest_path: Path):
    manifest = json.loads(manifest_path.read_text())
    for filename, expected_hash in manifest.items():
        actual_hash = hash_file(data_dir / filename)
        assert actual_hash == expected_hash, (
            f"{filename}: expected {expected_hash}, got {actual_hash}"
        )
```

**Convention**: After downloading or processing data, save a `data_manifest.json` mapping filenames to MD5 hashes. Verify the manifest before training to catch silent data corruption.

### Data Versioning with DVC

For projects with large or evolving datasets, use [DVC](https://dvc.org/) instead of manual hash manifests:

```bash
dvc init              # Initialize DVC in the project
dvc add data/raw/training_corpus.jsonl   # Track a data file
dvc push              # Push to remote storage
```

DVC handles hashing, storage, and versioning automatically. The generated `.dvc` files should be committed to git.

## Anti-Patterns

### Partial Seeding

```python
# Bad - only seeds Python random
random.seed(42)

# Good - seeds all RNG sources
set_all_seeds(42)
```

### Unpinned Dependencies

```bash
# Bad
pip install torch transformers wandb

# Good
pip install torch==2.4.0 transformers==4.44.0 wandb==0.17.0
```

### Non-Resumable Training

```python
# Bad - can't resume after a crash
torch.save(model.state_dict(), "model.pt")

# Good - saves everything needed to resume
save_training_state(model, optimizer, scheduler, scaler, step, epoch, cfg, output_dir)
```

### Running with Uncommitted Changes

```python
# Bad - running experiment with uncommitted changes (provenance hash is meaningless)
python train.py --config base.yaml

# Good - fail if repo is dirty
def pre_experiment_check():
    if _git("diff --stat"):
        raise RuntimeError(
            "Uncommitted changes detected. Commit or stash before running experiments. "
            "Use 'git stash' if you want to run without committing."
        )
```

**Convention**: Always `git commit` before launching an experiment run. The git hash in your provenance metadata is meaningless if the working tree is dirty.

## Integration with Other Skills

- **experiment-design**: Config structure enables reproducibility
- **data-pipeline**: Deterministic data loading and splitting
- **model-development**: Checkpoint completeness and weight init seeds
- **evaluation-metrics**: Multi-seed evaluation for reliable comparisons
