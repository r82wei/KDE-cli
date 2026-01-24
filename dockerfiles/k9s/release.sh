#!/bin/bash

K9S_VERSION=v0.50.18

echo "Release k9s ${K9S_VERSION} image ..."
docker buildx build --no-cache --platform linux/amd64,linux/arm64 --push --build-arg K9S_VERSION=${K9S_VERSION} -f Dockerfile -t r82wei/k9s:${K9S_VERSION} .
docker buildx build --platform linux/amd64,linux/arm64 --push --build-arg K9S_VERSION=${K9S_VERSION} -f Dockerfile -t r82wei/k9s:latest .