#!/bin/bash

TOOLS_VERSION=1.0.0
DATE=$(date +%Y%m%d%H%M%S)
TARGET_ARCH=$(arch | sed s/aarch64/arm64/ | sed s/x86_64/amd64/)

echo "Build tools image ..."
docker buildx build --load -f Dockerfile -t r82wei/kde-cli/tools:${TOOLS_VERSION}-${TARGET_ARCH}-${DATE} .
