#!/usr/bin/env bash
# macbox stop — stop a container

cmd_stop() {
  local name=""
  local stop_all=false

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --name)    name="$2"; shift 2 ;;
      --all|-a)  stop_all=true; shift ;;
      --help|-h) stop_usage; return 0 ;;
      -*)        die "Unknown flag: $1" ;;
      *)
        if [[ -z "$name" ]]; then
          name="$1"
        else
          die "Unexpected argument: $1"
        fi
        shift ;;
    esac
  done

  require_podman_machine

  if [[ "$stop_all" == true ]]; then
    local containers
    containers="$(podman ps --filter "label=manager=macbox" --format "{{.Names}}" 2>/dev/null)"
    if [[ -z "$containers" ]]; then
      info "No running macbox containers."
      return 0
    fi
    while IFS= read -r c; do
      podman stop "$c" >/dev/null 2>&1
      success "Stopped $(friendly_name "$c")"
    done <<< "$containers"
    return 0
  fi

  [[ -n "$name" ]] || die "Specify a container name or use --all. Run 'macbox list' to see containers."

  local container_name
  if container_exists "${MACBOX_CONTAINER_PREFIX}${name}"; then
    container_name="${MACBOX_CONTAINER_PREFIX}${name}"
  elif container_exists "$name"; then
    container_name="$name"
  else
    die "Container '$name' not found."
  fi

  if ! container_running "$container_name"; then
    info "Container '$(friendly_name "$container_name")' is already stopped."
    return 0
  fi

  podman stop "$container_name" >/dev/null 2>&1
  success "Stopped $(friendly_name "$container_name")"
}

stop_usage() {
  cat >&2 <<EOF
${BOLD}macbox stop${RESET} — stop a container

${BOLD}Usage:${RESET}
  macbox stop [name] [options]

${BOLD}Options:${RESET}
  --name NAME        Container to stop
  -a, --all          Stop all macbox containers
  -h, --help         Show this help
EOF
}
