#!/usr/bin/env bash
# setup-local-llm-tools.sh
# Configures cline, opencode, and aider to use a local Ollama instance.
# Usage: ./setup-local-llm-tools.sh [--ollama-url URL] [--model MODEL]
# Defaults: URL=http://localhost:11434, MODEL=qwen2.5-coder:7b

set -euo pipefail

# ── Defaults ────────────────────────────────────────────────────────────────
OLLAMA_URL="http://localhost:11434"
MODEL="qwen2.5-coder:7b"

# ── Argument parsing ─────────────────────────────────────────────────────────
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

OLLAMA_URL_V1="${OLLAMA_URL}/v1"

# ── Helpers ──────────────────────────────────────────────────────────────────
info()    { echo -e "\033[1;34m[INFO]\033[0m  $*"; }
ok()      { echo -e "\033[1;32m[ OK ]\033[0m  $*"; }
warn()    { echo -e "\033[1;33m[WARN]\033[0m  $*"; }
section() { echo -e "\n\033[1;37m──── $* ────\033[0m"; }

backup_file() {
  local file="$1"
  if [[ -f "$file" ]]; then
    local backup="${file}.bak.$(date +%Y%m%d%H%M%S)"
    cp "$file" "$backup"
    warn "Backed up existing $(basename "$file") → $backup"
  fi
}

# ── Preflight: check Ollama is reachable ─────────────────────────────────────
section "Preflight"
info "Checking Ollama at ${OLLAMA_URL} ..."
if curl -sf "${OLLAMA_URL}/api/tags" -o /dev/null; then
  ok "Ollama is reachable."
else
  warn "Ollama did not respond at ${OLLAMA_URL}. Continuing anyway — check your container port mapping."
fi

# ── aider ────────────────────────────────────────────────────────────────────
section "aider  (~/.aider.conf.yml)"
AIDER_CONF="${HOME}/.aider.conf.yml"

backup_file "$AIDER_CONF"

cat > "$AIDER_CONF" <<EOF
# aider config — local Ollama
# Docs: https://aider.chat/docs/config/aider_conf.html

model: openai/${MODEL}
openai-api-base: ${OLLAMA_URL_V1}
openai-api-key: ollama          # placeholder — required by the client, unused by Ollama
EOF

ok "Written: ${AIDER_CONF}"

# ── opencode ─────────────────────────────────────────────────────────────────
section "opencode  (~/.config/opencode/opencode.json)"
OPENCODE_DIR="${HOME}/.config/opencode"
OPENCODE_CONF="${OPENCODE_DIR}/opencode.json"

mkdir -p "$OPENCODE_DIR"
backup_file "$OPENCODE_CONF"

# Sanitise model name for JSON key (colons/dots → underscores)
MODEL_KEY="${MODEL//[:.\/]/_}"

cat > "$OPENCODE_CONF" <<EOF
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

ok "Written: ${OPENCODE_CONF}"
info "Inside opencode, run /models and select 'Ollama / ${MODEL}'."

# ── cline ────────────────────────────────────────────────────────────────────
section "cline  (~/.cline/data/globalState.json)"
CLINE_STATE="${HOME}/.cline/data/globalState.json"

if [[ ! -f "$CLINE_STATE" ]]; then
  warn "cline globalState.json not found at ${CLINE_STATE}."
  warn "Launch cline once to initialise it, then re-run this script."
else
  # Require jq
  if ! command -v jq &>/dev/null; then
    warn "jq not found — cannot patch cline config. Install with: sudo dnf install jq"
  else
    backup_file "$CLINE_STATE"

    # Patch the relevant keys in-place
    jq \
      --arg url  "$OLLAMA_URL" \
      --arg model "$MODEL" \
      '
        .actModeApiProvider          = "ollama" |
        .actModeOllamaBaseUrl        = $url     |
        .actModeOllamaModelId        = $model   |
        .planModeApiProvider         = "ollama" |
        .planModeOllamaBaseUrl       = $url     |
        .planModeOllamaModelId       = $model
      ' "$CLINE_STATE" > "${CLINE_STATE}.tmp" \
    && mv "${CLINE_STATE}.tmp" "$CLINE_STATE"

    ok "Patched: ${CLINE_STATE}"
    info "Keys set: actModeApiProvider=ollama, actModeOllamaModelId=${MODEL}"
  fi
fi

# ── gh copilot note ──────────────────────────────────────────────────────────
section "gh copilot"
warn "gh copilot CLI always routes through GitHub's cloud — local models not supported. Skipped."

# ── Summary ──────────────────────────────────────────────────────────────────
section "Done"
echo ""
echo "  Ollama URL : ${OLLAMA_URL}"
echo "  Model      : ${MODEL}"
echo ""
echo "  Files written:"
echo "    ${AIDER_CONF}"
echo "    ${OPENCODE_CONF}"
echo ""
echo "  Tip: if Ollama truncates context, add a Modelfile with:"
echo "    PARAMETER num_ctx 16384"
echo "  and rebuild your model: ollama create mymodel -f Modelfile"
echo ""
