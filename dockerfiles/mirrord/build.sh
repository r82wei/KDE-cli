#!/bin/bash
set -e

KDE_MIRRORD_VERSION=main
KUBECTL_VERSION=v1.33.0

echo "開始建置 Mirrord Docker 映像..."
docker buildx build --platform linux/amd64,linux/arm64 \
    --build-arg KDE_MIRRORD_VERSION=${KDE_MIRRORD_VERSION:-latest} \
    --build-arg KUBECTL_VERSION=${KUBECTL_VERSION:-v1.33.0} \
    --load \
    -t r82wei/kde-mirrord:${KDE_MIRRORD_VERSION:-latest} \
    .

echo "✅ Mirrord Docker 映像建置完成！"
