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

# Create a group and user matching the host, using /home/ubuntu as home so all
# installed tools and dotfiles are immediately available
getent group "$HOST_GID" > /dev/null 2>&1 || groupadd -g "$HOST_GID" devgroup
getent passwd "$HOST_UID" > /dev/null 2>&1 || \
  useradd -u "$HOST_UID" -g "$HOST_GID" -d /home/ubuntu -M -s /usr/bin/zsh devuser

USERNAME=$(getent passwd "$HOST_UID" | cut -d: -f1)

# Chown directories in /home/ubuntu so the user can create files inside them.
# -type d: only dirs need ownership fixed for write access.
# -xdev: stay on the container filesystem — skips bind-mounted directories,
#        which are already owned by HOST_UID on the host.
find /home/ubuntu -xdev -type d -print0 | xargs -0 chown "$HOST_UID:$HOST_GID" 2>/dev/null || true

# Chown files directly in /home/ubuntu that are bind-mounted (on a different
# device than the home dir). Host dotfiles may be owned by root or a different
# UID; chowning to HOST_UID makes them accessible to the container user.
home_dev=$(stat -c '%d' /home/ubuntu)
while IFS= read -r -d '' f; do
  f_dev=$(stat -c '%d' "$f" 2>/dev/null) || continue
  [ "$f_dev" = "$home_dev" ] && continue
  chown "$HOST_UID:$HOST_GID" "$f" 2>/dev/null || true
done < <(find /home/ubuntu -maxdepth 1 -type f -print0 2>/dev/null)

# Grant passwordless sudo
echo "$USERNAME ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/devuser
chmod 440 /etc/sudoers.d/devuser

exec gosu "$USERNAME" "$@"
