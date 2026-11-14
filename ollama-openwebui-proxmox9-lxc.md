# Ollama + Open WebUI on Proxmox 9 (LXC) — Homelab AI Server Guide

**Author:** [toor11](https://github.com/toor11)
**Last updated:** November 2026

My personal notes and checklist for setting up a self-hosted AI server on Proxmox 9 using Ollama and Open WebUI in an LXC container (no Docker).

**Series order:** 1) Ollama + Open WebUI (this guide) → 2) [Llama.cpp](./llamacpp-proxmox9-lxc.md) → 3) [vLLM](./vllm-proxmox9-lxc.md).
Follow in order — the backup made here is reused in later guides. Once the server is up, pick models from the companion [top-20 uncensored models guide](./uncensored-ai-models-guide.md); see the [series index](./README.md) for the full picture.

## Table of contents

1. [BIOS settings](#1-bios-settings)
2. [Install Proxmox 9](#2-install-proxmox-9)
3. [Initial Proxmox configuration](#3-initial-proxmox-configuration)
4. [Create the Open WebUI LXC](#4-create-the-open-webui-lxc)
5. [Install the NVIDIA driver on the host](#5-install-the-nvidia-driver-on-the-proxmox-host)
6. [Make GPU settings persist](#6-make-gpu-settings-persist-across-reboots)
7. [Install the NVIDIA driver inside the LXC](#7-install-the-nvidia-driver-inside-the-lxc)
8. [Pass the GPUs through](#8-pass-the-gpus-through-to-the-lxc)
9. [Back up the container](#9-back-up-the-container)
10. [Resize the LXC disk](#10-resize-the-lxc-disk-if-needed)
11. [Using Open WebUI](#11-using-open-webui)
12. [Troubleshooting](#troubleshooting)

---

## Goals

- Easy to administer; expandable from one machine to several
- Snapshots and fast backup/restore
- Fully free and open-source
- No Docker (everything runs in an LXC container)
- Works with GPUs or CPU-only (CPU-only is slower and suited to small 1B–3B models)

## Hardware

The author uses a quad RTX 3090 rig, but the steps are identical for a single GPU (e.g. a 3060 12GB) or CPU-only.

| Component | Example |
|---|---|
| GPU | 4× RTX 3090 24GB |
| CPU | AMD EPYC 7702 |
| Motherboard | Gigabyte MZ32-AR0 |
| RAM | 512GB DDR4 ECC |
| PSU | ASRock Rack 1600W |
| Storage | NVMe Gen4 1TB (ideally 2 drives for RAID1) |
| Cooler | Corsair H170i |
| Extras | GPU rack frame, 4× PCIe4 risers |

## 1. BIOS settings

- Disable UEFI if possible and enable **CSM** (easier troubleshooting, better compatibility with older gear).
- Make sure **IOMMU** is enabled.
- Use 2 drives for storage, but **do not use motherboard hardware RAID** — set up ZFS RAID1 inside Proxmox.
- Consider a NAS (NFS/SMB share) for storing models.

## 2. Install Proxmox 9

1. Download the ISO from <https://proxmox.com/en/downloads> (current release at time of writing: 9.2, which ships Linux kernel 7.0 by default — see [Troubleshooting](#troubleshooting)) and write it to USB with Rufus or balenaEtcher (or mount via KVM/BMC).
2. Choose **Install Proxmox VE (Graphical)** and accept the license.
3. Click **Options** and pick **ZFS (RAID1)**. Select only the drives you want to use — **all data on them is erased**.
4. Under **Advanced Options**, subtract ~1GB from the partition size so you can recover with a rescue USB if the disk ever fills up.
5. Set country/timezone, a root password, and a real email address (for system notifications). Default user is `root`.
6. Set hostname (e.g. `pve.lan` or `.home.arpa`) and a static IP **outside your DHCP range**.
7. Let it install and reboot, then log in at `https://<your-ip>:8006` as `root`.

## 3. Initial Proxmox configuration

**Do this before installing GPU drivers**, or the driver won't survive kernel updates.

1. Select the host → **Repositories**.
2. Disable the **enterprise** repos and add the **no-subscription** repo.
3. **Refresh → Update**, apply updates, then reboot.

Alternative: run the Proxmox VE Helper post-install script, which also removes the subscription nag:
<https://community-scripts.github.io/ProxmoxVE/scripts?id=post-pve-install>

## 4. Create the Open WebUI LXC

1. Open the Helper Scripts page for Open WebUI: <https://community-scripts.github.io/ProxmoxVE/scripts?id=openwebui> (review the script source before running it).
2. Paste the install command into the **host** terminal and choose **Advanced**.
3. Set a root password and other options. Disk size is easy to grow but hard to shrink. Suggested sizes:

| VRAM | Suggested LXC disk |
|---|---|
| 12 GB | 60 GB |
| 24 GB | 100 GB |
| 48 GB | 200 GB |
| 96 GB | 400 GB+ |

4. When prompted, answer **Y** to install Ollama in the same container. (You can use a separate Ollama container, but then you must point Open WebUI at its address.)
5. Don't shut the container down yet — the driver goes in next.

To update later: open the container shell and run `update` (updates both Open WebUI and Ollama).

## 5. Install the NVIDIA driver on the Proxmox host

> **Blackwell (RTX 50xx) users:** choose the **MIT** driver option during install, not Proprietary. Same download, different installer choice.
> Don't use Debian's packaged NVIDIA driver — it's older and can be slower or break on new cards.

**Install prerequisites and reboot:**

```bash
apt install g++ freeglut3-dev build-essential libx11-dev libxmu-dev libxi-dev libglu1-mesa-dev libfreeimage-dev libglfw3-dev wget htop btop nvtop nano glances git pciutils cmake curl libcurl4-openssl-dev proxmox-headers-$(uname -r) dkms make -y && update-initramfs -u && reboot now
```

**Download the driver:**

1. Go to <https://www.nvidia.com/en-us/drivers/unix/> and open the **Latest Production Branch** link.
2. Right-click the Download button and copy the link.
3. On the host terminal:

```bash
wget https://us.download.nvidia.com/XFree86/Linux-x86_64/620.70.06/NVIDIA-Linux-x86_64-620.70.06.run
chmod +x NVIDIA-Linux-x86_64-620.70.06.run
./NVIDIA-Linux-x86_64-620.70.06.run --dkms
```

4. In the installer: choose **NVIDIA Proprietary** (Ada or older cards), ignore the X and 32-bit warnings, and accept the modprobe/header prompts.
5. If it asks for a reboot, reboot, then **run `./NVIDIA-Linux-x86_64-620.70.06.run --dkms` again** and let it finish.
6. Verify with `nvtop` — all GPUs should appear.

## 6. Make GPU settings persist across reboots

```bash
crontab -e
```

Add this line at the top (enables persistence mode and caps power at 250W per GPU — lowers heat/idle draw with minimal inference impact). **250W is an example for RTX 3090s; check your card's default and supported range with `nvidia-smi -q -d POWER` and adjust.**

```cron
@reboot nvidia-smi -pm 1 && nvidia-smi -pl 250
```

## 7. Install the NVIDIA driver inside the LXC

Inside the container (`pct enter 100`, replacing 100 with your container ID):

```bash
apt update && apt upgrade -y && apt install nvtop -y
```

Back on the **host**, find the exact driver filename with `ls -la`, then push it into the container:

```bash
pct push 100 NVIDIA-Linux-x86_64-620.70.06.run /root/NVIDIA-Linux-x86_64-620.70.06.run
pct enter 100
chmod +x NVIDIA-Linux-x86_64-620.70.06.run
./NVIDIA-Linux-x86_64-620.70.06.run --no-kernel-modules
```

Accept the defaults (Proprietary). Then shut the container down.

> The filename above matches the driver downloaded in step 5. If you use a different version, adjust the filename.

## 8. Pass the GPUs through to the LXC

1. On the host: `ls -la /dev/nvidia*`
2. In the Proxmox UI: select the container → **Resources → Add → Device Passthrough**.
3. Add one entry for **each** `/dev/nvidia*` device listed (e.g. `/dev/nvidia0`, `/dev/nvidiactl`, `/dev/nvidia-uvm`, …).
4. **Stop and start** the container (a restart isn't enough for new devices).
5. Inside the container, run `nvtop` — your GPUs should now show up.

## 9. Back up the container

Do this now, before making further changes:

1. Select the container → **Backup → Backup now**.
2. Add a note such as `initial GPU setup`.

Backups are not the same as snapshots (snapshots are a separate, more advanced feature). If you have a NAS or USB drive, copy backups off the host eventually.

## 10. Resize the LXC disk (if needed)

Container → **Resources → Root Disk → Volume Actions → Resize**. The number you enter is **extra** space to add (e.g. +10 GiB). You can only grow it, and you don't need to resize anything inside the container.

## 11. Using Open WebUI

- Open `http://<LXC-IP>:8080` in your browser (8080 is the helper script's usual port — confirm it in the script's install summary) and create your admin account.
- Download models directly from the Open WebUI interface (pulled via Ollama).

## Bonus: run DeepSeek V3.1 in Ollama

This is just an example of a very large model. With about 168GB of combined RAM + VRAM you can run a very low quant (Q1) via Unsloth. Swap in any current model that fits your VRAM — including any of the 20 [uncensored/abliterated models](./uncensored-ai-models-guide.md) from the companion guide, since `ollama run hf.co/...` accepts the same GGUF repos:

```bash
# Top-20 #2 — Huihui Qwen3.8-27B Abliterated instead of the stock DeepSeek:
ollama run hf.co/huihui-ai/Huihui-Qwen3.8-27B-abliterated-GGUF:Q4_K_M
```

```bash
ollama run hf.co/unsloth/DeepSeek-V3.1-GGUF:TQ1_0
```

For larger quants, or for the more exotic GGUFs in the top-20 list (GSQ-RCO low-bit quants, MTP draft heads, mmproj vision projectors — anything a Modelfile wrapper doesn't handle), use llama.cpp instead (Step 2 of the series): see [Llama.cpp on Proxmox 9 LXC](./llamacpp-proxmox9-lxc.md)

## Troubleshooting

**Host misbehaves on kernel 7.0 (Proxmox 9.2 default).** Some users report regressions on the 7.0 kernel (guests failing to start, PCIe passthrough freezes, module-loading errors) on certain hardware. I haven't confirmed whether driver `620.70.06` builds cleanly against it on every system, so test before relying on it. If you hit problems, pin the older 6.17 kernel (use the exact version listed by `proxmox-boot-tool kernel list`):

```bash
proxmox-boot-tool kernel list
proxmox-boot-tool kernel pin 6.17.13-13-pve
reboot
```

After changing kernels, make sure the matching headers are installed and re-run the driver installer with `--dkms` (step 5).

**DKMS build fails or driver disappears after a kernel update.** Install headers for the running kernel (`proxmox-headers-$(uname -r)`), then re-run `./NVIDIA-Linux-x86_64-620.70.06.run --dkms`.

**GPUs not visible in the container.** Re-check the device passthrough entries (step 8) and make sure you **stopped and started** the container, not just restarted it.

---

## Quick checklist

- [ ] BIOS: IOMMU on, CSM on
- [ ] Proxmox 9 installed with ZFS RAID1
- [ ] Enterprise repos off, no-subscription on, updated, rebooted
- [ ] Open WebUI + Ollama LXC created (right disk size)
- [ ] NVIDIA driver on host (`--dkms`), `nvtop` shows GPUs
- [ ] `@reboot` cron for power limit set
- [ ] Driver installed in LXC (`--no-kernel-modules`)
- [ ] GPU devices passed through; container stopped and started
- [ ] Backup taken
- [ ] Model downloaded and chatting in Open WebUI
