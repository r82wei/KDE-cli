#!/bin/bash

KUBECTL_VERSION=v1.32.0

echo "Build telepresence image ..."
# docker buildx build --platform linux/amd64,linux/arm64 --push --build-arg KUBECTL_VERSION=${KUBECTL_VERSION} -f Dockerfile -t r82wei/telepresence:1.0.4-alpha-4 .
docker buildx build --platform linux/amd64,linux/arm64 --push --build-arg KUBECTL_VERSION=${KUBECTL_VERSION} -f Dockerfile -t r82wei/telepresence:1.0.4 .