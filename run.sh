#!/bin/bash

KDE_CLI_VERSION=v1.0.0-rc.2

read -e -p "Enter the project path (Default: ${PWD}): " PROJECT_PATH
PROJECT_PATH=${PROJECT_PATH:-${PWD}}
CONTAINER_NAME="kde-cli-$(echo "${PROJECT_PATH}" | sed 's/\//-/g')"

docker run -it --rm \
    --name ${CONTAINER_NAME} \
    -w ${PROJECT_PATH} \
    -v ${PROJECT_PATH}:${PROJECT_PATH} \
    -v /var/run/docker.sock:/var/run/docker.sock \
    -e PUID=$UID \
    -e PGID=$GID \
    -e USER_NAME=$USER \
    r82wei/kde-cli:${KDE_CLI_VERSION} \
    bash