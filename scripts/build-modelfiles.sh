#!/usr/bin/env zsh
# build-modelfiles.sh
# Assembles Modelfiles from prompt fragments and creates all models in Ollama.
# Usage: ./scripts/build-modelfiles.sh [--container NAME] [--dry-run]
#
# Requires: ollama running locally OR a running container name via --container.

set -euo pipefail

# ── Defaults ──────────────────────────────────────────────────────────────────
SCRIPT_DIR="${0:A:h}"
PROMPTS_DIR="${SCRIPT_DIR}/../prompts"
MODELFILES_DIR="${SCRIPT_DIR}/../modelfiles"
CONTAINER=""
DRY_RUN=false

# ── Model definitions ─────────────────────────────────────────────────────────
# Format: "ollama-model-name|base-ollama-model|lang-prompt-filename"
MODELS=(
  "eda-arch-rust|qwen2.5-coder:32b|lang-rust.txt"
  "eda-arch-scala|qwen2.5-coder:32b|lang-scala.txt"
  "eda-arch-python|qwen2.5-coder:32b|lang-python.txt"
  "eda-arch-typescript|qwen2.5-coder:32b|lang-typescript.txt"
  "eda-arch-golang|qwen2.5-coder:32b|lang-golang.txt"
  "eda-arch-bash|qwen2.5-coder:32b|lang-bash.txt"
  "eda-arch-actions|qwen2.5-coder:32b|lang-actions.txt"
)

# ── Argument parsing ──────────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
  case "$1" in
    --container) CONTAINER="$2"; shift 2 ;;
    --dry-run)   DRY_RUN=true; shift ;;
    -h|--help)
      echo "Usage: $0 [--container CONTAINER_NAME] [--dry-run]"
      exit 0 ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

# ── Helpers ───────────────────────────────────────────────────────────────────
info()    { echo "[INFO]  $*" }
ok()      { echo "[ OK ]  $*" }
warn()    { echo "[WARN]  $*" }
section() { echo "\n──── $* ────" }

ollama_cmd() {
  if [[ -n "$CONTAINER" ]]; then
    podman exec "$CONTAINER" ollama "$@"
  else
    ollama "$@"
  fi
}

model_exists() {
  local model="$1"
  ollama_cmd list 2>/dev/null | awk 'NR>1 {print $1}' | grep -qF "$model"
}

# ── Preflight ─────────────────────────────────────────────────────────────────
section "Preflight"

if [[ ! -f "${PROMPTS_DIR}/base-arch.txt" ]]; then
  warn "Missing: prompts/base-arch.txt"
  exit 1
fi

if [[ -n "$CONTAINER" ]]; then
  podman inspect --format '{{.State.Running}}' "$CONTAINER" 2>/dev/null \
    | grep -q "true" \
    || { warn "Container '$CONTAINER' is not running."; exit 1 }
fi

mkdir -p "$MODELFILES_DIR"

BASE_SYSTEM="$(< "${PROMPTS_DIR}/base-arch.txt")"
info "Base prompt loaded ($(echo "$BASE_SYSTEM" | wc -l) lines)"

# ── Build and create each model ───────────────────────────────────────────────
section "Building models"

for entry in "${MODELS[@]}"; do
  model_name="${entry%%|*}"
  rest="${entry#*|}"
  base_model="${rest%%|*}"
  lang_file="${rest##*|}"
  lang_path="${PROMPTS_DIR}/${lang_file}"
  modelfile_path="${MODELFILES_DIR}/${model_name}.Modelfile"

  if [[ ! -f "$lang_path" ]]; then
    warn "Missing language prompt: ${lang_path} — skipping ${model_name}"
    continue
  fi

  LANG_SYSTEM="$(< "$lang_path")"

  # Assemble Modelfile
  cat > "$modelfile_path" <<MODELFILE
FROM ${base_model}
PARAMETER temperature 0.2
PARAMETER seed 0
PARAMETER num_ctx 32768
SYSTEM """
${BASE_SYSTEM}

${LANG_SYSTEM}
"""
MODELFILE

  info "Assembled: ${modelfile_path}"

  if $DRY_RUN; then
    info "[dry-run] Would create model: ${model_name}"
    continue
  fi

  if model_exists "$model_name"; then
    info "Model already exists, recreating: ${model_name}"
    ollama_cmd rm "$model_name" 2>/dev/null || true
  fi

  info "Creating model: ${model_name}"
  if [[ -n "$CONTAINER" ]]; then
    podman cp "$modelfile_path" "${CONTAINER}:/tmp/${model_name}.Modelfile"
    podman exec "$CONTAINER" ollama create "$model_name" -f "/tmp/${model_name}.Modelfile"
  else
    ollama create "$model_name" -f "$modelfile_path"
  fi

  ok "Created: ${model_name}"
done

section "Done"
info "All models built."
