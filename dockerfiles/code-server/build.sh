#!/bin/bash

KDE_CLI_VERSION=v1.0.0-rc.1
DOCKER_VERSION=v1.32.0
DATE=$(date +%Y%m%d)

echo "Build kde-code-server image ..."
docker buildx build --platform linux/amd64,linux/arm64 --push --build-arg KDE_CLI_VERSION=${KDE_CLI_VERSION} -f Dockerfile -t r82wei/kde-code-server:${KDE_CLI_VERSION}-${DATE} .