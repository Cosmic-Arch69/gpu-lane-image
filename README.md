# gpu-lane-image

Docker recipe for the Yotta GPU lane: **JonathanColetti Qwen3.8-27B-Uncensored** (Q4_K_M, native 262k context, built-in MTP head) served by llama.cpp with CUDA.

Built so a fresh GPU box goes from zero to serving in ~3 minutes instead of ~25: the toolchain ships in the image, only the weights are pulled at boot.

## What is in the image, what is not

| In the image | Pulled at boot |
|---|---|
| `llama-server` compiled for CUDA 12.8 / sm_86 / linux-amd64 | `Qwen3.8-27B-Uncensored-Q4_K_M.gguf` (16.81 GB) |
| `libggml*.so` + `libllama.so` + CUDA runtime libs | `mmproj-...-F16.gguf` (0.93 GB) |
| `openssh-server` (port 22 — the SSH tunnel carries everything else) | |
| `libgomp1`, `ca-certificates`, `curl`, `python3` | |

Weights are deliberately **not** baked in. Pushing to a registry is capped by *upload* bandwidth (~155 Mbps on Yotta), so 17.7 GB of weights would add ~15 minutes to every build and every pull for nothing — the download side is fast.

## Build

The image needs linux/amd64 CUDA binaries, and this repo lives on an Apple-silicon Mac, so compilation happens in CI.

```bash
gh workflow run build-image.yml --repo Cosmic-Arch69/gpu-lane-image \
  -f llama_rev=8e2d31e -f tag=jonathan
gh run watch                                          # ~20-30 min, free runner
```

`build-image.yml` does four things: compiles inside `nvidia/cuda:12.8.1-devel-ubuntu22.04`, **smoke-tests the binary in the runtime base** (catches a libgomp/CUDA mismatch before it becomes a pod that never serves), builds the image, pushes to `ghcr.io/<owner>/qwen-lane:<tag>`.

## Deploy (Yotta)

Pod · RTX A6000 x1 on-demand **$0.45/hr** (2x A6000 = $0.90/hr for parallel slots) · Image Source **Other** · Image Type **Public** · init command:

```
/usr/sbin/sshd -D & /opt/start-lane.sh
```

Port **22** only. Model storage: 256 GB container storage is enough; no system volume buys anything since the pull is 3 minutes.

Then from the Mac:

```bash
~/.pi/agent/bin/qwen-pod up        # tunnel :8000 -> the pod's localhost:8000
~/.pi/agent/bin/qwen-pod status    # health http 200
```

## Tuning without a rebuild

| Env var | Default | Notes |
|---|---|---|
| `CTX_PER_SLOT` | `262144` | the model's native maximum |
| `NP` | `4` | parallel slots. Anything on the tunnel shares these slots — pin benchmarks with `"slot_id": N` |
| `SPEC_TYPE` / `SPEC_DRAFT_N_MAX` | `draft-mtp` / `3` | MTP speculative decoding, measured 76-93% acceptance |
| `NGL` | `99` | GPU layers |
| `HF_FILE` / `MMPROJ_FILE` | Q4_K_M / mmproj-F16 | swap quant without a rebuild |
| `PORT` | `8000` | bound to 127.0.0.1 only |

## Model notes (measured on 2x RTX A6000, llama.cpp 8e2d31e)

- **Thinking is ON by default** and eats short `max_tokens` budgets. Send `chat_template_kwargs: {"enable_thinking": false}` for snappy replies.
- Cold prefill: 30k tokens = 1,551 t/s; 145k tokens = **1,015 t/s** (142.8 s). Prefill degrades with context length — budget ~4.5 min for a full 262k prompt, not seconds.
- Decode: 85.8 t/s short context, 55.8 t/s at 30k.
- `general.architecture=qwen35`, `nextn_predict_layers=1` → the MTP head is inside the quant, so **no external draft model is needed**.
- Vision and native tool calls both verified (`--jinja` + mmproj).

## History

`orcarouter/Qwen3.8-27B-Uncensored` on HuggingFace is **gated** — the previous version of this recipe fetched weights from Ollama's registry as a workaround. Jonathan Coletti's repo is ungated with the same lineage, 16.81 GB Q4_K_M, and ships the MTP head and mmproj. `get_model.py` now goes to HuggingFace directly with resume-on-partial (`-C -`), verified.
