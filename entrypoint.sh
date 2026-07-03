#!/bin/bash
set -e

# Refuse to run anywhere but inside a container — this rewrites users, sudoers
# and ownership under /home/ubuntu, which would be destructive on a real host.
require_docker_container() {
  if [ ! -f /.dockerenv ]; then
    echo "Error: this script must run inside a Docker container." >&2
    exit 1
  fi
}

# Create a group and user matching the host UID/GID, using /home/ubuntu as home
# so all installed tools and dotfiles are immediately available. Sets USERNAME.
create_host_user() {
  getent group "$HOST_GID" > /dev/null 2>&1 || groupadd -g "$HOST_GID" devgroup
  getent passwd "$HOST_UID" > /dev/null 2>&1 || \
    useradd -u "$HOST_UID" -g "$HOST_GID" -d /home/ubuntu -M -s /usr/bin/zsh devuser
  USERNAME=$(getent passwd "$HOST_UID" | cut -d: -f1)
}

# Chown directories in /home/ubuntu so the user can create files inside them.
# -type d: files are already readable at 644/755, only dirs need ownership.
# -xdev: stay on the container filesystem — skips bind mounts, which are
#        already owned by HOST_UID on the host.
take_ownership_of_home() {
  find /home/ubuntu -xdev -type d -print0 | xargs -0 --no-run-if-empty chown "$HOST_UID:$HOST_GID"
}

grant_passwordless_sudo() {
  echo "$USERNAME ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/devuser
  chmod 440 /etc/sudoers.d/devuser
}

# Let the user talk to the Docker daemon without sudo. The mounted
# /var/run/docker.sock is owned by a GID inherited from the host; ensure a
# group with that GID exists and add the user to it.
grant_docker_access() {
  local sock=/var/run/docker.sock sock_gid sock_group
  [ -S "$sock" ] || return 0
  sock_gid=$(stat -c '%g' "$sock")
  sock_group=$(getent group "$sock_gid" | cut -d: -f1)
  if [ -z "$sock_group" ]; then
    sock_group=dockersock
    groupadd -g "$sock_gid" "$sock_group"
  fi
  usermod -aG "$sock_group" "$USERNAME"
}

main() {
  require_docker_container

  HOST_UID="${HOST_UID:-0}"
  HOST_GID="${HOST_GID:-0}"

  # Running as root on the host: no user to remap, just run the command.
  if [ "$HOST_UID" = "0" ]; then
    exec "$@"
  fi

  create_host_user
  take_ownership_of_home
  grant_passwordless_sudo
  grant_docker_access

  exec gosu "$USERNAME" "$@"
}

main "$@"
