#!/usr/bin/env bash
# setup-local-llm-tools.sh
# Configures cline, opencode, and aider to use a local Ollama instance.
# Usage: ./setup-local-llm-tools.sh [--ollama-url URL] [--model MODEL]
# Defaults: URL=http://localhost:11434, MODEL=qwen2.5-coder:7b

set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

# ── Configuration ────────────────────────────────────────────────────────────
DEFAULT_OLLAMA_URL="http://localhost:11434"
DEFAULT_MODEL="qwen2.5-coder:7b"

# ── Argument parsing ─────────────────────────────────────────────────────────
OLLAMA_URL="$DEFAULT_OLLAMA_URL"
MODEL="$DEFAULT_MODEL"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --ollama-url) OLLAMA_URL="$2"; shift 2 ;;
    --model)      MODEL="$2";      shift 2 ;;
    -h|--help)
      echo "Usage: $0 [--ollama-url URL] [--model MODEL]"
      exit 0 ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

readonly OLLAMA_URL_V1="${OLLAMA_URL}/v1"

# ── Preflight Checks ──────────────────────────────────────────────────────────
verify_ollama_connectivity() {
  log_section "Preflight"
  log_info "Checking Ollama at $OLLAMA_URL ..."

  if curl -sf "${OLLAMA_URL}/api/tags" -o /dev/null; then
    log_ok "Ollama is reachable."
  else
    log_warn "Ollama did not respond at $OLLAMA_URL. Continuing anyway — check your container port mapping."
  fi
}

# ── Configuration Management ──────────────────────────────────────────────────
configure_aider() {
  log_section "aider (~/.aider.conf.yml)"

  local aider_conf="$HOME/.aider.conf.yml"
  backup_file "$aider_conf"

  local config_content=$(cat <<EOF
# aider config — local Ollama
# Docs: https://aider.chat/docs/config/aider_conf.html

model: openai/${MODEL}
openai-api-base: ${OLLAMA_URL_V1}
openai-api-key: ollama          # placeholder — required by the client, unused by Ollama
EOF
)

  echo "$config_content" > "$aider_conf"
  log_ok "Written: $aider_conf"
}

configure_opencode() {
  log_section "opencode (~/.config/opencode/opencode.json)"

  local opencode_dir="$HOME/.config/opencode"
  local opencode_conf="$opencode_dir/opencode.json"

  mkdir -p "$opencode_dir"
  backup_file "$opencode_conf"

  # Sanitize model name for JSON key (colons/dots → underscores)
  local model_key="${MODEL//[:.\/]/_}"

  local config_content=$(cat <<EOF
{
  "\$schema": "https://opencode.ai/config.json",
  "provider": {
    "ollama": {
      "npm": "@ai-sdk/openai-compatible",
      "name": "Ollama",
      "options": {
        "baseURL": "${OLLAMA_URL_V1}"
      },
      "models": {
        "${MODEL}": {
          "name": "${MODEL}",
          "tools": true
        }
      }
    }
  }
}
EOF
)

  echo "$config_content" > "$opencode_conf"
  log_ok "Written: $opencode_conf"
  log_info "Inside opencode, run /models and select 'Ollama / $MODEL'."
}

configure_cline() {
  log_section "cline (~/.cline/data/globalState.json)"

  local cline_state="$HOME/.cline/data/globalState.json"

  if [[ ! -f "$cline_state" ]]; then
    log_warn "cline globalState.json not found at $cline_state."
    log_warn "Launch cline once to initialise it, then re-run this script."
    return 0
  fi

  if ! require_jq; then
    return 1
  fi

  backup_file "$cline_state"

  # Patch the relevant keys in-place
  patch_json_config "$cline_state" \
    --arg url "$OLLAMA_URL" \
    --arg model "$MODEL" \
    '
      .actModeApiProvider          = "ollama" |
      .actModeOllamaBaseUrl        = $url     |
      .actModeOllamaModelId        = $model   |
      .planModeApiProvider         = "ollama" |
      .planModeOllamaBaseUrl       = $url     |
      .planModeOllamaModelId       = $model
    '

  log_info "Keys set: actModeApiProvider=ollama, actModeOllamaModelId=$MODEL"
}

# ── Summary and Notes ─────────────────────────────────────────────────────────
display_completion_notes() {
  log_section "gh copilot"
  log_warn "gh copilot CLI always routes through GitHub's cloud — local models not supported. Skipped."

  log_section "Done"
  echo ""
  echo "  Ollama URL : $OLLAMA_URL"
  echo "  Model      : $MODEL"
  echo ""
  echo "  Files written:"
  echo "    $HOME/.aider.conf.yml"
  echo "    $HOME/.config/opencode/opencode.json"
  echo ""
  echo "  Tip: if Ollama truncates context, add a Modelfile with:"
  echo "    PARAMETER num_ctx 16384"
  echo "  and rebuild your model: ollama create mymodel -f Modelfile"
  echo ""
}

# ── Main Execution ────────────────────────────────────────────────────────────
main() {
  verify_ollama_connectivity
  configure_aider
  configure_opencode
  configure_cline
  display_completion_notes
}

main "$@"
