# gb-ollama-container

A terminal-centric, Docker-based infrastructure for running a local Ollama server with Open WebUI and OpenHands. This setup is optimized for senior engineering workflows with Hexagonal Architecture, TDD, and multi-language AI assistance.

## Quick Start

### Prerequisites
- Linux distribution (tested on Fedora 43 i3 spin)
- NVIDIA GPU with nvidia-container-toolkit installed
- Docker and docker-compose configured for current user
- At least 16GB RAM (32GB+ recommended for optimal performance)

### 1. Initial Setup
```bash
# Clone and make scripts executable
git clone https://github.com/gbrennon/gb-ollama-container
cd gb-ollama-container
chmod +x scripts/*.sh

# Build and start the stack
docker-compose up -d --build
```

### 2. Configure Host CLI Tools
```bash
# Install and configure Aider and Shell-GPT
./scripts/setup-ai-tools.sh
source ~/.zshrc
```

### 3. Verify Installation
```bash
# Check if services are running
docker-compose ps

# List available models
docker exec -it ollama ollama list

# Test the architecture model
docker exec -it ollama ollama run eda-architecture-pro
```

## Architecture Overview

This project provides a multi-model AI infrastructure with specialized capabilities:

### Core Services
- **Ollama Server** (Port 11434): Local LLM server with GPU acceleration
- **Open WebUI** (Port 3000): Web interface for chat and model management
- **OpenHands** (Port 3001): AI coding assistant with sandboxed execution

### Model Ecosystem
- **Base Models**: qwen2.5-coder:32b, deepseek-r1:14b, mistral:latest, llama3.1:8b
- **Architecture Models**: Specialized models for different programming languages
  - `eda-architecture-pro`: General architecture and engineering standards
  - `eda-arch-rust`: Rust-specific best practices
  - `eda-arch-golang`: Go-specific patterns and standards
  - `eda-arch-python`: Python development guidelines
  - `eda-arch-typescript`: TypeScript/JavaScript architecture
  - `eda-arch-scala`: Scala functional programming patterns
  - `eda-arch-bash`: Shell scripting standards
  - `eda-arch-actions`: GitHub Actions workflow optimization

## Project Structure

```
gb-ollama-container/
├── docker-compose.yml          # Docker stack configuration
├── Dockerfile                  # Ollama server customization
├── scripts/                    # Automation and management scripts
│   ├── load-models.sh         # Model loading and management
│   ├── setup-ai-tools.sh      # Host tool configuration
│   ├── build-modelfiles.sh    # Architecture model building
│   └── models.conf.sh         # Model configuration
├── knowledges/                 # Engineering standards and principles
│   ├── base/                  # Core architecture principles
│   └── lang/                  # Language-specific standards
├── modelfiles/                 # Ollama model definitions
├── prompts/                    # System prompts for AI agents
├── tools/                      # Open WebUI extensions
└── skills/                     # Agent capabilities
```

## Management Commands

### Service Management
| Task | Command |
|------|---------|
| Start Services | `docker-compose up -d` |
| Stop Services | `docker-compose down` |
| View Logs | `docker-compose logs -f server` |
| Restart Stack | `docker-compose restart` |
| Rebuild Stack | `docker-compose up -d --build` |

### Model Management
| Task | Command |
|------|---------|
| List Models | `docker exec -it ollama ollama list` |
| Pull Model | `docker exec -it ollama ollama pull <model>` |
| Create Model | `docker exec -it ollama ollama create <name> -f <modelfile>` |
| Sync Models | `docker exec -it ollama /usr/local/bin/load-models.sh` |
| Update Standards | `./scripts/build-modelfiles.sh && docker-compose up -d --build server` |

### Development Workflow
```bash
# Start coding session with architecture standards
aider-arch <path_to_your_code>

# Use specific language model
ollama run eda-arch-rust

# Test with Open WebUI
open http://localhost:3000

# Use OpenHands for coding assistance
open http://localhost:3001
```

## Engineering Standards

The architecture models are built with comprehensive engineering principles:

### Core Principles (Hexagonal Architecture)
- **Domain-Driven Design**: Pure domain layer with no external dependencies
- **Ports & Adapters**: Clean separation between business logic and infrastructure
- **SOLID Principles**: Single responsibility, open/closed, Liskov substitution, interface segregation, dependency inversion
- **Event-Driven Architecture**: Domain events with idempotency keys and outbox pattern

### Development Workflow (TDD)
- **Red-Green-Refactor**: Strict test-first development cycle
- **Unit Testing**: Domain and application layers with mocked dependencies
- **Integration Testing**: Infrastructure with real dependencies
- **Code Quality**: Zero tolerance for unchecked errors, God objects, or primitive obsession

### Language-Specific Standards
Each language model includes specialized best practices:
- **Rust**: Type safety, zero-unwrap policy, proper error handling with thiserror/anyhow
- **Go**: Interface design, error handling, concurrency patterns
- **Python**: Type hints, proper exception handling, clean architecture patterns
- **TypeScript**: Strict typing, proper async/await, functional programming patterns

## Configuration

### Environment Variables
The stack can be configured through environment variables in `docker-compose.yml`:
- `OLLAMA_CONTEXT_LENGTH`: Context window size (default: 32768)
- `LLM_MODEL`: Default model for OpenHands (default: ollama/eda-architecture-pro:latest)

### GPU Configuration
Ensure nvidia-container-toolkit is properly installed:
```bash
# Verify GPU access
docker run --rm --gpus all nvidia/cuda:11.0-base nvidia-smi
```

## Troubleshooting

### Common Issues
1. **Models not loading**: Check GPU memory and available disk space
2. **Port conflicts**: Ensure ports 11434, 3000, and 3001 are available
3. **Permission errors**: Verify Docker is configured for current user
4. **Slow performance**: Check available RAM and GPU memory

### Debug Commands
```bash
# Check service status
docker-compose ps

# View detailed logs
docker-compose logs --tail=100 -f

# Test model availability
docker exec -it ollama ollama run eda-architecture-pro "Hello"

# Check GPU utilization
docker exec -it ollama nvidia-smi
```

## Maintenance

### Regular Updates
1. **Update Models**: Run `./scripts/update-models.sh` to pull latest base models
2. **Refresh Standards**: Modify files in `knowledges/` and rebuild with `./scripts/build-modelfiles.sh`
3. **Clean Up**: Periodically run `docker system prune` to clean unused images

### Backup and Restore
```bash
# Backup model data
docker run --rm -v ollama_data:/data -v $(pwd):/backup busybox tar czf /backup/ollama-backup.tar.gz /data

# Restore model data
docker run --rm -v ollama_data:/data -v $(pwd):/backup busybox tar xzf /backup/ollama-backup.tar.gz -C /
```

## Contributing

1. Fork the repository
2. Create a feature branch
3. Add tests for new functionality
4. Ensure all scripts follow the `set -euo pipefail` standard
5. Update documentation as needed

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Acknowledgments

- Ollama for the local LLM server
- Open WebUI for the web interface
- OpenHands for the coding assistant
- The open-source community for incredible AI models

---

**Note**: This setup is optimized for development workflows and should be used in trusted environments. Always review generated code before deployment.
