#!/bin/bash

# 與 release.sh 一致,直接由 git tag 取版本(不再依賴不存在的 version.env)
KDE_CLI_VERSION=$(git describe --tags)
DATE=$(date +%Y%m%d%H%M%S)

echo "Build kde-code-server ${KDE_CLI_VERSION} image ..."
docker build -f Dockerfile -t r82wei/kde-code-server:${KDE_CLI_VERSION}-${DATE} ../..