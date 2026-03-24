# Bash / Zsh Standards

## Mandatory Header

Every script must declare its interpreter and safety flags:

```bash
#!/usr/bin/env bash
set -euo pipefail
```

## Logging Convention

Define these helpers at the top of every non-trivial script:

```bash
info()  { echo "[INFO]  $*"; }
warn()  { echo "[WARN]  $*" >&2; }
error() { echo "[ERROR] $*" >&2; exit 1; }
```

## Preflight Pattern

Validate all external dependencies and required arguments before doing any work:

```bash
require_cmd() {
  command -v "$1" >/dev/null 2>&1 || error "Required command not found: $1"
}

require_cmd curl
require_cmd jq
require_cmd podman
```

## Function Structure

```bash
do_something() {
  local input_file="$1"
  local output_dir="$2"

  [[ -f "$input_file" ]] || error "Input file not found: $input_file"
  [[ -d "$output_dir" ]] || error "Output directory not found: $output_dir"

  # logic here
}
```

## Temporary File Handling

```bash
TMP_FILE="$(mktemp)"
trap 'rm -f "$TMP_FILE"' EXIT
```

## Linting

All scripts must pass shellcheck with zero warnings:

```zsh
shellcheck scripts/*.sh
```

Configure shellcheck via `.shellcheckrc` at repository root:

```
shell=bash
enable=all
disable=SC2312  # example: disable specific noisy rules with justification
```

## Testing with bats-core

```bash
# tests/scripts/load-models.bats
@test "should exit 1 when ollama container is not running" {
  OLLAMA_CONTAINER="nonexistent" run ./scripts/load-models.sh
  [ "$status" -eq 1 ]
}

@test "should skip pull when model already exists" {
  # setup: mock ollama list output
  run ./scripts/load-models.sh
  [ "$status" -eq 0 ]
}
```

## CI Integration

Add a lint-scripts job to ci.yml:

```yaml
lint-scripts:
  runs-on: ubuntu-24.04
  steps:
    - uses: actions/checkout@v4
    - name: Install shellcheck
      run: sudo apt-get install -y shellcheck
    - name: Lint all shell scripts
      run: shellcheck scripts/*.sh tools/*.sh
```
