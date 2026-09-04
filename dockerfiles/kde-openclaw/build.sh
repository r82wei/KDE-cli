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

IMAGE="r82wei/kde-openclaw:${KDE_CLI_VERSION}-${OPENCLAW_VERSION}"

echo "Build ${IMAGE} ..."

# 刻意「不」打 latest tag。latest 的語意是「registry 上最新發布的版本」，而本機
# build 的產物只是一次性的測試映像。讓它冒用 latest 會污染之後所有
# kde openclaw run/restart 的映像來源：docker run 的預設 pull policy 是 missing,
# 本地有 latest 就直接用、永遠不回頭問 registry,於是本機跑一次 build.sh 就會讓
# 這台機器永久停在該映像上。症狀是「明明 release 了新版,容器卻一直是舊的」,
# 而且完全沒有徵兆——實際踩過。要用剛建好的映像請明確指定 OPENCLAW_IMAGE,
# 見下方提示；要換到已發布的版本用 kde openclaw upgrade。
if ! docker buildx build --load --no-cache \
    --platform linux/${TARGET_ARCH} \
    -f Dockerfile \
    --build-arg OPENCLAW_VERSION=${OPENCLAW_VERSION} \
    -t "${IMAGE}" \
    ../..; then
    echo "❌ 建置失敗"
    exit 1
fi

echo ""
echo "✓ 已建置 ${IMAGE}"
echo "  以此映像啟動：OPENCLAW_IMAGE=${IMAGE} kde openclaw run"
