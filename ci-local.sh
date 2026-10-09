#!/bin/bash
# Reproduce the CI compile step locally (Docker Desktop + amd64, no GPU needed).
# Catches cmake/linker failures in ~15 min instead of a 20-min CI round trip.
# NOTE: needs a big Docker VM disk — the devel image is ~3.5 GB.
set -euo pipefail
cd "$(dirname "$0")"
REV="${1:-8e2d31e}"
docker run --rm -v "$PWD:/w" -w /w -e REV="$REV" \
  nvcr.io/nvidia/cuda:12.8.1-devel-ubuntu22.04 bash -c '
    set -euo pipefail
    export DEBIAN_FRONTEND=noninteractive
    apt-get update -qq
    apt-get install -y -qq --no-install-recommends git cmake ninja-build libgomp1 ca-certificates
    cmake --version | head -1
    git clone --depth 50 https://github.com/ggml-org/llama.cpp /src
    git -C /src checkout "$REV"
    git -C /src log -1 --format="built %h %s"
    cmake -S /src -B /b -G Ninja \
      -DCMAKE_BUILD_TYPE=Release -DGGML_CUDA=ON -DBUILD_SHARED_LIBS=BUILD \
      -DCMAKE_CUDA_ARCHITECTURES=86 \
      -DCMAKE_CUDA_COMPILER=/usr/local/cuda/bin/nvcc \
      -DCMAKE_EXE_LINKER_FLAGS="-L/usr/local/cuda/lib64/stubs -Wl,--allow-shlib-undefined" \
      -DCMAKE_SHARED_LINKER_FLAGS="-L/usr/local/cuda/lib64/stubs -Wl,-rpath-link,/usr/local/cuda/lib64/stubs" \
      -DCMAKE_MODULE_LINKER_FLAGS="-L/usr/local/cuda/lib64/stubs -Wl,-rpath-link,/usr/local/cuda/lib64/stubs" \
      -DLLAMA_CURL=OFF
    cmake --build /b --target llama-server -j "$(nproc)"
    mkdir -p /w/build-out/bin /w/build-out/lib
    cp -av /b/bin/llama-server /w/build-out/bin/
    find /b -name "*.so*" -maxdepth 3 -exec cp -av {} /w/build-out/lib/ \;
    cp -av /usr/local/cuda/lib64/stubs/libcuda.so /w/build-out/lib/libcuda.so.1
    ls -la /w/build-out/bin /w/build-out/lib
  '
