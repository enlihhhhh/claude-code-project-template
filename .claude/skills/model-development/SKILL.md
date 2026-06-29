---
name: model-development
description: Model architecture patterns, training loops, checkpointing, distributed training, and optimization. Use when building models, writing training loops, implementing custom layers, or working with model weights.
---

# Model Development

## When to Use

- Building or modifying model architectures
- Writing or debugging training loops
- Implementing checkpointing and model saving
- Working with mixed precision or distributed training
- Implementing custom layers or attention mechanisms

## Core Patterns

### Model Architecture

```python
import torch
import torch.nn as nn

class TransformerBlock(nn.Module):
    def __init__(self, hidden_size: int, num_heads: int, dropout: float = 0.1):
        super().__init__()
        self.attention = nn.MultiheadAttention(
            hidden_size, num_heads, dropout=dropout, batch_first=True
        )
        self.norm1 = nn.LayerNorm(hidden_size)
        self.norm2 = nn.LayerNorm(hidden_size)
        self.ffn = nn.Sequential(
            nn.Linear(hidden_size, 4 * hidden_size),
            nn.GELU(),
            nn.Linear(4 * hidden_size, hidden_size),
            nn.Dropout(dropout),
        )

    def forward(self, x: torch.Tensor, mask: torch.Tensor | None = None) -> torch.Tensor:
        residual = x
        x = self.norm1(x)
        x, _ = self.attention(x, x, x, attn_mask=mask)
        x = x + residual

        residual = x
        x = self.norm2(x)
        x = self.ffn(x)
        x = x + residual
        return x
```

### Training Loop

```python
import logging
from torch.cuda.amp import GradScaler, autocast

logger = logging.getLogger(__name__)

def train(
    model: nn.Module,
    train_loader: DataLoader,
    optimizer: torch.optim.Optimizer,
    scheduler: torch.optim.lr_scheduler._LRScheduler,
    cfg: TrainingConfig,
):
    model.train()
    scaler = GradScaler(enabled=cfg.use_fp16)

    for step, batch in enumerate(train_loader):
        batch = {k: v.to(cfg.device) for k, v in batch.items()}

        with autocast(enabled=cfg.use_fp16):
            outputs = model(**batch)
            loss = outputs.loss / cfg.gradient_accumulation_steps

        scaler.scale(loss).backward()

        if (step + 1) % cfg.gradient_accumulation_steps == 0:
            scaler.unscale_(optimizer)
            grad_norm = torch.nn.utils.clip_grad_norm_(
                model.parameters(), cfg.max_grad_norm
            )
            scaler.step(optimizer)
            scaler.update()
            optimizer.zero_grad()
            scheduler.step()

            if step % cfg.log_every == 0:
                logger.info(
                    f"step={step} loss={loss.item():.4f} "
                    f"grad_norm={grad_norm:.4f} lr={scheduler.get_last_lr()[0]:.2e}"
                )

        if step % cfg.eval_every == 0:
            evaluate(model, val_loader, cfg)
            model.train()

        if step % cfg.save_every == 0:
            save_checkpoint(model, optimizer, scheduler, step, cfg)
```

### Checkpoint Save/Load

```python
def save_checkpoint(
    model: nn.Module,
    optimizer: torch.optim.Optimizer,
    scheduler,
    step: int,
    cfg: TrainingConfig,
):
    checkpoint = {
        "model_state_dict": model.state_dict(),
        "optimizer_state_dict": optimizer.state_dict(),
        "scheduler_state_dict": scheduler.state_dict(),
        "step": step,
        "config": vars(cfg),
        "rng_states": {
            "python": random.getstate(),
            "numpy": np.random.get_state(),
            "torch": torch.random.get_rng_state(),
            "cuda": torch.cuda.get_rng_state_all() if torch.cuda.is_available() else None,
        },
    }
    path = Path(cfg.output_dir) / f"checkpoint-{step}.pt"
    torch.save(checkpoint, path)
    logger.info(f"Saved checkpoint to {path}")


def load_checkpoint(path: Path, model: nn.Module, optimizer=None, scheduler=None):
    checkpoint = torch.load(path, weights_only=False)
    model.load_state_dict(checkpoint["model_state_dict"])
    if optimizer:
        optimizer.load_state_dict(checkpoint["optimizer_state_dict"])
    if scheduler:
        scheduler.load_state_dict(checkpoint["scheduler_state_dict"])
    return checkpoint["step"]
```

### Evaluation

```python
@torch.no_grad()
def evaluate(model: nn.Module, eval_loader: DataLoader, cfg: TrainingConfig) -> dict:
    model.eval()
    total_loss = 0.0
    num_batches = 0

    for batch in eval_loader:
        batch = {k: v.to(cfg.device) for k, v in batch.items()}
        outputs = model(**batch)
        total_loss += outputs.loss.item()
        num_batches += 1

    metrics = {"eval_loss": total_loss / num_batches}
    logger.info(f"Eval: {metrics}")
    return metrics
```

### Weight Initialization

```python
def init_weights(module: nn.Module):
    if isinstance(module, nn.Linear):
        torch.nn.init.normal_(module.weight, mean=0.0, std=0.02)
        if module.bias is not None:
            torch.nn.init.zeros_(module.bias)
    elif isinstance(module, nn.Embedding):
        torch.nn.init.normal_(module.weight, mean=0.0, std=0.02)
    elif isinstance(module, nn.LayerNorm):
        torch.nn.init.ones_(module.weight)
        torch.nn.init.zeros_(module.bias)
```

## Anti-Patterns

### Forgetting eval mode

```python
# Bad - model still in training mode during evaluation
loss = model(eval_batch).loss

# Good - eval mode + no_grad
model.eval()
with torch.no_grad():
    loss = model(eval_batch).loss
model.train()
```

### Incomplete checkpoints

```python
# Bad - only saves model weights
torch.save(model.state_dict(), "model.pt")

# Good - saves full training state for resumption
save_checkpoint(model, optimizer, scheduler, step, cfg)
```

### Silent NaN propagation

```python
# Bad - NaN loss goes undetected
loss.backward()

# Good - detect and halt
if torch.isnan(loss) or torch.isinf(loss):
    logger.error(f"NaN/Inf loss at step {step}")
    save_checkpoint(model, optimizer, scheduler, step, cfg)
    raise ValueError(f"Training diverged at step {step}")
loss.backward()
```

### Wrong gradient accumulation

```python
# Bad - loss not divided, effective LR scales with accumulation
loss = model(**batch).loss
loss.backward()

# Good - divide loss by accumulation steps
loss = model(**batch).loss / cfg.gradient_accumulation_steps
loss.backward()
```

### Calling forward() directly

```python
# Bad - bypasses hooks (forward hooks, backward hooks, Module.__call__ logic)
output = model.forward(batch)

# Good - uses __call__ which runs registered hooks and handles autograd properly
output = model(batch)
```

### Performance: cuDNN Autotuner

```python
# Enable for FIXED input shapes (speeds up convolutions and some attention ops)
torch.backends.cudnn.benchmark = True

# Disable if input shapes VARY across batches (e.g., variable-length sequences
# without padding) — the autotuner re-runs for each new shape, causing slowdowns
torch.backends.cudnn.benchmark = False
```

Note: `cudnn.benchmark = True` is incompatible with bitwise reproducibility. The reproducibility skill's `set_all_seeds(deterministic=True)` disables it.

## Integration with Other Skills

- **experiment-design**: Model configs and architecture decisions
- **data-pipeline**: Input format and batch structure
- **evaluation-metrics**: Metrics computed during evaluation
- **reproducibility**: Weight initialization seeds and checkpoint completeness
- **systematic-debugging**: Diagnosing training instability and NaN issues
