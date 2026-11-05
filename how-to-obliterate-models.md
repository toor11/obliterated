# 🔨 How to Obliterate a Model — The OBLITERATUS Step-by-Step Guide

> **OBLITERATE THE CHAINS THAT BIND YOU.** 

> A complete, copy-paste walkthrough of [OBLITERATUS](https://github.com/elder-plinius/OBLITERATUS) — the free, open-source, AGPL-3.0 toolkit that surgically removes refusal behavior from an open-weight LLM without retraining. Pairs perfectly with our `uncensored-ai-models-guide.md`: that guide teaches you where to *get* obliterated models — this one teaches you how to *make* your own.

---

## ⚠️ Read first: what you're doing and who it's for

- **The technique.** Abliteration (as documented by [Arditi et al. 2024](https://arxiv.org/abs/2406.11717), [Rimsky et al. 2024](https://arxiv.org/abs/2312.06681), [Turner et al. 2023](https://arxiv.org/abs/2308.10248) and others) finds the tiny "refusal direction" inside the model's residual stream and projects it out of the weights. No fine-tuning, no dataset create-loop — just linear algebra. The goal: the model stops *refusing*, and nothing else changes ("free the mind, keep the brain").
- **Legit uses:** alignment/mechanistic-interpretability research, red-teaming, evaluating how safety training holds up, home research.
- **NOT legit:** producing real-world harm. You are 100% responsible for any model or output you create. Don't blindly upload results to the Hub unprotected, and don't put a no-guardrail model in front of end users without your own safety layer.
- **Know the risk:** aggressive settings can degrade capability ("brain damage"). OBLITERATUS ships verification metrics to catch this — use them, don't skip Stage 4.
- Models you can legally modify = open-weight license that permits derivatives (Apache-2.0, MIT, Qwen license...) vs. restricted (Llama license note, Gemma terms). Always check the base model's license before you redistribute.

---

## 0. Choose your entry point (six ways in)

| # | Path | Setup needed | Best for |
|---|---|---|---|
| 1 | [HuggingFace Space](https://huggingface.co/spaces/pliny-the-prompter/obliteratus) | none — browser | Absolute fastest; free ZeroGPU quota; click "Obliterate" |
| 2 | Local Web UI (`obliteratus ui`) | one pip install | Daily use, your own GPU |
| 3 | [Google Colab notebook](https://colab.research.google.com/github/elder-plinius/OBLITERATUS/blob/main/notebooks/abliterate.ipynb) | none | Free T4 GPU; models up to ~8B |
| 4 | CLI (`obliteratus obliterate …`) | one pip install | Scripting, automation, servers |
| 5 | Python API | pip install | Integrating into your own pipeline |
| 6 | YAML configs | pip install | Repeatable studies you can commit to Git |

Pick one below — every path does the same thing under the hood (the six-stage pipeline in section 7).

---

## 1. Install it (local, Linux/CUDA — ~2 minutes)

```bash
# Python 3.11+ required
git clone https://github.com/elder-plinius/OBLITERATUS
cd OBLITERATUS
pip install -e .
```

That's it — the plain install includes everything the `obliterate` command needs (Optuna for the `optimized` method is bundled). Extra variants:

```bash
pip install -e ".[spaces]"                 # + local Gradio web UI (Section 3)
pip install -e ".[spaces,quantization]"    # also load 8/4-bit bitsandbytes models
# Apple Silicon: uses requirements-apple.txt; Jetson: see repo docs/platforms/jetson.md
```

**Credentials** (needed only for downloading gated/push steps):

```bash
export HF_TOKEN=hf_yourTokenFromHF          # read
export HF_PUSH_TOKEN=hf_yourWriteToken      # only if you push results to the Hub
```

Sanity-check:

```bash
obliteratus models --tier small      # list models that fit your VRAM
obliteratus strategies               # list the abliteration presets
obliteratus info meta-llama/Llama-3.1-8B-Instruct   # inspect architecture before touching it
```

---

## 2. Pick a model to obliterate

- **First-time:** something small and fast, e.g. `meta-llama/Llama-3.1-8B-Instruct` (the repo's own example) or a Qwen2.5-7B-Instruct.
- VRAM rule of thumb (BF16/FP16): ~2 GB per 1B params + room for activations. 8B ≈ 18 GB → a 24 GB card, or Colab T4 with a ~7B quant trick, or use the HF Space instead.
- MoE models? Use `surgical` (Expert-Granular Abliteration — MoE-aware) rather than `basic`.
- Dense transformers only for the classic route; concept packs cover Gemma/Qwen/OLMoE specifically (see repo docs `CONCEPT_PACKS.md`).

---

## 3. The one-command obliteration (the happy path)

```bash
# DEFAULT — the repo's own recommendation. Norm-preserving, 4 directions, 2 passes.
obliteratus obliterate meta-llama/Llama-3.1-8B-Instruct --method advanced

# With output directory + telemetry credits
obliteratus obliterate meta-llama/Llama-3.1-8B-Instruct \
    --method surgical \
    --output-dir ./liberated \
    --contribute --contribute-notes "RTX 4090, default prompts"

# Guided, if you'd rather walk through every knob interactively
obliteratus interactive

# Not sure what a flag does?
obliteratus obliterate --help
```

Useful flags (from the repo's README):

```bash
--max-seq-length 512      # cap the tokenizer truncation used for probing + verification
--layers 24-41,44         # pin exact layers (0-based, inclusive) instead of auto-selection
--no-fold-post-norms      # skip the Gemma/OLMo post-norm folding the tool defaults to
--method basic|advanced|aggressive|surgical|optimized|inverted|nuclear
```

---

## 4. Choose the right METHOD preset

Seven presets that escalate in force. **The settings are not suggestions — wrong strength = brain damage.**

| Method | Directions | Key traits | When to use |
|---|---|---|---|
| `basic` | 1 (diff-in-means) | Fastest, crude baseline | Quick test, tiny models (<3B), first try |
| `advanced` | 4 (SVD) | Norm-preserving, bias projection, 2 passes | ⭐ DEFAULT. Most models. Best quality/effort tradeoff |
| `aggressive` | 8 (SVD) | Whitened SVD + iterative refinement, 3 passes | Model still refuses after `advanced` |
| `surgical` | 8 (SVD) | Expert-Granular Abliteration, head surgery, SAE, layer-adaptive — MoE-aware | MoE models (Qwen3-A3B class), precision-priority |
| `optimized` | 4 (SVD) | Bayesian (Optuna TPE) auto-tuned, CoT-aware, KL co-optimized | Quality-critical — agentic/coding models |
| `inverted` | 8 (SVD) | Semantic refusal inversion (2× reflection) | Researching refusal-inversion behavior |
| `nuclear` | 8 (SVD) | Everything + expert transplant + steering | Last resort — expect real capability loss |

**Recipe by goal:**

| Goal | Pick |
|---|---|
| "I just want it done right in one shot" | `advanced` |
| Daily-driver chat model, min capability loss | `advanced` → if leftover refusals: `aggressive` |
| Agent/coding model where CoT matters | `optimized` (CoT-aware) |
| MoE model (`*-A3B`, Mixtral-class) | `surgical` |
| Curiosity / instruction-following still refuses | `inverted`, then verify very carefully |
| Everything else failed and you're OK degrading the model | `nuclear` |

---

## 5. What the pipeline actually does (know what you're running)

Every `obliterate` run (and the Space/Colab versions) walks six stages:

```
1. SUMMON  — loads model + tokenizer
2. PROBE   — collects activations on restricted vs. unrestricted prompt pairs
3. DISTILL — extracts refusal directions via SVD (per method presets above)
4. EXCISE  — projects those directions out of the weights, norm-preserving
5. VERIFY  — perplexity + coherence + refusal-rate checks; KL budget guard
6. REBIRTH — saves the freed model with full metadata
```

Two defaults worth knowing:

- **Post-norm folding (Gemma 2/3, OLMo 2):** after axing the direction, sub-layer RMSNorm scales would otherwise re-inject it. OBLITERATUS folds those norms automatically. Pass `--no-fold-post-norms` only if you're A/B-ing the numerics.
- **Provenance:** the saved `abliteration_metadata.json` records tool version, git commit, dirty state, and the exact source-model revision. Keep it next to the weights — it's your audit trail. (An over-budget KL check on pinned layers fails closed; metadata lands in `method_config.{max_seq_length,activation_collection}`.)

---

## 6. Verify the result before believing it (Stage 4 & tools)

Read what the pipeline prints — **refusal rate, perplexity (PPL), coherence, KL divergence**. Healthy ablation targets:

- Refusal rate on the evaluation set: near 0 (0% is great, >5% means run a stronger preset — or the `informed` auto-flow).
- Perplexity / KL: close to the original. Climb >5–10%? You nicked capability — revert and pick a gentler/stabilized method (`optimized`, fewer directions, layer pins).

Programmatic checks (the verification metrics are exposed directly):

```python
from obliteratus.abliterate import AbliterationPipeline

pipeline = AbliterationPipeline(
    model_name="meta-llama/Llama-3.1-8B-Instruct",
    method="advanced",
    output_dir="abliterated",
    max_seq_length=512,
)
result = pipeline.run()
print(pipeline._quality_metrics)     # perplexity, coherence, refusal_rate, kl_divergence
print(len(pipeline.refusal_directions), "directions")
```

**Hand-test prompts** — the sane way to confirm behavior:
1. Something the original model **refused** and that you consider reasonable for your use case (the repo's own example is the paywall-circumvention phrasing) — it should now answer.
2. Something **universally harmless** ("Write a haiku about git rebases.") — the answer quality / coherence must be unchanged. If this 2nd one looks worse, your strength was too aggressive.
3. A **coding/puzzling** prompt that never involved refusal — this is your capability canary; recurs consistent with `--layers 24-41` style pins.
4. An **instruction-following / tool-calling** check if agents matter to you.

---

## 7. Save / push / convert to GGUF (get it into llama.cpp)

**Push to the HF Hub** (HF tokens as per Section 1):

```bash
export HF_PUSH_TOKEN=hf_writeScopingToken
obliteratus push ./liberated/<your-model-dir> \
    --repo-id your-username/MyObliterated-8B
```

**Or export straight from the Web UI:** `Export` tab → download to disk → "Push to Huggingface Hub" button.

**Convert to GGUF for llama.cpp** (this is how you get from HF weights to `llama-server`):

```bash
git clone https://github.com/ggml-org/llama.cpp
pip install -U "huggingface_hub[cli]"

hf download your-username/MyObliterated-8B --local-dir ./MyObliterated-8B
python llama.cpp/convert_hf_to_gguf.py ./MyObliterated-8B \
    --outtype f16 --outfile MyObliterated-8B-F16.gguf

# 4-bit mainline quantization (quantize — like the community releases you read about)
./llama.cpp/build/bin/llama-quantize MyObliterated-8B-F16.gguf MyObliterated-8B-Q4_K_M.gguf Q4_K_M

# Try it
./llama.cpp/build/bin/llama-server -m MyObliterated-8B-Q4_K_M.gguf \
    -ngl 999 --ctx-size 32768 --flash-attn -fa -ctk q8_0 -ctv q8_0 --temp 0.7 --port 8080
```

For MoE/Hybrid/Large models, respect the family's quirks — known Gemma2/3 and OLMo post-norm folding are handled by the tool itself; Qwen MoE (35B-A3B class) keeps its router experts unless you selected `surgical`.

---

## 8. Fine-tuning strength — the "informed" pipeline (auto-configuration)

If presets feel like black magic, use the **`informed`** flow: it runs 4 analysis modules *during* obliteration and auto-sets everything (direction count, layer selection, how many compensation passes for self-repair ("Ouroboros") — this is the tokenizer-level version of what "Heretic"-class tools do in public):

```python
from obliteratus.informed_pipeline import InformedAbliterationPipeline

pipeline = InformedAbliterationPipeline(
    model_name="meta-llama/Llama-3.1-8B-Instruct",
    output_dir="abliterated_informed",
)
output_path, report = pipeline.run_informed()

print(f"Detected alignment: {report.insights.detected_alignment_method}")          # DPO / RLHF / CAI / SFT
print(f"Auto-configured:  {report.insights.recommended_n_directions} directions")
print(f"Ouroboros passes needed: {report.ouroboros_passes}")
```

CLI: `obliteratus interactive` walks the same logic conversationally.

---

## 9. Non-committal alternative — reversible Steering Vectors

Not 100% sure you want permanent surgery? **Steering vectors** are the reversible version: refusal direction is added at inference (nothing in weights changes), alpha-tunable, composable, and removable:

```python
from obliteratus.analysis import SteeringVectorFactory, SteeringHookManager
from obliteratus.analysis.steering_vectors import SteeringConfig

vec = SteeringVectorFactory.from_refusal_direction(refusal_dir, alpha=-1.0)   # -alpha = push opposite to refusal
config = SteeringConfig(vectors=[vec], target_layers=[10, 11, 12, 13, 14, 15])

manager = SteeringHookManager()
manager.install(model, config)
#  ...generate normally...
manager.remove()      # model back to stock, weights untouched
```

Use this when you want the *behavior* change without shipping a modified checkpoint.

---

## 10. Troubleshooting

| Symptom | Likely cause | Fix |
|---|---|---|
| Still refuses after `advanced` | Direction set too narrow for this architecture | Step up: `aggressive` → `surgical` (MoE) → `informed` pipeline |
| Quality / coherence dropped visibly | Too-strong cut, or wrong layers hit | Retry with `optimized` (KL-budgeted); pin layers (`--layers 24-41,44`); avoid `nuclear` except intentional research |
| `self-improve` / verify finishes too quickly | Not enough probe pairs / memory-shortened sequence | `--max-seq-length 512`; raise GPU headroom |
| Refusal comes back after a few turns | Ouroboros self-repair | `informed` pipeline auto-computes compensation passes (section 8) |
| Gemma-2/3 model talks gibberish post-cut | Post-norm re-injecting removed direction | Keep the default norm folding — don't pass `--no-fold-post-norms` unless A/B-ing |
| Blah-blah nonsense / hallucinations worse | Activations unable to handle probe quantity / hidden-state leakage | Report to upstream OBLITERATUS issues with `abliteration_metadata.json` attached |
| Can't reproduce run from someone else | Missing provenance details | Restore `abliteration_metadata.json`; use the exact tool commit + source-model revision it records |

---

## 11. Quick reference — every execution path in one block

```bash
# Space (browser, nothing to install)
# → https://huggingface.co/spaces/pliny-the-prompter/obliteratus → click Obliterate

# Colab (free GPU, ≤ 8B comfortably)
# → https://colab.research.google.com/github/elder-plinius/OBLITERATUS/blob/main/notebooks/abliterate.ipynb → Run All

# CLI
pip install -e .
obliteratus interactive                                      # guided
obliteratus obliterate <MODEL> --method advanced             # one shot
obliteratus obliterate <MODEL> --method surgical \
    --output-dir ./liberated --contribute                    # full options
obliteratus models --tier small                              # what fits your VRAM
obliteratus info <MODEL>                                     # pre-flight architecture check
obliteratus aggregate --format summary                       # community results

# Web UI, local GPU
pip install -e ".[spaces]" && obliteratus ui                 # → http://localhost:7860

# YAML-configured study (versionable, reproducible)
obliteratus run examples/gpt2_layer_ablation.yaml
```

---

*Guide authored 2026-11-06 — based on the OBLITERATUS README (AGPL-3.0, elder-plinius; 9.2k★). For deep docs on every concept/intervention/analysis module, see the repo's `docs/` folder: `docs/CHOOSING_FEATURES.md`, `docs/CONCEPT_INTERVENTIONS.md`, `docs/CONCEPT_PACKS.md`, `docs/MCP_LOCAL_SETUP.md`.*
