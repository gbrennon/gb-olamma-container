#!/usr/bin/env bash
set -euo pipefail

OLLAMA_HOST="${OLLAMA_HOST:-http://localhost:11434}"
DEFAULT_MODEL="eda-architecture-pro"

echo "🔧 Installing AI CLI tools..."

# Install Aider
if ! command -v aider &>/dev/null; then
  python3 -m pip install --user aider-install --quiet
  aider-install
fi

# Configure Aider
cat > "$HOME/.aider.conf.yml" <<EOF
model: ollama/$DEFAULT_MODEL
openai-api-base: $OLLAMA_HOST/v1
openai-api-key: ollama
dark-mode: true
stream: true
auto-commits: false
EOF

# Patch Shell Environment
block=$(cat <<EOF
# AI CLI Tools
export OLLAMA_HOST="$OLLAMA_HOST"
export OPENAI_API_BASE="\$OLLAMA_HOST/v1"
alias aider-arch='aider --model ollama/eda-architecture-pro'
EOF
)

[[ -f "$HOME/.zshrc" ]] && echo "$block" >> "$HOME/.zshrc"
echo "✅ Setup complete. Run 'source ~/.zshrc' to update your path."
