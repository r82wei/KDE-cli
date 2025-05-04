#!/bin/bash

KUBECTL_VERSION=v1.32.0

echo "Build cloudflare-tunnel-proxy image ..."
docker buildx build --platform linux/amd64,linux/arm64 --push --build-arg KUBECTL_VERSION=${KUBECTL_VERSION} -f Dockerfile -t r82wei/cloudflare-tunnel-proxy:1.0.0 .