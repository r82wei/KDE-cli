#!/bin/bash

# 本機建置 kde-openclaw 映像,只建目前主機架構並 --load 進本機 docker。
# 多架構(amd64 + arm64)由 release.sh 負責。
#
# OPENCLAW_VERSION 是官方 OpenClaw 映像的 tag(latest / slim / 2026.2.26 等),
# 升級 OpenClaw 只需要改這個值。

KDE_CLI_VERSION=$(git rev-parse --short HEAD)
TARGET_ARCH=$(arch | sed s/aarch64/arm64/ | sed s/x86_64/amd64/)
# 刻意釘住版本而非用浮動的 latest：base image 一升級就可能動到我們寫死的假設
# （tini 路徑、使用者名稱 node/uid 1000、apt 可用性、home 內容），升級應該是一次
# 有意識的 commit，而不是任何一次 rebuild 的副作用。
OPENCLAW_VERSION=${OPENCLAW_VERSION:-2026.9.1}

echo "Build r82wei/kde-openclaw:${KDE_CLI_VERSION}-${OPENCLAW_VERSION} ..."

docker buildx build --load --no-cache \
    --platform linux/${TARGET_ARCH} \
    -f Dockerfile \
    --build-arg OPENCLAW_VERSION=${OPENCLAW_VERSION} \
    -t r82wei/kde-openclaw:${KDE_CLI_VERSION}-${OPENCLAW_VERSION} \
    -t r82wei/kde-openclaw:latest \
    ../..
