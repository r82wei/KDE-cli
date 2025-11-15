#!/bin/bash

KDE_CLI_VERSION=v1.0.0-rc.4
DATE="20250823105008"

read -e -p "Enter the project path: " PROJECT_PATH

docker run -it --rm \
    -w ${PROJECT_PATH} \
    -v ${PROJECT_PATH}:${PROJECT_PATH} \
    -v /var/run/docker.sock:/var/run/docker.sock \
    -e PUID=$UID \
    -e PGID=$GID \
    -e USER_NAME=$USER \
    r82wei/kde-cli:${KDE_CLI_VERSION}-${DATE} \
    bash