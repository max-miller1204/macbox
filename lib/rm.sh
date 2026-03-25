#!/usr/bin/env bash
# macbox rm — remove a container

cmd_rm() {
  local name=""
  local force=false
  local remove_all=false

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --name)     name="$2"; shift 2 ;;
      --force|-f) force=true; shift ;;
      --all|-a)   remove_all=true; shift ;;
      --help|-h)  rm_usage; return 0 ;;
      -*)         die "Unknown flag: $1" ;;
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

  if [[ "$remove_all" == true ]]; then
    local containers
    containers="$(podman ps --all --filter "label=manager=macbox" --format "{{.Names}}" 2>/dev/null)"
    if [[ -z "$containers" ]]; then
      info "No macbox containers to remove."
      return 0
    fi
    while IFS= read -r c; do
      local display
      display="$(friendly_name "$c")"
      if [[ "$force" != true ]]; then
        read -rp "Remove container '$display'? [y/N] " confirm
        [[ "$confirm" =~ ^[Yy] ]] || continue
      fi
      podman rm --force "$c" >/dev/null 2>&1
      success "Removed $display"
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

  local display
  display="$(friendly_name "$container_name")"

  if [[ "$force" != true ]]; then
    read -rp "Remove container '$display'? [y/N] " confirm
    [[ "$confirm" =~ ^[Yy] ]] || { info "Cancelled."; return 0; }
  fi

  podman rm --force "$container_name" >/dev/null 2>&1
  success "Removed $display"
}

rm_usage() {
  cat >&2 <<EOF
${BOLD}macbox rm${RESET} — remove a container

${BOLD}Usage:${RESET}
  macbox rm [name] [options]

${BOLD}Options:${RESET}
  --name NAME        Container to remove
  -f, --force        Skip confirmation
  -a, --all          Remove all macbox containers
  -h, --help         Show this help

${BOLD}Examples:${RESET}
  macbox rm ubuntu
  macbox rm --all --force
EOF
}
