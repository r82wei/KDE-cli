#!/bin/bash

TOOLS_VERSION=1.0.0

echo "Release tools ${TOOLS_VERSION} image ..."
docker buildx build --no-cache --platform linux/amd64,linux/arm64 --push -f Dockerfile -t r82wei/kde-cli/tools:${TOOLS_VERSION} .
docker buildx build --platform linux/amd64,linux/arm64 --push -f Dockerfile -t r82wei/kde-cli/tools:latest .
