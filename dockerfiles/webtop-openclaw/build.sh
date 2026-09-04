#!/bin/bash

# 本機建置 webtop-openclaw 映像,只建目前主機架構並 --load 進本機 docker。
# 多架構(amd64 + arm64)由 release.sh 負責。

KDE_CLI_VERSION=$(git rev-parse --short HEAD)
TARGET_ARCH=$(arch | sed s/aarch64/arm64/ | sed s/x86_64/amd64/)
WEBTOP_VERSION=${TARGET_ARCH}-ubuntu-kde
OPENCLAW_VERSION=v2026.8.1

echo "Build r82wei/webtop-openclaw:${WEBTOP_VERSION}-${KDE_CLI_VERSION}-${OPENCLAW_VERSION} (${TARGET_ARCH}) ..."
echo "  base image: lscr.io/linuxserver/webtop:${WEBTOP_VERSION} (linux/${TARGET_ARCH})"

docker buildx build --load --no-cache \
    --platform linux/${TARGET_ARCH} \
    -f Dockerfile \
    --build-arg WEBTOP_VERSION=${WEBTOP_VERSION} \
    --build-arg OPENCLAW_VERSION=${OPENCLAW_VERSION} \
    -t r82wei/webtop-openclaw:${WEBTOP_VERSION}-${KDE_CLI_VERSION}-${OPENCLAW_VERSION} \
    ../..
