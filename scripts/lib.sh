#!/usr/bin/env bash
# lib.sh - Shared library for gb-ollama-container scripts
# Contains common functions and utilities used across all scripts

set -euo pipefail

# ── Constants and Configuration ─────────────────────────────────────────────
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-${(%):-%x}}")" && pwd)"
readonly REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
readonly OLLAMA_HOST="${OLLAMA_HOST:-http://localhost:11434}"
readonly OLLAMA_HOST_V1="${OLLAMA_HOST}/v1"
CONTAINER="${OLLAMA_CONTAINER:-ollama}"

# ── Logging Functions ───────────────────────────────────────────────────────
log_info()    { echo -e "\033[1;34m[INFO]\033[0m  $*"; }
log_ok()      { echo -e "\033[1;32m[ OK ]\033[0m  $*"; }
log_warn()    { echo -e "\033[1;33m[WARN]\033[0m  $*"; }
log_error()   { echo -e "\033[1;31m[ERROR]\033[0m $*" >&2; }
log_section() { echo -e "\n\033[1;37m──── $* ────\033[0m"; }

# ── Argument Parsing Helpers ────────────────────────────────────────────────
parse_common_args() {
  local container_ref="$1"
  local dry_run_ref="$2"
  shift 2
  
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --container) 
        eval "$container_ref=\"$2\""
        shift 2 
        ;;
      --dry-run)   
        eval "$dry_run_ref=true"
        shift 
        ;;
      -h|--help)   return 0 ;;
      *) echo "Unknown option: $1"; return 1 ;;
    esac
  done
}

# ── Container and Ollama Helpers ────────────────────────────────────────────
container_is_running() {
  local container_name="${1:-$CONTAINER}"
  podman inspect --format '{{.State.Running}}' "$container_name" 2>/dev/null | grep -q "true"
}

ollama_is_healthy() {
  local host="${1:-$OLLAMA_HOST}"
  curl -sf "${host}/api/tags" >/dev/null 2>&1
}

wait_for_ollama() {
  local host="${1:-$OLLAMA_HOST}"
  local retries="${2:-30}"
  local interval="${3:-5}"
  
  log_info "Waiting for Ollama to be healthy at $host..."
  
  while [[ $retries -gt 0 ]]; do
    if ollama_is_healthy "$host"; then
      log_ok "Ollama is healthy at $host"
      return 0
    fi
    
    retries=$((retries - 1))
    if [[ $retries -eq 0 ]]; then
      log_error "Ollama did not become healthy in time"
      return 1
    fi
    
    log_info "Not ready yet, retrying in ${interval}s... ($retries attempts left)"
    sleep "$interval"
  done
}

start_ollama_if_needed() {
  local host="${1:-$OLLAMA_HOST}"
  local pid_var="${2:-OLLAMA_PID}"
  
  if ollama_is_healthy "$host"; then
    log_info "Ollama already running at $host, skipping serve..."
    return 0
  fi
  
  log_info "Starting Ollama..."
  ollama serve &
  local ollama_pid=$!
  
  # Export the PID to the calling scope
  eval "$pid_var=$ollama_pid"
  
  wait_for_ollama "$host" || {
    log_error "Failed to start Ollama"
    kill "$ollama_pid" 2>/dev/null || true
    return 1
  }
}

# ── Model Management Helpers ────────────────────────────────────────────────
model_exists() {
  local model="$1"
  local host="${2:-$OLLAMA_HOST}"
  local normalized
  
  normalized=$(echo "$model" | tr '[:upper:]' '[:lower:]')
  
  if [[ -n "${CONTAINER:-}" ]] && container_is_running "$CONTAINER"; then
    podman exec "$CONTAINER" ollama list 2>/dev/null | awk 'NR>1 {print $1}' | grep -qF "$normalized"
  else
    ollama list 2>/dev/null | awk 'NR>1 {print $1}' | grep -qF "$normalized"
  fi
}

ollama_cmd() {
  # Check if we're running inside a container or if CONTAINER is set and running
  if [[ -n "${CONTAINER:-}" ]] && container_is_running "$CONTAINER"; then
    podman exec "$CONTAINER" ollama "$@"
  elif [[ -n "${CONTAINER:-}" ]] && ! container_is_running "$CONTAINER" 2>/dev/null; then
    # Container is specified but not running - this might be inside the container itself
    ollama "$@"
  else
    ollama "$@"
  fi
}

pull_model_if_missing() {
  local model="$1"
  
  if model_exists "$model"; then
    log_info "Model already present, skipping: $model"
  else
    log_info "Pulling: $model"
    ollama_cmd pull "$model"
  fi
}

create_model_from_modelfile() {
  local model_name="$1"
  local modelfile_path="$2"
  
  if model_exists "$model_name"; then
    log_info "Model already exists, recreating: $model_name"
    ollama_cmd rm "$model_name" 2>/dev/null || true
  fi
  
  log_info "Creating model: $model_name"
  
  if [[ -n "${CONTAINER:-}" ]] && container_is_running "$CONTAINER"; then
    local container_modelfile="/tmp/${model_name}.Modelfile"
    podman cp "$modelfile_path" "${CONTAINER}:${container_modelfile}"
    podman exec "$CONTAINER" ollama create "$model_name" -f "$container_modelfile"
  else
    ollama create "$model_name" -f "$modelfile_path"
  fi
  
  log_ok "Created: $model_name"
}

# ── File and Directory Helpers ──────────────────────────────────────────────
ensure_directory() {
  local dir="$1"
  mkdir -p "$dir"
}

backup_file() {
  local file="$1"
  if [[ -f "$file" ]]; then
    local backup="${file}.bak.$(date +%Y%m%d%H%M%S)"
    cp "$file" "$backup"
    log_warn "Backed up existing $(basename "$file") → $backup"
  fi
}

# ── Configuration Loading ───────────────────────────────────────────────────
load_models_config() {
  local config_file="$SCRIPT_DIR/models.conf.sh"
  if [[ -f "$config_file" ]]; then
    source "$config_file"
  else
    log_error "Models configuration not found at $config_file"
    return 1
  fi
}

load_prompts() {
  local base_prompt_file="$SCRIPT_DIR/../prompts/base-arch.txt"
  local lang_prompt_file="$1"
  
  if [[ ! -f "$base_prompt_file" ]]; then
    log_error "Missing base prompt: $base_prompt_file"
    return 1
  fi
  
  if [[ ! -f "$lang_prompt_file" ]]; then
    log_error "Missing language prompt: $lang_prompt_file"
    return 1
  fi
  
  local base_system
  local lang_system
  
  base_system="$(< "$base_prompt_file")"
  lang_system="$(< "$lang_prompt_file")"
  
  echo "$base_system"
  echo ""
  echo "$lang_system"
}

# ── Cleanup Helpers ─────────────────────────────────────────────────────────
setup_ollama_cleanup() {
  local pid_var="${1:-OLLAMA_PID}"
  
  cleanup() {
    local pid
    eval "pid=\$$pid_var"
    
    if [[ -n "$pid" ]]; then
      log_info "Stopping Ollama (pid $pid)..."
      kill "$pid" 2>/dev/null || true
    fi
  }
  
  trap cleanup EXIT
}

# ── Validation Helpers ──────────────────────────────────────────────────────
require_command() {
  local cmd="$1"
  if ! command -v "$cmd" &>/dev/null; then
    log_error "$cmd not found. Install with: sudo dnf install $cmd"
    return 1
  fi
  log_ok "Found $cmd"
}

require_container_running() {
  local container_name="${1:-$CONTAINER}"
  if ! container_is_running "$container_name"; then
    log_error "Container '$container_name' is not running."
    log_warn "Override with: OLLAMA_CONTAINER=<name> $0"
    return 1
  fi
}

# ── Dry Run Helpers ─────────────────────────────────────────────────────────
is_dry_run() {
  [[ "${DRY_RUN:-false}" == "true" ]]
}

dry_run_info() {
  if is_dry_run; then
    log_info "[dry-run] $*"
  fi
}

dry_run_execute() {
  if is_dry_run; then
    log_info "[dry-run] Would execute: $*"
    return 0
  fi
  
  # Execute the command
  "$@"
}

# ── Shell Configuration Helpers ─────────────────────────────────────────────
append_to_shell_config() {
  local content="$1"
  local config_file="$2"
  
  if [[ -f "$config_file" ]]; then
    backup_file "$config_file"
  fi
  
  echo "$content" >> "$config_file"
  log_ok "Updated: $config_file"
}

# ── JSON Configuration Helpers ──────────────────────────────────────────────
require_jq() {
  if ! command -v jq &>/dev/null; then
    log_warn "jq not found — cannot patch JSON config. Install with: sudo dnf install jq"
    return 1
  fi
}

patch_json_config() {
  local config_file="$1"
  shift
  local jq_args=("$@")
  
  if [[ ! -f "$config_file" ]]; then
    log_warn "Config file not found: $config_file"
    return 1
  fi
  
  backup_file "$config_file"
  
  jq "${jq_args[@]}" "$config_file" > "${config_file}.tmp" && \
    mv "${config_file}.tmp" "$config_file"
  
  log_ok "Patched: $config_file"
}