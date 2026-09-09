#!/bin/bash
set -euo pipefail

# Usage:
#   IMAGE=r82wei/kde-tui KDE_CLI_VERSION=v1.0.0-rc.6 ./release.sh

IMAGE=${IMAGE:-r82wei/kde-tui}
KDE_CLI_VERSION=${KDE_CLI_VERSION:-main}
DATE=$(date +%Y%m%d%H%M%S)
TAG_VERSION="${IMAGE}:${KDE_CLI_VERSION}-${DATE}"
TAG_LATEST="${IMAGE}:latest"

echo "Building ${TAG_VERSION} ..."
docker build \
  --build-arg KDE_CLI_VERSION=${KDE_CLI_VERSION} \
  -f Dockerfile \
  -t ${TAG_VERSION} \
  -t ${TAG_LATEST} \
  .

echo "Pushing ${TAG_VERSION} ..."
docker push ${TAG_VERSION}

echo "Pushing ${TAG_LATEST} ..."
docker push ${TAG_LATEST}

echo "Release done:"
echo "  - ${TAG_VERSION}"
echo "  - ${TAG_LATEST}"
