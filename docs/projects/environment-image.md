## 自訂 Docker Image

### 為不同階段自訂 Image

每個 CI/CD 階段都可以使用不同的 Docker Image：

```bash
# 基本環境
DEVELOP_IMAGE=node:20
DEPLOY_IMAGE=r82wei/deploy-env:1.0.0

# 自訂每個階段的 Image
PRE_BUILD_IMAGE=node:20-alpine        # 輕量版用於安裝相依套件
BUILD_IMAGE=node:20                   # 完整版用於建置
POST_BUILD_IMAGE=amazon/aws-cli       # AWS CLI 用於上傳產物

PRE_DEPLOY_IMAGE=r82wei/deploy-env:1.0.0  # 建立 K8s 資源
POST_DEPLOY_IMAGE=curlimages/curl         # 健康檢查

UNDEPLOY_IMAGE=r82wei/deploy-env:1.0.0    # 清理資源
```

### 自訂開發環境 Image

建立包含常用工具的開發環境：

**Dockerfile 範例：**

```dockerfile
FROM node:20

# 安裝開發工具
RUN apt-get update && apt-get install -y \
    git \
    vim \
    curl \
    wget \
    jq \
    && rm -rf /var/lib/apt/lists/*

# 安裝全域 npm 套件
RUN npm install -g \
    typescript \
    ts-node \
    nodemon \
    prettier \
    eslint

# 設定工作目錄
WORKDIR /workspace

CMD ["/bin/bash"]
```

**使用自訂 Image：**

```bash
# project.env
DEVELOP_IMAGE=myregistry/nodejs-dev:latest
```

### 自訂部署環境 Image

建立包含部署工具的環境：

**Dockerfile 範例：**

```dockerfile
FROM alpine:3.18

# 安裝 kubectl
RUN apk add --no-cache curl && \
    curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl" && \
    install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl

# 安裝 helm
RUN curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# 安裝其他工具
RUN apk add --no-cache \
    git \
    bash \
    jq \
    yq

WORKDIR /workspace

CMD ["/bin/bash"]
```
