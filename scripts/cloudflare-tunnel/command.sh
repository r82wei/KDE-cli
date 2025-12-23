#!/bin/bash

source ${KDE_SCRIPTS_PATH}/utils/cloudflare.sh



# 定義顯示說明的函數
show_help() {
    echo "usage:"
    echo "  kde cloudflare-tunnel <target> [options]     透過 Cloudflare Tunnel 建立連線"
    echo ""
    echo "target:"
    echo "  url                  透過 Cloudflare Tunnel 與 url 建立連線 (e.g. http://localhost:8080 or http://192.168.1.1)"
    echo "  service              透過 Cloudflare Tunnel 與當前 k8s 環境的 service 建立連線"
    echo "  pod                  透過 Cloudflare Tunnel 與當前 k8s 環境的 pod 建立連線"
    echo ""
    echo "options:"
    echo "  -h, --help              Show help"
    echo "  -q, --quick             使用隨機網址的 Cloudflare Tunnel (不需要登入 Cloudflare 帳號)"
    echo "  -d, --domain            Cloudflare Tunnel 的自訂 domain (需要登入 Cloudflare 帳號且 Domain 有託管在 Cloudflare 上) (e.g. myapp.example.com)"
    echo "  -u, --url               要轉發的目標 URL 位址 (e.g. http://localhost:8080 or http://192.168.1.1)"
    echo "  -n, --namespace         Namespace 名稱"
    echo "  -s, --service           Service 名稱"
    echo "  --pod                   Pod 名稱"
    echo "  -p, --port              Port 號碼"
    echo "  --network           Docker 網路 (default: 當前 K8s 環境的 Docker 網路)，也可設定為 host (即使用主機的網路)"

}

TARGET=$1

if [[ -z "${TARGET}" || "$1" == "--help" || "$1" == "-h" ]]; then
    show_help
    exit 1
fi

# 移除第一個參數（TARGET）
shift

# 解析 options
while [[ $# -gt 0 ]]; do
    case "$1" in
        -d|--domain)
            DOMAIN="$2"
            shift 2
            ;;
        -u|--url)
            export TARGET_URL="$2"
            shift 2
            ;;
        -n|--namespace)
            TARGET_NAMESPACE="$2"
            shift 2
            ;;
        -s|--service)
            TARGET_SERVICE="$2"
            shift 2
            ;;
        --pod)
            TARGET_POD="$2"
            shift 2
            ;;
        -p|--port)
            TARGET_PORT="$2"
            shift 2
            ;;
        -q|--quick)
            export QUICK_TUNNEL=true
            shift 1
            ;;
        --network)
            export DOCKER_NETWORK="$2"
            shift 2
            ;;
        *)
            shift 1
            ;;
    esac
done


case "${TARGET}" in
    "service")
        exit_if_env_not_exist ${CUR_ENV}
        select_namespace
        select_service ${TARGET_NAMESPACE}
        select_port ${TARGET_NAMESPACE} "service" ${TARGET_SERVICE}
        if [[ -n "${QUICK_TUNNEL}" ]]; then
            cloudflare_quick_tunnel_service ${TARGET_NAMESPACE} ${TARGET_SERVICE} ${TARGET_PORT}
        else
            cloudflare_tunnel_service ${DOMAIN} ${TARGET_NAMESPACE} ${TARGET_SERVICE} ${TARGET_PORT}
        fi
        ;;
    "pod")
        exit_if_env_not_exist ${CUR_ENV}
        select_namespace
        select_pod ${TARGET_NAMESPACE}
        select_port ${TARGET_NAMESPACE} "pod" ${TARGET_POD}
        if [[ -n "${QUICK_TUNNEL}" ]]; then
            cloudflare_quick_tunnel_pod ${TARGET_NAMESPACE} ${TARGET_POD} ${TARGET_PORT}
        else
            cloudflare_tunnel_pod ${DOMAIN} ${TARGET_NAMESPACE} ${TARGET_POD} ${TARGET_PORT}
        fi
        ;;
    "url")
        if [[ -z "${TARGET_URL}" ]]; then
            read -p "請輸入要轉發的目標 URL 位址: " TARGET_URL
        fi
        if [[ -n "${QUICK_TUNNEL}" ]]; then
            cloudflare_quick_tunnel_url ${TARGET_URL} ${DOCKER_NETWORK}
        else
            if [[ -z "${DOMAIN}" ]]; then
                read -p "請輸入 Cloudflare Tunnel 的自訂 domain: " DOMAIN   
            fi
            cloudflare_tunnel_url ${DOMAIN} ${TARGET_URL} ${DOCKER_NETWORK}
        fi
        ;;
    *)
        echo "錯誤的 target: ${TARGET}"
        exit 1
        ;;
esac
