#!/bin/sh
# macbox-init — container entrypoint script
# Runs as root inside the Linux container. Must be POSIX sh, idempotent.
set -e

MACBOX_HOST_USER="${MACBOX_HOST_USER:?MACBOX_HOST_USER not set}"
MACBOX_HOST_UID="${MACBOX_HOST_UID:?MACBOX_HOST_UID not set}"
MACBOX_HOST_GID="${MACBOX_HOST_GID:?MACBOX_HOST_GID not set}"
MACBOX_HOST_HOME="${MACBOX_HOST_HOME:?MACBOX_HOST_HOME not set}"
MACBOX_HOST_SHELL="${MACBOX_HOST_SHELL:-bash}"

# --- Package manager detection ---

install_packages() {
  if command -v apt-get >/dev/null 2>&1; then
    apt-get update -qq >/dev/null 2>&1
    DEBIAN_FRONTEND=noninteractive apt-get install -y -qq "$@" >/dev/null 2>&1
  elif command -v dnf >/dev/null 2>&1; then
    dnf install -y -q "$@" >/dev/null 2>&1
  elif command -v pacman >/dev/null 2>&1; then
    pacman -Sy --noconfirm "$@" >/dev/null 2>&1
  elif command -v apk >/dev/null 2>&1; then
    apk add --no-cache "$@" >/dev/null 2>&1
  elif command -v zypper >/dev/null 2>&1; then
    zypper install -y "$@" >/dev/null 2>&1
  else
    echo "macbox-init: WARNING: unknown package manager, skipping package install" >&2
  fi
}

# --- Install essential packages ---

needed=""
if ! command -v sudo >/dev/null 2>&1; then
  needed="$needed sudo"
fi
if ! command -v "$MACBOX_HOST_SHELL" >/dev/null 2>&1; then
  needed="$needed $MACBOX_HOST_SHELL"
fi

if [ -n "$needed" ]; then
  echo "macbox-init: installing:$needed"
  install_packages $needed
fi

# --- Create group matching host GID ---

if ! getent group "$MACBOX_HOST_GID" >/dev/null 2>&1; then
  if command -v groupadd >/dev/null 2>&1; then
    groupadd -g "$MACBOX_HOST_GID" "$MACBOX_HOST_USER" 2>/dev/null || true
  elif command -v addgroup >/dev/null 2>&1; then
    addgroup -g "$MACBOX_HOST_GID" "$MACBOX_HOST_USER" 2>/dev/null || true
  fi
fi

# --- Create user matching host UID/GID ---

shell_path="$(command -v "$MACBOX_HOST_SHELL" 2>/dev/null || echo /bin/sh)"

if ! id "$MACBOX_HOST_USER" >/dev/null 2>&1; then
  if command -v useradd >/dev/null 2>&1; then
    useradd \
      -u "$MACBOX_HOST_UID" \
      -g "$MACBOX_HOST_GID" \
      -d "$MACBOX_HOST_HOME" \
      -s "$shell_path" \
      -M \
      "$MACBOX_HOST_USER" 2>/dev/null || true
  elif command -v adduser >/dev/null 2>&1; then
    # Alpine/BusyBox syntax
    adduser \
      -u "$MACBOX_HOST_UID" \
      -G "$(getent group "$MACBOX_HOST_GID" | cut -d: -f1)" \
      -h "$MACBOX_HOST_HOME" \
      -s "$shell_path" \
      -D \
      "$MACBOX_HOST_USER" 2>/dev/null || true
  fi
else
  # User exists — update home and shell
  if command -v usermod >/dev/null 2>&1; then
    usermod -d "$MACBOX_HOST_HOME" -s "$shell_path" "$MACBOX_HOST_USER" 2>/dev/null || true
  fi
fi

# --- Passwordless sudo ---

if [ -d /etc/sudoers.d ]; then
  echo "$MACBOX_HOST_USER ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/macbox-user
  chmod 440 /etc/sudoers.d/macbox-user
fi

# --- Container shell rc files ---
# Create sane defaults so the user gets a working interactive shell
# instead of sourcing macOS rc files that won't work inside Linux.

mkdir -p /etc/macbox

cat > /etc/macbox/.bashrc <<'BASHRC'
# macbox bashrc
[ -f /etc/bash.bashrc ] && . /etc/bash.bashrc
[ -f /etc/profile ] && . /etc/profile
export PS1='\[\e[1;35m\]macbox\[\e[0m\] \[\e[1;34m\]\w\[\e[0m\] \$ '
alias ls='ls --color=auto'
alias ll='ls -la'
BASHRC

cat > /etc/macbox/.zshrc <<'ZSHRC'
# macbox zshrc
autoload -Uz compinit && compinit
autoload -Uz promptinit && promptinit
bindkey -e
# Arrow keys
bindkey '^[[A' up-line-or-history
bindkey '^[[B' down-line-or-history
bindkey '^[[C' forward-char
bindkey '^[[D' backward-char
# Home/End
bindkey '^[[H' beginning-of-line
bindkey '^[[F' end-of-line
# Delete
bindkey '^[[3~' delete-char
# History search with arrows
bindkey '^[[A' up-line-or-search
bindkey '^[[B' down-line-or-search
HISTFILE=~/.macbox_zsh_history
HISTSIZE=10000
SAVEHIST=10000
setopt SHARE_HISTORY
export PS1='%B%F{magenta}macbox%f%b %B%F{blue}%~%f%b %# '
alias ls='ls --color=auto'
alias ll='ls -la'
ZSHRC

# --- Signal readiness ---

echo "macbox-init: ready"
touch /run/macbox-ready

# --- Keep container alive ---

exec tail -f /dev/null
