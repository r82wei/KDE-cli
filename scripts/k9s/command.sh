#!/bin/bash

source ${KDE_SCRIPTS_PATH}/utils/k9s.sh

# 定義顯示說明的函數
show_help() {
    echo "usage: kde k9s [option]"
    echo ""
    echo "example:"
    echo "  -p, --publish       透過 docker run --expose 將 k9s 指定的 port 或 port 範圍對應到本機"
    echo "  -h, --help          顯示此幫助訊息"
}

if [[ $(is_env_exist ${CUR_ENV}) == "false" ]]; then
    echo "請先建立 k8s 環境"
    exit 1
fi

# 根據第一個參數來選擇不同的處理流程
case "$1" in
    --port|-p)
        expose_k9s $2
        ;;
    --help|-h)
        show_help
        exit 0
        ;;
    *)
        start_k9s
        exit 0
        ;;
esac