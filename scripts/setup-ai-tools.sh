#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

DEFAULT_MODEL="eda-architecture-pro"

# ── Tool Installation ─────────────────────────────────────────────────────────
install_aider() {
  log_section "Installing AI CLI tools"
  
  if ! command -v aider &>/dev/null; then
    log_info "Installing aider..."
    python3 -m pip install --user aider-install --quiet
    aider-install
  else
    log_info "Aider already installed"
  fi
}

# ── Configuration Management ──────────────────────────────────────────────────
configure_aider() {
  log_section "Configuring Aider"
  
  local aider_config="$HOME/.aider.conf.yml"
  local config_content=$(cat <<EOF
model: ollama/$DEFAULT_MODEL
openai-api-base: $OLLAMA_HOST_V1
openai-api-key: ollama
dark-mode: true
stream: true
auto-commits: false
EOF
)
  
  echo "$config_content" > "$aider_config"
  log_ok "Written: $aider_config"
}

patch_shell_environment() {
  log_section "Updating Shell Environment"
  
  local shell_config="$HOME/.zshrc"
  local block=$(cat <<EOF
# AI CLI Tools
export OLLAMA_HOST="$OLLAMA_HOST"
export OPENAI_API_BASE="\$OLLAMA_HOST/v1"
alias aider-arch='aider --model ollama/eda-architecture-pro'
EOF
)
  
  append_to_shell_config "$block" "$shell_config"
}

# ── Main Execution ────────────────────────────────────────────────────────────
main() {
  install_aider
  configure_aider
  patch_shell_environment
  
  log_section "Done"
  log_info "Setup complete. Run 'source ~/.zshrc' to update your path."
}

main "$@"
