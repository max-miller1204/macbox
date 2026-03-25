#!/usr/bin/env bash
# macbox - common utilities and constants

# Colors (only if stderr is a terminal)
if [[ -t 2 ]]; then
  RED=$'\033[0;31m'
  GREEN=$'\033[0;32m'
  YELLOW=$'\033[0;33m'
  BLUE=$'\033[0;34m'
  BOLD=$'\033[1m'
  RESET=$'\033[0m'
else
  RED='' GREEN='' YELLOW='' BLUE='' BOLD='' RESET=''
fi

# Constants
MACBOX_LABEL="manager=macbox"
MACBOX_CONTAINER_PREFIX="macbox-"

# Host info
HOST_USER="$(id -un)"
HOST_UID="$(id -u)"
HOST_GID="$(id -g)"
HOST_HOME="${HOME}"
HOST_SHELL="$(basename "${SHELL:-/bin/bash}")"

# Default image aliases
declare -A MACBOX_IMAGES=(
  [ubuntu]="docker.io/library/ubuntu:latest"
  [fedora]="registry.fedoraproject.org/fedora:latest"
  [arch]="docker.io/archlinux:latest"
  [debian]="docker.io/library/debian:latest"
  [alpine]="docker.io/library/alpine:latest"
  [opensuse]="docker.io/opensuse/tumbleweed:latest"
)

# --- Output helpers ---

die() {
  printf "${RED}${BOLD}error:${RESET} %s\n" "$*" >&2
  exit 1
}

warn() {
  printf "${YELLOW}${BOLD}warn:${RESET} %s\n" "$*" >&2
}

info() {
  printf "${BLUE}${BOLD}::${RESET} %s\n" "$*" >&2
}

success() {
  printf "${GREEN}${BOLD}::${RESET} %s\n" "$*" >&2
}

# --- Podman checks ---

require_podman() {
  command -v podman &>/dev/null || die "Podman is not installed. Install it with: brew install podman"
}

require_podman_machine() {
  require_podman
  if ! podman info &>/dev/null; then
    die "Podman machine is not running. Start it with:
  podman machine init   # (first time only)
  podman machine start"
  fi
}

# --- Image / name resolution ---

resolve_image() {
  local input="$1"
  if [[ -n "${MACBOX_IMAGES[$input]+x}" ]]; then
    echo "${MACBOX_IMAGES[$input]}"
  else
    echo "$input"
  fi
}

resolve_name() {
  local image="$1"
  local name="$2"

  if [[ -n "$name" ]]; then
    echo "${MACBOX_CONTAINER_PREFIX}${name}"
    return
  fi

  # Derive from image: take basename, strip tag/registry
  local base
  base="$(echo "$image" | sed 's|.*/||; s|:.*||')"
  echo "${MACBOX_CONTAINER_PREFIX}${base}"
}

# Friendly name (strip prefix for display)
friendly_name() {
  local name="$1"
  echo "${name#"$MACBOX_CONTAINER_PREFIX"}"
}

# --- Container state helpers ---

container_exists() {
  podman container exists "$1" 2>/dev/null
}

container_running() {
  [[ "$(podman inspect --format '{{.State.Running}}' "$1" 2>/dev/null)" == "true" ]]
}

# Wait for container init to complete
wait_for_ready() {
  local container="$1"
  local timeout="${2:-30}"
  local i

  for i in $(seq 1 "$timeout"); do
    if podman exec "$container" test -f /run/macbox-ready 2>/dev/null; then
      return 0
    fi
    sleep 1
  done

  warn "Container init timed out after ${timeout}s. Check logs with: podman logs $container"
  return 1
}

# --- Usage ---

usage() {
  cat >&2 <<EOF
${BOLD}macbox${RESET} — run Linux distros on macOS via Podman

${BOLD}Usage:${RESET}
  macbox <command> [options]

${BOLD}Commands:${RESET}
  create    Create a new container
  enter     Enter a container
  list      List containers
  stop      Stop a container
  rm        Remove a container
  version   Show version

${BOLD}Examples:${RESET}
  macbox create ubuntu
  macbox create fedora --name mydev
  macbox enter ubuntu
  macbox enter --name mydev -- neofetch
  macbox list
  macbox rm ubuntu --force

Run 'macbox <command> --help' for command-specific help.
EOF
  exit 0
}
