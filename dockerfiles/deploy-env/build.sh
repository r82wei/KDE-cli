#!/bin/bash

echo "Build deploy-env image ..."
docker buildx build --platform linux/amd64,linux/arm64 --push -f Dockerfile -t docker.anyong.com.tw/quick-start/deploy-env:1.0.0 .