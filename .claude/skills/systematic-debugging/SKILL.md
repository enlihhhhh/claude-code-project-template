---
name: systematic-debugging
description: Debugging methodology for research code including training instability, NaN/Inf issues, shape mismatches, OOM errors, and performance regressions. Use when investigating bugs, fixing failures, or troubleshooting unexpected behavior. Emphasizes NO FIXES WITHOUT ROOT CAUSE FIRST.
---

# Systematic Debugging for Research Code

## Core Principle

**NO FIXES WITHOUT ROOT CAUSE INVESTIGATION FIRST.**

Never apply symptom-focused patches. Understand WHY something fails before attempting to fix it.

## The Four-Phase Framework

### Phase 1: Root Cause Investigation

Before touching any code:

1. **Read error messages thoroughly** — every word matters, especially shape info
2. **Reproduce the issue consistently** — set seeds, use same config
3. **Examine recent changes** — what changed before this started failing?
4. **Gather diagnostic evidence** — full traceback, tensor shapes, GPU memory
5. **Trace data flow** — follow tensors from input through each operation

**Root Cause Tracing for Tensors:**
```
1. Where does the error manifest? (e.g., loss is NaN at step 500)
2. What value is incorrect? (e.g., which tensor has NaN?)
3. Trace backward: where does the bad value first appear?
4. Check inputs to that operation: shapes, dtypes, value ranges
5. Find the original trigger (e.g., exploding gradients from step 450)
```

### Phase 2: Pattern Analysis

1. **Locate working examples** — find similar code that works
2. **Compare implementations** — don't just skim
3. **Identify differences** — what's different between working and broken?
4. **Check assumptions** — shapes, dtypes, device placement, grad requirements

### Phase 3: Hypothesis and Testing

1. **Formulate ONE clear hypothesis** — "The NaN occurs because gradients explode in layer 8"
2. **Design minimal test** — add a gradient norm check after layer 8
3. **Predict the outcome** — "If correct, grad norm will spike before NaN"
4. **Run the test** — execute and observe
5. **Iterate or proceed** — refine hypothesis if wrong

### Phase 4: Implementation

1. **Create test case** that reproduces the issue with a small input
2. **Implement single fix** addressing root cause
3. **Verify fix** — test passes, training is stable
4. **Run full pipeline** — no regressions
5. **If fix fails, STOP** — re-evaluate hypothesis

**Critical rule:** If THREE or more fixes fail consecutively, STOP. This signals architectural problems requiring discussion.

## Common Research Code Bugs

### NaN/Inf in Training

```python
# Diagnosis
for name, param in model.named_parameters():
    if param.grad is not None:
        if torch.isnan(param.grad).any():
            print(f"NaN grad in {name}")
        if torch.isinf(param.grad).any():
            print(f"Inf grad in {name}")
        print(f"{name}: grad norm = {param.grad.norm():.4f}")
```

Common causes:
- Learning rate too high
- Missing gradient clipping
- Division by zero (e.g., in normalization with zero variance)
- Log of zero or negative values
- Exploding embeddings (check embedding norms)

### Shape Mismatches

```python
# Diagnosis: add shape assertions at key points
def forward(self, x: torch.Tensor) -> torch.Tensor:
    B, T, D = x.shape
    assert D == self.hidden_size, f"Expected dim {self.hidden_size}, got {D}"

    attn_out = self.attention(x)
    assert attn_out.shape == (B, T, D), f"Attention output shape: {attn_out.shape}"

    return self.output(attn_out)
```

Common causes:
- Wrong `dim` argument in `softmax`, `mean`, `sum`
- Silent broadcasting (shapes accidentally compatible)
- Transposed dimensions from different conventions (batch-first vs seq-first)
- Off-by-one in sequence length after padding/truncation

### GPU Out of Memory (OOM)

```python
# Diagnosis
import torch

print(f"Allocated: {torch.cuda.memory_allocated() / 1e9:.2f} GB")
print(f"Cached: {torch.cuda.memory_reserved() / 1e9:.2f} GB")
print(f"Max allocated: {torch.cuda.max_memory_allocated() / 1e9:.2f} GB")

# Enable memory snapshot for detailed analysis
torch.cuda.memory._record_memory_history()
```

Common causes:
- Gradients accumulating without `optimizer.zero_grad()`
- Tensors stored in lists across steps (memory leak)
- Eval not wrapped in `torch.no_grad()`
- Batch size too large for GPU memory
- Hidden state retained across batches (detach or delete)

### Data Pipeline Issues

```python
# Diagnosis: check a few batches manually
for i, batch in enumerate(dataloader):
    for key, val in batch.items():
        print(f"Batch {i}, {key}: shape={val.shape}, dtype={val.dtype}, "
              f"min={val.min():.4f}, max={val.max():.4f}")
    if i >= 2:
        break
```

Common causes:
- Wrong padding token ID
- Labels not aligned with inputs after tokenization
- Attention mask doesn't match padding
- Preprocessing applied differently to train vs eval

### Performance Regression

When training suddenly gets slower:
- Check if `torch.cuda.synchronize()` was accidentally added
- Check if a CPU operation snuck into the GPU pipeline
- Profile with `torch.profiler`:

```python
with torch.profiler.profile(
    activities=[
        torch.profiler.ProfilerActivity.CPU,
        torch.profiler.ProfilerActivity.CUDA,
    ],
    record_shapes=True,
) as prof:
    for step, batch in enumerate(train_loader):
        train_step(model, batch)
        if step >= 5:
            break

print(prof.key_averages().table(sort_by="cuda_time_total", row_limit=20))
```

## Red Flags — Stop and Rethink

| Red Flag | Instead |
|----------|---------|
| "Quick fix for now, investigate later" | Document the issue and schedule proper investigation |
| "One more fix attempt" (after 3+ failures) | Step back, write a minimal reproducer, discuss with team |
| "This should work" (without evidence) | State your hypothesis explicitly, design a test for it |
| Loss oscillates wildly | Check learning rate and data pipeline first, not model code |
| Different results on CPU vs GPU | Check `use_deterministic_algorithms` and floating point precision |

## Debugging Checklist

Before claiming a bug is fixed:

- [ ] Root cause identified and documented
- [ ] Hypothesis formed and tested
- [ ] Fix addresses root cause, not symptoms
- [ ] Test created that reproduces the bug
- [ ] Test passes with fix
- [ ] Full test suite passes
- [ ] Training runs stably for sufficient steps

## Integration with Other Skills

- **model-development**: Training loop correctness and NaN detection
- **data-pipeline**: Data integrity and preprocessing validation
- **reproducibility**: Using seeds to reproduce bugs consistently
