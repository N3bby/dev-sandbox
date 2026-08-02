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

# Slow-path fallback (UID mismatch / old image without the build-time user
# reconciliation): create a group and user matching the host UID/GID, using
# /home/ubuntu as home so all installed tools and dotfiles are immediately
# available. Sets USERNAME.
create_host_user() {
  getent group "$HOST_GID" > /dev/null 2>&1 || groupadd -g "$HOST_GID" devgroup
  getent passwd "$HOST_UID" > /dev/null 2>&1 || \
    useradd -u "$HOST_UID" -g "$HOST_GID" -d /home/ubuntu -M -s /usr/bin/zsh devuser
  USERNAME=$(getent passwd "$HOST_UID" | cut -d: -f1)
}

# Slow-path fallback only. Chown directories in /home/ubuntu so the user can
# create files inside them.
# -type d: files are already readable at 644/755, only dirs need ownership.
# -xdev: stay on the container filesystem — skips bind mounts, which are
#        already owned by HOST_UID on the host.
take_ownership_of_home() {
  echo "==> chown /home/ubuntu directories"
  find /home/ubuntu -xdev -type d -print0 | xargs -0 --no-run-if-empty chown "$HOST_UID:$HOST_GID"

  # asdf's shims are rewritten in place by `asdf reshim` (which plugins like
  # nodejs run automatically after every install) to add each newly
  # installed version. Unlike the rest of /home/ubuntu, those shim files —
  # not just their directory — need to be writable by the runtime user, or
  # reshim fails with a permission error and the install is discarded.
  if [ -d "$ASDF_DATA_DIR" ]; then
    echo "==> chown -R \$ASDF_DATA_DIR"
    chown -R "$HOST_UID:$HOST_GID" "$ASDF_DATA_DIR"
  fi
}

grant_passwordless_sudo() {
  echo "$USERNAME ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/devuser
  chmod 440 /etc/sudoers.d/devuser
}

# The mounted project's .tool-versions may pin a version this image never
# installed. Install anything missing before running the command, so asdf
# shims don't fail. Best-effort: offline or a missing plugin shouldn't block
# startup — the shim will surface the real error if the version is still gone.
# Runs as $1 since installed versions must be owned by whoever ends up using
# them.
run_asdf_install() {
  gosu "$1" asdf install || true
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

  # Fast path: the image was built for this host UID, so the `ubuntu` user was
  # renumbered to it at build time and /home/ubuntu is already owned correctly —
  # nothing to create, nothing to chown (this is the whole speedup). We take it
  # when a username resolves for HOST_UID and either /home/ubuntu is already
  # owned by HOST_UID, or HOST_UID is root (which can write regardless).
  # Otherwise (UID mismatch, or an old root-owned image) fall back to creating a
  # matching user and chowning home at runtime — self-healing but slow.
  USERNAME=$(getent passwd "$HOST_UID" | cut -d: -f1)
  local home_owner
  home_owner=$(stat -c '%u' /home/ubuntu 2>/dev/null || echo -1)
  if [ -n "$USERNAME" ] && { [ "$home_owner" = "$HOST_UID" ] || [ "$HOST_UID" = "0" ]; }; then
    echo "==> using prebuilt user '$USERNAME' (no chown needed)"
  else
    echo "==> create_host_user (UID/ownership mismatch — falling back)"
    create_host_user
    echo "==> take_ownership_of_home"
    take_ownership_of_home
  fi

  echo "==> grant_passwordless_sudo"
  grant_passwordless_sudo

  echo "==> grant_docker_access"
  grant_docker_access

  echo "==> run_asdf_install"
  run_asdf_install "$USERNAME"

  echo "==> exec"
  exec gosu "$USERNAME" "$@"
}

main "$@"
