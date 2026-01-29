#!/bin/bash

K9S_VERSION=v0.50.18
DATE=$(date +%Y%m%d%H%M%S)

if [ -d "k9s" ]; then
    rm -rf k9s
fi

git clone -b ${K9S_VERSION} https://github.com/derailed/k9s.git
cd k9s
docker buildx build --no-cache --platform linux/amd64,linux/arm64 --push -t r82wei/k9s:${K9S_VERSION}-${DATE} .