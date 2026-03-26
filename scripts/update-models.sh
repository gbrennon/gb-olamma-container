#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "$0")/lib.sh"
load_models_config

# ── Preflight Checks ──────────────────────────────────────────────────────────
validate_container_status() {
  log_section "Container Validation"
  
  require_container_running "$CONTAINER" || {
    log_error "Container '$CONTAINER' is not running."
    log_warn "Override with: OLLAMA_CONTAINER=<name> $0"
    exit 1
  }
  
  log_info "Target container: $CONTAINER"
}

# ── Model Update Management ───────────────────────────────────────────────────
update_models() {
  log_section "Model Updates"
  
  for model in "${MODELS[@]}"; do
    pull_model_if_missing "$model"
  done
}

# ── Main Execution ────────────────────────────────────────────────────────────
main() {
  validate_container_status
  update_models
  log_section "Done"
  log_info "All models updated."
}

main "$@"
