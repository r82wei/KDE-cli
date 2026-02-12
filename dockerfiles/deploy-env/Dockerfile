FROM ubuntu:22.04

ARG KUBECTL_VERSION=v1.32.0
ARG TARGETARCH

RUN apt-get update
RUN apt-get install ca-certificates curl gnupg lsb-release gridsite-clients gcc g++ make unzip jq gettext -y

# Install Helm
RUN curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3
RUN chmod 700 get_helm.sh
RUN ./get_helm.sh

# Install aws cli
RUN set -eux; \
  if [ "${TARGETARCH}" = "amd64" ]; then \
    curl -Lo awscliv2.zip "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip"; \
  elif [ "${TARGETARCH}" = "arm64" ]; then \
    curl -Lo awscliv2.zip "https://awscli.amazonaws.com/awscli-exe-linux-aarch64.zip"; \
  else \
    echo "Unsupported architecture: ${TARGETARCH}"; \
    exit 1; \
  fi; \
  unzip awscliv2.zip; \
  ./aws/install; \
  rm -rf aws awscliv2.zip

# Install az 
RUN curl -sL https://aka.ms/InstallAzureCLIDeb | bash

# Install docker engine
RUN mkdir -p /etc/apt/keyrings
RUN curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
RUN echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
RUN apt-get update
RUN apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

# Install kubectlf
RUN set -eux; \
    curl -LO https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/${TARGETARCH}/kubectl;\
    chmod +x kubectl; \
    mv ./kubectl /usr/local/bin/kubectl