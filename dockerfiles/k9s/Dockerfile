# 第一階段：下載階段
FROM alpine:latest AS downloader

# 定義變數，並設置預設值 (若不傳參則預設使用 v0.50.18)
ARG K9S_VERSION=v0.50.18

# 安裝必要的下載工具
RUN apk add --no-cache curl tar

# 自動偵測架構並根據變數下載指定版本
RUN ARCH=$(uname -m) && \
    if [ "$ARCH" = "x86_64" ]; then K9S_ARCH="amd64"; else K9S_ARCH="arm64"; fi && \
    curl -LO "https://github.com/derailed/k9s/releases/download/${K9S_VERSION}/k9s_Linux_${K9S_ARCH}.tar.gz" && \
    tar -xvf k9s_Linux_${K9S_ARCH}.tar.gz

# 第二階段：最終鏡像
FROM alpine:latest

# 從第一階段複製執行檔
COPY --from=downloader /k9s /usr/local/bin/k9s

# 為了確保在某些 Alpine 環境能正確執行，建議加上相容庫
RUN apk add --no-cache libc6-compat

ENTRYPOINT ["k9s"]