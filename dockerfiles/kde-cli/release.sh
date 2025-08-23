#!/bin/bash

source ./version.env

echo "Release kde-cli ${KDE_CLI_VERSION} image ..."
docker buildx build --no-cache --platform linux/amd64,linux/arm64 --push --build-arg KDE_CLI_VERSION=${KDE_CLI_VERSION} -f Dockerfile -t r82wei/kde-cli:${KDE_CLI_VERSION} .
docker buildx build --platform linux/amd64,linux/arm64 --push --build-arg KDE_CLI_VERSION=${KDE_CLI_VERSION} -f Dockerfile -t r82wei/kde-cli:latest .