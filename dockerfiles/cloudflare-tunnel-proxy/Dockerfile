### 下載 kubectl 二進位檔 ###
FROM curlimages/curl:8.4.0 AS downloader

ARG KUBECTL_VERSION=$(curl -L -s https://dl.k8s.io/release/stable.txt)
ARG TARGETARCH

# 下載並賦予執行權限
RUN curl -SL https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/${TARGETARCH}/kubectl \
    -o /tmp/kubectl && chmod +x /tmp/kubectl


### 下載 shellbin ###
FROM busybox:1.35.0 AS shellbin


FROM cloudflare/cloudflared:latest

# 複製 kubectl 二進位檔到 /usr/local/bin，並設定權限
COPY --from=downloader /tmp/kubectl /usr/local/bin/kubectl

# 複製 shellbin 到 /bin/sh
COPY --from=shellbin /bin/sh /bin/sh

# 設定 entrypoint 為 kubectl
ENTRYPOINT ["/bin/sh", "-c"]