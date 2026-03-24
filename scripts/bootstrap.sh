#!/usr/bin/env zsh
# bootstrap.sh - Complete automation for gb-ollama-container setup
# Optimized for Fedora 43 / Podman environments
# Usage: ./scripts/bootstrap.sh [--dry-run]

set -euo pipefail

SCRIPT_DIR="${0:A:h}"
REPO_ROOT="${SCRIPT_DIR}/.."
DRY_RUN=false
OLLAMA_CONTAINER="ollama"
OLLAMA_HOST="http://localhost:11434"

# ── Argument parsing ──────────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) DRY_RUN=true; shift ;;
    -h|--help)
      echo "Usage: $0 [--dry-run]"
      exit 0 ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

# ── Helpers ───────────────────────────────────────────────────────────────────
info()    { echo -e "\033[1;34m[INFO]\033[0m  $1" }
ok()      { echo -e "\033[1;32m[ OK ]\033[0m  $1" }
warn()    { echo -e "\033[1;33m[WARN]\033[0m  $1" }
section() { echo -e "\n\033[1;37m──── $1 ────\033[0m" }

# ── 1. Preflight ──────────────────────────────────────────────────────────────
section "Preflight"

for cmd in podman podman-compose curl; do
  if ! command -v "$cmd" &>/dev/null; then
    warn "$cmd not found. Install with: sudo dnf install $cmd"
    exit 1
  fi
  ok "Found $cmd"
done

# ── 2. Podman health ──────────────────────────────────────────────────────────
section "Podman health"

if ! podman ps >/dev/null 2>&1; then
  warn "Podman is not responding. Check your rootless podman setup."
  exit 1
fi
ok "Podman is healthy"

# ── 3. Start container stack ──────────────────────────────────────────────────
section "Container stack"

if $DRY_RUN; then
  info "[dry-run] Would run: podman-compose up -d --build"
else
  info "Starting stack (this will also pull base models via container entrypoint)..."
  cd "$REPO_ROOT"
  podman-compose up -d --build
  ok "Stack started"
fi

# ── 4. Wait for Ollama to be healthy ─────────────────────────────────────────
section "Waiting for Ollama"

if $DRY_RUN; then
  info "[dry-run] Would wait for Ollama at $OLLAMA_HOST"
else
  info "Waiting for Ollama container to be ready..."
  RETRIES=30
  until curl -sf "${OLLAMA_HOST}/api/tags" >/dev/null; do
    RETRIES=$((RETRIES - 1))
    if [[ $RETRIES -eq 0 ]]; then
      warn "Ollama did not become healthy in time. Check: podman logs $OLLAMA_CONTAINER"
      exit 1
    fi
    info "Not ready yet, retrying in 5s... ($RETRIES attempts left)"
    sleep 5
  done
  ok "Ollama is healthy at $OLLAMA_HOST"
fi

# ── 5. Build and register custom models ───────────────────────────────────────
section "Custom models"

BUILD_SCRIPT="${SCRIPT_DIR}/build-modelfiles.sh"

if [[ ! -f "$BUILD_SCRIPT" ]]; then
  warn "build-modelfiles.sh not found at $BUILD_SCRIPT"
  exit 1
fi

chmod +x "$BUILD_SCRIPT"

if $DRY_RUN; then
  info "[dry-run] Would run: $BUILD_SCRIPT --container $OLLAMA_CONTAINER --dry-run"
  "$BUILD_SCRIPT" --container "$OLLAMA_CONTAINER" --dry-run
else
  "$BUILD_SCRIPT" --container "$OLLAMA_CONTAINER"
fi

# ── 6. Summary ────────────────────────────────────────────────────────────────
section "Done"
ok "Bootstrap complete."
echo ""
info "Services:"
echo "    Ollama API   : $OLLAMA_HOST"
echo "    Open WebUI   : http://localhost:3000"
echo "    OpenHands    : http://localhost:3001"
echo ""
info "Add to ~/.zshrc:"
echo "    alias aider-rust='aider --model ollama/eda-arch-rust --openai-api-base $OLLAMA_HOST/v1 --auto-commits false'"
echo "    alias aider-scala='aider --model ollama/eda-arch-scala --openai-api-base $OLLAMA_HOST/v1 --auto-commits false'"
echo "    alias aider-python='aider --model ollama/eda-arch-python --openai-api-base $OLLAMA_HOST/v1 --auto-commits false'"
echo "    alias aider-ts='aider --model ollama/eda-arch-typescript --openai-api-base $OLLAMA_HOST/v1 --auto-commits false'"
echo "    alias aider-go='aider --model ollama/eda-arch-golang --openai-api-base $OLLAMA_HOST/v1 --auto-commits false'"
echo "    alias aider-bash='aider --model ollama/eda-arch-bash --openai-api-base $OLLAMA_HOST/v1 --auto-commits false'"
echo "    alias aider-actions='aider --model ollama/eda-arch-actions --openai-api-base $OLLAMA_HOST/v1 --auto-commits false'"
echo ""
