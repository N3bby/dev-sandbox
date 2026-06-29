FROM ubuntu:24.04

RUN apt-get update && apt-get install -y curl git vim gosu sudo unzip

# Install UTF-8 locales
RUN apt-get install -y locales && locale-gen en_US.UTF-8
ENV LANG=en_US.UTF-8
ENV LC_ALL=en_US.UTF-8

# Use /home/ubuntu as the actual home directory for all tool installations
RUN mkdir -p /home/ubuntu
ENV HOME=/home/ubuntu

# Install Zsh and Oh My Zsh
RUN apt-get install -y zsh
RUN sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
ENV SHELL=/usr/bin/zsh
ENV ZDOTDIR=/home/ubuntu

# Customise Zsh prompt
RUN echo "CAP_LEFT=\$'\\ue0b6'" >> /home/ubuntu/.zshrc \
    && echo "CAP_RIGHT=\$'\\ue0b4'" >> /home/ubuntu/.zshrc \
    && echo 'PROMPT="%F{black}${CAP_LEFT}%K{black}%fdev%k%F{black}${CAP_RIGHT}%f%k $PROMPT"' >> /home/ubuntu/.zshrc

# Install Docker CLI
RUN install -m 0755 -d /etc/apt/keyrings \
    && curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc \
    && chmod a+r /etc/apt/keyrings/docker.asc \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null \
    && apt-get update \
    && apt-get install -y docker-ce-cli docker-compose-plugin

# Install Claude Code
RUN curl -fsSL https://claude.ai/install.sh | bash
ENV PATH="/home/ubuntu/.local/bin:$PATH"

# Install asdf
RUN git clone https://github.com/asdf-vm/asdf.git /opt/asdf --branch v0.16.7
ENV PATH="/opt/asdf/bin:/opt/asdf/shims:$PATH"
RUN echo '. /opt/asdf/asdf.sh' >> /home/ubuntu/.zshrc

# Install Terraform
RUN asdf plugin add terraform https://github.com/asdf-community/asdf-hashicorp.git

# Install Java
# RUN asdf plugin add java
# RUN asdf install java temurin-25.0.3+9.0.LTS

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]
CMD ["/usr/bin/zsh"]

