# Copilot Instructions for gb-ollama-container

## Build, Test, and Lint Commands

- **Build Ollama container:**
  - `docker-compose build gb-ollama-server`
- **Start services:**
  - `docker-compose up -d`
- **Stop services:**
  - `docker-compose down`
- **Pre-pull models during build:**
  - Handled in Dockerfile and `init-models.sh`.
- **Run model initialization script:**
  - `bash init-models.sh` (ensure OLLAMA_HOST is set)

*No test or lint commands detected in this repository.*

## High-Level Architecture

- **Multi-container setup:**
  - `gb-ollama-server`: Runs Ollama LLM server, exposes port 11434, uses GPU if available.
  - `open-webui`: Provides a web UI for interacting with Ollama, connects via internal network.
- **Model management:**
  - Models are pre-pulled in Dockerfile and managed via `init-models.sh`.
  - Data is persisted in Docker volumes (`ollama_data`, `open_webui_data`).
- **GPU support:**
  - Docker Compose configures NVIDIA GPU access for Ollama if available.

## Key Conventions

- **Model list:**
  - Edit `init-models.sh` to add/remove models as needed.
- **Health checks:**
  - `init-models.sh` waits for Ollama to be healthy before pulling models.
- **Environment variables:**
  - Set `OLLAMA_HOST` for scripts interacting with Ollama API.
- **Web UI configuration:**
  - `open-webui` uses `OLLAMA_BASE_URL` to connect to Ollama server.

## Integration with Other AI Assistant Configs

- No other AI assistant configuration files detected.

---

If you want to configure MCP servers (e.g., Playwright for web testing), let me know your requirements.
