#!/bin/bash
set -euo pipefail

KDE_CLI_VERSION=${KDE_CLI_VERSION:-main}
DATE=$(date +%Y%m%d%H%M%S)
IMAGE=${IMAGE:-r82wei/kde-tui}

docker build \
  --build-arg KDE_CLI_VERSION=${KDE_CLI_VERSION} \
  -f Dockerfile \
  -t ${IMAGE}:${KDE_CLI_VERSION}-${DATE} \
  -t ${IMAGE}:latest \
  .

echo "Built: ${IMAGE}:${KDE_CLI_VERSION}-${DATE}"
