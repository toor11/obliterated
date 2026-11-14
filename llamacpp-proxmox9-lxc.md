# Llama.cpp on Proxmox 9 (LXC) — Homelab AI Server Guide

**Author:** [toor11](https://github.com/toor11)
**Last updated:** November 2026

My personal notes and checklist for building llama.cpp from source with CUDA inside a Proxmox 9 LXC container, downloading GGUF models, and connecting it to Open WebUI.

**Series order:**
1. [Ollama + Open WebUI](./ollama-openwebui-proxmox9-lxc.md)
2. Llama.cpp + Unsloth (this guide)
3. [vLLM](./vllm-proxmox9-lxc.md)

Companion guides (what to run once the server exists): [top-20 uncensored models](./uncensored-ai-models-guide.md) · [obliterate your own](./how-to-obliterate-models.md) — see the [series index](./README.md) for the full picture.

## Table of contents

1. [Prerequisites](#prerequisites)
2. [Install the CUDA toolkit on the Proxmox host](#1-install-the-cuda-toolkit-on-the-proxmox-host)
3. [Set up the LXC: driver and CUDA toolkit](#2-set-up-the-lxc-driver-and-cuda-toolkit)
4. [Build llama.cpp from source](#3-build-llamacpp-from-source)
5. [Run a model directly from Hugging Face](#4-run-a-model-directly-from-hugging-face)
6. [Alternative: download models with huggingface_hub](#5-alternative-download-models-with-huggingface_hub)
7. [Run a downloaded GGUF](#6-run-a-downloaded-gguf)
8. [Connect Open WebUI to llama.cpp](#7-connect-open-webui-to-llamacpp)
9. [Snapshot](#8-snapshot)
10. [Quick checklist](#quick-checklist)

---

## Prerequisites

- You completed [Step 1](./ollama-openwebui-proxmox9-lxc.md): Proxmox 9 is running and the NVIDIA driver is installed on the host with working GPU passthrough to LXCs.
- Parts of this guide are installed on the **host** and parts **inside the LXC**; some steps appear in both.
- **Driver and CUDA toolkit versions should match between the host and the LXC.**
- Check your GPU's [CUDA compute capability](https://developer.nvidia.com/cuda-gpus) when choosing build levels. Examples from the author: RTX 3090 = 8.6, RTX 4090 = 8.9, RTX 5060 Ti = 12.0.
- **Blackwell (RTX 50xx) users:** pick the **MIT** driver option during install, not Proprietary.

> **Version note:** This guide installs CUDA toolkit 13.2, which needs a driver of at least 595.45.04. The driver used in Step 1 (`620.70.06`) meets that. CUDA 13.3 has since been released (it needs at least 610.43.02, which `620.70.06` also meets), so you may install it instead — if you do, change the package name (e.g. `cuda-toolkit-13-3`) and the `PATH` line (`/usr/local/cuda-13.3/bin`) everywhere they appear, and confirm the package name in NVIDIA's Debian 13 repo. Either way, keep the host and the LXC on the same toolkit and driver versions, and avoid chasing brand-new releases.

## 1. Install the CUDA toolkit on the Proxmox host

Open the **host** shell (click the node name → Shell, or SSH in).

**Prerequisites** (likely already installed from Step 1):

```bash
apt install g++ freeglut3-dev build-essential libx11-dev libxmu-dev libxi-dev libglu1-mesa-dev libfreeimage-dev libglfw3-dev wget htop btop nvtop glances git pciutils cmake curl libcurl4-openssl-dev -y
```

**Install CUDA toolkit 13.2** and back up your `.bashrc`:

```bash
wget https://developer.download.nvidia.com/compute/cuda/repos/debian13/x86_64/cuda-keyring_1.1-1_all.deb
dpkg -i cuda-keyring_1.1-1_all.deb
apt update && apt -y install cuda-toolkit-13-2
cp .bashrc .bashrc-backup
nano .bashrc
```

Add this line to `.bashrc`:

```bash
export PATH=/usr/local/cuda-13.2/bin${PATH:+:${PATH}}
```

Reload and reboot:

```bash
source .bashrc
reboot now
```

**Verify:**

```bash
nvcc --version
nvidia-smi
```

The host setup is now done.

## 2. Set up the LXC: driver and CUDA toolkit

Create a new LXC for llama.cpp, then install the driver and CUDA inside it.

**Creating the container:**

1. Download a **Debian 13** container template (Proxmox UI → local storage → CT Templates → Templates). Use Debian 13 so it matches the `debian13` CUDA repo used below.
2. Create the container with enough disk for models (see the sizing table in [Step 1](./ollama-openwebui-proxmox9-lxc.md#4-create-the-open-webui-lxc)) and plenty of RAM/cores.
3. Before starting it, add **Device Passthrough** entries for every `/dev/nvidia*` device, exactly as in [Step 1, section 8](./ollama-openwebui-proxmox9-lxc.md#8-pass-the-gpus-through-to-the-lxc). Start it (stop/start, not restart, if you add devices later).
4. Run `apt update && apt upgrade -y` inside it.

**Then install the driver and CUDA.**

**On the host**, push the same driver file you used in Step 1 into the container (replace `101` with your container ID):

```bash
pct push 101 NVIDIA-Linux-x86_64-620.70.06.run /root/NVIDIA-Linux-x86_64-620.70.06.run
pct enter 101
```

If you no longer have the file on the host, download it again:

```bash
wget https://us.download.nvidia.com/XFree86/Linux-x86_64/620.70.06/NVIDIA-Linux-x86_64-620.70.06.run
```

**Inside the LXC**, install the driver without kernel modules:

```bash
chmod +x NVIDIA-Linux-x86_64-620.70.06.run
./NVIDIA-Linux-x86_64-620.70.06.run --no-kernel-modules
```

Choose the appropriate driver branch (Proprietary, or MIT for Blackwell), then test with `nvidia-smi`.

**Install the prerequisites** inside the LXC:

```bash
apt install g++ freeglut3-dev build-essential libx11-dev libxmu-dev libxi-dev libglu1-mesa-dev libfreeimage-dev libglfw3-dev wget htop btop nvtop glances git pciutils cmake curl libcurl4-openssl-dev -y
```

**Install CUDA toolkit 13.2** inside the LXC:

```bash
wget https://developer.download.nvidia.com/compute/cuda/repos/debian13/x86_64/cuda-keyring_1.1-1_all.deb
dpkg -i cuda-keyring_1.1-1_all.deb
apt update && apt -y install cuda-toolkit-13-2
cp .bashrc .bashrc-backup
nano .bashrc
```

Add the same `PATH` line to `.bashrc`, then reload it:

```bash
export PATH=/usr/local/cuda-13.2/bin${PATH:+:${PATH}}
```

```bash
source .bashrc
nvcc --version
```

## 3. Build llama.cpp from source

Build a plain baseline first and take a snapshot **before** experimenting with extra compile flags. (Older guides add `-DLLAMA_CURL=ON`; current llama.cpp ignores that flag and auto-detects curl, which is why `libcurl4-openssl-dev` is in the prerequisites — it's what lets `-hf` download models.) The upstream [build docs](https://github.com/ggml-org/llama.cpp/blob/master/docs/build.md#performance-tuning) list many performance options.

```bash
git clone https://github.com/ggml-org/llama.cpp
cmake llama.cpp -B llama.cpp/build -DGGML_CUDA=ON
cmake --build llama.cpp/build --config Release -j
```

This produces these binaries under your home directory:

| Binary | Path |
|---|---|
| `llama-cli` | `llama.cpp/build/bin/llama-cli` |
| `llama-bench` | `llama.cpp/build/bin/llama-bench` |
| `llama-server` | `llama.cpp/build/bin/llama-server` |
| `llama-gguf-split` | `llama.cpp/build/bin/llama-gguf-split` |

Prebuilt binaries exist, but building from source on Linux is the recommended route.

## 4. Run a model directly from Hugging Face

Any GGUF repo works here. The point of this whole series: you don't have to run stock models — pick from the companion [top-20 uncensored/abliterated model guide](./uncensored-ai-models-guide.md) (all 20 HF links are in [§2.1](./uncensored-ai-models-guide.md#21-the-actual-hugging-face-links)) or [obliterate your own](./how-to-obliterate-models.md). Two ready-made examples:

```bash
# Top-20 #2 — Huihui Qwen3.8-27B Abliterated (Q4_K_M ≈ 16 GB, fits one 24 GB card)
./llama.cpp/build/bin/llama-server -hf huihui-ai/Huihui-Qwen3.8-27B-abliterated-GGUF:Q4_K_M \
  --port 9876 --host <LXC-IP> --api-key <your-api-key> --temp 0.7 --min-p 0.05

# Top-20 #3 — Huihui Qwen3.6-35B-A3B MoE (Q2_K ≈ 13 GB, MoE = fast per token)
./llama.cpp/build/bin/llama-server -hf huihui-ai/Huihui-Qwen3.6-35B-A3B-abliterated-MTP-GGUF:Q2_K \
  --port 9876 --host <LXC-IP> --api-key <your-api-key>
```

For the best sampling settings per model family (temp / min-p / repeat-penalty, MTP speculative decoding, KV-cache quant), use the companion guide's [per-family settings](./uncensored-ai-models-guide.md#35-the-best-settings-per-family-turn-these-into-your-defaults) instead of defaults.

Original (stock) example — DeepSeek V3.1 at Q4_K_M (a good balance if you have ~512GB RAM plus some GPUs and accept slower speed):

```bash
./llama.cpp/build/bin/llama-server -hf unsloth/DeepSeek-V3.1-GGUF:Q4_K_M --port 9876 --host <LXC-IP> --api-key <your-api-key>
```

Replace `<LXC-IP>` with the container's IP address and pick your own API key. Adjust the repo/quant to whatever you can run — the [model guide's VRAM table](./uncensored-ai-models-guide.md#32-download-a-gguf) maps GPU sizes to quants.

If the download times out or restarts, you may have packet loss — use the alternative method below.

## 5. Alternative: download models with huggingface_hub

```bash
apt install python3-full python3-pip pipenv
mkdir hf && cd hf
pipenv shell
pip install huggingface_hub hf_transfer
nano dl.py
```

Paste in this downloader script (structured for how Unsloth publishes quants), then save with `Ctrl+X`, `Y`:

```python
import os

os.environ["HF_HUB_ENABLE_HF_TRANSFER"] = "0"  # Can sometimes rate limit, so keep disabled

from huggingface_hub import snapshot_download

snapshot_download(
    repo_id="unsloth/DeepSeek-V3.1-GGUF",
    local_dir="unsloth/DeepSeek-V3.1-GGUF",
    allow_patterns=["*UD-Q2_K_XL*"],  # Change the pattern to the quant you want
)
```

Run it:

```bash
chmod +x dl.py
python3 dl.py
```

Files land in the directory you ran it from. Find the path to the first split file (the one ending in `-00001-of-0000N.gguf`) — that's what you pass to llama.cpp.

## 6. Run a downloaded GGUF

Example starting point for a quad RTX 3090 / 512GB EPYC system. **`--n-gpu-layers`, `--threads` and `--ctx-size` are tuned to that hardware — set them for yours.** (Adjust path, IP and key too.)

```bash
./llama.cpp/build/bin/llama-server \
  --model hf/unsloth/DeepSeek-V3.1-GGUF/Q4_K_M/DeepSeek-V3.1-Q4_K_M-00001-of-00009.gguf \
  --port 9876 --host <LXC-IP> --api-key <your-api-key> \
  --n-gpu-layers 12 --seed 42069 --prio 3 \
  --temp 0.6 --top-p 0.95 --ctx-size 4096 --threads 60
```

## 7. Connect Open WebUI to llama.cpp

1. In Open WebUI, open the **Admin** menu → **Settings** (lower left).
2. Add a connection to your llama.cpp server: `http://<LXC-IP>:9876/v1`, with your API key.
3. Set a **prefix** (e.g. `llamacpp-`) so you can tell at a glance which server is running which model and avoid overloading VRAM on one machine.
4. Go to **Models** and use the pencil icon to rename long, unreadable model names.

The advanced parameter settings in Open WebUI may not apply to llama.cpp — test before relying on them.

## 8. Snapshot

Once everything works, snapshot the LXC so you have a known-good state to roll back to. Snapshot before upgrades too.

## Next

Continue with [Step 3: vLLM](./vllm-proxmox9-lxc.md).

---

## Quick checklist

- [ ] Step 1 completed (host driver + GPU passthrough working)
- [ ] CUDA toolkit 13.2 installed on host, `nvcc --version` works
- [ ] New LXC created with GPUs passed through
- [ ] Driver installed in LXC (`--no-kernel-modules`), `nvidia-smi` works
- [ ] CUDA toolkit 13.2 installed in LXC, `PATH` set
- [ ] llama.cpp cloned and built with `-DGGML_CUDA=ON`
- [ ] Model downloaded (via `-hf` or `huggingface_hub`)
- [ ] `llama-server` running, reachable on port 9876
- [ ] Open WebUI connected with a prefix
- [ ] Snapshot taken
