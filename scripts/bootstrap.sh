#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${SCRIPT_DIR}/.."
source "$SCRIPT_DIR/lib.sh"

DRY_RUN=false

usage() {
  cat <<EOF
Usage: $0 [OPTIONS]

Options:
  --dry-run       Run without making changes
  -h, --help      Show this help message
EOF
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --dry-run)
        DRY_RUN=true
        shift
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      *)
        echo "Unknown option: $1"
        usage
        exit 1
        ;;
    esac
  done
}

detect_container_runtime() {
  log_section "Container Runtime Detection"

  if command -v docker &>/dev/null && docker ps >/dev/null 2>&1; then
    CONTAINER_RUNTIME="docker"
    COMPOSE_CMD="docker-compose"
    log_info "Detected Docker runtime"
  elif command -v podman &>/dev/null && podman ps >/dev/null 2>&1; then
    CONTAINER_RUNTIME="podman"
    COMPOSE_CMD="podman-compose"
    log_info "Detected Podman runtime"
  else
    log_error "Neither Docker nor Podman is available or responsive"
    log_info "Install Docker with: sudo dnf install docker docker-compose"
    log_info "Or install Podman with: sudo dnf install podman podman-compose"
    exit 1
  fi

  log_info "Using $CONTAINER_RUNTIME with $COMPOSE_CMD"
}

verify_prerequisites() {
  log_section "Preflight"

  if [[ "$CONTAINER_RUNTIME" == "docker" ]]; then
    for cmd in docker docker-compose curl; do
      require_command "$cmd" || exit 1
    done
  else
    for cmd in podman podman-compose curl; do
      require_command "$cmd" || exit 1
    done
  fi

  log_section "${CONTAINER_RUNTIME^} Health Check"

  if ! $CONTAINER_RUNTIME ps >/dev/null 2>&1; then
    log_error "$CONTAINER_RUNTIME is not responding. Check your setup."
    exit 1
  fi
  log_ok "$CONTAINER_RUNTIME is healthy"
}

start_container_stack() {
  log_section "Container Stack"

  dry_run_execute $COMPOSE_CMD up -d --build

  if ! is_dry_run; then
    log_ok "Stack started"
  fi
}

wait_for_ollama_service() {
  log_section "Waiting for Ollama"

  dry_run_info "Would wait for Ollama at $OLLAMA_HOST"

  if ! is_dry_run; then
    wait_for_ollama "$OLLAMA_HOST" 30 5 || {
      log_error "Ollama did not become healthy in time. Check: $CONTAINER_RUNTIME logs $CONTAINER"
      exit 1
    }
  fi
}

build_custom_models() {
  log_section "Custom Models"

  local build_script="$SCRIPT_DIR/build-modelfiles.sh"

  if [[ ! -f "$build_script" ]]; then
    log_error "build-modelfiles.sh not found at $build_script"
    exit 1
  fi

  chmod +x "$build_script"

  dry_run_execute "$build_script" --container "$CONTAINER"
}

display_completion_summary() {
  log_section "Done"
  log_ok "Bootstrap complete."

  echo ""
  log_info "Services:"
  echo "    Ollama API   : $OLLAMA_HOST"
  echo "    Open WebUI   : http://localhost:3000"
  echo "    OpenHands    : http://localhost:3001"
  echo ""
  log_info "Add to ~/.zshrc:"
  echo "    alias aider-rust='aider --model ollama/eda-arch-rust --openai-api-base $OLLAMA_HOST/v1 --auto-commits false'"
  echo "    alias aider-scala='aider --model ollama/eda-arch-scala --openai-api-base $OLLAMA_HOST/v1 --auto-commits false'"
  echo "    alias aider-python='aider --model ollama/eda-arch-python --openai-api-base $OLLAMA_HOST/v1 --auto-commits false'"
  echo "    alias aider-ts='aider --model ollama/eda-arch-typescript --openai-api-base $OLLAMA_HOST/v1 --auto-commits false'"
  echo "    alias aider-go='aider --model ollama/eda-arch-golang --openai-api-base $OLLAMA_HOST/v1 --auto-commits false'"
  echo "    alias aider-bash='aider --model ollama/eda-arch-bash --openai-api-base $OLLAMA_HOST/v1 --auto-commits false'"
  echo "    alias aider-actions='aider --model ollama/eda-arch-actions --openai-api-base $OLLAMA_HOST/v1 --auto-commits false'"
  echo ""
}

main() {
  parse_args "$@"

  cd "$REPO_ROOT"

  detect_container_runtime
  verify_prerequisites
  start_container_stack
  wait_for_ollama_service
  build_custom_models
  display_completion_summary
}

main "$@"
