#!/bin/bash

# 定義顯示說明的函數
show_help() {
    echo "usage:"
    echo "  kde expose [namespace] [pod|service] [target port] [local port]         將 port forward 到本地端"
    echo ""
    echo "option:"
    echo "  -h, --help           顯示說明"
}

if [[ $1 == "--help" || $1 == "-h" ]]; then
    show_help
    exit 0
fi

exit_if_env_not_running ${ENV_NAME}

NAMESPACE=$1
RESOURCE_TYPE=$(echo $2 | tr '[:upper:]' '[:lower:]')
RESOURCE_NAME=$3
TARGET_PORT=$4
LOCAL_PORT=$5

if [[ $(is_namespace_exist ${NAMESPACE}) == "true" && $(is_pod_or_service_exist ${NAMESPACE} ${RESOURCE_TYPE} ${RESOURCE_NAME}) == "true" && $(is_port_valid ${TARGET_PORT}) == "true" && $(is_port_valid ${LOCAL_PORT}) == "true" ]]; then    
    exec_port_forward ${NAMESPACE} ${RESOURCE_TYPE} ${RESOURCE_NAME} ${TARGET_PORT} ${LOCAL_PORT}
else
    # 取得 Namespace 名稱
    select_namespace

    # 選擇要 Port forward 的服務類型(Service/Pod)
    while true; do
        echo "請選擇要 Port forward 的服務類型："
        echo "1) Service"
        echo "2) Pod"
        echo "3) 退出"

        read -p "輸入選項編號: " RESOURCE_TYPE

        case "$RESOURCE_TYPE" in
        1)
            export RESOURCE_TYPE=service
            break
            ;;
        2)
            export RESOURCE_TYPE=pod
            break
            ;;
        3)
            echo "退出程式"
            exit 0
            ;;
        *)
            echo "無效的選項，請重新輸入！"
            ;;
        esac
    done


    # 取得 Service/Pod 名稱並存入陣列
    if [[ "${RESOURCE_TYPE}" == "service" ]]; then
        resources=($(get_services ${TARGET_NAMESPACE}))
    elif [[ "${RESOURCE_TYPE}" == "pod" ]]; then
        resources=($(get_pods ${TARGET_NAMESPACE}))
    fi

    # 顯示選單
    PS3="請選擇 ${RESOURCE_TYPE} 名稱（輸入編號）："
    select resource in "${resources[@]}" "退出"
    do
        case $resource in
            "退出")
                echo "退出"
                exit 0
                ;;
            "")
                echo "無效選擇，請重新輸入。"
                ;;
            *)
                select_port ${TARGET_NAMESPACE} ${RESOURCE_TYPE} ${resource}
                read -p "請輸入本地 port: " LOCAL_PORT
                exec_port_forward ${TARGET_NAMESPACE} ${RESOURCE_TYPE} ${resource} ${TARGET_PORT} ${LOCAL_PORT}
                break
                ;;
        esac
    done

fi
