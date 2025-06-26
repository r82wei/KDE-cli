#!/bin/bash

source ${KDE_SCRIPTS_PATH}/utils/project.sh
source ${KDE_SCRIPTS_PATH}/utils/telepresence.sh

# 定義顯示說明的函數
show_help() {
    echo "usage:"
    echo "  kde telepresence <command> [namespace] [workload]     透過 Telepresence 在本地啟動擁有遠端 Pod 相同網路及環境變數的容器，並且可以攔截遠端 Pod 的流量到本地環境"
    echo ""
    echo "command:"
    echo "  list            列出目前所有 Telepresence 的連線狀態"
    echo "  replace         啟動本地開發環境，並且攔截遠端 Pod 的流量到本地環境，並且停止遠端 Pod 的運行 (攔截流量、停止遠端 Pod 運行)"
    echo "  intercept       啟動本地開發環境，並且攔截遠端 Pod 的流量到本地環境，但不干擾遠端 Pod 的運行 (攔截流量、不干擾遠端 Pod 運行)"
    echo "  wiretap         啟動本地開發環境，並且複製遠端 Pod 的流量到本地環境，但不干擾遠端 Pod 的運行 (不攔截流量、不干擾遠端 Pod 運行，僅傳送流量副本)"
    echo "  ingest          啟動本地開發環境，但不會攔截流量，也不干擾遠端 Pod 的運行，僅讓本地環境可以連線 k8s 環境內的服務 (不攔截流量、不干擾遠端 Pod 運行)"
    echo "  uninstall       卸載 Namespace 下所有 Telepresence 的代理程式"
    echo "  clear           停止所有 Telepresence 的連線"
    echo ""
    echo ""
    echo "namespace:    k8s 環境的 namespace"
    echo "workload:     telepresence 的 workload"
}

COMMAND=$1
NAMESPACE=$2
WORKLOAD=$3


case "${COMMAND}" in
    "clear")
        stop_all_telepresence_session_containers
        exit 0
        ;;
    "-h"|"--help"|"")
        show_help
        exit 1
        ;;
esac


if [[ -z "${NAMESPACE}" ]]; then
    # select namespace
    select_namespace
    export NAMESPACE=${TARGET_NAMESPACE}
fi


case "${COMMAND}" in
    "list")
        list_status ${NAMESPACE}
        exit 0
        ;;
    "uninstall")
        uninstall_telepresence_agents ${NAMESPACE}
        exit 0
        ;;
esac

# 啟動 telepresence container 並且透過 telepresence connect ${NAMESPACE} 連線
if [[ -z "${TELEPRESENCE_ALSO_PROXY_CIDR}" ]]; then
    read -p "請輸入要 Proxy 的內網網段(CIDR)，如果沒有請直接按 Enter: " PROXY_CIDR
    export TELEPRESENCE_ALSO_PROXY_CIDR=${PROXY_CIDR}
else
    echo "TELEPRESENCE_ALSO_PROXY_CIDR: ${TELEPRESENCE_ALSO_PROXY_CIDR}"
fi
create_telepresence_session_container ${NAMESPACE}

# 將後面啟動的 container 的 docker network 設定為 telepresence container 的網路
export DOCKER_NETWORK="container:kde-telepresence-session-${CUR_ENV}-${NAMESPACE}"


if [[ -z "${WORKLOAD}" ]]; then
    select_workload ${NAMESPACE}
fi

case "${COMMAND}" in
    "replace")
        replace_workload ${NAMESPACE} ${WORKLOAD}
        ;;
    "intercept")
        intercept_workload ${NAMESPACE} ${WORKLOAD}
        ;;
    "wiretap")
        wiretap_workload ${NAMESPACE} ${WORKLOAD}
        ;;
    "ingest")
        ingest_workload ${NAMESPACE} ${WORKLOAD}
        ;;
    *)
        show_help
        exit 0
        ;;
esac

if [[ $? -ne 0 ]]; then
    exit 1
fi

# 選擇專案
select_project ${NAMESPACE}

# 進入專案開發容器
exec_project_develop_container ${PROJECT_NAME}

# 停止 telepresence session container
if [[ $(is_any_container_use_telepresence_session_network ${NAMESPACE}) == "false" ]]; then
    stop_telepresence_session_container ${NAMESPACE}
fi