#!/bin/bash

K9S_VERSION=v0.50.18
DATE=$(date +%Y%m%d%H%M%S)
TARGET_ARCH=$(arch | sed s/aarch64/arm64/ | sed s/x86_64/amd64/)

if [ -d "k9s" ]; then
    rm -rf k9s
fi

git clone -b ${K9S_VERSION} https://github.com/derailed/k9s.git
cd k9s
docker buildx build --load -t r82wei/k9s:${K9S_VERSION}-${TARGET_ARCH}-${DATE} .