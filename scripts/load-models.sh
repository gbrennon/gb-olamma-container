#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "$0")/models.conf.sh"

OLLAMA_HOST="${OLLAMA_HOST:-http://localhost:11434}"
ARCHITECTURE_MODELFILE="${ARCHITECTURE_MODELFILE:-/usr/local/bin/Architecture.Modelfile}"
OLLAMA_PID=""

is_ollama_running() {
  curl -sf "$OLLAMA_HOST/api/tags" >/dev/null
}

model_exists() {
  local model="$1"
  local normalized
  normalized=$(echo "$model" | tr '[:upper:]' '[:lower:]')
  ollama list 2>/dev/null | awk 'NR>1 {print $1}' | grep -qF "$normalized"
}

cleanup() {
  if [[ -n "$OLLAMA_PID" ]]; then
    echo "Stopping Ollama (pid $OLLAMA_PID)..."
    kill "$OLLAMA_PID" 2>/dev/null || true
  fi
}
trap cleanup EXIT

# Only start ollama serve if not already running
if is_ollama_running; then
  echo "Ollama already running at $OLLAMA_HOST, skipping serve..."
else
  echo "Starting Ollama..."
  ollama serve &
  OLLAMA_PID=$!

  echo "Waiting for Ollama to be healthy..."
  until is_ollama_running; do
    sleep 2
  done
fi

for model in "${MODELS[@]}"; do
  if model_exists "$model"; then
    echo "Model already present, skipping: $model"
  else
    echo "Pulling: $model"
    ollama pull "$model"
  fi
done

if model_exists "eda-architecture-pro"; then
  echo "Model already present, skipping: eda-architecture-pro"
else
  if [[ ! -f "$ARCHITECTURE_MODELFILE" ]]; then
    echo "ERROR: Modelfile not found at $ARCHITECTURE_MODELFILE" >&2
    exit 1
  fi
  echo "Building eda-architecture-pro..."
  ollama create eda-architecture-pro -f "$ARCHITECTURE_MODELFILE"
fi

echo "All models ready."

# Only wait if we spawned the process
if [[ -n "$OLLAMA_PID" ]]; then
  wait "$OLLAMA_PID"
fi