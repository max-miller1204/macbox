#!/usr/bin/env bash
# macbox list — list containers

cmd_list() {
  local quiet=false

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --quiet|-q) quiet=true; shift ;;
      --help|-h)  list_usage; return 0 ;;
      *)          die "Unknown argument: $1" ;;
    esac
  done

  require_podman_machine

  if [[ "$quiet" == true ]]; then
    podman ps --all --filter "label=manager=macbox" --format "{{.Names}}" 2>/dev/null \
      | sed "s/^${MACBOX_CONTAINER_PREFIX}//"
  else
    local output
    output="$(podman ps --all --filter "label=manager=macbox" \
      --format "table {{.Names}}\t{{.Image}}\t{{.Status}}" 2>/dev/null)"

    if [[ -z "$output" ]] || [[ "$(echo "$output" | wc -l)" -le 1 ]]; then
      info "No macbox containers. Create one with: macbox create ubuntu"
      return 0
    fi

    # Replace container names with friendly names (strip prefix)
    echo "$output" | sed "s/${MACBOX_CONTAINER_PREFIX}//"
  fi
}

list_usage() {
  cat >&2 <<EOF
${BOLD}macbox list${RESET} — list containers

${BOLD}Usage:${RESET}
  macbox list [options]

${BOLD}Options:${RESET}
  -q, --quiet        Show only container names
  -h, --help         Show this help
EOF
}
