#!/bin/bash

start_k9s() {
    # 如果已經有 k9s 指令，就執行 k9s 指令，否則透過 docker run 執行 k9s 指令
    if command -v k9s > /dev/null 2>&1; then
        k9s -A
    else
        docker run --rm -it --net ${DOCKER_NETWORK} -v ${KUBECONFIG}:/root/.kube/config ${K9S_IMAGE} -A
    fi
}

expose_k9s() {
    K9S_PORT=$1
    # 如果已經有 k9s 指令，就執行 k9s 指令，否則透過 docker run 執行 k9s 指令
    if command -v k9s > /dev/null 2>&1; then
        k9s -A
    else
        docker run --rm -it --net ${DOCKER_NETWORK} -v ${KUBECONFIG}:/root/.kube/config -p "${K9S_PORT}":"${K9S_PORT}" ${K9S_IMAGE} -A
    fi
}

