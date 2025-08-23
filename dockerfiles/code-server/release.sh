#!/bin/bash

source ./version.env

echo "Release kde-code-server ${KDE_CLI_VERSION} image ..."
docker buildx build --platform linux/amd64,linux/arm64 --push --build-arg KDE_CLI_VERSION=${KDE_CLI_VERSION} -f Dockerfile -t r82wei/kde-code-server:${KDE_CLI_VERSION} .