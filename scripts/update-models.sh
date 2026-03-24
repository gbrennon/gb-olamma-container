#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "$0")/models.conf.sh"

CONTAINER="${OLLAMA_CONTAINER:-ollama}"

container_running() {
  podman inspect --format '{{.State.Running}}' "$CONTAINER" 2>/dev/null | grep -q "true"
}

model_exists() {
  local model="$1"
  local normalized
  normalized=$(echo "$model" | tr '[:upper:]' '[:lower:]')
  podman exec "$CONTAINER" ollama list 2>/dev/null \
    | awk 'NR>1 {print $1}' \
    | grep -qF "$normalized"
}

if ! container_running; then
  echo "ERROR: container '$CONTAINER' is not running." >&2
  echo "Override with: OLLAMA_CONTAINER=<name> $0" >&2
  exit 1
fi

echo "Target container: $CONTAINER"

for model in "${MODELS[@]}"; do
  if model_exists "$model"; then
    echo "Already present, skipping: $model"
  else
    echo "Pulling: $model"
    podman exec "$CONTAINER" ollama pull "$model"
  fi
done

echo "Done."