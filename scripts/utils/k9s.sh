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
        K9S_CMD="k9s ${K9S_ARGS}"

        # 如果自訂設定檔目錄存在，則 mount 到容器內
        if [[ -n "$K9S_CONFIG_DIR" ]]; then
            K9S_CMD="K9S_CONFIG_DIR=${K9S_CONFIG_DIR} ${K9S_CMD}"
            echo "k9s 使用自訂設定檔目錄: ${K9S_CONFIG_DIR}"
        fi

        eval $K9S_CMD
    else
        # 建立 docker run 指令
        local DOCKER_CMD="docker run --rm -it --net ${DOCKER_NETWORK} -e KUBECONFIG=${KUBECONFIG} -v ${KUBECONFIG}:${KUBECONFIG}"
        
        # 如果自訂設定檔目錄存在，則 mount 到容器內
        if [[ -n "$K9S_CONFIG_DIR" ]]; then
            # 為什麼不能直接寫 -e USER=${USER}：
            # k9s 是停用 CGO 的 Go binary，設了 K9S_CONFIG_DIR 之後 InitLogLoc()
            # 會走到 os/user.Current()，而該函式在沒有 CGO 時只剩「查 /etc/passwd」
            # 與「讀 $USER」兩條路。下面的 -u 讓容器以主機 uid 執行，但 k9s 映像
            # (alpine base) 的 /etc/passwd 並沒有該 uid 的條目，於是 $USER 成為
            # 唯一還通的那條路——傳空值會讓 k9s 以
            # 「user: Current requires cgo or $USER set in environment」開場，
            # 並因 AppLogFile 從未被賦值而接著噴 log file "" init failed。
            #
            # 而 USER 並非到處都有：docker exec 只從 /etc/passwd 帶入 HOME，
            # 不會設 USER/LOGNAME，因此在 kde openclaw exec 的容器內跑 kde k9s
            # 時它是空的（主機上不出問題，只是因為主機 bash 剛好有 USER）。
            # 依序退回 id -un（容器內通常查得到，如 openclaw 的 node）與 uid 數字；
            # 後者純粹是最後防線，k9s 只拿這個值當 log 目錄名，不必是真實帳號。
            local K9S_USER="${USER:-$(id -un 2>/dev/null || id -u)}"
            DOCKER_CMD="${DOCKER_CMD} -u $(id -u):$(id -g) -e USER=${K9S_USER} -e K9S_CONFIG_DIR=${K9S_CONFIG_DIR} -v ${K9S_CONFIG_DIR}:${K9S_CONFIG_DIR} -e XDG_CONFIG_HOME=${K9S_CONFIG_DIR}/.config -e XDG_DATA_HOME=${K9S_CONFIG_DIR}/.data -v ${K9S_CONFIG_DIR}/.config:${K9S_CONFIG_DIR}/.config -v ${K9S_CONFIG_DIR}/.data:${K9S_CONFIG_DIR}/.data"
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

