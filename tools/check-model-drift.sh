#!/usr/bin/env bash
# check-model-drift.sh
# Detects drift between assembled Modelfiles in modelfiles/ and what Ollama
# reports as the running model configuration.
#
# Usage: ./tools/check-model-drift.sh [--container NAME]
#
# Exit codes:
#   0 — no drift detected
#   1 — drift detected or model missing
#   2 — usage error

set -euo pipefail

# ── Helpers ───────────────────────────────────────────────────────────────────
info()  { echo "[INFO]  $*"; }
warn()  { echo "[WARN]  $*" >&2; }
error() { echo "[ERROR] $*" >&2; exit 2; }

usage() {
  echo "Usage: $0 [--container CONTAINER_NAME]"
  echo ""
  echo "  --container NAME   Run ollama commands inside a podman container"
  echo "  -h, --help         Show this help"
  exit 0
}

# ── Argument parsing ──────────────────────────────────────────────────────────
CONTAINER=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --container) CONTAINER="$2"; shift 2 ;;
    -h|--help)   usage ;;
    *) error "Unknown option: $1" ;;
  esac
done

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
MODELFILES_DIR="${REPO_ROOT}/modelfiles"

# ── Preflight ─────────────────────────────────────────────────────────────────
if [[ ! -d "$MODELFILES_DIR" ]]; then
  error "modelfiles/ directory not found at ${MODELFILES_DIR}. Run scripts/build-modelfiles.sh first."
fi

ollama_cmd() {
  if [[ -n "$CONTAINER" ]]; then
    podman exec "$CONTAINER" ollama "$@"
  else
    ollama "$@"
  fi
}

command -v ollama >/dev/null 2>&1 || [[ -n "$CONTAINER" ]] \
  || error "ollama not found and no --container specified."

if [[ -n "$CONTAINER" ]]; then
  podman inspect --format '{{.State.Running}}' "$CONTAINER" 2>/dev/null \
    | grep -q "true" \
    || error "Container '${CONTAINER}' is not running."
fi

# ── Drift check ───────────────────────────────────────────────────────────────
DRIFT_FOUND=false
CHECKED=0

for modelfile in "${MODELFILES_DIR}"/*.Modelfile; do
  [[ -f "$modelfile" ]] || continue

  model_name="$(basename "$modelfile" .Modelfile)"
  CHECKED=$((CHECKED + 1))

  # Extract SYSTEM block from local Modelfile
  local_system="$(awk '/^SYSTEM """/{flag=1; next} /^"""/{flag=0} flag' "$modelfile")"

  # Pull model info from Ollama and extract system prompt
  model_info="$(ollama_cmd show --modelfile "$model_name" 2>/dev/null)" || {
    warn "Model not found in Ollama: ${model_name}"
    DRIFT_FOUND=true
    continue
  }

  running_system="$(echo "$model_info" | awk '/^SYSTEM """/{flag=1; next} /^"""/{flag=0} flag')"

  if [[ "$local_system" != "$running_system" ]]; then
    warn "DRIFT DETECTED: ${model_name}"
    echo ""
    diff <(echo "$local_system") <(echo "$running_system") \
      --label "modelfiles/${model_name}.Modelfile" \
      --label "ollama (running)" \
      || true
    echo ""
    DRIFT_FOUND=true
  else
    info "OK: ${model_name}"
  fi
done

if [[ $CHECKED -eq 0 ]]; then
  warn "No .Modelfile files found in ${MODELFILES_DIR}. Run scripts/build-modelfiles.sh first."
  exit 1
fi

# ── Result ────────────────────────────────────────────────────────────────────
echo ""
if $DRIFT_FOUND; then
  warn "Drift detected. Run scripts/build-modelfiles.sh to rebuild and sync models."
  exit 1
else
  info "All ${CHECKED} model(s) are in sync with their Modelfiles."
  exit 0
fi
