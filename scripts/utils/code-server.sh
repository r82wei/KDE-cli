#!/bin/bash

start_code_server() {
    PORT=$1
    DAEMON=$2

    mkdir -p ${KDE_PATH}/.code-server
    if [[ "${DAEMON}" == "true" ]]; then
        docker run -it -d \
        --name code-server \
        --workdir ${KDE_PATH} \
        --group-add $( (stat -c '%g' /var/run/docker.sock 2>/dev/null || stat -f '%g' /var/run/docker.sock) ) \
        -p ${PORT}:8080 \
        -e "PASSWORD=${PASSWORD}" \
        -v "${KDE_PATH}/.code-server:/home/coder" \
        -v "${KDE_PATH}:${KDE_PATH}" \
        -v /var/run/docker.sock:/var/run/docker.sock:ro \
        -u "$(id -u):$(id -g)" \
        -e "DOCKER_USER=$USER" \
        ${CODE_SERVER_IMAGE} \
        ${KDE_PATH}
    else
        docker run -it --rm \
        --name code-server \
        --workdir ${KDE_PATH} \
        --group-add $( (stat -c '%g' /var/run/docker.sock 2>/dev/null || stat -f '%g' /var/run/docker.sock) ) \
        -p ${PORT}:8080 \
        -e "PASSWORD=${PASSWORD}" \
        -v "${KDE_PATH}/.code-server:/home/coder" \
        -v "${KDE_PATH}:${KDE_PATH}" \
        -v /var/run/docker.sock:/var/run/docker.sock:ro \
        -u "$(id -u):$(id -g)" \
        -e "DOCKER_USER=$USER" \
        ${CODE_SERVER_IMAGE} \
        ${KDE_PATH}
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