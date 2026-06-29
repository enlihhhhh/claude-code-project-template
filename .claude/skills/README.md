# Claude Code Skills

This directory contains research-specific skills that provide Claude with domain knowledge and best practices for R&D projects.

## Skills by Category

### Experiment Methodology
| Skill | Description |
|-------|-------------|
| [experiment-design](./experiment-design/SKILL.md) | Config management, hypothesis testing, ablation studies, hyperparameter sweeps |
| [reproducibility](./reproducibility/SKILL.md) | Seed management, environment pinning, deterministic operations, provenance tracking |

### Data & Models
| Skill | Description |
|-------|-------------|
| [data-pipeline](./data-pipeline/SKILL.md) | Data loading, preprocessing, splitting, validation, tokenization |
| [model-development](./model-development/SKILL.md) | Model architecture, training loops, checkpointing, mixed precision |

### Evaluation & Debugging
| Skill | Description |
|-------|-------------|
| [evaluation-metrics](./evaluation-metrics/SKILL.md) | Metrics computation, benchmarking, statistical significance, result reporting |
| [systematic-debugging](./systematic-debugging/SKILL.md) | Four-phase debugging for research code, NaN diagnosis, OOM fixes, shape debugging |

## Skill Combinations for Common Tasks

### Running a New Experiment
1. **experiment-design** — Config structure and hypothesis
2. **reproducibility** — Seeds and environment
3. **data-pipeline** — Data loading
4. **model-development** — Training loop
5. **evaluation-metrics** — Metrics and reporting

### Building a Data Pipeline
1. **data-pipeline** — Loading and preprocessing
2. **reproducibility** — Deterministic splits and workers

### Debugging Training Issues
1. **systematic-debugging** — Root cause analysis
2. **model-development** — Training loop patterns
3. **reproducibility** — Consistent reproduction

### Evaluating and Reporting Results
1. **evaluation-metrics** — Metrics and significance
2. **experiment-design** — Controlled comparisons

## How Skills Work

Skills are automatically suggested when Claude recognizes relevant context in your prompt. Each skill provides:

- **When to Use** — Trigger conditions
- **Core Patterns** — Best practices with code examples
- **Anti-Patterns** — What to avoid
- **Integration** — How skills connect

## Adding New Skills

1. Create directory: `.claude/skills/skill-name/`
2. Add `SKILL.md` (case-sensitive) with YAML frontmatter:
   ```yaml
   ---
   name: skill-name
   description: What it does and when to use it. Include trigger keywords.
   ---
   ```
3. Include standard sections: When to Use, Core Patterns, Anti-Patterns, Integration
4. Add to this README
5. Add triggers to `.claude/hooks/skill-rules.json`

**Important:** The `description` field is critical — Claude uses semantic matching on it to decide when to apply the skill. Include keywords users would naturally mention.
