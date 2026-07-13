#!/bin/bash

start_code_server() {
    local PORT=$1
    local DAEMON=$2
    local NAME=${3:-code-server}
    local OPEN_PATH_ARG=$4
    shift 4
    local -a RAW_MOUNTS=("$@")

    # 無掛載目標時預設當前路徑
    if [[ ${#RAW_MOUNTS[@]} -eq 0 ]]; then
        RAW_MOUNTS=("$PWD")
    fi

    # 解析、驗證、去重
    local -a MOUNTS=()       # 全部掛載目標（絕對路徑）
    local -a DIR_MOUNTS=()   # 其中的目錄型掛載
    local m abs
    for m in "${RAW_MOUNTS[@]}"; do
        abs=$(readlink -f "$m" 2>/dev/null) || true
        if [[ ! -e "$abs" ]]; then
            echo "❌ 掛載目標不存在：$m"
            return 1
        fi
        if [[ ! -d "$abs" && ! -f "$abs" ]]; then
            echo "❌ 掛載目標必須是目錄或檔案：$m"
            return 1
        fi
        # 去重（相同絕對路徑只掛一次）
        if [[ " ${MOUNTS[*]} " == *" $abs "* ]]; then
            continue
        fi
        MOUNTS+=("$abs")
        if [[ -d "$abs" ]]; then
            DIR_MOUNTS+=("$abs")
        fi
    done

    # 決定開啟資料夾（workdir）
    local OPEN_PATH
    if [[ -n "$OPEN_PATH_ARG" ]]; then
        OPEN_PATH=$(readlink -f "$OPEN_PATH_ARG")
        if [[ ! -d "$OPEN_PATH" ]]; then
            echo "❌ 開啟資料夾不存在或不是目錄：${OPEN_PATH}"
            return 1
        fi
    else
        if [[ ${#DIR_MOUNTS[@]} -eq 0 ]]; then
            echo "❌ 沒有可開啟的目錄型掛載，請用 -w/--workdir 明確指定開啟資料夾"
            return 1
        fi
        OPEN_PATH=${DIR_MOUNTS[0]}
    fi

    # 開啟資料夾必須位於任一目錄型掛載底下，否則 container 內看不到
    local under=false d
    for d in "${DIR_MOUNTS[@]}"; do
        if [[ "$OPEN_PATH" == "$d" || "$OPEN_PATH" == "$d"/* ]]; then
            under=true
            break
        fi
    done
    if [[ "$under" != "true" ]]; then
        echo "❌ 開啟資料夾 (${OPEN_PATH}) 必須位於其中一個目錄型掛載底下"
        return 1
    fi

    # 檢查同名容器是否已存在
    if docker ps -a --format '{{.Names}}' | grep -qx "${NAME}"; then
        echo "❌ 容器名稱 ${NAME} 已存在，請先停止/移除，或用 -n 指定其他名稱"
        echo "   docker rm -f ${NAME}"
        return 1
    fi

    local CONFIG_DIR=${KDE_PATH}/.code-server/${NAME}
    mkdir -p ${CONFIG_DIR}

    # 組出掛載參數（每個目標 host 路徑 = container 路徑）
    local -a MOUNT_ARGS=()
    for m in "${MOUNTS[@]}"; do
        MOUNT_ARGS+=(-v "${m}:${m}")
    done

    local DOCKER_SOCK_GID
    DOCKER_SOCK_GID=$( (stat -c '%g' /var/run/docker.sock 2>/dev/null || stat -f '%g' /var/run/docker.sock 2>/dev/null) ) || true

    if [[ "${DAEMON}" == "true" ]]; then
        docker run -it -d \
        --name ${NAME} \
        --workdir ${OPEN_PATH} \
        --group-add ${DOCKER_SOCK_GID} \
        -p ${PORT}:8080 \
        -e "PASSWORD=${PASSWORD}" \
        -v "${CONFIG_DIR}:/home/coder" \
        "${MOUNT_ARGS[@]}" \
        -v "${KDE_CLI_PATH}:/usr/local/lib/kde:ro" \
        -v /var/run/docker.sock:/var/run/docker.sock:ro \
        -u "$(id -u):$(id -g)" \
        -e "DOCKER_USER=$USER" \
        ${CODE_SERVER_IMAGE} \
        ${OPEN_PATH}

        echo "✓ code-server 已在背景啟動 (${NAME})"
        echo "掛載目標:"
        for m in "${MOUNTS[@]}"; do echo "  - ${m}"; done
        echo "開啟資料夾: ${OPEN_PATH}"
        echo "存取網址: http://localhost:${PORT}"
        echo "停止服務: docker stop ${NAME}"
    else
        docker run -it --rm \
        --name ${NAME} \
        --workdir ${OPEN_PATH} \
        --group-add ${DOCKER_SOCK_GID} \
        -p ${PORT}:8080 \
        -e "PASSWORD=${PASSWORD}" \
        -v "${CONFIG_DIR}:/home/coder" \
        "${MOUNT_ARGS[@]}" \
        -v "${KDE_CLI_PATH}:/usr/local/lib/kde:ro" \
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