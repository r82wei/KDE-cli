#!/bin/bash

source ${KDE_SCRIPTS_PATH}/utils/ngrok.sh

# 定義顯示說明的函數
show_help() {
    echo "usage:"
    echo "  kde ngrok 透過 Ngrok 建立連線"
    echo ""
    echo "option:"
    echo "  daemon, -d          在背景執行"
}

OPTION=$1

case "${OPTION}" in
    "")
        exit_if_env_not_exist ${CUR_ENV}
        ngrok_http_ingress ${CUR_ENV}
        ;;
    "service")
        select_namespace
        select_service ${TARGET_NAMESPACE}
        select_port ${TARGET_NAMESPACE} "service" ${TARGET_SERVICE}
        ngrok_http_k8s_service ${CUR_ENV} ${TARGET_NAMESPACE} ${TARGET_SERVICE} ${TARGET_PORT}
        ;;
    "pod")
        select_namespace
        select_pod ${TARGET_NAMESPACE}
        select_port ${TARGET_NAMESPACE} "pod" ${TARGET_POD}
        ngrok_http_k8s_pod ${CUR_ENV} ${TARGET_NAMESPACE} ${TARGET_POD} ${TARGET_PORT}
        ;;
esac