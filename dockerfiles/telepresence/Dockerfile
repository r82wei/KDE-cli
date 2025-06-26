FROM ubuntu:22.04

ARG KUBECTL_VERSION=v1.32.0
ARG TARGETARCH

RUN apt-get update && apt-get install -y \
    curl \
    gnupg \
    lsb-release \
    sudo \
    iptables \
    # FUSE 是 Telepresence 攔截 volume mounts 所需
    fuse3 && \
    rm -rf /var/lib/apt/lists/*

# Install kubectl
RUN set -eux; \
    curl -LO https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/${TARGETARCH}/kubectl;\
    chmod +x kubectl; \
    mv ./kubectl /usr/local/bin/kubectl

# Install telepresence
RUN curl -fL https://github.com/telepresenceio/telepresence/releases/latest/download/telepresence-linux-${TARGETARCH} -o /usr/local/bin/telepresence && chmod a+x /usr/local/bin/telepresence

# 將 entrypoint 腳本複製到容器中
COPY entrypoint.sh /usr/local/bin/entrypoint.sh

# 賦予它可執行權限
RUN chmod +x /usr/local/bin/entrypoint.sh

# 設定 entrypoint
ENTRYPOINT ["entrypoint.sh"]