#!/bin/bash
# Bring up the lane: fetch weights if missing, then serve.
set -e
/usr/bin/python3 /opt/get_model.py

MM=""
[ -s "${MODEL_DIR:-/models}/mmproj.gguf" ] && MM="--mmproj ${MODEL_DIR:-/models}/mmproj.gguf"

exec /opt/llama/bin/llama-server \
  --model "${MODEL_DIR:-/models}/model.gguf" $MM \
  --spec-type "${SPEC_TYPE:-draft-mtp}" --spec-draft-n-max "${SPEC_DRAFT_N_MAX:-3}" \
  --jinja -ngl "${NGL:-99}" -c "${CTX_PER_SLOT:-262144}" -np "${NP:-4}" --flash-attn on \
  --host 127.0.0.1 --port "${PORT:-8000}"
