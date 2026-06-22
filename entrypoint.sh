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

# Transfer ownership of the home dir so the user can create new files there
chown "$HOST_UID:$HOST_GID" /root

# Grant passwordless sudo
echo "$USERNAME ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/devuser
chmod 440 /etc/sudoers.d/devuser

exec gosu "$USERNAME" "$@"
