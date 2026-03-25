# macbox

Run Linux distros on macOS — the missing [distrobox](https://distrobox.it/)/[toolbx](https://containertoolbx.org/) for Mac.

macbox creates tightly integrated Linux containers on macOS using Podman. Your home directory is shared, your user is mirrored, and you get a fully working shell with sudo — no VM management required.

## Install

### Homebrew

```bash
brew tap max-miller1204/macbox
brew install macbox
```

### From source

```bash
git clone https://github.com/max-miller1204/macbox.git
cd macbox
sudo make install
```

Or just run it directly — no install needed:

```bash
./macbox create ubuntu
```

## Prerequisites

[Podman](https://podman.io/) must be installed and a machine running:

```bash
brew install podman
podman machine init
podman machine start
```

## Quick start

```bash
macbox create ubuntu           # Create an Ubuntu container
macbox enter ubuntu            # Drop into it — you're you, with your home dir
macbox create arch --name dev  # Another distro alongside
macbox list                    # See all containers
macbox stop ubuntu             # Stop without removing
macbox rm ubuntu --force       # Remove it
```

## Supported distros

Use any OCI image, or these built-in aliases:

| Alias | Image |
|-------|-------|
| `ubuntu` | `docker.io/library/ubuntu:latest` |
| `fedora` | `registry.fedoraproject.org/fedora:latest` |
| `arch` | `docker.io/archlinux:latest` |
| `debian` | `docker.io/library/debian:latest` |
| `alpine` | `docker.io/library/alpine:latest` |
| `opensuse` | `docker.io/opensuse/tumbleweed:latest` |

```bash
macbox create docker.io/library/centos:7 --name legacy
```

## What it does

When you `macbox create`, it:

1. Pulls the image via Podman
2. Creates a container with your home directory mounted
3. Runs an init script inside that:
   - Detects the package manager (apt/dnf/pacman/apk/zypper)
   - Installs sudo and your shell (bash/zsh/fish)
   - Creates a user matching your macOS username, UID, and GID
   - Grants passwordless sudo
   - Sets up shell config with working keybindings and prompt

When you `macbox enter`, it execs into the container as your user with a proper interactive login shell.

## Commands

```
macbox create [image] [options]   Create a new container
macbox enter [name] [-- cmd...]   Enter a container (or run a command)
macbox list                       List containers
macbox stop [name|--all]          Stop a container
macbox rm [name|--all] [--force]  Remove a container
macbox version                    Show version
```

Run `macbox <command> --help` for full options.

## How it works

macbox is a thin bash wrapper around Podman. On macOS, Podman runs containers inside a lightweight Linux VM (via Apple Virtualization). macbox handles the tedious parts — user creation, shell setup, home directory sharing, and lifecycle management — so you just get a working Linux shell.

```
macOS host  →  Podman VM (automatic)  →  Your container (Ubuntu, Fedora, etc.)
  /Users/max ──────────────────────────→ /Users/max (same path, shared)
```

## VS Code

macbox containers work with VS Code's Dev Containers extension:

1. Install the **Dev Containers** extension
2. Set `"dev.containers.dockerPath": "podman"` in VS Code settings
3. Use **"Attach to Running Container"** from the command palette

## License

MIT
