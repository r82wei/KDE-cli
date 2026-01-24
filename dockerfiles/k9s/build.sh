#!/bin/bash

K9S_VERSION=v0.50.18
DATE=$(date +%Y%m%d%H%M%S)

echo "Build k9s image ..."
docker build --build-arg K9S_VERSION=${K9S_VERSION} -f Dockerfile -t r82wei/k9s:${K9S_VERSION}-${DATE} .