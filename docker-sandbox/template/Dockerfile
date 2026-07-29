# Template image for Docker Sandboxes (sbx), built on Docker's official
# claude-code base template.
#
# docker/sandbox-templates:claude-code already satisfies the whole template
# contract, so none of the old from-ubuntu boilerplate is needed here:
#   - Ubuntu, a non-root `agent` user at UID 1000 with sudo  (no usermod rename)
#   - the HTTP(S)_PROXY env vars sbx injects at runtime       (nothing to set)
#   - git, the Docker CLI, and the Claude Code agent binary   (preinstalled)
#   - a working private Docker daemon (dockerd) started at boot
#   - Node.js, Python, Go, Java                               (preinstalled)
# We use the FULL claude-code variant (not `-minimal`) specifically because the
# minimal variant ships NO Docker daemon and NO language runtimes. Since the
# base already provides Node/Python, we do NOT reinstall them via asdf — asdf is
# kept only for terraform (and on-demand project tool versions).
#
# Base variants: claude-code, claude-code-minimal, codex, copilot, cursor-agent,
# docker-agent, droid, gemini, kiro, opencode, shell. See
# https://docs.docker.com/ai/sandboxes/customize/templates/
#
# Build + load locally (see docker-sandbox/README.md):
#   dev --build     # docker build + docker save + sbx template load
# or push to a registry and point the kit's sandbox.image at that ref.

FROM docker/sandbox-templates:claude-code-minimal

# ---- root-level packages ----
USER root

# Zsh, plus common build deps for native extensions / on-demand `asdf install
# python <ver>` when a project pins one.
# NOTE: we deliberately KEEP apt's package index (no `rm -rf .../apt/lists`) so
# that inside the running sandbox `sudo apt install <pkg>` works immediately,
# without first running `sudo apt update`. Costs ~tens of MB of image size.
RUN apt-get update && apt-get install -y \
      zsh \
      build-essential gdb lcov pkg-config \
      libbz2-dev libffi-dev libgdbm-dev libgdbm-compat-dev liblzma-dev \
      libncurses5-dev libreadline6-dev libsqlite3-dev libssl-dev \
      tk-dev uuid-dev zlib1g-dev libzstd-dev

ENV SHELL=/usr/bin/zsh
ENV ZDOTDIR=/home/agent
ENV COLORTERM=truecolor

# The -minimal base sets no UTF-8 locale, so zsh can't encode the powerline
# glyphs in the prompt ($'' etc.) -> "character not in range". C.UTF-8 is
# built into Ubuntu (no locales package / locale-gen needed) and fixes it.
ENV LANG=C.UTF-8
ENV LC_ALL=C.UTF-8

# asdf binary (plugins + tool versions are installed below as the agent user
# into $HOME/.asdf). Shims go on PATH ahead of the base image's system tools.
RUN curl -L https://github.com/asdf-vm/asdf/releases/download/v0.19.0/asdf-v0.19.0-linux-amd64.tar.gz | tar -xz -C /usr/local/bin
ENV ASDF_DATA_DIR=/home/agent/.asdf
ENV PATH="${ASDF_DATA_DIR}/shims:$PATH"

# ---- everything below installs into $HOME as the agent user ----
USER agent

# Oh My Zsh + our prompt, and make the asdf shims visible in interactive shells.
RUN sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
RUN echo "CAP_LEFT=\$'\\ue0b6'" >> /home/agent/.zshrc \
    && echo "CAP_RIGHT=\$'\\ue0b4'" >> /home/agent/.zshrc \
    && echo 'PROMPT="%F{black}${CAP_LEFT}%K{black}%fdev%k%F{black}${CAP_RIGHT}%f%k $PROMPT"' >> /home/agent/.zshrc \
    && echo 'export PATH="${ASDF_DATA_DIR:-$HOME/.asdf}/shims:$PATH"' >> /home/agent/.zshrc

# asdf-managed toolchain. Terraform needs asdf; the pinned python/node below
# shadow the base image's system versions to match the old setup — drop these
# two blocks if the base's Node/Python are good enough for you.
RUN asdf plugin add terraform https://github.com/asdf-community/asdf-hashicorp.git

RUN asdf plugin add python \
    && asdf install python 3.14.6 \
    && asdf set -u python 3.14.6

RUN asdf plugin add nodejs https://github.com/asdf-vm/asdf-nodejs.git \
    && asdf install nodejs 26.5.0 \
    && asdf set -u nodejs 26.5.0

# Install Java
# RUN asdf plugin add java
# RUN asdf install java temurin-25.0.3+9.0.LTS

# The kit's sandbox.entrypoint launches the agent; a shell is the fallback for
# `sbx exec`.
CMD ["/usr/bin/zsh"]
