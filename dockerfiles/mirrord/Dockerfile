FROM ubuntu:24.04

ARG KUBECTL_VERSION=v1.33.0
ARG KDE_MIRRORD_VERSION=main
ARG TARGETARCH

# 安裝基本工具
RUN apt-get update && apt-get install -y \
    curl \
    gnupg \
    lsb-release \
    sudo \
    iptables \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# 安裝 Docker CLI
RUN install -m 0755 -d /etc/apt/keyrings && \
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc && \
    chmod a+r /etc/apt/keyrings/docker.asc && \
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
    $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null && \
    apt-get update && \
    apt-get install -y docker-ce-cli && \
    rm -rf /var/lib/apt/lists/*

# 安裝 kubectl
RUN set -eux; \
    curl -LO https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/${TARGETARCH}/kubectl;\
    chmod +x kubectl; \
    mv ./kubectl /usr/local/bin/kubectl

# 安裝 mirrord
RUN curl -fsSL https://raw.githubusercontent.com/metalbear-co/mirrord/${KDE_MIRRORD_VERSION}/scripts/install.sh | bash

# 複製 entrypoint 腳本
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

ENTRYPOINT ["entrypoint.sh"]
