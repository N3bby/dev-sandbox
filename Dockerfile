FROM ubuntu:24.04

RUN apt-get update && apt-get install -y curl git vim gosu sudo

# Install UTF-8 locales
RUN apt-get install -y locales && locale-gen en_US.UTF-8
ENV LANG=en_US.UTF-8
ENV LC_ALL=en_US.UTF-8

# Install Zsh and Oh My Zsh
RUN apt-get install -y zsh
RUN sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
RUN chsh -s /usr/bin/zsh
ENV SHELL=/usr/bin/zsh
ENV ZDOTDIR=/root

# Customise Zsh prompt
RUN echo "CAP_LEFT=\$'\\ue0b6'" >> /root/.zshrc \
    && echo "CAP_RIGHT=\$'\\ue0b4'" >> /root/.zshrc \
    && echo 'PROMPT="%F{black}${CAP_LEFT}%K{black}%fdev%k%F{black}${CAP_RIGHT}%f%k $PROMPT"' >> /root/.zshrc

# Install Docker CLI
RUN install -m 0755 -d /etc/apt/keyrings \
    && curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc \
    && chmod a+r /etc/apt/keyrings/docker.asc \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null \
    && apt-get update \
    && apt-get install -y docker-ce-cli docker-compose-plugin

# Install Claude Code
RUN curl -fsSL https://claude.ai/install.sh | bash
ENV PATH="/root/.local/bin:$PATH"

# Install asdf
RUN git clone https://github.com/asdf-vm/asdf.git /opt/asdf --branch v0.16.7
ENV PATH="/opt/asdf/bin:/opt/asdf/shims:$PATH"
RUN echo '. /opt/asdf/asdf.sh' >> /root/.zshrc

# Install Java
RUN asdf plugin add java
RUN asdf install java temurin-25.0.3+9.0.LTS

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]
CMD ["/usr/bin/zsh"]

