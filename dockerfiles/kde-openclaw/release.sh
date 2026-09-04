#!/bin/bash

# 發布 kde-openclaw 映像:同時建 linux/amd64 與 linux/arm64 並推上 registry。
#
# 前置需求:buildx builder 要支援多平台(docker-container driver),在 amd64 主機上建 arm64
# 還需要 QEMU:docker run --privileged --rm tonistiigi/binfmt --install all
#
# OPENCLAW_VERSION 是官方 OpenClaw 映像的 tag,升級 OpenClaw 只需要改這個值。

KDE_CLI_VERSION=$(git rev-parse --short HEAD)
# 刻意釘住版本而非用浮動的 latest：base image 一升級就可能動到我們寫死的假設
# （tini 路徑、使用者名稱 node/uid 1000、apt 可用性、home 內容），升級應該是一次
# 有意識的 commit，而不是任何一次 rebuild 的副作用。
OPENCLAW_VERSION=${OPENCLAW_VERSION:-2026.9.1}
PLATFORMS=linux/amd64,linux/arm64

echo "Release r82wei/kde-openclaw:${KDE_CLI_VERSION}-${OPENCLAW_VERSION} (${PLATFORMS}) ..."

# build context 必須是 repo 根目錄:Dockerfile 會 COPY . /tmp/kde-src/ 再跑 local-install.sh
docker buildx build --no-cache --platform ${PLATFORMS} --push \
    -f Dockerfile \
    --build-arg OPENCLAW_VERSION=${OPENCLAW_VERSION} \
    -t r82wei/kde-openclaw:${KDE_CLI_VERSION}-${OPENCLAW_VERSION} \
    ../..

docker buildx build --platform ${PLATFORMS} --push \
    -f Dockerfile \
    --build-arg OPENCLAW_VERSION=${OPENCLAW_VERSION} \
    -t r82wei/kde-openclaw:latest \
    ../..
