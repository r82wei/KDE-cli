#!/bin/bash

source ${KDE_SCRIPTS_PATH}/utils/cloudflare.sh

# 定義顯示說明的函數
show_help() {
    echo "usage:"
    echo "  kde cloudflare-tunnel <domain> <target>     透過 Cloudflare Tunnel 建立連線"
    echo ""
    echo "domain:"
    echo "  Cloudflare Tunnel 的自訂 domain"
    echo ""
    echo "target:"
    echo "  ingress          透過 Cloudflare Tunnel 與 ingress 建立連線"
    echo "  service          透過 Cloudflare Tunnel 與 service 建立連線"
    echo "  pod              透過 Cloudflare Tunnel 與 pod 建立連線"
    echo "  [url]            透過 Cloudflare Tunnel 與 url 建立連線 (e.g. http://localhost:8080)"
}

DOMAIN=$1
TARGET=$2

if [[ -z "${DOMAIN}" || "${DOMAIN}" == "--help" || "${DOMAIN}" == "-h" ]]; then
    show_help
    exit 1
fi

if [[ -z "${TARGET}" ]]; then
    TARGET="ingress"
fi


case "${TARGET}" in
    "ingress")
        exit_if_env_not_exist ${CUR_ENV}
        cloudflare_tunnel_url ${DOMAIN} http://${K8S_CONTAINER_NAME}:30080 ${DOCKER_NETWORK}
        ;;
    "service")
        exit_if_env_not_exist ${CUR_ENV}
        select_namespace
        select_service ${TARGET_NAMESPACE}
        select_port ${TARGET_NAMESPACE} "service" ${TARGET_SERVICE}
        cloudflare_tunnel_service ${DOMAIN} ${TARGET_NAMESPACE} ${TARGET_SERVICE} ${TARGET_PORT}
        ;;
    "pod")
        exit_if_env_not_exist ${CUR_ENV}
        select_namespace
        select_pod ${TARGET_NAMESPACE}
        select_port ${TARGET_NAMESPACE} "pod" ${TARGET_POD}
        cloudflare_tunnel_pod ${DOMAIN} ${TARGET_NAMESPACE} ${TARGET_POD} ${TARGET_PORT}
        ;;
    *)
        cloudflare_tunnel_url ${DOMAIN} ${TARGET}
        ;;
esac