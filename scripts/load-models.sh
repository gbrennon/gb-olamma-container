#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib.sh"
source "$SCRIPT_DIR/models.conf.sh"

ARCHITECTURE_MODELFILE="${ARCHITECTURE_MODELFILE:}"
OLLAMA_PID=""

start_ollama_service() {
  log_section "Ollama Service"

  if ollama_is_healthy "$OLLAMA_HOST"; then
    log_info "Ollama already running at $OLLAMA_HOST, skipping serve..."
    return 0
  fi

  log_info "Starting Ollama..."
  ollama serve &
  OLLAMA_PID=$!

  trap 'cleanup' EXIT

  wait_for_ollama "$OLLAMA_HOST" 30 2 || {
    log_error "Failed to start Ollama"
    kill "$OLLAMA_PID" 2>/dev/null || true
    exit 1
  }

  log_ok "Ollama is running (PID: $OLLAMA_PID)"
}

cleanup() {
  if [[ -n "$OLLAMA_PID" ]] && kill -0 "$OLLAMA_PID" 2>/dev/null; then
    log_info "Stopping Ollama (PID: $OLLAMA_PID)..."
    kill "$OLLAMA_PID" 2>/dev/null || true
  fi
}

pull_base_models() {
  log_section "Base Models"

  for model in "${MODELS[@]}"; do
    pull_model_if_missing "$model"
  done
}

create_architecture_model() {
  log_section "Architecture Model"

  if model_exists "eda-architecture-pro"; then
    log_info "Model already present, skipping: eda-architecture-pro"
    return 0
  fi

  if [[ ! -f "$ARCHITECTURE_MODELFILE" ]]; then
    log_error "Modelfile not found at $ARCHITECTURE_MODELFILE"
    exit 1
  fi

  log_info "Building eda-architecture-pro..."
  create_model_from_modelfile "eda-architecture-pro" "$ARCHITECTURE_MODELFILE"
}

main() {
  start_ollama_service
  pull_base_models
  create_architecture_model
  log_section "Done"
  log_info "All models ready. Keeping Ollama running..."

  while true; do
    if ! kill -0 "$OLLAMA_PID" 2>/dev/null; then
      log_error "Ollama process died, exiting..."
      exit 1
    fi
    sleep 60
  done
}

main "$@"
