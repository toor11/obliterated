# 🔓 Obliterated — Self-Hosted Uncensored AI on Proxmox

A connected guide series: pick (or make) an uncensored model, stand up the
hardware, serve it, and use it — with nothing ever leaving your network.

**Every document in this folder is part of one series.** Read order depends on
where you're starting:

```
                     ┌──────────────────────────────┐
                     │  1. GET MODELS               │
                     │  uncensored-ai-models-guide  │◄──────┐
                     │  (top-20 field guide)        │       │ pick models
                     └──────────────┬───────────────┘       │ to serve
                                    │ optional: make        │
                                    ▼ your own              │
                     ┌──────────────────────────────┐       │
                     │  2. MAKE MODELS              │───────┘
                     │  how-to-obliterate-models    │
                     │  (OBLITERATUS walkthrough)   │
                     └──────────────┬───────────────┘
                                    │ you have GGUF/safetensors
                                    ▼
                     ┌──────────────────────────────┐
                     │  3. BUILD THE SERVER         │
                     │  Proxmox 9 LXC series        │
                     │  Step 1 → ollama-openwebui   │  host, driver, GPU
                     │  Step 2 → llamacpp           │  passthrough, CUDA
                     │  Step 3 → vllm               │
                     └──────────────────────────────┘
```

## The five guides

| # | Guide | What it teaches | Read it when... |
|---|---|---|---|
| 0 | [**uncensored-ai-models-guide.md**](./uncensored-ai-models-guide.md) | The top-20 uncensored/abliterated models: what each is, exact HF links, per-family llama.cpp settings, free-access paths, hosted providers | You want to know *which* model to run |
| ⚒️ | [**how-to-obliterate-models.md**](./how-to-obliterate-models.md) | Make your **own** abliterated model with [OBLITERATUS](https://github.com/elder-plinius/OBLITERATUS): methods, verification, GGUF conversion | The model you want doesn't exist yet, or you want to ablate a specific base |
| 1 | [**ollama-openwebui-proxmox9-lxc.md**](./ollama-openwebui-proxmox9-lxc.md) | **Foundation.** Proxmox 9 install, NVIDIA driver, GPU passthrough to LXC, Open WebUI + Ollama, backups | You're building the server from bare metal |
| 2 | [**llamacpp-proxmox9-lxc.md**](./llamacpp-proxmox9-lxc.md) | CUDA toolkit in host + LXC, build llama.cpp, download & serve GGUFs (incl. split files), connect Open WebUI | You want the best runtime for **GGUF** quants and big RAM+VRAM offload |
| 3 | [**vllm-proxmox9-lxc.md**](./vllm-proxmox9-lxc.md) | vLLM in an LXC: `uv` install, tensor parallelism, API keys, systemd service, Open WebUI connection | The model fits in VRAM and you want **max throughput / concurrency** |

**Start with Step 1 if you're touching the hardware for the first time** — the
driver install, GPU passthrough and backup workflow made there are reused by
every later guide.

## The end-to-end path (models → Proxmox → chat)

1. **Choose a model** from the [top-20 table](./uncensored-ai-models-guide.md#5-comparison-stats--one-table-all-20)
   — match its VRAM column to your GPUs. Everyday pick: **#2 Huihui Qwen3.8-27B
   Abliterated** (Q4_K_M ≈ 16 GB); small pick: **#16 HauhauCS Gemma 4 12B QAT
   Balanced** (6.9 GB, only Q4_K_M exists); big pick: **#3/#19 Qwen3.6-35B-A3B MoE**.
2. **Download the GGUF** on the LXC — `llama-server -hf <repo>:<quant>` (Step 2,
   §4) or the `huggingface_hub` script (Step 2, §5) for split files.
3. **Serve it** — llama.cpp (Step 2) with the per-family sampling settings from
   the [model guide §3.5](./uncensored-ai-models-guide.md#35-the-best-settings-per-family-turn-these-into-your-defaults).
   Rule of thumb: GGUF / CPU+GPU offload → llama.cpp; fits in VRAM + concurrency → vLLM (Step 3).
4. **Connect Open WebUI** (built in Step 1) to llama.cpp or vLLM, with a
   prefix (`llamacpp-` / `vllm-`) so you always know which backend serves what.
5. **Snapshot the LXC** once it works — the same rollback trick used
   throughout the Proxmox series.

## Which runtime for which model?

| You have... | Use | Guide |
|---|---|---|
| GGUF quants (the whole top-20 list), split multi-file models, CPU+GPU offload | **llama.cpp** | [Step 2](./llamacpp-proxmox9-lxc.md) |
| Model fits entirely in VRAM, need many concurrent users (agent loops, OpenCode) | **vLLM** (needs safetensors — e.g. #19 Bahushruth v4, HauhauCS #9/#14/#16; not the `*-GGUF` repos) | [Step 3](./vllm-proxmox9-lxc.md) |
| Just want to chat in a browser ASAP | **Ollama + Open WebUI** | [Step 1](./ollama-openwebui-proxmox9-lxc.md) |
| A model you ablated yourself | Convert to GGUF ([OBLITERATUS §7](./how-to-obliterate-models.md#7-save--push--convert-to-gguf-get-it-into-llamacpp)) then llama.cpp | [Step 2](./llamacpp-proxmox9-lxc.md) |

## House rules (every guide assumes these)

- **"Uncensored" ≠ "unlawful"** — you own everything the model outputs. Both
  model guides open with the full safety notes.
- **Local-first:** anything sensitive (security work, client data) never goes
  to a hosted API — that's the whole point of the Proxmox series.
- **Snapshot before you experiment**, and keep host/LXC driver+CUDA versions matched.

---
*Part of the [toor11](https://github.com/toor11) homelab notes · November 2026*
