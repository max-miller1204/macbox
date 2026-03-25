#!/usr/bin/env bash
# macbox create — create a new container

cmd_create() {
  local image_input=""
  local name=""
  local mount_home=true
  local pull_policy="missing"
  local -a extra_volumes=()

  # Parse args
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --name)     name="$2"; shift 2 ;;
      --image)    image_input="$2"; shift 2 ;;
      --no-home)  mount_home=false; shift ;;
      --volume)   extra_volumes+=("--volume" "$2"); shift 2 ;;
      --pull)     pull_policy="$2"; shift 2 ;;
      --help|-h)  create_usage; return 0 ;;
      -*)         die "Unknown flag: $1. Run 'macbox create --help'." ;;
      *)
        # Positional arg = image (if --image not given)
        if [[ -z "$image_input" ]]; then
          image_input="$1"
        else
          die "Unexpected argument: $1"
        fi
        shift ;;
    esac
  done

  # Defaults
  image_input="${image_input:-ubuntu}"

  require_podman_machine

  local image
  image="$(resolve_image "$image_input")"

  local container_name
  container_name="$(resolve_name "$image" "$name")"

  local display_name
  display_name="$(friendly_name "$container_name")"

  # Check if already exists
  if container_exists "$container_name"; then
    if container_running "$container_name"; then
      info "Container '$display_name' already exists and is running."
      info "Enter it with: macbox enter $display_name"
      return 0
    else
      info "Container '$display_name' already exists but is stopped. Starting it..."
      podman start "$container_name" >/dev/null
      wait_for_ready "$container_name"
      success "Container '$display_name' is ready. Enter with: macbox enter $display_name"
      return 0
    fi
  fi

  # Pull image
  info "Pulling $image..."
  if ! podman pull --policy "$pull_policy" "$image" >/dev/null 2>&1; then
    die "Failed to pull image: $image"
  fi

  # Build volume args
  local -a vol_args=()
  vol_args+=("--volume" "${LIB_DIR}/init.sh:/macbox-init:ro")

  if [[ "$mount_home" == true ]]; then
    vol_args+=("--volume" "${HOST_HOME}:${HOST_HOME}:rw")
  fi

  # Create container
  info "Creating container '$display_name' from $image..."
  if ! podman create \
    --name "$container_name" \
    --hostname "$display_name" \
    --label "manager=macbox" \
    --label "macbox.image=$image" \
    --label "macbox.name=$display_name" \
    --user root \
    --entrypoint '["/bin/sh", "/macbox-init"]' \
    --env "MACBOX_HOST_USER=${HOST_USER}" \
    --env "MACBOX_HOST_UID=${HOST_UID}" \
    --env "MACBOX_HOST_GID=${HOST_GID}" \
    --env "MACBOX_HOST_HOME=${HOST_HOME}" \
    --env "MACBOX_HOST_SHELL=${HOST_SHELL}" \
    "${vol_args[@]}" \
    "${extra_volumes[@]}" \
    "$image" >/dev/null 2>&1; then
    die "Failed to create container"
  fi

  # Start container
  info "Starting container..."
  if ! podman start "$container_name" >/dev/null; then
    die "Failed to start container"
  fi

  # Wait for init
  if wait_for_ready "$container_name"; then
    success "Container '$display_name' is ready!"
    info "Enter with: macbox enter $display_name"
  fi
}

create_usage() {
  cat >&2 <<EOF
${BOLD}macbox create${RESET} — create a new container

${BOLD}Usage:${RESET}
  macbox create [image] [options]

${BOLD}Arguments:${RESET}
  image              Image name or alias (default: ubuntu)
                     Aliases: ubuntu, fedora, arch, debian, alpine, opensuse
                     Or any OCI image: docker.io/library/centos:7

${BOLD}Options:${RESET}
  --name NAME        Container name (default: derived from image)
  --image IMAGE      Image name (alternative to positional arg)
  --no-home          Don't mount home directory
  --volume SRC:DST   Additional bind mount (repeatable)
  --pull POLICY      Pull policy: always, missing, never (default: missing)
  -h, --help         Show this help

${BOLD}Examples:${RESET}
  macbox create ubuntu
  macbox create fedora --name mydev
  macbox create docker.io/library/centos:7 --name legacy
  macbox create arch --volume /tmp/shared:/shared
EOF
}
