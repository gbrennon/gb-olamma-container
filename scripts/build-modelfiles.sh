#!/usr/bin/env zsh
# build-modelfiles.sh
# Assembles Modelfiles from prompt fragments and creates all models in Ollama.
# Usage: ./scripts/build-modelfiles.sh [--container NAME] [--dry-run]
#
# Requires: ollama running locally OR a running container name via --container.

set -euo pipefail

SCRIPT_DIR="${0:A:h}"
source "$SCRIPT_DIR/lib.sh"

# ── Model definitions ─────────────────────────────────────────────────────────
# Format: "ollama-model-name|base-ollama-model|lang-prompt-filename"
readonly MODELS=(
  "eda-arch-rust|qwen2.5-coder:32b|lang-rust.txt"
  "eda-arch-scala|qwen2.5-coder:32b|lang-scala.txt"
  "eda-arch-python|qwen2.5-coder:32b|lang-python.txt"
  "eda-arch-typescript|qwen2.5-coder:32b|lang-typescript.txt"
  "eda-arch-golang|qwen2.5-coder:32b|lang-golang.txt"
  "eda-arch-bash|qwen2.5-coder:32b|lang-bash.txt"
  "eda-arch-actions|qwen2.5-coder:32b|lang-actions.txt"
)

# ── Argument parsing ──────────────────────────────────────────────────────────
DRY_RUN=false

parse_common_args CONTAINER DRY_RUN "$@" || {
  echo "Usage: $0 [--container CONTAINER_NAME] [--dry-run]"
  exit 1
}

# ── Preflight Checks ──────────────────────────────────────────────────────────
validate_environment() {
  log_section "Preflight"
  
  local base_prompt_file="$SCRIPT_DIR/../prompts/base-arch.txt"
  if [[ ! -f "$base_prompt_file" ]]; then
    log_error "Missing: prompts/base-arch.txt"
    exit 1
  fi
  
  if [[ -n "$CONTAINER" ]]; then
    require_container_running "$CONTAINER" || exit 1
  fi
  
  ensure_directory "$SCRIPT_DIR/../modelfiles"
  
  local base_system
  base_system="$(< "$base_prompt_file")"
  log_info "Base prompt loaded ($(echo "$base_system" | wc -l) lines)"
}

# ── Model Processing ──────────────────────────────────────────────────────────
process_model_entry() {
  local entry="$1"
  local model_name="${entry%%|*}"
  local rest="${entry#*|}"
  local base_model="${rest%%|*}"
  local lang_file="${rest##*|}"
  local lang_path="$SCRIPT_DIR/../prompts/$lang_file"
  local modelfile_path="$SCRIPT_DIR/../modelfiles/${model_name}.Modelfile"
  
  if [[ ! -f "$lang_path" ]]; then
    log_warn "Missing language prompt: $lang_path — skipping $model_name"
    return 0
  fi
  
  assemble_modelfile "$model_name" "$base_model" "$lang_path" "$modelfile_path"
  
  if ! is_dry_run; then
    create_model_from_modelfile "$model_name" "$modelfile_path"
  else
    log_info "[dry-run] Would create model: $model_name"
  fi
}

assemble_modelfile() {
  local model_name="$1"
  local base_model="$2"
  local lang_prompt_file="$3"
  local modelfile_path="$4"
  
  local combined_prompts
  combined_prompts="$(load_prompts "$lang_prompt_file")"
  
  cat > "$modelfile_path" <<MODELFILE
FROM ${base_model}
PARAMETER temperature 0.2
PARAMETER seed 0
PARAMETER num_ctx 32768
SYSTEM """
${combined_prompts}
"""
MODELFILE
  
  log_info "Assembled: $modelfile_path"
}

# ── Main Execution ────────────────────────────────────────────────────────────
main() {
  validate_environment
  
  log_section "Building models"
  
  for entry in "${MODELS[@]}"; do
    process_model_entry "$entry"
  done
  
  log_section "Done"
  log_info "All models built."
}

main "$@"
