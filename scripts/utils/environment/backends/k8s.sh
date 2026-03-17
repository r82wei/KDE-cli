#!/bin/bash

# Environment backend: External K8s
# Connects to an existing K8s cluster via kubeconfig.
# No infrastructure management — the cluster is managed externally.

_backend_env_create() {
    # 設定 DOCKER_NETWORK
    export DOCKER_NETWORK="bridge"
    echo "DOCKER_NETWORK=${DOCKER_NETWORK}" >> ${K8S_ENV_FILE_PATH}
}

_backend_env_init() {
    KUBECONFIG_PATH=${1:-${KUBECONFIG_PATH}}
    # 設定 KUBECONFIG 路徑
    if [[ -z "${KUBECONFIG_PATH}" ]]; then
        read -e -p "請輸入 kubeconfig 路徑: " KUBECONFIG_PATH
    fi
    KUBECONFIG_PATH="${KUBECONFIG_PATH/#\~/$HOME}"
    cp ${KUBECONFIG_PATH} ${ENV_PATH}/${KUBE_CONFIG_DIR}/config

    if [[ -z "${K8S_CONTAINER_NAME}" ]]; then
        # Get the current context from kubeconfig
        CURRENT_CONTEXT=$(exec_script_in_deploy_env_without_tty "kubectl config current-context")

        # Get the cluster name from the current context
        CLUSTER_NAME=$(exec_script_in_deploy_env_without_tty "kubectl config view -o jsonpath=\"{.contexts[?(@.name == '${CURRENT_CONTEXT}')].context.cluster}\"")

        # Get the server IP from the cluster configuration
        SERVER_IP=$(exec_script_in_deploy_env_without_tty "kubectl config view -o jsonpath=\"{.clusters[?(@.name == '${CLUSTER_NAME}')].cluster.server}\" | sed 's|https://||' | cut -d: -f1")

        # 設定 K8S control plane node IP
        export K8S_CONTAINER_NAME=${SERVER_IP}
        echo "K8S_CONTAINER_NAME=${K8S_CONTAINER_NAME}" >> ${K8S_ENV_FILE_PATH}
    fi

    echo "K8S 環境設定初始化已完成"
}

_backend_env_start() {
    echo "外部 K8S 叢集，無需啟動"
}

_backend_env_stop() {
    echo "外部 K8S 叢集，請自行管理"
}

_backend_env_delete() {
    echo "外部 K8S 叢集，僅移除本地設定"
}

_backend_env_status() {
    if kubectl --kubeconfig="${KUBECONFIG}" get nodes &>/dev/null; then
        echo "running"
    else
        echo "unreachable"
    fi
}

_backend_env_exec_node() {
    echo "外部 K8S 叢集不支援直接 exec 進入 node"
    return 1
}
