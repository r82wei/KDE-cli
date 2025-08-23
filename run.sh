#!/bin/bash

# 若外部已設定 PROJECT_PATH，略過互動；否則從 TTY 讀
if [[ -z "${PROJECT_PATH:-}" ]]; then
  read -e -p "Enter the project path (Default: ${PWD}): " PROJECT_PATH
fi
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
    r82wei/kde-cli:latest \
    bash