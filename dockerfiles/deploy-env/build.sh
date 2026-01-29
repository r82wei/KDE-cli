#!/bin/bash

KUBECTL_VERSION=v1.32.0

echo "Build deploy-env image ..."
docker buildx build --platform linux/amd64,linux/arm64 --push --build-arg KUBECTL_VERSION=${KUBECTL_VERSION} -f Dockerfile -t r82wei/deploy-env:1.1.0 .