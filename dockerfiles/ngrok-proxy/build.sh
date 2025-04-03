#!/bin/bash

KUBECTL_VERSION=v1.32.0

echo "Build ngrok-proxy image ..."
docker buildx build --platform linux/amd64,linux/arm64 --push --build-arg KUBECTL_VERSION=${KUBECTL_VERSION} -f Dockerfile -t anyong.azurecr.io/quick-start/ngrok-proxy:1.0.0 .
