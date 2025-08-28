FROM codercom/code-server:latest

USER root

ARG KDE_CLI_VERSION

RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    gnupg \
    git \
    gettext-base \
    && rm -rf /var/lib/apt/lists/*

# Add the Docker repository to Apt sources (Debian base image)
RUN install -m 0755 -d /etc/apt/keyrings
RUN curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
RUN chmod a+r /etc/apt/keyrings/docker.gpg
RUN echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian $(. /etc/os-release && echo \"$VERSION_CODENAME\") stable" > /etc/apt/sources.list.d/docker.list
RUN apt-get update && apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin && rm -rf /var/lib/apt/lists/*

# Install kde-cli
RUN set -eux; \
    git clone -b ${KDE_CLI_VERSION} https://github.com/r82wei/KDE-cli.git; \
    cd KDE-cli; \
    ./install.sh; \
    cd ..; \
    rm -rf KDE-cli

USER coder