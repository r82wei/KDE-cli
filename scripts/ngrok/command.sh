#!/bin/bash

source ${KDE_SCRIPTS_PATH}/utils/ngrok.sh

# 定義顯示說明的函數
show_help() {
    echo "usage:"
    echo "  kde ngrok <target> 透過 Ngrok 建立連線"
    echo ""
    echo "target:"
    echo "  ingress          透過 Ngrok 與 ingress 建立連線"
    echo "  service          透過 Ngrok 與 service 建立連線"
    echo "  pod              透過 Ngrok 與 pod 建立連線"
    echo "  [url]            透過 Ngrok 與 url 建立連線 (e.g. http://192.168:8080)"
    echo "option:"
    echo "  daemon, -d          在背景執行"
}

TARGET=$1

if [[ -z "${TARGET}" || "${TARGET}" == "--help" || "${TARGET}" == "-h" ]]; then
    show_help
    exit 1
fi

case "${TARGET}" in
    "ingress")
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
    *)
        ngrok_http_url ${CUR_ENV} ${TARGET}
        ;;
esac