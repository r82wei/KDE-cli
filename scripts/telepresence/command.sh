#!/bin/bash

source ${KDE_SCRIPTS_PATH}/utils/k8s.sh
source ${KDE_SCRIPTS_PATH}/utils/telepresence.sh

# 定義顯示說明的函數
show_help() {
    echo "usage:"
    echo "  kde telepresence <command> [namespace] [workload]     透過 Telepresence 建立連線現有的 k8s 環境"
    echo ""
    echo "command:"
    echo "  replace         攔截目標 Pod 的流量到本地環境，並且停止 Pod 的運行 (攔截流量、停止 Pod 運行)"
    echo "  intercept       攔截目標 Pod 的流量到本地環境，但不干擾目標 Pod 的運行 (攔截流量、不干擾 Pod 運行)"
    echo "  wiretap         複製目標 Pod 的流量到本地環境，但不干擾目標 Pod 的運行 (不攔截流量、不干擾 Pod 運行，僅傳送流量副本)"
    echo "  ingest          不會攔截流量，也不不干擾目標 Pod 的運行，僅讓本地環境可以連線 k8s 環境內的服務 (不攔截流量、不干擾 Pod 運行)"
    echo ""
    echo ""
    echo "namespace:    k8s 環境的 namespace"
    echo "workload:     telepresence 的 workload"
}

COMMAND=$1
NAMESPACE=$2
WORKLOAD=$3

if [[ -z "${COMMAND}" || "${COMMAND}" == "--help" || "${COMMAND}" == "-h" ]]; then
    show_help
    exit 1
fi

if [[ -z "${NAMESPACE}" ]]; then
    # select namespace
    select_namespace
    export NAMESPACE=${TARGET_NAMESPACE}
fi

# 啟動 telepresence container 並且透過 telepresence connect ${NAMESPACE} 連線
create_telepresence_session_container ${NAMESPACE}

# 將後面啟動的 container 的 docker network 設定為 telepresence container 的網路
export DOCKER_NETWORK="container:kde-telepresence-session-${NAMESPACE}"


if [[ -z "${WORKLOAD}" ]]; then
    # TODO: 透過 telepresence list 列出所有可用的 Intercepts
    select_workload
    export WORKLOAD=${TARGET_SERVICE}
fi

# TODO: 需要輸出 env-file (WORKLOAD.env) 到 /root/.telepresence/env-files 中
case "${COMMAND}" in
    "replace")
        
        ;;
    "intercept")
    
        ;;
    "wiretap")
        
        ;;
    "ingest")
        
        ;;
    *)
        show_help
        exit 0
        ;;
esac


# 進入專案開發容器
select_project ${NAMESPACE}
exec_project_develop_container ${PROJECT_NAME}