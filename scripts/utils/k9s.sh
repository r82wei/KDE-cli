#!/bin/bash

start_k9s() {
    local K9S_PORT="$1"
    local K9S_NAMESPACE="$2"
    local K9S_ARGS=""
    local K9S_CONFIG="${3:-${ENV_PATH}/k9s-config.yaml}"

    # 如果 K9S_CONFIG 不存在，則不使用設定檔
    if [[ ! -f "$K9S_CONFIG" ]]; then
        K9S_CONFIG=""
    fi

    # 如果沒有指定 namespace，則使用 -A（所有 namespace）
    if [[ -z "$K9S_NAMESPACE" ]]; then
        K9S_ARGS="${K9S_ARGS} -A"
    else
        K9S_ARGS="${K9S_ARGS} -n ${K9S_NAMESPACE}"
    fi

    # 如果自訂設定檔存在，則加入 --config 參數
    if [[ -f "$K9S_CONFIG" ]]; then
        K9S_ARGS="${K9S_ARGS} --config ${K9S_CONFIG}"
        echo "k9s 使用自訂設定檔: ${K9S_CONFIG}"
    fi
    
    # 如果已經有 k9s 指令，就執行 k9s 指令，否則透過 docker run 執行 k9s 指令
    if command -v k9s > /dev/null 2>&1; then
        k9s ${K9S_ARGS}
    else
        # 建立 docker run 指令
        local DOCKER_CMD="docker run --rm -it --net ${DOCKER_NETWORK} -e KUBECONFIG=${KUBECONFIG} -v ${KUBECONFIG}:${KUBECONFIG}"
        
        # 如果自訂設定檔存在，mount 到容器內
        if [[ -f "$K9S_CONFIG" ]]; then
            DOCKER_CMD="${DOCKER_CMD} -v ${K9S_CONFIG}:${K9S_CONFIG}"
        fi
        
        # 如果有指定 port，則加入 port mapping
        if [[ -n "$K9S_PORT" ]]; then
            DOCKER_CMD="${DOCKER_CMD} -p ${K9S_PORT}:${K9S_PORT}"
        fi
        
        DOCKER_CMD="${DOCKER_CMD} ${K9S_IMAGE} ${K9S_ARGS}"
        
        eval $DOCKER_CMD
    fi
}

