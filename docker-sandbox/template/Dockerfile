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

# Install asdf (mkdir since the codex base image lacks ~/.local/bin)
USER agent
RUN mkdir -p /home/agent/.local/bin && \
    curl -L https://github.com/asdf-vm/asdf/releases/download/v0.20.0/asdf-v0.20.0-linux-amd64.tar.gz | tar -xz -C /home/agent/.local/bin
RUN echo 'export ASDF_DATA_DIR=/home/agent/.asdf' >> /home/agent/.zshenv
RUN echo 'export PATH="/home/agent/.asdf/shims:$PATH"' >> /home/agent/.zshenv
RUN echo 'export ASDF_DATA_DIR=/home/agent/.asdf' >> /home/agent/.bash_profile
RUN echo 'export PATH="/home/agent/.asdf/shims:$PATH"' >> /home/agent/.bash_profile
ENV BASH_ENV=/home/agent/.bash_profile

# Install terraform
RUN asdf plugin add terraform https://github.com/asdf-community/asdf-hashicorp.git
RUN asdf install terraform 1.15.8
RUN asdf set -u terraform 1.15.8

# Install Node.js
RUN asdf plugin add nodejs https://github.com/asdf-vm/asdf-nodejs.git
RUN asdf install nodejs 26.5.0
RUN asdf set -u nodejs 26.5.0

# Install Java
RUN asdf plugin add java
RUN asdf install java temurin-25.0.3+9.0.LTS
RUN asdf set -u java temurin-25.0.3+9.0.LTS

# Install Python
USER root
RUN apt-get install -y build-essential gdb lcov pkg-config \
      libbz2-dev libffi-dev libgdbm-dev libgdbm-compat-dev liblzma-dev \
      libncurses5-dev libreadline6-dev libsqlite3-dev libssl-dev \
      lzma tk-dev uuid-dev zlib1g-dev libzstd-dev \
      inetutils-inetd
USER agent
RUN asdf plugin add python
RUN asdf install python 3.14.6
RUN asdf set -u python 3.14.6

# Enable fullscreen mode for claude code by default
ENV CLAUDE_CODE_NO_FLICKER=1

# Change user back to agent
USER agent
