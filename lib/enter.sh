#!/usr/bin/env bash
# macbox enter — enter a container

cmd_enter() {
  local name=""
  local -a cmd=()
  local parsing_flags=true

  # Parse args
  while [[ $# -gt 0 ]]; do
    if [[ "$parsing_flags" == true ]]; then
      case "$1" in
        --name)    name="$2"; shift 2 ;;
        --help|-h) enter_usage; return 0 ;;
        --)        parsing_flags=false; shift ;;
        -*)        die "Unknown flag: $1. Run 'macbox enter --help'." ;;
        *)
          # Positional arg = container name (if --name not given)
          if [[ -z "$name" ]]; then
            name="$1"
          else
            cmd+=("$1")
          fi
          shift ;;
      esac
    else
      cmd+=("$1")
      shift
    fi
  done

  require_podman_machine

  local container_name

  if [[ -n "$name" ]]; then
    # Try with prefix first, then raw name
    if container_exists "${MACBOX_CONTAINER_PREFIX}${name}"; then
      container_name="${MACBOX_CONTAINER_PREFIX}${name}"
    elif container_exists "$name"; then
      container_name="$name"
    else
      die "Container '$name' not found. Run 'macbox list' to see available containers."
    fi
  else
    # Auto-select if only one macbox container exists
    local containers
    containers="$(podman ps --all --filter "label=manager=macbox" --format "{{.Names}}" 2>/dev/null)"
    local count
    count="$(echo "$containers" | grep -c . 2>/dev/null || echo 0)"

    if [[ "$count" -eq 0 ]]; then
      die "No macbox containers found. Create one with: macbox create ubuntu"
    elif [[ "$count" -eq 1 ]]; then
      container_name="$containers"
    else
      die "Multiple containers found. Specify one with --name:
$(echo "$containers" | sed "s/${MACBOX_CONTAINER_PREFIX}/  /g")"
    fi
  fi

  # Start if stopped
  if ! container_running "$container_name"; then
    info "Starting container..."
    podman start "$container_name" >/dev/null
    wait_for_ready "$container_name"
  fi

  # Build env args
  local -a env_args=(
    --env "TERM=${TERM:-xterm-256color}"
    --env "COLORTERM=${COLORTERM:-}"
    --env "LANG=${LANG:-C.UTF-8}"
    --env "EDITOR=${EDITOR:-}"
    --env "VISUAL=${VISUAL:-}"
  )

  # Default command: user's shell with container-specific rc files
  if [[ ${#cmd[@]} -eq 0 ]]; then
    local shell_path
    shell_path="$(podman exec "$container_name" sh -c "command -v $HOST_SHELL" 2>/dev/null || echo /bin/sh)"

    case "$(basename "$shell_path")" in
      zsh)
        # ZDOTDIR tells zsh to read rc files from /etc/macbox instead of $HOME
        env_args+=(--env "ZDOTDIR=/etc/macbox")
        cmd=("$shell_path" "-li")
        ;;
      bash)
        cmd=("$shell_path" "--rcfile" "/etc/macbox/.bashrc" "-i")
        ;;
      *)
        cmd=("$shell_path" "-li")
        ;;
    esac
  fi

  # Enter the container
  exec podman exec \
    --interactive \
    --tty \
    --user "$HOST_USER" \
    --workdir "$HOST_HOME" \
    "${env_args[@]}" \
    "$container_name" \
    "${cmd[@]}"
}

enter_usage() {
  cat >&2 <<EOF
${BOLD}macbox enter${RESET} — enter a container

${BOLD}Usage:${RESET}
  macbox enter [name] [options] [-- command...]

${BOLD}Arguments:${RESET}
  name               Container name (optional if only one exists)

${BOLD}Options:${RESET}
  --name NAME        Container name (alternative to positional arg)
  -h, --help         Show this help

${BOLD}Examples:${RESET}
  macbox enter                        # Enter the only container
  macbox enter ubuntu                 # Enter by name
  macbox enter ubuntu -- neofetch     # Run a command
  macbox enter --name mydev -- ls -la
EOF
}
