FROM ubuntu:24.04

RUN apt-get update && apt-get install -y curl git vim gosu sudo unzip jq

# Install UTF-8 locales
RUN apt-get install -y locales && locale-gen en_US.UTF-8
ENV LANG=en_US.UTF-8
ENV LC_ALL=en_US.UTF-8

# Use /home/ubuntu as the actual home directory for all tool installations
RUN mkdir -p /home/ubuntu
ENV HOME=/home/ubuntu

# Install Zsh (Oh My Zsh is installed later, as the ubuntu user, into $HOME)
RUN apt-get install -y zsh
ENV SHELL=/usr/bin/zsh
ENV ZDOTDIR=/home/ubuntu

# Set terminal color
ENV COLORTERM=truecolor

# Install Docker CLI
RUN install -m 0755 -d /etc/apt/keyrings \
    && curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc \
    && chmod a+r /etc/apt/keyrings/docker.asc \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null \
    && apt-get update \
    && apt-get install -y docker-ce-cli docker-compose-plugin

# Install mise-en-place (a single static binary in /usr/local/bin; tool versions
# are installed later, as the ubuntu user, into $MISE_DATA_DIR). The release
# asset name embeds the version, so it has to be pinned rather than "latest";
# bump MISE_VERSION to upgrade.
ARG MISE_VERSION=v2026.8.8
RUN arch="$(dpkg --print-architecture)" \
    && case "$arch" in amd64) arch=x64 ;; esac \
    && curl -fsSL -o /usr/local/bin/mise \
         "https://github.com/jdx/mise/releases/download/${MISE_VERSION}/mise-${MISE_VERSION}-linux-${arch}" \
    && chmod +x /usr/local/bin/mise
ENV MISE_DATA_DIR=/home/ubuntu/.local/share/mise
ENV PATH="${MISE_DATA_DIR}/shims:$PATH"
# Trust any mise config the mounted project ships. mise refuses to load a
# mise.toml carrying [env]/[tasks] from an untrusted path — it errors out rather
# than prompting — which would break every mise command inside /workspace. The
# workspace is the directory the user deliberately mounted, so trust it.
ENV MISE_TRUSTED_CONFIG_PATHS=/workspace

# Install Python build dependencies
RUN apt-get install -y build-essential gdb lcov pkg-config \
      libbz2-dev libffi-dev libgdbm-dev libgdbm-compat-dev liblzma-dev \
      libncurses5-dev libreadline6-dev libsqlite3-dev libssl-dev \
      lzma lzma-dev tk-dev uuid-dev zlib1g-dev libzstd-dev \
      inetutils-inetd

# Re-point the base image's default `ubuntu` user/group at the host's UID/GID so
# everything installed into /home/ubuntu below is owned by the runtime user —
# eliminating the runtime chown. No-op when HOST_UID/GID are already 1000. The
# host UID/GID come from `bin/dev` as build args; since `id -u` is stable per
# machine, the resulting layers stay cached across runs.
ARG HOST_UID=1000
ARG HOST_GID=1000
RUN if [ "$HOST_GID" != "1000" ] && ! getent group "$HOST_GID" >/dev/null 2>&1; then \
      groupmod -g "$HOST_GID" ubuntu; \
    fi \
 && if [ "$HOST_UID" != "1000" ] && [ "$HOST_UID" != "0" ]; then \
      usermod -u "$HOST_UID" -g "$HOST_GID" ubuntu; \
    fi \
 && chown -R "$HOST_UID:$HOST_GID" /home/ubuntu

# Everything below installs into $HOME, so run it as the ubuntu user to bake in
# correct ownership at build time (no runtime chown of the mise tree, etc.).
USER ubuntu

# Install Oh My Zsh
RUN sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended

# Customise Zsh prompt
RUN echo "CAP_LEFT=\$'\\ue0b6'" >> /home/ubuntu/.zshrc \
    && echo "CAP_RIGHT=\$'\\ue0b4'" >> /home/ubuntu/.zshrc \
    && echo 'PROMPT="%F{black}${CAP_LEFT}%K{black}%fdev%k%F{black}${CAP_RIGHT}%f%k $PROMPT"' >> /home/ubuntu/.zshrc

# Install Claude Code
RUN curl -fsSL https://claude.ai/install.sh | bash
ENV PATH="/home/ubuntu/.local/bin:$PATH"

# Install Opencode
RUN curl -fsSL https://opencode.ai/install | bash
ENV PATH="/home/ubuntu/.opencode/bin:$PATH"

# Activate mise in interactive shells. Activation (unlike the shims already on
# PATH above) also exports the tool env — JAVA_HOME and friends — and switches
# versions on every `cd`. The shims stay on PATH for non-interactive shells,
# which never source .zshrc.
RUN echo 'eval "$(mise activate zsh)"' >> /home/ubuntu/.zshrc

# Install the default tool versions. `mise use -g` installs the version and pins
# it in the global config (~/.config/mise/config.toml) in one step, and every
# tool below resolves through mise's built-in registry, so there are no plugins
# to add first.
#
# Terraform needs no step of its own: no global version is pinned here (there
# wasn't one before either), and a project pinning it resolves straight from the
# registry when `mise install` runs at startup.

# Install Python
RUN mise use -g python@3.14.6

# Install Node.js
RUN mise use -g node@26.5.0

# Install Java. mise spells JDKs `<vendor>-<version>` and resolves a partial
# version to the newest matching build, so this pins Temurin 25.0.3 without
# hardcoding its build suffix (`temurin-25.0.3+9.0.LTS` today).
RUN mise use -g java@temurin-25.0.3

# Install pnpm
RUN mise use -g pnpm@11.19.0

# Install gradle
RUN mise use -g gradle@8.14.4

# Install codex. Its runtime (the standalone binaries the ~/.local/bin/codex
# symlink points into) normally lives under ~/.codex/packages, the same dir it
# uses for config.toml/auth.json. Since docker-container/mounts bind-mounts a
# persisted (initially empty) host dir over ~/.codex, that would shadow the
# runtime and dangle the symlink. Relocate the runtime to ~/.codex-runtime via
# CODEX_HOME (set on the `bash` side of the pipe, not `curl`) so ~/.codex holds
# only config/auth — which is exactly what we want to persist. No CODEX_HOME is
# exported into any shell profile, so at runtime codex still reads/writes the
# default ~/.codex.
RUN curl -fsSL https://chatgpt.com/codex/install.sh | CODEX_HOME=/home/ubuntu/.codex-runtime bash

# Back to root so the entrypoint can write sudoers and manage the docker-socket
# group before dropping to the user via gosu.
USER root

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]
CMD ["/usr/bin/zsh"]
