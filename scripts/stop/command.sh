#!/bin/bash

# 定義顯示說明的函數
show_help() {
    echo "usage:"
    echo "  kde k8s stop <name> [option]  關閉 k8s 環境"
    echo ""
    echo "option:"
    echo "  -f, --force  強制關閉 k8s 環境"
}

if [[ $1 == "--help" || $1 == "-h" ]]; then
    show_help
    exit 0
fi

# --- New-style environment path ---
if [[ -f "${ENV_PATH}/environment.env" ]]; then
    source ${KDE_SCRIPTS_PATH}/utils/environment/environment.sh
    env_stop
    exit 0
fi
# --- End new-style path ---

# Legacy path below (existing code, unchanged)...

# 根據環境類型來選擇不同的處理流程
case "${ENV_TYPE}" in
    k3d)
        echo "關閉 k3d 環境"
        stop_k3d ${1:-${CUR_ENV}} $2
        ;;
    kind)
        echo "關閉 kind 環境"
        stop_kind ${1:-${CUR_ENV}} $2
        ;;
    k8s)
        echo "外部 K8S 環境請自行關閉"
        ;;
    *)
        show_help
        ;;
esac
