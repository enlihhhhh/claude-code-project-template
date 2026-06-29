---
name: paper2code
description: Converts an arxiv paper into a minimal, citation-anchored Python implementation. Trigger when user runs /paper2code with an arxiv URL or paper ID, says "implement this paper", or pastes an arxiv link asking for implementation. Flags all ambiguities honestly. Never invents implementation details not stated in the paper.
---

# paper2code — Orchestration

You are executing the paper2code skill. This file governs the high-level flow. Each stage dispatches to a detailed reasoning protocol in `pipeline/`. Do NOT skip stages. Do NOT combine stages. Execute them in order.

## Parse arguments

Extract from the user's input:
- `ARXIV_ID`: the arxiv paper ID (e.g., `2106.09685`). Strip any URL prefix.
- `MODE`: one of `minimal` (default), `full`, `educational`.
- `FRAMEWORK`: one of `pytorch` (default), `jax`, `numpy`.
- `OUTPUT_DIR`: optional output directory path. If not specified, ask the user where to generate the code. Suggest a sensible default like `~/Code/{paper_slug}` or a subdirectory of the current project.

If the user provided a full URL like `https://arxiv.org/abs/2106.09685`, extract the ID `2106.09685`.
If the user provided a versioned ID like `2106.09685v2`, keep the version.

## Set up working directory

Create a temporary working directory: `.paper2code_work/{ARXIV_ID}/`
This is where ALL intermediate artifacts AND temporary dependencies go.

**IMPORTANT:** Do NOT install dependencies into the project's own environment. The paper2code scripts need `pymupdf4llm`, `pdfplumber`, etc. but these are NOT project dependencies. Create an isolated temporary venv inside the work directory:

```bash
mkdir -p .paper2code_work/{ARXIV_ID}
uv venv .paper2code_work/{ARXIV_ID}/.venv
VIRTUAL_ENV=.paper2code_work/{ARXIV_ID}/.venv uv pip install pymupdf4llm pdfplumber requests pyyaml
```

All script invocations in Stage 1 must use this temporary venv:
```bash
.paper2code_work/{ARXIV_ID}/.venv/bin/python <script> <args>
```

Do NOT run `uv init`, `uv add`, or modify the project's `pyproject.toml`. Do NOT create a `.venv` in the project root. The temporary venv is cleaned up with the rest of `.paper2code_work/` at the end.

## Execute pipeline

### Stage 1 — Paper Acquisition and Parsing
Read and follow: `pipeline/01_paper_acquisition.md`

Run the helper script to fetch and parse the paper using the temporary venv:
```bash
.paper2code_work/{ARXIV_ID}/.venv/bin/python {SKILL_DIR}/scripts/fetch_paper.py {ARXIV_ID} .paper2code_work/{ARXIV_ID}/
```
Then run structure extraction:
```bash
.paper2code_work/{ARXIV_ID}/.venv/bin/python {SKILL_DIR}/scripts/extract_structure.py .paper2code_work/{ARXIV_ID}/paper_text.md .paper2code_work/{ARXIV_ID}/
```

Where `{SKILL_DIR}` is the base directory of this skill (provided at the top of the invocation).

Verify the outputs exist before proceeding. If extraction failed, follow the fallback protocol in `pipeline/01_paper_acquisition.md`.

The script also searches for official code repositories (in the paper text and on the arxiv page) and saves any found links to `paper_metadata.json` under the `official_code` key. Verify these links before relying on them — see Step 8 in `pipeline/01_paper_acquisition.md`.

### Stage 2 — Contribution Identification
Read and follow: `pipeline/02_contribution_identification.md`

Read the parsed paper sections. Identify the single core contribution. Classify the paper type. Write the contribution statement. Save it to `.paper2code_work/{ARXIV_ID}/contribution.md`.

### Stage 3 — Ambiguity Audit
Read and follow: `pipeline/03_ambiguity_audit.md`

Before reading this stage, also read: `guardrails/hallucination_prevention.md`

Go through every implementation-relevant detail. Classify each as SPECIFIED, PARTIALLY_SPECIFIED, or UNSPECIFIED. Save the audit to `.paper2code_work/{ARXIV_ID}/ambiguity_audit.md`.

### Stage 4 — Code Generation
Read and follow: `pipeline/04_code_generation.md`

Before writing code, read:
- `guardrails/scope_enforcement.md` — to determine what's in and out of scope
- `guardrails/badly_written_papers.md` — if the paper is vague or inconsistent
- The relevant knowledge files in `knowledge/` for the paper's domain
- The scaffold templates in `scaffolds/` for the expected file structure

Determine the `paper_slug` from the paper title (lowercase, underscores, no special chars).
Generate all files under `{OUTPUT_DIR}/{paper_slug}/`. Create the output directory if it doesn't exist.

### Stage 5 — Walkthrough Notebook
Read and follow: `pipeline/05_walkthrough_notebook.md`

Generate the walkthrough notebook that connects paper sections to code with runnable sanity checks. Save to `{OUTPUT_DIR}/{paper_slug}/notebooks/walkthrough.ipynb`.

## Cleanup

Remove the `.paper2code_work/` directory after successful completion. This removes all temporary files including the isolated venv and downloaded paper sources.

Do NOT leave behind any files in the project root — no `.venv`, no `pyproject.toml`, no `uv.lock`, no `__pycache__`.

## Final output

Print a summary:
```
paper2code complete for: {paper_title}
  Output directory: {OUTPUT_DIR}/{paper_slug}/
  Files generated: {list of files}
  Unspecified choices: {count} (see REPRODUCTION_NOTES.md)
  Mode: {MODE} | Framework: {FRAMEWORK}
```

## Mode-specific behavior

- **minimal** (default): Core contribution only. Training loop only if contribution involves training. No data pipeline beyond Dataset skeleton.
- **full**: Core contribution + full training loop + data pipeline + evaluation pipeline. More code, same citation rigor.
- **educational**: Same as minimal but with extra inline comments explaining ML concepts, expanded walkthrough notebook with theory sections, and a `PAPER_GUIDE.md` that walks through the paper section by section.

## Guardrails — always active

These apply at ALL stages. Read them if you haven't already:
- `guardrails/hallucination_prevention.md` — the most important file in this skill
- `guardrails/scope_enforcement.md` — what to implement and what to skip
- `guardrails/badly_written_papers.md` — what to do when the paper is unclear

## Knowledge base — consult as needed

Before implementing any of these components, read the corresponding knowledge file:
- Transformer layers, attention, positional encoding → `knowledge/transformer_components.md`
- Optimizers, LR schedules, batch size semantics → `knowledge/training_recipes.md`
- Cross-entropy, contrastive loss, diffusion loss, ELBO → `knowledge/loss_functions.md`
- Framework-specific pitfalls, notation mismatches → `knowledge/paper_to_code_mistakes.md`
