# Tools

Helper scripts for maintaining the repository itself. These are not part of the model
build lifecycle (that lives in scripts/). These scripts operate on the repo's own health.

## Index

| Script                  | Purpose                                                         |
|-------------------------|-----------------------------------------------------------------|
| check-model-drift.sh    | Diff assembled Modelfiles against running Ollama model configs  |

## Usage

```zsh
# Check drift against local ollama
./tools/check-model-drift.sh

# Check drift against a running podman container
./tools/check-model-drift.sh --container ollama
```

## Adding a tool

Keep tools single-purpose. Each script must:
- Begin with #!/usr/bin/env bash and set -euo pipefail
- Include a usage() function
- Write errors to stderr
- Exit with a meaningful code (0 = success, 1 = actionable failure, 2 = usage error)
- Pass shellcheck with zero warnings
