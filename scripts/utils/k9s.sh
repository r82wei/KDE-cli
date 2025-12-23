#!/bin/bash

start_k9s() {
    local K9S_PORT="$1"
    local K9S_NAMESPACE="$2"
    local K9S_ARGS=""
    
    # 如果沒有指定 namespace，則使用 -A（所有 namespace）
    if [[ -z "$K9S_NAMESPACE" ]]; then
        K9S_ARGS="-A"
    else
        K9S_ARGS="-n ${K9S_NAMESPACE}"
    fi
    
    # 如果已經有 k9s 指令，就執行 k9s 指令，否則透過 docker run 執行 k9s 指令
    if command -v k9s > /dev/null 2>&1; then
        k9s ${K9S_ARGS}
    else
        # 建立 docker run 指令
        local DOCKER_CMD="docker run --rm -it --net ${DOCKER_NETWORK} -v ${KUBECONFIG}:/root/.kube/config"
        
        # 如果有指定 port，則加入 port mapping
        if [[ -n "$K9S_PORT" ]]; then
            DOCKER_CMD="${DOCKER_CMD} -p ${K9S_PORT}:${K9S_PORT}"
        fi
        
        DOCKER_CMD="${DOCKER_CMD} ${K9S_IMAGE} ${K9S_ARGS}"
        
        eval $DOCKER_CMD
    fi
}

