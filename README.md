# claude-code-project-template

Claude Code configuration template for **researchers** in Language AI R&D. Provides a complete `.claude/` setup with research-specific skills, hooks, agents, and commands — all grounded in industry standards from PyTorch docs, NeurIPS reproducibility guidelines, cookiecutter-data-science, and probabl-ai/skills.

## Quick Start

1. Copy `.claude/`, `CLAUDE.md`, and `.mcp.json` into your research project
2. Customize `CLAUDE.md` with your project's stack, directories, and conventions
3. Run `chmod +x .claude/hooks/skill-eval.sh`
4. Start Claude Code — skills are suggested automatically as you work

## Directory Structure

```
your-project/
├── CLAUDE.md                                  # Project conventions (loaded every session)
├── .mcp.json                                  # MCP server config (GitHub, Notion)
├── .claude/
│   ├── settings.json                          # Hooks, env vars, permissions
│   ├── settings.md                            # Human-readable hook documentation
│   ├── .gitignore                             # Ignores local settings + tasks
│   ├── agents/
│   │   ├── research-reviewer.md               # Code reviewer (Opus) — correctness, reproducibility
│   │   └── github-workflow.md                 # Git workflow (Sonnet) — commits, branches, PRs
│   ├── commands/
│   │   ├── onboard.md                         # /onboard — deep codebase exploration
│   │   ├── experiment.md                      # /experiment — hypothesis → config → run → analyze
│   │   ├── literature.md                      # /literature — search and synthesize papers
│   │   ├── pr-review.md                       # /pr-review — review PR against research standards
│   │   ├── pr-summary.md                      # /pr-summary — generate PR body from branch diff
│   │   └── results.md                         # /results — analyze experiment outputs
│   ├── hooks/
│   │   ├── skill-eval.sh                      # Bash wrapper for skill evaluation engine
│   │   ├── skill-eval.js                      # Node.js skill matching engine (~410 lines)
│   │   ├── skill-rules.json                   # Trigger rules for 10 skill categories
│   │   └── skill-rules.schema.json            # JSON Schema for skill-rules validation
│   └── skills/
│       ├── README.md                          # Skills overview + how to add new ones
│       ├── experiment-design/SKILL.md         # Config management, journal, ablations, sweeps
│       ├── data-pipeline/SKILL.md             # Data loading, preprocessing, splitting
│       ├── model-development/SKILL.md         # Architectures, training loops, checkpointing
│       ├── evaluation-metrics/SKILL.md        # Metrics, significance testing, compute reporting
│       ├── reproducibility/SKILL.md           # Seeds, determinism, DVC, dataset hashing
│       ├── systematic-debugging/SKILL.md      # NaN, OOM, shapes, training instability
│       └── paper-to-code/                     # Paper → code implementation pipeline
│           ├── SKILL.md                       # Orchestration — 5-stage pipeline
│           ├── guardrails/
│           │   ├── hallucination_prevention.md # Anti-hallucination rules and citation protocol
│           │   ├── scope_enforcement.md       # Decision tree for what to implement
│           │   └── badly_written_papers.md    # Handling incomplete/contradictory papers
│           ├── knowledge/
│           │   ├── transformer_components.md  # MHA, positional encodings, LayerNorm, FFN
│           │   ├── training_recipes.md        # Optimizers, LR schedules, batch size semantics
│           │   ├── loss_functions.md          # Cross-entropy, contrastive, diffusion, VAE
│           │   └── paper_to_code_mistakes.md  # BN momentum, dropout, GELU, init pitfalls
│           ├── pipeline/
│           │   ├── 01_paper_acquisition.md    # Fetch (LaTeX/PDF/HTML) + parse + quality check
│           │   ├── 02_contribution_identification.md  # Classify paper type + scope
│           │   ├── 03_ambiguity_audit.md      # SPECIFIED / PARTIALLY / UNSPECIFIED audit
│           │   ├── 04_code_generation.md      # Citation-anchored code with §references
│           │   └── 05_walkthrough_notebook.md # Pedagogical notebook with sanity checks
│           ├── scaffolds/                     # Template files for generated projects
│           ├── scripts/
│           │   ├── fetch_paper.py             # Multi-fallback fetcher (LaTeX → PDF → HTML)
│           │   └── extract_structure.py       # Splits paper into sections/equations/tables
│           └── worked/                        # Worked examples (Transformer, DDPM)
```

## How Skills Work

Skills are domain-knowledge modules that Claude loads on demand. They contain code patterns, anti-patterns, and conventions specific to ML research workflows.

### Automatic Activation

When you type a prompt, the skill evaluation engine (`.claude/hooks/skill-eval.js`) runs automatically and matches your prompt against trigger rules in `skill-rules.json`. It scores matches using:

- **Keywords** (2 pts) — e.g., "experiment", "dataset", "NaN"
- **Keyword patterns** (3 pts) — regex matches like `\bmodel\b`
- **Intent patterns** (4 pts) — e.g., "fix.*training" or "create.*dataloader"
- **Path patterns** (4 pts) — file paths in your prompt matching globs like `**/*.yaml`
- **Directory mappings** (5 pts) — e.g., files in `src/models/` trigger `model-development`

When a skill scores above the threshold (3 pts), Claude is prompted to evaluate and activate it before proceeding.

### Manual Activation

You can also invoke skills directly by name in your prompt:

```
Use the experiment-design skill to set up a new ablation study
```

Or reference the skill file:

```
Follow the patterns in .claude/skills/reproducibility/SKILL.md
```

### What Each Skill Provides

Every skill follows a consistent structure:

| Section | Purpose |
|---------|---------|
| **When to Use** | Trigger conditions — when this skill applies |
| **Core Patterns** | Best-practice code examples you should follow |
| **Anti-Patterns** | Common mistakes with bad → good comparisons |
| **Integration** | How this skill connects to other skills |

#### experiment-design

Covers config-driven experiments, YAML config structure, hyperparameter sweep generation, ablation study organization, and the **experiment journal** pattern — a living `experiments/JOURNAL.md` index that tracks every experiment's hypothesis, status, and result. Includes a pre-flight checklist and forbidden shortcuts table.

**Key pattern**: Every experiment gets a JOURNAL entry and a `DESIGN.md` (hypothesis, variables, method) *before* implementation begins.

#### data-pipeline

Covers Dataset class construction, deterministic data splitting, reproducible DataLoader setup (with `worker_init_fn` and `generator` seeding), data validation assertions, variable-length collation, and dataset statistics logging.

**Key pattern**: Data loading must be fully deterministic — seeded workers, seeded shuffle, consistent preprocessing between train and eval.

#### model-development

Covers model architecture patterns (transformer blocks), training loops with mixed precision and gradient accumulation, checkpoint save/load with full RNG state, evaluation mode, weight initialization, and the cuDNN autotuner.

**Key pattern**: Never call `model.forward(x)` — use `model(x)` to run registered hooks. Detect NaN/Inf loss and halt before it propagates.

#### evaluation-metrics

Covers metric tracking, standard NLP metrics, evaluation harnesses, multi-seed evaluation with 95% confidence intervals, statistical significance testing, results table generation, and compute resource reporting.

**Key pattern**: Never optimize across seeds — fix hyperparameters on one seed via validation, then report final numbers across 5+ seeds with CIs.

#### reproducibility

Covers comprehensive seed setting with a single `set_all_seeds(seed, deterministic=False)` entry point, deterministic PyTorch operations, environment pinning, experiment provenance capture, resumable training state, config hashing, dataset integrity verification (MD5 manifests), and DVC for data versioning.

**Key pattern**: Always `git commit` before launching an experiment. A provenance JSON with `dirty: true` is useless.

#### systematic-debugging

Covers a four-phase debugging framework (Root Cause → Pattern Analysis → Hypothesis → Implementation), with research-specific sections on NaN/Inf diagnosis, shape mismatch debugging, GPU OOM analysis, data pipeline issues, and performance regression profiling.

**Key pattern**: NO FIXES WITHOUT ROOT CAUSE FIRST. If 3+ consecutive fixes fail, stop — it's an architecture problem, not a code bug.

## Hooks

The template includes 7 automated hooks:

| Hook | Type | What It Does |
|------|------|-------------|
| Skill evaluation | UserPromptSubmit | Suggests relevant skills based on your prompt |
| Branch protection | PreToolUse | Blocks file edits on `main` branch |
| Enforce uv | PreToolUse | Blocks `pip install`, redirects to `uv add` |
| Auto-format | PostToolUse | Runs `ruff format` + import sorting on `.py` files |
| Auto-test | PostToolUse | Runs `pytest` when test files change |
| Lint check | PostToolUse | Runs `ruff check` on edited `.py` files |
| Data/results warning | PostToolUse | Warns when editing files in `data/` or `results/` |

## Agents

| Agent | Model | Purpose |
|-------|-------|---------|
| `research-reviewer` | Opus | Proactive code reviewer. Checks numerical correctness (tensor shapes, loss order, gradient flow), reproducibility (seeds, configs, determinism), data integrity (leakage, consistent preprocessing), training loop correctness, and Python quality. |
| `github-workflow` | Sonnet | Git workflow assistant. Enforces branch naming (`{initials}/{desc}`, `exp/{name}`), conventional commits with research types (`exp:`, `data:`, `eval:`), and PR creation with experiment context. |

## Commands

| Command | What It Does |
|---------|-------------|
| `/onboard` | Deep-dives into the codebase and records findings in `.claude/tasks/` for future sessions |
| `/experiment` | Full experiment lifecycle: define hypothesis → register in journal → create config → branch → implement → run → analyze → record results |
| `/literature` | Searches and synthesizes relevant papers into a structured review |
| `/pr-review` | Reviews a PR against the research-reviewer checklist |
| `/pr-summary` | Generates a PR body from `git log main..HEAD` |
| `/results` | Analyzes experiment outputs: extracts metrics, compares against baselines, generates summary tables |

## MCP Servers

Configured in `.mcp.json` (all optional — remove what you don't use):

| Server | Purpose | Required Env Vars |
|--------|---------|-------------------|
| GitHub | PR and issue integration | `GITHUB_TOKEN` |
| Notion | Documentation access | `NOTION_API_KEY` |

## Setup: API Keys

MCP servers read credentials from **shell environment variables** (not from a `.env` file). You need to export the required variables before launching Claude Code.

### Option 1: Shell Profile (simplest)

Add to your `~/.zshrc` or `~/.bashrc`:

```bash
export GITHUB_TOKEN="ghp_your_token_here"
export NOTION_API_KEY="ntn_your_key_here"
```

Then reload: `source ~/.zshrc`

### Option 2: settings.local.json (Claude Code only)

Create `.claude/settings.local.json` (already gitignored by this template):

```json
{
  "env": {
    "GITHUB_TOKEN": "ghp_your_token_here",
    "NOTION_API_KEY": "ntn_your_key_here"
  }
}
```

This sets the variables only within Claude Code sessions, not your general shell.

### Where to Get Tokens

| Token | Where to Create |
|-------|----------------|
| `GITHUB_TOKEN` | [GitHub Settings → Developer settings → Personal access tokens](https://github.com/settings/tokens) — select `repo` scope |
| `NOTION_API_KEY` | [Notion Integrations](https://www.notion.so/my-integrations) — create an internal integration, then share target pages with it |

### Removing an MCP Server

If you don't use a server (e.g., Notion), delete its entry from `.mcp.json`. Claude Code will skip servers that aren't configured.

## Customization

### Adapting CLAUDE.md

Update the Quick Facts section with your actual stack, commands, and directory layout. The template assumes Python/PyTorch/uv, but the patterns work with JAX, TensorFlow, or any ML framework.

The `data/` directory follows the [cookiecutter-data-science](https://cookiecutter-data-science.drivendata.org/) convention: `raw/` (immutable originals), `interim/` (intermediate transforms), `processed/` (training-ready), `external/` (third-party).

### Adding a New Skill

1. Create `.claude/skills/your-skill/SKILL.md` with YAML frontmatter:
   ```yaml
   ---
   name: your-skill
   description: What it does and when to use it. Include trigger keywords.
   ---
   ```
2. Include sections: When to Use, Core Patterns, Anti-Patterns, Integration
3. Add trigger rules to `.claude/hooks/skill-rules.json`
4. Update `.claude/skills/README.md`

See the [Agent Skills Specification](https://agentskills.io/specification) for the full SKILL.md format.

### Modifying Hooks

Edit `.claude/settings.json` to add, remove, or adjust hooks. See `.claude/settings.md` for documentation on all hooks, response formats, and exit codes.

### Disabling the enforce-uv Hook

If your project uses `pip` or `conda` instead of `uv`, remove the enforce-uv `PreToolUse` entry from `.claude/settings.json`.

## Contributions

The `paper-to-code` skill was built by synthesizing ideas from several open-source projects:

- [PrathamLearnsToCode/paper2code](https://github.com/PrathamLearnsToCode/paper2code) — 5-stage pipeline (acquisition → contribution ID → ambiguity audit → code generation → walkthrough notebook), citation-anchored code, hallucination guardrails, scope enforcement, badly-written paper handling, knowledge files, scaffold templates, and worked examples
- [karpathy/nanochat](https://github.com/karpathy/nanochat) (`.claude/skills/read-arxiv-paper/`) — LaTeX source fetching approach (download arxiv e-print source instead of PDF to avoid parsing artifacts and get exact equations)
- [fcakyon/phd-skills](https://github.com/fcakyon/phd-skills) — provenance tags for hyperparameters, multi-tier validation (smoke → single step → overfit → full reproduction), honest verdict labels ([matched]/[gap]/[fundamental disagreement])
- [issol14/paper2code-skill](https://github.com/issol14/paper2code-skill) — YAML intermediate representations between pipeline phases, completion checklists

## References

This template incorporates patterns from:

- [PyTorch Reproducibility Guide](https://docs.pytorch.org/docs/stable/notes/randomness.html) — seed management, deterministic ops
- [NeurIPS Paper Checklist](https://neurips.cc/public/guides/PaperChecklist) — error bars, compute resources, reproducibility
- [probabl-ai/skills](https://github.com/probabl-ai/skills) — experiment journal pattern, pre-flight checklists
- [cookiecutter-data-science](https://cookiecutter-data-science.drivendata.org/) — `data/raw/interim/processed/` hierarchy
- [PyTorch Style Guide](https://github.com/IgorSusmelj/pytorch-styleguide) — `cudnn.benchmark`, naming conventions
- [pydevtools.com](https://pydevtools.com/handbook/tutorial/set-up-a-python-project-for-claude-code/) — enforce-uv hook pattern
- [Agent Skills Specification](https://agentskills.io/specification) — SKILL.md format standard
