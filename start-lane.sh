#!/bin/bash
# Boot-time lane. Run as the Yotta init command (inline, or COPY this into the image):
#   /usr/sbin/sshd -D & /opt/start-lane.sh
set -e
M=/models
mkdir -p $M
# -C - resumes a partial pull; the real files are 16.8 GB and 0.93 GB, so anything
# smaller than that floor is an error page or a truncated download -> re-pull.
pull() { # url out floor
  [ -s "$2" ] && [ "$(stat -c%s "$2")" -gt "$3" ] && return 0
  curl -L -C - --fail -o "$2" "$1"
}
pull https://huggingface.co/JonathanColetti/Qwen3.8-27B-Uncensored-GGUF/resolve/main/Qwen3.8-27B-Uncensored-Q4_K_M.gguf $M/model.gguf 10000000000
pull https://huggingface.co/JonathanColetti/Qwen3.8-27B-Uncensored-GGUF/resolve/main/mmproj-Qwen3.8-27B-Uncensored-F16.gguf $M/mmproj.gguf 500000000
exec /opt/llama-server -m $M/model.gguf --mmproj $M/mmproj.gguf \
  --spec-type draft-mtp --spec-draft-n-max 3 \
  -c 262144 -ngl 99 -fa on --jinja --host 127.0.0.1 --port 8000
