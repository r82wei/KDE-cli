#!/bin/bash

start_k9s() {
    local K9S_PORT="$1"
    local K9S_NAMESPACE="$2"
    local K9S_ARGS=""

    # 如果沒有指定 namespace，則使用 -A（所有 namespace）
    if [[ -z "$K9S_NAMESPACE" ]]; then
        K9S_ARGS="${K9S_ARGS} -A"
    else
        K9S_ARGS="${K9S_ARGS} -n ${K9S_NAMESPACE}"
    fi

    # （單一環境）如果有 Env dir 底下存在 k9s config dir 則設定 K9S_CONFIG_DIR
    if [[ -d "${ENV_PATH}/k9s" ]]; then
        export K9S_CONFIG_DIR="${ENV_PATH}/k9s"
    # （全部環境）如果 KDE_PATH 底下存在 k9s config dir 則設定 K9S_CONFIG_DIR
    elif [[ -d "${KDE_PATH}/k9s" ]]; then
        export K9S_CONFIG_DIR="${KDE_PATH}/k9s"
    fi
    
    # 如果已經有 k9s 指令，就執行 k9s 指令，否則透過 docker run 執行 k9s 指令
    if command -v k9s > /dev/null 2>&1; then
        k9s ${K9S_ARGS}
    else
        # 建立 docker run 指令
        local DOCKER_CMD="docker run --rm -it --net ${DOCKER_NETWORK} -e KUBECONFIG=${KUBECONFIG} -v ${KUBECONFIG}:${KUBECONFIG}"
        
        # 如果自訂設定檔目錄存在，則 mount 到容器內
        if [[ -n "$K9S_CONFIG_DIR" ]]; then
            DOCKER_CMD="${DOCKER_CMD} -e K9S_CONFIG_DIR=${K9S_CONFIG_DIR} -v ${K9S_CONFIG_DIR}:${K9S_CONFIG_DIR}"
            echo "k9s 使用自訂設定檔目錄: ${K9S_CONFIG_DIR}"
        fi
        
        # 如果有指定 port，則加入 port mapping
        if [[ -n "$K9S_PORT" ]]; then
            DOCKER_CMD="${DOCKER_CMD} -p ${K9S_PORT}:${K9S_PORT}"
        fi
        
        DOCKER_CMD="${DOCKER_CMD} ${K9S_IMAGE} ${K9S_ARGS}"
        
        eval $DOCKER_CMD
    fi
}

