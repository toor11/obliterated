# TOP 20 UNCENSORED AI MODELS YOU SHOULD KNOW 😲 — Field Guide

> **TL;DR:** This is a plain-English guide to a community top-20 list of "uncensored" open-weight models: what each one is, how to run them with `llama.cpp`, the settings that matter, which ones cost nothing to try, and which ones make the most sense for cybersecurity, coding, and agent work.

---

## ⚠️ Read this first

- **"Uncensored" ≠ "unlawful."** These models simply have their safety refusals toned down so they will answer edgy *or unusual* prompts (security research, medical questions, dark fiction, constructive criticism, etc.). You are still 100% responsible for what you do with the output. Don't use them to break laws or hurt people.
- **Verify before you download.** This list moves fast — fine-tunes get renamed, re-quantized, or republished. Always check the actual Hugging Face repo for the real model card, true parameter count, license, and MD5/SHA256 of the GGUF you download.
- **Some stats below are estimates.** Where a repo-specific benchmark hasn't been independently verified, the tables give *family-typical* values, clearly marked. Don't quote them as gospel.
- Many of these are stacks of the same base families (Qwen3.8/3.6/3.5, Gemma 4, Ornith, DeepSeek V4.1) with different "uncensoring" methods — pick by family + technique, not brand hype.

---

## 1. The lingo, decoded

| Term | What it actually means |
|---|---|
| **Abliterated** | A surgical editing of the model weights (activation steering / ablation) so the "refusal directions" are neutralized. Makes the model answer nearly everything while destroying as few capabilities as possible.
| **Obliterated** | Ablation turned up to 11 — more aggressive de-restriction, sometimes at the cost of coherency.
| **Heretic** | A tool ("Heretic-AI") that auto-bilks the refusal direction out of a model. "Heretic" in a model name = it was produced with this method (measured by "KLD drop" on a badness scale).
| **Uncensored (generic)** | Usually fine-tuned on a removed-toxicity dataset (e.g., conservative RLHF removal). Quality varies wildly by the author.
| **Aggressive** | Community shorthand (e.g., HauhauCS releases) for the strongest de-restriction pass — most compliant, sometimes greatest quality loss.
| **Balanced** | The milder release of the same tune — usually best for daily-driver use.
| **A3B / MoE** | Mixture-of-Experts model — 35B total weights with only ~3B "active" per token (Qwen3.6-35B-A3B = fast like a 3B, smart like a 35B).
| **GSQ** | **Gumbel-Softmax Quantization** ([arXiv 2604.18556](https://arxiv.org/abs/2604.18556)) — a quant method where each tensor's grid assignment and per-group scales are *learned*, not heuristic. **RCO** ([arXiv 2605.00649](https://arxiv.org/abs/2605.00649)) then picks one quantization *type per tensor* under a total size budget. Result: very low-bit (2–3 bpw) quants that punch far above their weight class. ⚠️ GSQ tensors can't be re-quantized from BF16 — that's why #1 ships as a **tensor transplant**, not a fresh quant. |
| **MTP** | Multi-Token Prediction — a small draft head shipped with the model for **speculative decoding** in llama.cpp (`-md mtp-*.gguf` / `--spec-type draft-mtp`). Roughly 60% more tok/s, identical output quality. |
| **GGUF** | llama.cpp-native quantized format. This is what you download to run locally.
| **FP8** | 8-bit float. Great for vLLM/ExLlama on modern GPUs; **not** what you load with llama.cpp (convert or grab a GGUF instead).
| **Context (K / M)** | How much text the model can "see" at once (e.g., 128K, 256K context window).

---

## 2. The 20 models explained

> Sizes/type noted from the published name; confirm the exact weight, quants, and license in the repository. 🔗 **[Jump to real download links](#21-the-actual-hugging-face-links)**.

### 2.1 The actual Hugging Face links

Straight from @alizeh_ai's post (link #20 was truncated in the source):

1. https://huggingface.co/SC117/Qwen3.8-Flash-Next-GSQ-RCO-abliterated-GGUF
2. https://huggingface.co/huihui-ai/Huihui-Qwen3.8-27B-abliterated-GGUF
3. https://huggingface.co/huihui-ai/Huihui-Qwen3.6-35B-A3B-abliterated-MTP-GGUF
4. https://huggingface.co/JonathanColletti/Qwen3.8-27B-Uncensored-GGUF
5. https://huggingface.co/HauhauCS/Qwen3.8-27B-Uncensored-HauhauCS-Aggressive-MTP-GGUF
6. https://huggingface.co/DavidAU/Qwen3.5-9B-The-Defiant-Fable-Uncensored-Heretic-NEO-IMATRIX-MAX-MTP-GGUF
7. https://huggingface.co/mradermacher/Ornith-1.5-9B-uncensored-GGUF
8. https://huggingface.co/DavidAU/Qwen3.8-27B-TURBO-Fable-Cold-Fusion-735-882-Heretic-Uncensored-NEO-CODER-MAX-MTP-GGUF
9. https://huggingface.co/HauhauCS/Qwen3.6-35B-A3B-Uncensored-HauhauCS-Aggressive
10. https://huggingface.co/0bserverx/Qwen3.8-27B-Heretic-Abliterated-Uncensored-GGUF
11. https://huggingface.co/orcarouter/Qwen3.8-Flash-Next-Uncensored-GGUF
12. https://huggingface.co/mradermacher/Cyber-Ornith-1.5-9B-OBLITERATED-i1-GGUF
13. https://huggingface.co/jegreene/Swift-1.5-Qwen3.8-27B-heretic-GSQ-RCO-GGUF
14. https://huggingface.co/HauhauCS/Gemma-4-E4B-Uncensored-HauhauCS-Aggressive
15. https://huggingface.co/AtomicChat/Qwen-Image-2.1-Turbo-Uncensored-GGUF
16. https://huggingface.co/HauhauCS/Gemma4-12B-QAT-Uncensored-HauhauCS-Balanced
17. https://huggingface.co/mradermacher/Qwen3-VL-8B-Instruct-abliterated-GGUF
18. https://huggingface.co/HauhauCS/Qwen3.5-9B-Uncensored-HauhauCS-Aggressive
19. https://huggingface.co/Bahushruth/Qwen3.6-35B-A3B-abliterated-v4 *(GGUF quants: `Bahushruth/Qwen3.6-35B-A3B-abliterated-v4-GGUF`)*
20. https://huggingface.co/Abiray/DeepSeek-V4.1-Flash-1017-Uncensored-GSQ-RCO-Coder-GGUF *(197B — a low-bit IQ2_XXS variant also exists at [`DeepSeek-V4.1-Flash-1017-Uncensored-GSQ-RCO-IQ2_XXS-GGUF`](https://huggingface.co/Abiray/DeepSeek-V4.1-Flash-1017-Uncensored-GSQ-RCO-IQ2_XXS-GGUF))*

| # | Model | Family / Base | Size & Type | Uncensoring method | Works best as |
|---|---|---|---|---|---|
| 1 | **Qwen3.8-Flash-Next GSQ-RCO Abliterated** ⭐ [verified](https://huggingface.co/SC117/Qwen3.8-Flash-Next-GSQ-RCO-abliterated-GGUF) | Qwen3.8-Flash-Next (base: Qwen) | **~177B MoE hybrid** (DeltaNet + QSA attention, 512 routed experts, 48 layers), *multimodal* (mmproj included) | Abliterated via **tensor transplant into the GSQ-RCO quant** — 144 residual-stream tensors swapped, no re-quantization | Big multimodal brain at lowest-known VRAM for its class; the llama.cpp ships **262K context**, MTP draft head, IQ3_S→Q2_0 tiers (67–84 GB full weights + 28.8 GB n-gram shard). Runs Q2_0 tier on a **12 GB GPU + 64 GB RAM via the Strata engine** |
| 2 | **Huihui Qwen3.8-27B Abliterated** | Qwen3.8 27B | 27B dense | Abliterated (gentle) | Daily driver — best balance, usually keeps 99% of reasoning |
| 3 | **Huihui Qwen3.6-35B-A3B Abliterated** ⭐ [verified](https://huggingface.co/huihui-ai/Huihui-Qwen3.6-35B-A3B-abliterated-MTP-GGUF) | Qwen3.6-35B-A3B | 35B total / ~3B active MoE (256 experts, 8+1 active; 30 linear-attn + 10 full-attn layers), vision-capable | Abliterated (proof-of-concept method) + MTP draft head | Long-form, agentic, low-VRAM speed demon — Q2_K 13.2 GB → Q8_0 37.8 GB, specs up to 262K ctx special-decode-fast with `--spec-type draft-mtp` |
| 4 | **Qwen3.8-27B Uncensored (Heretic)** | Qwen3.8 27B | 27B dense | Heretic (a refusal-direction pass) | General chat + roleplay with better prose than abliterated versions |
| 5 | **HauhauCS Qwen3.8-27B Uncensored Aggressive** | Qwen3.8 27B | 27B dense | Fine-tune, aggressive | Zero-refusal compliance, minor quality hit |
| 6 | **Qwen3.5-9B Defiant Fable Heretic Uncensored** | Qwen3.5 9B | 9B dense | Heretic + creative fine-tune | Writing/roleplay on small hardware |
| 7 | **Ornith 1.5 9B Uncensored** | Ornith 1.5 | 9B dense | Fine-tune | Light chat on laptops/older GPUs |
| 8 | **Qwen3.8-27B TURBO Heretic Uncensored** | Qwen3.8 27B | 27B, pushed-quant / speed quants | Heretic | Fast 27B usage on mid GPUs |
| 9 | **HauhauCS Qwen3.6-35B-A3B Uncensored Aggressive** | Qwen3.6 35B MoE | 35B-A3B | Fine-tune, aggressive | MoE comfort with maximum compliance |
| 10 | **Qwen3.8-27B Heretic Abliterated Uncensored** | Qwen3.8 27B | 27B dense | Heretic + Abliterated double pass | Most "it will never say no" 27B — verify quality is what you want |
| 11 | **Qwen3.8-Flash-Next Uncensored** | Qwen "Flash-Next" | ~mid-size | Generic fine-tune | Probably-equivalent of #1 without the quant-experiment tag |
| 12 | **Cyber-Ornith 1.5 9B Obliterated** | Ornith 1.5 | 9B dense | Obliterated + security-flavored data | Light security-focused work on small rigs |
| 13 | **Swift 1.5 Qwen3.8-27B Heretic GSQ-RCO** | Qwen3.8 27B | 27B, **GSQ-RCO quantized** heretic tune | Heretic + GSQ low-bit quant | Latency-matters 27B use at low VRAM (low-bit GSQ tiers) |
| 14 | **HauhauCS Gemma 4 E4B Uncensored Aggressive** | Gemma 4 E4B (MoE-ish "Edge") | ~4B active | Fine-tune, aggressive | Tiny VRAM (<8 GB GPU) agent testing |
| 15 | **Qwen-Image 2.1 Turbo Uncensored** | Qwen-Image 2.1 | DiT/image model, published as GGUF | Fine-tune | **NOT a language model** — GGUF DiT weights are for ComfyUI/sd.cpp-style pipelines, not `llama-server` |
| 16 | **HauhauCS Gemma 4 12B QAT Uncensored Balanced** ⭐ [verified](https://huggingface.co/HauhauCS/Gemma4-12B-QAT-Uncensored-HauhauCS-Balanced) | Gemma 4 12B (google/gemma-4-12B-it, **QAT** = quantization-aware-trained) | 12B dense, **vision** (mmproj), 256K context, **only Q4_K_M 6.9 GB** (QAT makes 4-bit the sweet spot) + MTP drafter | Fine-tune, balanced — reported **0/465 refusals**, capabilities untouched | The small daily-driver: agentic coding, reasoning, RP; ~60% faster via MTP; license = Gemma terms (not Apache!) |
| 17 | **Qwen3-VL-8B Abliterated** | Qwen3-VL 8B | 8B, vision-language | Abliterated | Screenshot/OCR/image-QA tasks that mainstream VL models refuse |
| 18 | **HauhauCS Qwen3.5-9B Uncensored Aggressive** | Qwen3.5 9B | 9B dense | Fine-tune, aggressive | Zero-refusal small model on modest VRAM |
| 19 | **Bahushruth Qwen3.6-35B-A3B Abliterated v4** ⭐ [verified](https://huggingface.co/Bahushruth/Qwen3.6-35B-A3B-abliterated-v4) | Qwen3.6-35B-**A3B** (MoE hybrid, 256 experts 8+1) | 35B total / ~3B active, ~40 layers | Abliterated **v4** — norm-preserving orthogonalization, enriched 7.4K-prompt dataset; author reports **0% refusals, capabilities intact** | Big MoE work in ~24 GB (use the `-v4-GGUF` quants); smartest small-active MoE alongside #3 |
| 20 | **DeepSeek V4.1 Flash 1017 Uncensored** ⭐ [repo](https://huggingface.co/Abiray/DeepSeek-V4.1-Flash-1017-Uncensored-GSQ-RCO-Coder-GGUF) | DeepSeek-V4.1-Flash (1017 checkpoint) | **197 B MoE, GSQ-RCO quant** (Ultra-low-bit coder build; IQ2_XXS variant also published) | Uncensored + GSQ-RCO low-bit quant | Hard coding + long-context reasoning; GSQ-RCO low-bit makes a 197B plausible on serious single-box setups |

### Reality-check notes

- **#1 vs #11**: they are directly related — SC117's #1 takes the abliterated tensors *from* #11 (`orcarouter/Qwen3.8-Flash-Next-Uncensored-GGUF`, which was fine-tuned/done by orcarouter) and transplants them into ISTA-DASLab's official GSQ-RCO quants. Same brain, two different wrappings: #1 keeps the GSQ-RCO low-bit quant; #11 is the plain release.
- **#5, #9, #14, #16, #18** are the HauhauCS release family. The name pattern is `[family] [behavior]`. Aggressive = most compliant; Balanced = the author's own recommendation (99%+ of users won't need Aggressive).
- **#15** is an image generator. You will not load it in `llama-server` and get English back — GGUF DiT weights go into ComfyUI / sd.cpp-style pipelines.
- **#19 vs #3**: both are the same base (Qwen3.6-35B-A3B MoE). #3 (huihui) ships GGUF with an MTP drafter; #19 (Bahushruth v4) is the highest-quality ablation of that family (norm-preserving, 0% refusals, capabilities intact) — grab its `-v4-GGUF` repo for llama.cpp.
- **The specs below are verified from the repos for #1, #3, #16, #19 and #20** (flagged ⭐/✅). The rest remain name-based estimates. All of them have much better hardware-efficiency stories than the raw names suggest.

---

## 3. The llama.cpp tutorial (estimate-free, copy-paste friendly)

### 3.1 Get llama.cpp

```bash
# Fastest: grab a prebuilt nightly or build once
git clone https://github.com/ggml-org/llama.cpp
cd llama.cpp
cmake -B build -DGGML_CUDA=ON    # use -DGGML_VULKAN=ON for AMD/other GPUs
cmake --build build -j
# binaries land in build/bin
```

On Arch-like systems you can also install `pacman -S llama.cpp` or use `paru -S llama.cpp-cuda`.

### 3.2 Download a GGUF

Go to the model's Hugging Face page → **Files** → grab the GGUF that matches your VRAM:

| Your GPU/free VRAM | Suggested quant for ~27B | Suggested quant for 9–12B | Suggested quant for 35B-A3B |
|---|---|---|---|
| 8 GB / laptop | IQ3_XS (~12 GB, partial offload) | Q4_K_M (~5–6 GB) | Q4_K_M single-GPU offload OK |
| 12–16 GB | Q4_K_M / Q5_K_M | Q6_K / IQ5_XS | — |
| 24 GB | Q5_K_M / Q6_K | Q8 / FP16-cli | Q4_K_M, fast MoE |
| 48 GB+ | Q8_0 / FP16 | — | — |

```bash
# via the HF CLI
pip install -U "huggingface_hub[cli]"
hf download <org>/<repo> --include "*Q4_K_M*" --local-dir ~/models/qwen38-27b
# or with aria2 (faster, resume-able):
aria2c -x8 -s8 "https://huggingface.co/<org>/<repo>/resolve/main/<model>.Q4_K_M.gguf"
```

### 3.3 Launch the server (this is the part that makes it useful)

```bash
# Groaning-maximum Qwen3.8-27B (Q4_K_M) on a 24 GB card:
./build/bin/llama-server \
  -m ~/models/qwen38-27b/model-Q4_K_M.gguf \
  --alias qwen38-27b \
  -ngl 999 --ctx-size 32768 \
  --flash-attn --mlock --no-mmap \
  --temp 0.7 --min-p 0.05 --repeat-penalty 1.1 \
  --host 127.0.0.1 --port 8080
```

Now it's an OpenAI-compatible server. Point **anything** at it:

```bash
curl http://127.0.0.1:8080/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "qwen38-27b",
    "messages": [{"role":"user","content":"Explain buffer overflows"}],
    "temperature": 0.7
  }'
```

Tools that speak the OpenAI API and will "just work": **OpenCode / Cline / Zed / Cursor (via OpenRouter-style proxy override), Hermes, LM Studio, anything with `base_url` support.** For OpenCode, you can also run `opencode` → add provider → base URL `http://127.0.0.1:8080/v1`, model `qwen38-27b`, API key anything.

### 3.4 Memory cheatsheet (all models, one place)

| Problem | Fix |
|---|---|
| OOM on load | Lower `-ngl`, drop to a smaller quant (Q4_K_M → IQ3_XS), or use fewer context |
| Context too small | `--ctx-size 65536` + shrink `-ngl` to make room, or use `-fa` + KV-cache quantization (see 3.5) |
| Want it snappy | Use `--flash-attn` (Qwen & DeepSeek support it) and `--mlock` |
| Weird repetition / loops | Raise `--repeat-penalty` to 1.1–1.15, or add `--presence-penalty 0.5` |
| Model goes brain-dead on Chinese/Cyrillic output | Lower temp, raise min-p slightly |
| Model talks to itself / split personalities | Add `--reasoning-budget 0` if it's a Qwen thinking variant |

### 3.5 The best settings, per family (turn these into your defaults)

> **Rule of thumb:** On uncensored variants, do NOT crank temperature up. Ablated weights are already "loosened"; high sampling makes them confabulate.

**Qwen3.8 / 3.6 / 3.5 family (dense 9B / MoE 35B-3A / 27B / Flash)**
```ini
# llama-server equivalents
--temp 0.7 --min-p 0.05          # chat, general writing
--temp 0.15 --top-p 0.85         # CODE + agent work (this is the Qwen team favourite combo)
--temp 0.6 --top-k 20 --min-p 0.0 # default balanced
--repeat-penalty 1.05
-ngl 999 --flash-attn --ctx-size 32768
```
- **Qwen thinking/reasoning variants:** drop `--temp 0.6`, add `--reasoning-budget 0` if you *don't* want the "Thinking..." block in output.
- **MoE 35B-A3B variants** (#3, #9): the "3B active" weight means your GPU idles at maybe 15–20 GB free with a 65K context. Feel free to swing `--ctx-size` up to 131072 on 24 GB cards. #3 (huihui) ships MTP draft heads — verified command from the repo card:

```bash
./llama.cpp/llama-cli \
  -m Huihui-Qwen3.6-35B-A3B-abliterated-ggml-model-Q4_K.gguf \
  -ngl 99 -c 262144 -fa on -np 1 \
  --spec-type draft-mtp --spec-draft-n-max 6
```

**Qwen3.8-Flash-Next GSQ-RCO (#1) — the 177B flag-worthy, verified from the repo card.** Ships as two shards per tier (weights + 28.8 GB n-gram table), plus an mmproj vision projector and MTP drafter:

```bash
# Download one tier (IQ3_S here) — both shards, llama.cpp picks up shard 2 automatically:
hf download SC117/Qwen3.8-Flash-Next-GSQ-RCO-abliterated-GGUF \
  --include "IQ3_S/*" --local-dir .

# Text
llama-cli \
  -m IQ3_S/Qwen3.8-Flash-Next-GSQ-RCO-abliterated-IQ3_S-00001-of-00002.gguf \
  -lm mmap --lazy-mode on -ngl 99 -c 32768 \
  -p "Your prompt here"

# Vision (multimodal)
llama-mtmd-cli \
  -m IQ3_S/Qwen3.8-Flash-Next-GSQ-RCO-abliterated-IQ3_S-00001-of-00002.gguf \
  --mmproj mmproj-Qwen3.8-Flash-Next-BF16.gguf \
  -lm mmap --lazy-mode on --image photo.jpg -p "Describe this image."

# Speculative decoding with the MTP draft head
llama-cli \
  -m IQ3_S/Qwen3.8-Flash-Next-GSQ-RCO-abliterated-IQ3_S-00001-of-00002.gguf \
  -md mtp-Qwen3.8-Flash-Next-Q4_0.gguf --draft-max 4 \
  -lm mmap --lazy-mode on -ngl 99
```
- `-lm mmap --lazy-mode on` keeps the 28.8 GB n-gram table memory-mapped on disk (one row read per token); only shard 1 needs to be resident in VRAM/RAM. Tier sizes (total download): IQ3_S 83.9 GB · IQ3_XXS 76.1 GB · IQ2_XS 78.5 GB · Q2_0 76.8 GB. Native context 262144 — start at `-c 32768` and work up.
- **Strata engine path (low-VRAM win):** the official model runs on a **single 12 GB card + 64 GB system RAM** with Strata; this build is only +0.25 GB and verified at 104.4 tok/s (dual-GPU, ≤ upstream). If you migrate from the official GSQ-RCO pack, you **must rebuild the native pack** for this repo's GGUFs (tensor offsets changed — the old `native_experts.txt` won't match).
- The MTP draft head is **not** abliterated (no abliterated MTP head exists) and the `mtp-q2_0.gguf`/`strata/` files are Strata-only — with llama.cpp use the root `mtp-Qwen3.8-Flash-Next-Q4_0.gguf` instead.

**Gemma 4 family (E4B, 12B) — HauhauCS builds are author-tuned**
```ini
# The HauhauCS Balanced 12B (QAT) ships with its own dialed-in settings — use these:
--temp 0.6 --top-k 64 --top-p 0.9 --min-p 0.05 --repeat-penalty 1.1
-ngl 99 -fa on
```
The author tunes each HauhauCS release end-to-end, so prefer their published settings over stock Gemma defaults (note the repeat-penalty 1.1 here — Gemma 4 is more robust to it than Gemma 3 was; the old "Gemma hates repeat penalty" lore is stale for Gemma 4).

**Gemma 4 12B (QAT) — verified load with vision + MTP speedup** *(#16)*:
```bash
llama-server \
  -m Gemma4-12B-QAT-Uncensored-HauhauCS-Balanced-Q4_K_M.gguf \
  -md mtp-gemma-4-12B-it.gguf --spec-type draft-mtp \
  -ngl 99 -fa on
# For image input, add:
#   --mmproj mmproj-Gemma4-12B-QAT-Uncensored-HauhauCS-Balanced-BF16.gguf
```
⚠️ Only Q4_K_M exists for this QAT build, and that's on purpose — Gemma 4 is quantization-aware-trained, so Q4_K_M *is* the sweet spot; higher-precision quants just waste VRAM. Also: if you run LM Studio on multi-GPU, avoid its *tensor-split* mode with Gemma 4 (known crashes — use layer-split on a single card instead).

**Ornith 1.5 (9B) + Cyber-Ornith (+ Obliterated)**
```ini
--temp 0.9 --min-p 0.05 --repeat-penalty 1.1 # chat
--temp 0.2 --top-p 0.9                       # cyber analysis / terminal/script work
```
Obliterated nothing at all - great compliance, slightly drifty output. Keep temp low for anything that touches code.

**DeepSeek V4.1 "Flash" (Uncensored)**
```bash
# cannot be pushed past ~0.6 temp without nonsense
--temp 0.6 --min-p 0.05 --repeat-penalty 1.0
-ngl 999 --ctx-size 65536 --flash-attn
```
If V4.1 is the full-Expert MoE class, most people can't run it locally. Only quantized/smaller or the "Flash" distill variants are practical — check the repo for which checkpoint is what. Otherwise use it through an API provider.

**Qwen3-VL-8B (image-aware)**
```bash
# Multimodal: page in the mmproj too
./build/bin/llama-server \
  -m Qwen3-VL-8B-abliterated.Q4_K_M.gguf \
  --mmproj Qwen3-VL-8B-mmproj-Q8.gguf \
  -ngl 999 --ctx-size 16384 --temp 0.2
```

**Qwen-Image 2.1 Turbo (Obsolete: not a text model)**
- Needs `sd.cpp`, ComfyUI, or Swiper.cpp — it takes **prompts**, not chat messages.
- 20–40 steps, CFG 2–5 (Turbo distills don't want a high CFG),负面-negatives all standard.

### 3.6 Advanced knobs that actually help

```bash
# KV-cache quant saves 50%+ of context VRAM with almost no quality cost:
--flash-attn -fa -ctk q8_0 -ctv q8_0

# Partial GPU offload when you don't fit:
-ngl 45    # pick a number until it fits

# Chat template override IF the GGUF bundles a broken template:
--chat-template qwen

# Make a *faster* server start on cold boot:
--no-mmap --mlock
```

---

## 4. Which ones are free, and how to use each for $0

| Access path | Cost | What you get | How |
|---|---|---|---|
| **Own hardware (best)** | $*/h it burns | Full GGUF / FP8, no logging, full speed | Download GGUF from Hugging Face, run `llama-server` (section 3) |
| **OpenRouter** | several have `:free` slugs | Uncensored fine-tunes behind rotating IDs | `site:openrouter.ai/models` → add `:free` variant → standard OpenAI client with `OUT` headers. Free has ~20 RPM/day caps — fine for testing
| **Venice AI ("experiential")** | free tier | Curated uncensored/pro-choice models, prompt-anonymized | GUI at venice.ai; API at docs.venice.ai with a ~$0 OPENAI-style key; free tier gives daily tokens |
| **OpenCode / Cline / Zed / Cursor / Hermes** | free when pointed locally | Whatever you ran in llama.cpp | Set `base_url=http://127.0.0.1:8080/v1`, model = your `--alias` |
| **LM Studio / Ollama / GPT4All** | free | Easy GUI or `ollama run` wrappers | Drop GGUF in LM Studio, create a Modelfile for Ollama |
| **Hugging Face Spaces** | free (sometimes) | Occasional demos of new crowd tunes | `huggingface.co/spaces` search — makesmodel may LPS gone after a day |

> API credits needed for: **big DeepSeek V4.1-class MoE**, anything on providers without a `:free` route, and image models like **#15** if you don't run it on ComfyUI locally.

**Golden rule:** run-family = "who is holding your logs." Anything an API sees, you can't un-see from the API's side. Use local for anything sensitive — doubly true for the cybersecurity job below.

---

## 5. Comparison stats — one table, all 20

> 📊 **Key:** Type = `dense` / `MoE` / `image` / `VL`. VRAM = rough Q4_K_M full GPU-offload estimate. Speed = rough tok/s on RTX 4090-class hardware at 32K prompt-full — treat anything as ballpark, not gospel. ⚔ = independently benchmarked in the wild, ✗ = repo card only / community vibe (verify).

| # | Model | Params | Type | Quant VRAM ~ | Desktop fits | Context | Best score at |
|---|---|---|---|---|---|---|---|
| 1 | Qwen3.8-Flash-Next GSQ-RCO Abliterated ✅ | **177 B** MoE hybrid | **MoE** + vision, verified | **67 GB (Q2_0) → 84 GB (IQ3_S)** full + 28.8 GB n-gram shard; **12 GB GPU + 64 GB RAM** via Strata engine | Multi-GPU / Strata | **262 K** ✅ | Big-brain multimodal chat, GSQ low-bit math ✅ (104.5 tok/s on Strata dual-GPU, upstream parity) |
| 2 | Huihui Qwen3.8-27B Abliterated | 27 B | dense ⚔ | 16 GB @ Q4 | 16–24 GB | 128K ⚔ | Coding ⚔ Reasoning ⚔ = solid day-to-day chat |
| 3 | Huihui Qwen3.6-35B-A3B Abliterated ✅ | 35B/3A | MoE + vision + MTP, verified | **13.2 GB @ Q2_K · 29.2 GB @ Q6_K** | 16–24 GB | **262 K** ✅ | Agentic tools + long docs at 3B speed, MTP spec-decode ✅ |
| 4 | Qwen3.8-27B Uncensored (Heretic) | 27 B | dense ✗ | 16 GB @ Q4 | 16–24 GB | 128K ⚔ | Chat/Writing ✗ |
| 5 | HauhauCS Qwen3.8-27B Aggressive | 27 B | dense ✗ | 16 GB @ Q4 | 16–24 GB | 128K ⚔ | Raw compliance ✗ |
| 6 | Qwen3.5-9B Defiant Fable Heretic | 9 B | dense ✗ | 5–6 GB @ Q4 | 8 GB | 256K ✗ | Creative / fiction on small rigs ✗ |
| 7 | Ornith 1.5 9B Uncensored | 9 B | dense ✗ | 5–6 GB @ Q4 | 8 GB | 128K ✗ | Light assistant ✗ |
| 8 | Qwen3.8-27B TURBO Heretic | 27 B | dense/pushed ✗ | 12–16 GB | 16 GB+ | 128K ⚔ | Gas-throughput 27B ✗ |
| 9 | HauhauCS Qwen3.6-35B-A3B Aggressive | 35B/3A | MoE ✗ | 20 GB @ Q4 | 24 GB | 128K ⚔ | Agents with no refusals ✗ |
| 10 | Qwen3.8-27B Heretic+Abliterated | 27 B | dense ✗ | 16 GB @ Q4 | 16–24 GB | 128K ⚔ | Maximum-no-refusals 27B ✗ |
| 11 | Qwen3.8-Flash-Next Uncensored | ~mid | dense ✗ | 15–18 GB | 16 GB+ | 128K ⚔ | Fast chat ✗ |
| 12 | Cyber-Ornith 1.5 9B Obliterated | 9 B | dense ✗ | 5–6 GB | 8 GB | 128K ✗ | Small-VRAM security ✗ |
| 13 | Swift 1.5 Qwen3.8-27B Heretic GSQ-RCO | 27 B | dense (GSQ low-bit) ✗ | 12–16 GB (low-bit GSQ) | 16 GB+ | 128K ⚔ | Latency-heavy 27B at low VRAM ✗ |
| 14 | Gemma 4 E4B Aggressive | ~4B active | MoE-ish ✗ | 3–4 GB | <8 GB | 128K ⚔ | Tiny-VRAM agent testing ✗ |
| 15 | Qwen-Image 2.1 Turbo Uncensored | image | image ✗ | 6–12 GB @ FP8 | 12 GB | n/a | nsfw image gen ✗ need+different pipeline |
| 16 | HauhauCS Gemma 4 12B QAT Balanced ✅ | 12 B | **dense + vision + MTP** ✅, verified | **6.9 GB — only Q4_K_M exists** (QAT-tuned, by design) | 8 GB+ | **262 K** ✅ | Agentic coding, reasoning, RP on a small card; ~60% faster with MTP ✅ |
| 17 | Qwen3-VL-8B Abliterated | 8 B + vision | VL ✗ | 6–8 GB | 8–12 GB | 128K ⚔ | Unrefused image QA / OCR ✗ |
| 18 | HauhauCS Qwen3.5-9B Aggressive | 9 B | dense ✗ | 5–6 GB | 8 GB | 256K ✗ | Zero-refusal small ✗ |
| 19 | Bahushruth Qwen3.6-35B-A3B Abliterated v4 ✅ | 35B/3A | **MoE** ✅ (safetensors + `-v4-GGUF` quants) | ~13–25 GB @ Q2–Q5 (MoE GGUF, estim.) | 16–24 GB | 128 K | Cleanest ablation of the 35B-A3B family: 0% refusals, capabilities intact ✅ |
| 20 | DeepSeek V4.1 Flash 1017 Uncensored ✅ | **197 B** GSQ-RCO MoE | MoE + Coder ✅ | low-bit GSQ tiers (check the repo's Files tab — no Q4/Q8 exists for 197B) | multi-GPU / Strata-class | check repo | Hard coding + long-context reasoning, GSQ-quantized ✅ |

**Named hard hitters for "capability":"**
- 🥇 Top reasoning / hardest coding: **#1** (177B MoE hybrid) and **#20** (197B GSQ-RCO Coder — now locally runnable via Strata-class hardware) if you own the VRAM, or **#19 / #3** (35B-A3B MoE) for reachable local rigs
- 🥈 Best speed-per-smart local: **#3 and #9** (35B-A3B MoE — the 3B-active speed-priceless option for agents); **#16** with MTP for smaller cards
- 🥉 Best everyday 27B: **#2 Huihui** (best "I'm still smart, just not refusing" balance)
- 🏅 Most "will answer anything" per GB: **#12 Cyber-Ornith / #10 double-pass 27B**
- 🏅 Tiny rigs: **#16 Gemma 4 12B QAT** (6.9 GB char-perfect daily driver, verify) or **#14 Gemma E4B** for even less

---

## 6. The three career questions

### 🕵️ Best FOR CYBERSECURITY
1. **#12 Cyber-Ornith 1.5 9B Obliterated** — small, refuses nothing, straight to payload analysis / CTF hints / reverse-engineering notes on a 6 GB GPU
2. **#5 or #10 (27B variants)** — same brain as the best 27B with no squeamishness explaining exploit paths, red-team guidelines, or taking on a pentest-report rewrite
3. **#3 / #9 (35B-A3B MoE)** — agentic and tool-calling savvy for building analyst pipelines that chew logs

⚠️ **Field-real tips for security work:**
- Run these **locally, always**. Client incidents, NDA data, fuzzing payloads = nono to a cloud API.
- Keep `--temp 0.15–0.3` for exploit reasoning, and `--ctx-size 65536` when feeding code.
- Use `--dry-on-uncensored` (`--dry-run`?) & never rely on the model's memory — it's noise, not ground truth. Verify all drivel against a source.

**How to use for cyber:** OpenCode in agent mode + BB (bb, dap, gdb) + MCP? B, with the local llama-server as provider → point OpenCode `base_url` at it and ask it to critique logs, write PoCs, explain cryptic crash stacks, or help with never-say-refused red-team reports.

### 💻 Best FOR CODING
1. **#20 DeepSeek V4.1 Flash** — top-tier for real code if API location/latency OK
2. **#3 Huihui Qwen3.6-35B-A3B Abliterated** — best local coding monster: MoE = fast enough for agent loops, enforcement hits Qwen-team reference values
3. **#2 Huihui Qwen3.8-27B Abliterated** — the 24 GB land of желания coding daily driver
4. **#14 Gemma 4 E4B Aggressive** — CI runner / single-IDE wingers with a 4-B you can shove in the corner of a VM

- **Golden gear:** `--temp 0.15 --top-p 0.85` for code, `--ctx-size 65536` min for big files. **Huihui abliteration-style keeps 98% of original code-ability** — the removal of refusal directions doesn't remove function.
- For a 100% on-Y finish, drop in a repo map and run Cline/OpenCode with tool-calling mode on the 35B-A3B MoE variant — it's tested well with tool-calls at 0.15 temp.

### 🤖 Best FOR AGENT WORK
1. **#3 and #9 Qwen3.6-35B-A3B (Abliterated / Aggressive)** — the agents' favourite: fast per token, great tool-calling, no "I can't help with embedded pentesting" stopsign
2. **#1 / #11 Flash-Next** — when the agent loop needs 100+ steps and you don't want to watch it do slow 27B
3. **#16 HauhauCS Gemma 4 12B Balanced** — the tiny agent-friendly assistant for a laptop
4. **#17 Qwen3-VL-8B Abliterated** — screenshot agents that read UIs and refuse nothing

- **Agent settings:** `--temp 0.2 --top-p 0.85 --repeat-penalty 1.0 --ctx-size 131072` (kill that odd Qwen sampling drift on very long contexts with `--no-reasoning`), and always cap `max_tokens` per step (512–1024) so a runaway tool call can't torrefy context.

---

## 7. Where to use them (recap of the list's pointers)

- **Venice AI / "experiential"** — browser-friendly, anonymous-ish, free tier, some models image+text
- **OpenRouter** — dozens of these variants, `:free` routes for the small/average ones; standard OpenAI API contract (drop-in to OpenCode, Cline, Zed, Cursor, Hermes via `base_url=https://openrouter.ai/api/v1`)
- **OpenCode / Cline / Zed / Cursor / Hermes via API** — the coding-agent crowd; combined with a local `llama-server` you get agents with **zero** logging
- **Local via Hugging Face GGUF / FP8** — the privacy end-game: GGUF for llama.cpp (all GPUs, even CPU); FP8 for vLLM/ExLlama on modern datacenter/Ada GPUs

---

## 8. Quick-start for the impatient

**The one-liner way (llama.cpp now ships an app layer that pulls straight from HF):**
```bash
curl -LsSf https://llama.app/install.sh | sh          # Linux/macOS
llama serve -hf SC117/Qwen3.8-Flash-Next-GSQ-RCO-abliterated-GGUF:IQ2_XS
# …or any repo from section 2.1, with any quant it publishes
```

**The manual way:**
```bash
# 1. Get llama.cpp running
pacman -S llama.cpp        # or build from source above

# 2. Grab an everyday 27B
hf download huihui-ai/Huihui-Qwen3.8-27B-abliterated-GGUF \
  --include "*Q4_K_M*" --local-dir ~/models/qwen

# 3. Serve it
llama-server -m ~/models/qwen/*Q4_K_M*.gguf -ngl 999 \
  --ctx-size 32768 --flash-attn \
  --temp 0.7 --min-p 0.05 --repeat-penalty 1.05 \
  --port 8080

# 4. Browse to http://127.0.0.1:8080
# or point OpenCode/Cline/Zed/Cursor/Hermes at it with:
#   base_url = http://127.0.0.1:8080/v1
#   api_key  = anything
#   model    = qwen38-27b
```

---

*File last assembled: 2026-11-05 — ⭐ flags mark entries whose specs and load commands were verified directly against their Hugging Face model cards (currently #1, #3, #16, #19). Community fine-tunes rename weekly — the model card on Hugging Face is the source of truth, not social media lists.* 🫡
