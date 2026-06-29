---
name: data-pipeline
description: Data loading, preprocessing, augmentation, dataset creation, and data validation patterns for research. Use when building data loaders, processing datasets, creating train/val/test splits, or debugging data issues.
---

# Data Pipeline

## When to Use

- Building or modifying data loaders
- Creating preprocessing or augmentation pipelines
- Splitting datasets into train/val/test
- Validating data integrity or debugging data issues
- Working with tokenizers or feature extractors

## Core Patterns

### Dataset Class

```python
from pathlib import Path
from torch.utils.data import Dataset
import json

class JsonlDataset(Dataset):
    def __init__(self, path: Path, tokenizer, max_length: int = 512):
        self.samples = []
        with open(path) as f:
            for line in f:
                self.samples.append(json.loads(line))
        self.tokenizer = tokenizer
        self.max_length = max_length

    def __len__(self) -> int:
        return len(self.samples)

    def __getitem__(self, idx: int) -> dict:
        sample = self.samples[idx]
        encoding = self.tokenizer(
            sample["text"],
            max_length=self.max_length,
            padding="max_length",
            truncation=True,
            return_tensors="pt",
        )
        return {k: v.squeeze(0) for k, v in encoding.items()}
```

### Deterministic Data Splitting

```python
from sklearn.model_selection import train_test_split

def create_splits(
    data: list,
    train_ratio: float = 0.8,
    val_ratio: float = 0.1,
    test_ratio: float = 0.1,
    seed: int = 42,
) -> tuple[list, list, list]:
    assert abs(train_ratio + val_ratio + test_ratio - 1.0) < 1e-6
    train, temp = train_test_split(data, train_size=train_ratio, random_state=seed)
    relative_val = val_ratio / (val_ratio + test_ratio)
    val, test = train_test_split(temp, train_size=relative_val, random_state=seed)
    return train, val, test
```

### DataLoader with Reproducible Workers

```python
import torch
import numpy as np

def seed_worker(worker_id: int):
    worker_seed = torch.initial_seed() % 2**32
    np.random.seed(worker_seed)
    random.seed(worker_seed)

def create_dataloader(
    dataset: Dataset,
    batch_size: int,
    shuffle: bool,
    seed: int = 42,
    num_workers: int = 4,
) -> DataLoader:
    generator = torch.Generator()
    generator.manual_seed(seed)
    return DataLoader(
        dataset,
        batch_size=batch_size,
        shuffle=shuffle,
        num_workers=num_workers,
        worker_init_fn=seed_worker,
        generator=generator,
        pin_memory=True,
    )
```

### Data Validation

```python
def validate_batch(batch: dict, expected_keys: list[str], batch_size: int):
    for key in expected_keys:
        assert key in batch, f"Missing key: {key}"
        assert batch[key].shape[0] == batch_size, (
            f"{key}: expected batch size {batch_size}, got {batch[key].shape[0]}"
        )
    if "input_ids" in batch and "attention_mask" in batch:
        assert batch["input_ids"].shape == batch["attention_mask"].shape
```

### Collate Function for Variable-Length Sequences

```python
from torch.nn.utils.rnn import pad_sequence

def collate_fn(batch: list[dict]) -> dict:
    input_ids = pad_sequence(
        [item["input_ids"] for item in batch],
        batch_first=True,
        padding_value=0,
    )
    attention_mask = pad_sequence(
        [item["attention_mask"] for item in batch],
        batch_first=True,
        padding_value=0,
    )
    labels = torch.stack([item["label"] for item in batch])
    return {
        "input_ids": input_ids,
        "attention_mask": attention_mask,
        "labels": labels,
    }
```

### Dataset Statistics Logging

```python
import logging

logger = logging.getLogger(__name__)

def log_dataset_stats(dataset: Dataset, name: str):
    logger.info(f"Dataset '{name}': {len(dataset)} samples")
    if hasattr(dataset, "samples"):
        lengths = [len(s.get("text", "")) for s in dataset.samples]
        logger.info(
            f"  Text length — min: {min(lengths)}, max: {max(lengths)}, "
            f"mean: {sum(lengths)/len(lengths):.0f}"
        )
```

## Anti-Patterns

### Data Leakage

```python
# Bad - fitting scaler on all data including test
scaler.fit(all_data)
train_scaled = scaler.transform(train_data)
test_scaled = scaler.transform(test_data)

# Good - fit only on training data
scaler.fit(train_data)
train_scaled = scaler.transform(train_data)
test_scaled = scaler.transform(test_data)
```

### Non-Deterministic Shuffling

```python
# Bad - no seed, different order each run
loader = DataLoader(dataset, shuffle=True)

# Good - seeded for reproducibility
loader = create_dataloader(dataset, batch_size=32, shuffle=True, seed=42)
```

### Inconsistent Preprocessing

```python
# Bad - different preprocessing for train and eval
train_transform = Compose([Normalize(), Augment(), Tokenize()])
eval_transform = Compose([Tokenize()])  # Missing Normalize!

# Good - shared base, optional augmentation
base_transform = Compose([Normalize(), Tokenize()])
train_transform = Compose([base_transform, Augment()])
eval_transform = base_transform
```

## Integration with Other Skills

- **experiment-design**: Data config structure and split parameters
- **reproducibility**: Deterministic data loading and worker seeding
- **evaluation-metrics**: Ensuring eval data is correctly prepared
- **systematic-debugging**: Diagnosing data-related training issues
