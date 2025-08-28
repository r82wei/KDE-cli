#!/bin/bash

source ./version.env
DATE=$(date +%Y%m%d%H%M%S)

echo "Build kde-cli image ..."
docker build --build-arg KDE_CLI_VERSION=${KDE_CLI_VERSION} -f Dockerfile -t r82wei/kde-cli:${KDE_CLI_VERSION}-${DATE} .