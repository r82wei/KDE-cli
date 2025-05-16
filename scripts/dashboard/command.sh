#!/bin/bash

source ${KDE_SCRIPTS_PATH}/utils/dashboard.sh

# 定義顯示說明的函數
show_help() {
    echo "usage: kde dashboard [option]"
    echo ""
    echo "example:"
    echo "  -p, --port          透過指定的 Port 啟動 K8S Dashboard (預設為 8443)"
    echo "  -h, --help          顯示此幫助訊息"
}

if [[ $(is_env_exist ${CUR_ENV}) == "false" ]]; then
    echo "請先啟動 k8s 環境"
    exit 1
fi

# 根據第一個參數來選擇不同的處理流程
case "$1" in
    --port|-p)
        if [[ "$3" == "--insecure" ]]; then
            ENABLE_SSL="false"
        else
            ENABLE_SSL="true"
        fi
        start_dashboard $2 $3
        ;;
    --help|-h)
        show_help
        exit 0
        ;;
    *)
        if [[ "$2" == "--insecure" ]]; then
            ENABLE_SSL="false"
        else
            ENABLE_SSL="true"
        fi
        start_dashboard 8443 $2
        exit 0
        ;;
esac