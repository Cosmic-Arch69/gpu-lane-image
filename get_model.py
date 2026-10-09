#!/usr/bin/env python3
"""Fetch the GGUF + vision projector straight from HuggingFace.

JonathanColetti's repo is UNGATED — that is the entire reason for this file.
The earlier version of this recipe detoured through Ollama's registry because
orcarouter's HF repo required an approved access request. No token needed here.

Writes atomically (.part then rename) so a re-pull never sees a half file, and
sizes are checked against the expected minimum so a truncated download retries.
"""
import os
import subprocess
import sys

REPO = os.environ.get("HF_REPO", "JonathanColetti/Qwen3.8-27B-Uncensored-GGUF")
D = os.environ.get("MODEL_DIR", "/models")
os.makedirs(D, exist_ok=True)

WANT = [
    (os.environ.get("HF_FILE", "Qwen3.8-27B-Uncensored-Q4_K_M.gguf"), "model.gguf", 1_000_000_000),
    (os.environ.get("MMPROJ_FILE", "mmproj-Qwen3.8-27B-Uncensored-F16.gguf"), "mmproj.gguf", 300_000_000),
]

for remote, local, min_bytes in WANT:
    target = os.path.join(D, local)
    if os.path.exists(target) and os.path.getsize(target) >= min_bytes:
        print(f"{local}: present ({os.path.getsize(target)} bytes), skipping")
        continue
    if os.path.exists(target):
        print(f"{local}: too small ({os.path.getsize(target)}), re-pulling")
        os.remove(target)
    url = f"https://huggingface.co/{REPO}/resolve/main/{remote}"
    print(f"{local}: pulling {url}")
    # -C - resumes a partial .part; --fail stops an HTML error page becoming a model
    cmd = ["curl", "--fail", "--location", "--continue-at", "-",
           "--retry", "5", "--retry-delay", "5",
           "--output", target + ".part", url]
    rc = subprocess.call(cmd)
    if rc != 0:
        sys.exit(f"download failed rc={rc} for {remote} (partial kept at {target}.part, rerun resumes)")
    size = os.path.getsize(target + ".part")
    if size < min_bytes:
        sys.exit(f"downloaded {size} bytes, expected at least {min_bytes} for {remote}")
    os.replace(target + ".part", target)
    print(f"{local}: ok ({size} bytes)")

print("models ready")
