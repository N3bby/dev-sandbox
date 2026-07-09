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

# Install asdf (the binary goes in /usr/local/bin; plugins and tool versions are
# installed later, as the ubuntu user, into $HOME/.asdf)
RUN curl -L https://github.com/asdf-vm/asdf/releases/download/v0.19.0/asdf-v0.19.0-linux-amd64.tar.gz | tar -xz -C /usr/local/bin
ENV ASDF_DATA_DIR=/home/ubuntu/.asdf
ENV PATH="${ASDF_DATA_DIR}/shims:$PATH"

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
RUN if [ "$HOST_GID" != "1000" ]; then groupmod -g "$HOST_GID" ubuntu; fi \
 && if [ "$HOST_UID" != "1000" ] && [ "$HOST_UID" != "0" ]; then usermod -u "$HOST_UID" -g "$HOST_GID" ubuntu; fi \
 && chown -R "$HOST_UID:$HOST_GID" /home/ubuntu

# Everything below installs into $HOME, so run it as the ubuntu user to bake in
# correct ownership at build time (no runtime chown of the asdf tree, etc.).
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

# Make asdf shims available in interactive shells
RUN echo 'export PATH="${ASDF_DATA_DIR:-$HOME/.asdf}/shims:$PATH"' >> /home/ubuntu/.zshrc

# Install Terraform
RUN asdf plugin add terraform https://github.com/asdf-community/asdf-hashicorp.git

# Install Python
RUN asdf plugin add python
RUN asdf install python 3.14.6
RUN asdf set -u python 3.14.6

# Install Node.js
RUN asdf plugin add nodejs https://github.com/asdf-vm/asdf-nodejs.git
RUN asdf install nodejs 26.5.0
RUN asdf set -u nodejs 26.5.0

# Install Java
# RUN asdf plugin add java
# RUN asdf install java temurin-25.0.3+9.0.LTS

# Back to root so the entrypoint can write sudoers and manage the docker-socket
# group before dropping to the user via gosu.
USER root

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]
CMD ["/usr/bin/zsh"]
