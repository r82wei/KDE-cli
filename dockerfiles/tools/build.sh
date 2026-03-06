#!/bin/bash

echo "Build tools image ..."
docker buildx build --platform linux/amd64,linux/arm64 --push -f Dockerfile -t r82wei/tools:1.0.0 .
