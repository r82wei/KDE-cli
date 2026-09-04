#!/bin/bash

# 發布 webtop-openclaw 映像:同時建 linux/amd64 與 linux/arm64 並推上 registry。
#
# 可以跨架構的原因:base image lscr.io/linuxserver/webtop 的 ubuntu-kde 系列 tag 本身就是
# amd64 + arm64v8 的 multi-arch manifest,openclaw 的 install.sh 會自己偵測 x86_64/aarch64,
# kde-cli 則是純 Bash(local-install.sh 只做複製),三者都與架構無關。
#
# 前置需求:buildx builder 要支援多平台(docker-container driver),在 amd64 主機上建 arm64
# 還需要 QEMU:docker run --privileged --rm tonistiigi/binfmt --install all

KDE_CLI_VERSION=$(git rev-parse --short HEAD)
WEBTOP_VERSION=ubuntu-kde
OPENCLAW_VERSION=v2026.8.1
PLATFORMS=linux/amd64,linux/arm64

echo "Release r82wei/webtop-openclaw:${WEBTOP_VERSION}-${OPENCLAW_VERSION} (${PLATFORMS}) ..."

# build context 必須是 repo 根目錄:Dockerfile 會 COPY . /tmp/kde-src/ 再跑 local-install.sh
docker buildx build --no-cache --platform ${PLATFORMS} --push \
    -f Dockerfile \
    --build-arg WEBTOP_VERSION=${WEBTOP_VERSION} \
    --build-arg OPENCLAW_VERSION=${OPENCLAW_VERSION} \
    -t r82wei/webtop-openclaw:${WEBTOP_VERSION}-${OPENCLAW_VERSION} \
    ../..

docker buildx build --platform ${PLATFORMS} --push \
    -f Dockerfile \
    --build-arg WEBTOP_VERSION=${WEBTOP_VERSION} \
    --build-arg OPENCLAW_VERSION=${OPENCLAW_VERSION} \
    -t r82wei/webtop-openclaw:latest \
    ../..
docker push r82wei/webtop-openclaw:latest
