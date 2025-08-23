#!/bin/bash

KDE_CLI_VERSION=v1.0.0-rc.2

# 若外部已設定 PROJECT_PATH，略過互動；否則從 TTY 讀
if [[ -z "${PROJECT_PATH:-}" ]]; then
  if [[ -t 0 ]]; then
    # 互動式有 TTY
    read -e -p "Enter the project path (Default: ${PWD}): " PROJECT_PATH
  else
    # 即使 stdin 不是 TTY，也強制從 /dev/tty 讀
    read -e -p "Enter the project path (Default: ${PWD}): " PROJECT_PATH </dev/tty
  fi
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
    r82wei/kde-cli:${KDE_CLI_VERSION} \
    bash