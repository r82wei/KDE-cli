FROM ubuntu:22.04

ARG KDE_CLI_VERSION=main
ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y \
    sudo ca-certificates curl wget gnupg lsb-release gosu git bash \
    fzf \
    && rm -rf /var/lib/apt/lists/*

# Install gum
RUN set -eux; \
    ARCH=$(dpkg --print-architecture); \
    case "$ARCH" in \
      amd64) GUM_ARCH="amd64" ;; \
      arm64) GUM_ARCH="arm64" ;; \
      *) echo "unsupported arch: $ARCH"; exit 1 ;; \
    esac; \
    GUM_VERSION="0.14.5"; \
    wget -qO /tmp/gum.deb "https://github.com/charmbracelet/gum/releases/download/v${GUM_VERSION}/gum_${GUM_VERSION}_${GUM_ARCH}.deb"; \
    dpkg -i /tmp/gum.deb; \
    rm -f /tmp/gum.deb

# Docker CLI inside container
RUN mkdir -p /etc/apt/keyrings && \
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg && \
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" > /etc/apt/sources.list.d/docker.list && \
    apt-get update && apt-get install -y docker-ce-cli && \
    rm -rf /var/lib/apt/lists/*

# Install kde-cli
RUN set -eux; \
    git clone -b ${KDE_CLI_VERSION} https://github.com/r82wei/KDE-cli.git /tmp/KDE-cli; \
    cd /tmp/KDE-cli; \
    ./install.sh; \
    rm -rf /tmp/KDE-cli

RUN echo '%sudo ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers

COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

WORKDIR /home/user
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["bash", "-lc", "kde tui2"]
