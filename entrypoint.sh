#!/bin/bash
set -e

if [ ! -f /.dockerenv ]; then
  echo "Error: this script must run inside a Docker container." >&2
  exit 1
fi

HOST_UID="${HOST_UID:-0}"
HOST_GID="${HOST_GID:-0}"

if [ "$HOST_UID" = "0" ]; then
  exec "$@"
fi

# Create a group and user matching the host, using /root as home so all
# installed tools and dotfiles are immediately available
getent group "$HOST_GID" > /dev/null 2>&1 || groupadd -g "$HOST_GID" devgroup
getent passwd "$HOST_UID" > /dev/null 2>&1 || \
  useradd -u "$HOST_UID" -g "$HOST_GID" -d /root -M -s /usr/bin/zsh devuser

USERNAME=$(getent passwd "$HOST_UID" | cut -d: -f1)

# Chown directories in /root so the user can create files inside them.
# -type d: files are already readable at 644/755, only dirs need ownership.
# -xdev: stay on the container filesystem — skips bind mounts, which are
#        already owned by HOST_UID on the host.
find /root -xdev -type d -print0 | xargs -0 chown "$HOST_UID:$HOST_GID" 2>/dev/null || true

# Grant passwordless sudo
echo "$USERNAME ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/devuser
chmod 440 /etc/sudoers.d/devuser

exec gosu "$USERNAME" "$@"
