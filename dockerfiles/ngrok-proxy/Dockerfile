FROM alpine:latest

ARG KUBECTL_VERSION=v1.32.0
ARG TARGETARCH

# install curl
RUN apk add --no-cache curl

# Install kubectlf
RUN set -eux; \
    curl -LO https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/${TARGETARCH}/kubectl;\
    chmod +x kubectl; \
    mv ./kubectl /usr/local/bin/kubectl

# Install ngrok
RUN set -eux; \
    curl -LO https://bin.equinox.io/c/bNyj1mQVY4c/ngrok-v3-stable-linux-${TARGETARCH}.tgz; \
    tar -xvzf ngrok-v3-stable-linux-${TARGETARCH}.tgz -C /usr/local/bin; \
    rm ngrok-v3-stable-linux-${TARGETARCH}.tgz