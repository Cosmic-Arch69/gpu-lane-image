#!/bin/bash
# Boot-time lane: pull weights (skips if already on disk), then serve.
set -e
export LD_LIBRARY_PATH=/opt/llama:${LD_LIBRARY_PATH:-}
M=/models; mkdir -p $M
pull(){ # url out floor_mb
  [ -s "$2" ] && [ "$(stat -c%s "$2")" -gt $(( $3 * 1000000 )) ] && { echo "$(basename $2): present"; return 0; }
  echo "$(basename $2): pulling"; curl -L -C - --fail --retry 5 --output "$2.part" "$1" && mv "$2.part" "$2"
}
R=https://huggingface.co/JonathanColetti/Qwen3.8-27B-Uncensored-GGUF/resolve/main
pull $R/Qwen3.8-27B-Uncensored-Q4_K_M.gguf $M/model.gguf 10000
pull $R/mmproj-Qwen3.8-27B-Uncensored-F16.gguf $M/mmproj.gguf 500
# ponytail: assumes Yotta Pod launcher runs the image directly; if its init box rejects nested docker run, set this image as the pod image and keep init as: /usr/sbin/sshd -D & /opt/start-lane.sh
exec /opt/llama/llama-server -m $M/model.gguf --mmproj $M/mmproj.gguf \
  --spec-type draft-mtp --spec-draft-n-max "${SPEC_DRAFT_N_MAX:-3}" \
  -c "${CTX_PER_SLOT:-262144}" -np "${NP:-4}" --kv-unified -ngl "${NGL:-99}" --flash-attn on \
  --jinja --host 127.0.0.1 --port "${PORT:-8000}"
