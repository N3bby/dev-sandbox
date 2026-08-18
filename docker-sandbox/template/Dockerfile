# Base image set per agent variant by bin/dev; defaults to claude-code.
ARG BASE_IMAGE=docker/sandbox-templates:claude-code-docker
FROM ${BASE_IMAGE}

# Update whichever agent CLI the base image ships (before the purge removes npm).
RUN if command -v codex  >/dev/null 2>&1; then npm install -g @openai/codex@latest; fi
RUN if command -v claude >/dev/null 2>&1; then claude update; fi

USER root

# Remove pre-installed runtimes from image
RUN apt-get purge -y python3 python3-pip openjdk-* nodejs npm

# Load apt-get lists
RUN apt-get update

# Install Zsh (Oh My Zsh is installed later, as the ubuntu user, into $HOME)
RUN apt-get install -y zsh
ENV SHELL=/usr/bin/zsh
ENV ZDOTDIR=/home/agent

# Install Oh My Zsh
USER agent
RUN sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
RUN echo 'PROMPT="[sandbox] $PROMPT"' >> /home/agent/.zshrc

# Install mise-en-place — a single static binary (mkdir since the codex base
# image lacks ~/.local/bin). The release asset name embeds the version, so it
# has to be pinned rather than "latest"; bump MISE_VERSION to upgrade.
USER agent
ARG MISE_VERSION=v2026.8.8
RUN mkdir -p /home/agent/.local/bin && \
    arch="$(uname -m)" && \
    case "$arch" in x86_64) arch=x64 ;; aarch64) arch=arm64 ;; esac && \
    curl -fsSL -o /home/agent/.local/bin/mise \
      "https://github.com/jdx/mise/releases/download/${MISE_VERSION}/mise-${MISE_VERSION}-linux-${arch}" && \
    chmod +x /home/agent/.local/bin/mise
# Put mise and its shims on PATH for every process in the sandbox, including the
# non-interactive `bash -c` invocations agents shell out through.
ENV MISE_DATA_DIR=/home/agent/.local/share/mise
ENV PATH="/home/agent/.local/bin:${MISE_DATA_DIR}/shims:$PATH"
# Belt and braces for login shells, which is where the agent CLIs land.
RUN echo 'export PATH="/home/agent/.local/bin:/home/agent/.local/share/mise/shims:$PATH"' >> /home/agent/.zshenv
RUN echo 'export PATH="/home/agent/.local/bin:/home/agent/.local/share/mise/shims:$PATH"' >> /home/agent/.bash_profile
ENV BASH_ENV=/home/agent/.bash_profile
# Activation on top of the shims: it also exports the tool env (JAVA_HOME and
# friends) and re-resolves versions on every `cd`, which shims alone don't do.
RUN echo 'eval "$(mise activate zsh)"' >> /home/agent/.zshrc
# Trust any mise config the mounted workspace ships. mise refuses to load a
# mise.toml carrying [env]/[tasks] from an untrusted path — it errors out rather
# than prompting — which would break every mise command in the workspace. sbx
# picks the in-sandbox workspace path, so scope this to the whole (disposable,
# YOLO-by-design) sandbox filesystem rather than guessing that path.
ENV MISE_TRUSTED_CONFIG_PATHS=/

# Install the default tool versions. `mise use -g` installs the version and pins
# it in the global config (~/.config/mise/config.toml) in one step, and every
# tool below resolves through mise's built-in registry, so there are no plugins
# to add first.

# Install terraform
RUN mise use -g terraform@1.15.8

# Install Node.js
RUN mise use -g node@26.5.0

# Install Java. mise spells JDKs `<vendor>-<version>` and resolves a partial
# version to the newest matching build, so this pins Temurin 25.0.3 without
# hardcoding its build suffix (`temurin-25.0.3+9.0.LTS` today).
RUN mise use -g java@temurin-25.0.3

# Install Python
USER root
RUN apt-get install -y build-essential gdb lcov pkg-config \
      libbz2-dev libffi-dev libgdbm-dev libgdbm-compat-dev liblzma-dev \
      libncurses5-dev libreadline6-dev libsqlite3-dev libssl-dev \
      lzma tk-dev uuid-dev zlib1g-dev libzstd-dev \
      inetutils-inetd
USER agent
RUN mise use -g python@3.14.6
# yq ships the `tomlq` the codex-config kit uses. Installing it into the
# mise-managed python needs a reshim so its entry points get shims of their own.
RUN python -m pip install --no-cache-dir yq && \
    mise reshim

# Enable fullscreen mode for claude code by default
ENV CLAUDE_CODE_NO_FLICKER=1

# Change user back to agent
USER agent
