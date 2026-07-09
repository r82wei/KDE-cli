#!/bin/bash

start_code_server() {
    PORT=$1
    DAEMON=$2
    NAME=${3:-code-server}
    MOUNT_PATH=${4:-$PWD}          # 掛載到 container 的目錄，預設為當前路徑
    OPEN_PATH=${5:-$MOUNT_PATH}    # code-server 開啟的資料夾，預設與掛載路徑相同

    # 解析為絕對路徑
    MOUNT_PATH=$(readlink -f "${MOUNT_PATH}")
    OPEN_PATH=$(readlink -f "${OPEN_PATH}")

    # 驗證掛載路徑
    if [[ ! -d "${MOUNT_PATH}" ]]; then
        echo "❌ 掛載路徑不存在或不是目錄：${MOUNT_PATH}"
        return 1
    fi
    # 驗證開啟資料夾
    if [[ ! -d "${OPEN_PATH}" ]]; then
        echo "❌ 開啟資料夾不存在或不是目錄：${OPEN_PATH}"
        return 1
    fi
    # 開啟資料夾必須位於掛載路徑底下，否則 container 內看不到
    if [[ "${OPEN_PATH}" != "${MOUNT_PATH}" && "${OPEN_PATH}" != "${MOUNT_PATH}"/* ]]; then
        echo "❌ 開啟資料夾 (${OPEN_PATH}) 必須位於掛載路徑 (${MOUNT_PATH}) 底下"
        return 1
    fi

    # 檢查同名容器是否已存在，避免 Docker 原生的錯誤訊息
    if docker ps -a --format '{{.Names}}' | grep -qx "${NAME}"; then
        echo "❌ 容器名稱 ${NAME} 已存在，請先停止/移除，或用 -n 指定其他名稱"
        echo "   docker rm -f ${NAME}"
        return 1
    fi

    CONFIG_DIR=${KDE_PATH}/.code-server/${NAME}
    mkdir -p ${CONFIG_DIR}
    if [[ "${DAEMON}" == "true" ]]; then
        docker run -it -d \
        --name ${NAME} \
        --workdir ${OPEN_PATH} \
        --group-add $( (stat -c '%g' /var/run/docker.sock 2>/dev/null || stat -f '%g' /var/run/docker.sock) ) \
        -p ${PORT}:8080 \
        -e "PASSWORD=${PASSWORD}" \
        -v "${CONFIG_DIR}:/home/coder" \
        -v "${MOUNT_PATH}:${MOUNT_PATH}" \
        -v /var/run/docker.sock:/var/run/docker.sock:ro \
        -u "$(id -u):$(id -g)" \
        -e "DOCKER_USER=$USER" \
        ${CODE_SERVER_IMAGE} \
        ${OPEN_PATH}

        echo "✓ code-server 已在背景啟動 (${NAME})"
        echo "掛載目錄: ${MOUNT_PATH}"
        echo "開啟資料夾: ${OPEN_PATH}"
        echo "存取網址: http://localhost:${PORT}"
        echo "停止服務: docker stop ${NAME}"
    else
        docker run -it --rm \
        --name ${NAME} \
        --workdir ${OPEN_PATH} \
        --group-add $( (stat -c '%g' /var/run/docker.sock 2>/dev/null || stat -f '%g' /var/run/docker.sock) ) \
        -p ${PORT}:8080 \
        -e "PASSWORD=${PASSWORD}" \
        -v "${CONFIG_DIR}:/home/coder" \
        -v "${MOUNT_PATH}:${MOUNT_PATH}" \
        -v /var/run/docker.sock:/var/run/docker.sock:ro \
        -u "$(id -u):$(id -g)" \
        -e "DOCKER_USER=$USER" \
        ${CODE_SERVER_IMAGE} \
        ${OPEN_PATH}
    fi
}

# 暫時不使用
start_linuxserver_code_server() {
    PORT=$1
    DAEMON=$2

    if [[ "${DAEMON}" == "true" ]]; then
        docker run -it -d \
        -p ${PORT}:8443 \
        -e "PASSWORD=${PASSWORD}" \
        -v "${KDE_PATH}/.code-server:/config" \
        -v "${KDE_PATH}:/home/coder/project" \
        -e "PUID=${UID}" \
        -e "PGID=${GID}" \
        -e "DEFAULT_WORKSPACE=$USER" \
        --restart unless-stopped \
        lscr.io/linuxserver/code-server:latest
    else
        docker run -it --rm \
        -p ${PORT}:8443 \
        -e "PASSWORD=${PASSWORD}" \
        -e "SUDO_PASSWORD=${PASSWORD}" \
        -v "${KDE_PATH}/.code-server:/config" \
        -v "${KDE_PATH}:/home/coder/project" \
        -e "PUID=${UID}" \
        -e "PGID=${GID}" \
        -e "DEFAULT_WORKSPACE=$USER" \
        lscr.io/linuxserver/code-server:latest
    fi
}