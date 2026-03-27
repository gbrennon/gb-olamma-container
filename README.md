# gb-ollama-container

A fully automated local AI infrastructure for senior engineering workflows with Hexagonal Architecture, TDD, and multi-language AI assistance.

## Quick Start

```bash
# Clone and run the bootstrap script
git clone https://github.com/gbrennon/gb-ollama-container
cd gb-ollama-container
./scripts/bootstrap.sh
```

That's it. The bootstrap script handles everything:
- Detects Docker or Podman
- Finds available compose tool (`docker compose`, `docker-compose`, `podman compose`, `podman-compose`)
- Builds and starts the container stack
- Loads base models from `models.conf.sh`
- Generates the architecture model
- Keeps Ollama running

## What Happens Automatically

1. **Runtime Detection**: Chooses between Docker or Podman
2. **Compose Detection**: Uses `docker compose`, `docker-compose`, `podman compose`, or `podman-compose`
3. **Container Stack**: Builds and starts Ollama, Open WebUI, and OpenHands
4. **Model Registration**: Pulls all models defined in `scripts/models.conf.sh`
5. **Architecture Generation**: Creates `eda-architecture-pro` from the modelfile
6. **Keepalive**: Keeps container running with Ollama as foreground process

## Configuration

### Models

Edit `scripts/models.conf.sh` to add or remove base models:

```bash
MODELS=(
  "qwen2.5-coder:32b"
  "deepseek-r1:14b"
  "mistral:latest"
  "llama3.1:8b"
)
```

### Architecture Model

The `eda-architecture-pro` model is built from the modelfile in `modelfiles/`. To regenerate after editing:

```bash
docker exec -it ollama /usr/local/bin/load-models.sh
```

### Environment

Edit `docker-compose.yml` to customize:
- `OLLAMA_CONTEXT_LENGTH`: Context window (default: 32768)
- `LLM_MODEL`: Default model for OpenHands

## Access Points

| Service | URL |
|---------|-----|
| Ollama API | http://localhost:11434 |
| Open WebUI | http://localhost:3000 |
| OpenHands | http://localhost:3001 |

## Model Ecosystem

- **Base Models**: qwen2.5-coder:32b, deepseek-r1:14b, mistral:latest, llama3.1:8b
- **Architecture Model**: `eda-architecture-pro` - Hexagonal Architecture, TDD, SOLID principles

## Engineering Standards

The architecture model includes:
- **Hexagonal Architecture**: Domain-Driven Design, Ports & Adapters
- **SOLID Principles**: SRP, OCP, LSP, ISP, DIP
- **TDD**: Red-Green-Refactor, test-first development
- **Code Quality**: No God objects, zero-unchecked-errors, proper error handling

## Troubleshooting

```bash
# Check container status
./scripts/bootstrap.sh --dry-run  # Preview commands without running

# View logs
docker compose logs -f server

# Restart after config changes
./scripts/bootstrap.sh
```

## Requirements

- Linux with systemd
- NVIDIA GPU + nvidia-container-toolkit
- Docker or Podman
- At least 16GB RAM (32GB+ recommended)