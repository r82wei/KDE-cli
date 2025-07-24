#!/bin/bash

source ${KDE_SCRIPTS_PATH}/utils/headlamp.sh

# 定義顯示說明的函數
show_help() {
    echo "usage: kde headlamp [-p port]"
    echo ""
    echo "example:"
    echo "  -p, --port          透過指定的 Port 啟動 K8S Headlamp (預設為 4466)"
    echo "  -h, --help          顯示此幫助訊息"
}

if [[ $(is_env_exist ${CUR_ENV}) == "false" ]]; then
    echo "請先啟動 k8s 環境"
    exit 1
fi

# 根據第一個參數來選擇不同的處理流程
case "$1" in
    --help|-h)
        show_help
        exit 0
        ;;
    --port|-p)
        start_headlamp $2
        ;;
    *)
        start_headlamp 4466
        exit 0
        ;;
esac