# vLLM on Proxmox 9 (LXC) — Homelab AI Server Guide

**Author:** [toor11](https://github.com/toor11)
**Last updated:** November 2026

My personal notes and checklist for running [vLLM](https://docs.vllm.ai/) — a high-throughput inference server with an OpenAI-compatible API — inside a Proxmox 9 LXC container with NVIDIA GPU passthrough, and connecting it to Open WebUI.

**Series order:**
1. [Ollama + Open WebUI](./ollama-openwebui-proxmox9-lxc.md)
2. [Llama.cpp + Unsloth](./llamacpp-proxmox9-lxc.md)
3. vLLM (this guide)

Companion guides (what to run once the server exists): [top-20 uncensored models](./uncensored-ai-models-guide.md) · [obliterate your own](./how-to-obliterate-models.md) — see the [series index](./README.md) for the full picture.

## Table of contents

1. [When to use vLLM](#when-to-use-vllm)
2. [Prerequisites](#prerequisites)
3. [Create the LXC](#1-create-the-lxc)
4. [Install the driver in the LXC](#2-install-the-nvidia-driver-in-the-lxc)
5. [Install uv and vLLM](#3-install-uv-and-vllm)
6. [Hugging Face access](#4-hugging-face-access-optional)
7. [Smoke test with a small model](#5-smoke-test-with-a-small-model)
8. [Serve a real model across your GPUs](#6-serve-a-real-model-across-your-gpus)
9. [Test the API](#7-test-the-api)
10. [Run vLLM as a service](#8-run-vllm-as-a-systemd-service-optional)
11. [Connect Open WebUI](#9-connect-open-webui)
12. [Snapshot](#10-snapshot)
13. [Troubleshooting](#troubleshooting)
14. [Quick checklist](#quick-checklist)

---

## When to use vLLM

- **vLLM** is built for throughput and serving several requests at once (continuous batching), and it can split one model across multiple GPUs (tensor parallelism). It mostly runs models in their original Hugging Face formats (safetensors, plus quantizations such as AWQ/GPTQ/FP8 where supported).
- **llama.cpp / Ollama** are better for CPU+GPU offloading, GGUF quants and very large models that don't fit in VRAM.
- Rule of thumb: if the model fits in your total VRAM and you want speed and concurrency, use vLLM; if it doesn't, use llama.cpp.

## Prerequisites

- [Step 1](./ollama-openwebui-proxmox9-lxc.md) completed: Proxmox 9, NVIDIA driver on the host, GPU passthrough working.
- An NVIDIA GPU with enough VRAM for the model you want. vLLM keeps the model **and** a KV cache in VRAM, so leave headroom.
- Driver version on the host and in the LXC must match (this repo uses `620.70.06`).
- vLLM's docs list Linux and Python 3.11–3.14 as requirements. You don't need to rely on the container's system Python: `uv` below installs its own.
- You do **not** need to build anything from source. The prebuilt wheels pull in their own CUDA runtime libraries. The CUDA toolkit from [Step 2](./llamacpp-proxmox9-lxc.md) isn't normally required, but it doesn't hurt to have it if you want to compile extensions later.

## 1. Create the LXC

1. Download a **Debian 13** container template.
2. Create a new container with generous disk (models are large — see the sizing table in [Step 1](./ollama-openwebui-proxmox9-lxc.md#4-create-the-open-webui-lxc); vLLM also caches downloads) and plenty of RAM and CPU cores.
3. Before starting it, add **Device Passthrough** entries for every `/dev/nvidia*` device, as in [Step 1, section 8](./ollama-openwebui-proxmox9-lxc.md#8-pass-the-gpus-through-to-the-lxc).
4. Start the container and update it:

```bash
apt update && apt upgrade -y
apt install -y curl git nano htop nvtop
```

## 2. Install the NVIDIA driver in the LXC

On the **host**, push the same driver file used in Step 1 into the container (replace `102` with your container ID):

```bash
pct push 102 NVIDIA-Linux-x86_64-620.70.06.run /root/NVIDIA-Linux-x86_64-620.70.06.run
pct enter 102
```

Inside the LXC:

```bash
chmod +x NVIDIA-Linux-x86_64-620.70.06.run
./NVIDIA-Linux-x86_64-620.70.06.run --no-kernel-modules
```

Choose Proprietary (or MIT for Blackwell RTX 50xx), then verify:

```bash
nvidia-smi
```

You should see all passed-through GPUs.

## 3. Install uv and vLLM

[`uv`](https://docs.astral.sh/uv/) is the Python environment manager vLLM's docs recommend. Install it and create an environment:

```bash
curl -LsSf https://astral.sh/uv/install.sh | sh
source ~/.bashrc    # or open a new shell so `uv` is on your PATH

mkdir -p ~/vllm && cd ~/vllm
uv venv --python 3.12 --seed
source .venv/bin/activate
```

Install vLLM. `--torch-backend=auto` makes uv pick the PyTorch build that matches your installed driver:

```bash
uv pip install vllm --torch-backend=auto
```

vLLM's quickstart also lists an optional step that pre-downloads kernels it would otherwise fetch and compile at first startup (this mainly saves several minutes on Hopper and newer GPUs):

```bash
vllm download-kernels
```

Verify:

```bash
python -c "import vllm; print(vllm.__version__)"
```

> Activate the environment (`source ~/vllm/.venv/bin/activate`) every time you open a new shell before running `vllm`.

## 4. Hugging Face access (optional)

Public models download without logging in. For gated models (some Llama/Gemma releases, for example), create a token at huggingface.co and log in:

```bash
hf auth login
```

By default, models are cached under `~/.cache/huggingface`. To keep them somewhere else (e.g. a bigger mount or a shared model directory), set `HF_HOME` before running vLLM:

```bash
export HF_HOME=/path/to/models
```

## 5. Smoke test with a small model

Start with a tiny model to confirm the GPU stack works before downloading something huge:

```bash
vllm serve Qwen/Qwen2.5-1.5B-Instruct
```

By default the server listens on `http://localhost:8000`. In another shell:

```bash
curl http://localhost:8000/v1/models
```

Stop it with `Ctrl+C` once it responds.

## 6. Serve a real model across your GPUs

Replace `<org>/<model>` with a Hugging Face model that fits in your total VRAM (weights + KV cache). **One format caveat from the companion model guide:** vLLM serves the original Hugging Face formats (safetensors / AWQ / GPTQ / FP8), **not GGUF**. So the natural picks from the [top-20 uncensored guide](./uncensored-ai-models-guide.md) are the releases published as safetensors: #19 Bahushruth Qwen3.6-35B-A3B v4 (verified — the repo ships both safetensors and `-v4-GGUF`), and the HauhauCS releases **without** a `-GGUF` suffix (#9, #14, #16, #18 — confirm the Files tab has safetensors before downloading). Everything GGUF-only belongs in the [llama.cpp LXC](./llamacpp-proxmox9-lxc.md) instead — that includes every `*-GGUF` repo, the HauhauCS **MTP-GGUF** releases (#5), and the GSQ-RCO low-bit builds (#1, #13, #20). Example for 4 GPUs:

```bash
vllm serve <org>/<model> \
  --host 0.0.0.0 \
  --port 8000 \
  --api-key <your-api-key> \
  --tensor-parallel-size 4 \
  --gpu-memory-utilization 0.90 \
  --max-model-len 16384
```

To connect this to the coding-agent workflow described in the model guide (OpenCode/Cline pointed at a local uncensored model for security or agent work), the OpenAI-compatible endpoint above is all they need — `base_url=http://<LXC-IP>:8000/v1`, model = `<org>/<model>`, your `--api-key` as the key. See [model guide §3.3](./uncensored-ai-models-guide.md#33-launch-the-server-this-is-the-part-that-makes-it-useful).

What the main flags do:

| Flag | Purpose |
|---|---|
| `--host 0.0.0.0` / `--port 8000` | Listen on all interfaces so Open WebUI (another container) can reach it. Only do this on a trusted network. |
| `--api-key` | Require this key in the `Authorization` header. You can also set the `VLLM_API_KEY` environment variable instead. |
| `--tensor-parallel-size N` | Split the model across N GPUs. N is normally the number of GPUs you want to use and has to divide evenly into the model's attention heads, so 1, 2, 4 and 8 are the usual choices. |
| `--gpu-memory-utilization` | Fraction of each GPU's VRAM vLLM may claim (weights + KV cache). Lower it if you hit out-of-memory errors or share the GPU with something else. |
| `--max-model-len` | Maximum context length. Shorter context = smaller KV cache = more room for concurrent requests. |

Notes:

- With one GPU, drop `--tensor-parallel-size` (the default is 1).
- By default vLLM applies the sampling defaults recommended by the model's `generation_config.json`. Pass `--generation-config vllm` if you want vLLM's own defaults instead.
- Quantized models (AWQ/GPTQ/FP8) use less VRAM. Check that your GPU generation supports the format; older cards such as the RTX 3090 don't have native FP8 hardware support, so AWQ/GPTQ are the more common choices there.
- The first start of a new model downloads it and can take a long time. Later starts load from the cache.

## 7. Test the API

```bash
curl http://<LXC-IP>:8000/v1/models \
  -H "Authorization: Bearer <your-api-key>"
```

Chat completion example:

```bash
curl http://<LXC-IP>:8000/v1/chat/completions \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer <your-api-key>" \
  -d '{
    "model": "<org>/<model>",
    "messages": [{"role": "user", "content": "Say hello in one sentence."}]
  }'
```

Use `nvtop` in another shell to watch all GPUs load.

## 8. Run vLLM as a systemd service (optional)

So it starts on boot and restarts on failure. Create the unit file:

```bash
nano /etc/systemd/system/vllm.service
```

```ini
[Unit]
Description=vLLM OpenAI-compatible server
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
WorkingDirectory=/root/vllm
Environment="VLLM_API_KEY=<your-api-key>"
Environment="HF_HOME=/root/.cache/huggingface"
ExecStart=/root/vllm/.venv/bin/vllm serve <org>/<model> \
  --host 0.0.0.0 --port 8000 \
  --tensor-parallel-size 4 \
  --gpu-memory-utilization 0.90 \
  --max-model-len 16384
Restart=on-failure
RestartSec=10

[Install]
WantedBy=multi-user.target
```

Enable and start it:

```bash
systemctl daemon-reload
systemctl enable --now vllm
journalctl -u vllm -f
```

Only one vLLM service can use the GPUs at a time. Stop the service (`systemctl stop vllm`) before running another model by hand.

## 9. Connect Open WebUI

1. In Open WebUI, open **Admin → Settings → Connections** and add an OpenAI-compatible connection.
2. URL: `http://<vLLM-LXC-IP>:8000/v1`
3. API key: the key you set with `--api-key`.
4. Optionally set a prefix (e.g. `vllm-`) so you can tell which backend serves which model.
5. Your served model should appear in the model list. Rename it from the **Models** page if the name is long.

If Ollama, llama.cpp and vLLM share the same GPUs, don't run them all at once — each one reserves VRAM.

## 10. Snapshot

Once everything works, snapshot the LXC (Container → Snapshots) so you have a known-good state. Snapshot again before upgrading vLLM.

To upgrade later:

```bash
cd ~/vllm && source .venv/bin/activate
uv pip install --upgrade vllm --torch-backend=auto
```

---

## Troubleshooting

**`nvidia-smi` shows no GPUs in the LXC.** Re-check the device passthrough entries and do a full **stop/start** of the container. Confirm the host and LXC driver versions match.

**Out-of-memory errors at startup.** Lower `--gpu-memory-utilization`, lower `--max-model-len`, use a quantized model, or increase `--tensor-parallel-size` if you have more GPUs free. Make sure no other service (Ollama, llama.cpp) is holding VRAM.

**`--tensor-parallel-size` error.** The value has to divide the model's attention heads evenly. Try 1, 2, 4 or 8 and check the model's config on Hugging Face.

**Very slow first start.** The first run downloads the model and may compile kernels. `vllm download-kernels` and a warm model cache help on later runs.

**Open WebUI can't connect.** Confirm vLLM is listening on `0.0.0.0` (not only `localhost`), the port is reachable from the Open WebUI container, and the URL ends in `/v1` with a matching API key.

---

## Quick checklist

- [ ] Steps 1 and 2 completed (host driver, GPU passthrough working)
- [ ] New Debian 13 LXC with all `/dev/nvidia*` devices passed through
- [ ] Driver installed in LXC (`--no-kernel-modules`), `nvidia-smi` shows GPUs
- [ ] `uv` installed, venv created, `vllm` installed
- [ ] Smoke test with a small model works (`/v1/models` responds)
- [ ] Real model served with the right `--tensor-parallel-size`
- [ ] API key set and tested with `curl`
- [ ] (Optional) systemd service enabled
- [ ] Open WebUI connected via `http://<LXC-IP>:8000/v1`
- [ ] Snapshot taken
