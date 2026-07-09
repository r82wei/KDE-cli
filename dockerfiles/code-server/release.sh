#!/bin/bash

# 取得目前 git tag 版本
KDE_CLI_VERSION=$(git describe --tags)

echo "Release kde-code-server ${KDE_CLI_VERSION} image ..."
docker buildx build --no-cache --platform linux/amd64,linux/arm64 --push -f Dockerfile -t r82wei/kde-code-server:${KDE_CLI_VERSION} ../..
docker buildx build --platform linux/amd64,linux/arm64 --push -f Dockerfile -t r82wei/kde-code-server:latest ../..
