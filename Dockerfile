# Jonathan Qwen3.8-27B inference lane — CUDA 12.8, llama.cpp 8e2d31e, linux/amd64.
# Small base on purpose: pushing to a registry is limited by UPLOAD bandwidth
# (~155 Mbps on Yotta), so every base layer we avoid is ~5 min saved.
#
# The compiled binaries are COPYed in, NOT built here. They come from
# .github/workflows/build-image.yml, which compiles inside
# nvidia/cuda:12.8.1-devel-ubuntu22.04 on a free GitHub runner and writes them
# to ./build-out/. Models are NOT in the image — boot pulls ~17.7 GB from HuggingFace.
FROM nvcr.io/nvidia/cuda:12.8.1-runtime-ubuntu22.04

ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y --no-install-recommends \
      openssh-server ca-certificates curl python3 libcurl4 libgomp1 \
    && rm -rf /var/lib/apt/lists/* \
    && mkdir -p /run/sshd && chmod 755 /run/sshd

COPY build-out/bin/    /opt/llama/bin/
COPY build-out/lib/    /opt/llama/lib/
# Placeholder only: the nvidia container runtime bind-mounts the real driver
# libcuda.so.1 over this path on a GPU pod.
COPY build-out/lib/libcuda.so.1 /usr/lib/x86_64-linux-gnu/libcuda.so.1
COPY get_model.py      /opt/get_model.py
COPY start-lane.sh     /opt/start-lane.sh
RUN chmod +x /opt/start-lane.sh /opt/get_model.py /opt/llama/bin/llama-server

ENV LD_LIBRARY_PATH=/opt/llama/lib:/usr/local/cuda/lib64
ENV HF_REPO=JonathanColetti/Qwen3.8-27B-Uncensored-GGUF \
    HF_FILE=Qwen3.8-27B-Uncensored-Q4_K_M.gguf \
    MMPROJ_FILE=mmproj-Qwen3.8-27B-Uncensored-F16.gguf \
    MODEL_DIR=/models \
    CTX_PER_SLOT=262144 NP=4 NGL=99 PORT=8000 \
    SPEC_TYPE=draft-mtp SPEC_DRAFT_N_MAX=3

EXPOSE 22
CMD ["/usr/sbin/sshd", "-D"]
