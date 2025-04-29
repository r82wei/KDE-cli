#!/bin/bash

# 定義顯示說明的函數
show_help() {
    echo "usage:"
    echo "  kde start <name> [option]  啟動 k8s 環境"
    echo ""
    echo "option:"
    echo "  --kind           啟動 kind 環境 (預設)"
    echo "  --k3d, --k3s     啟動 k3d 環境"
}

if [ "$1" == "--help" ] || [ "$1" == "-h" ]; then
    show_help
    exit 0
fi

if [[ $2 == "--k3d" || $2 == "k3d" || $2 == "--k3s" || $2 == "k3s" ]]; then
    ENV_TYPE="k3d"
elif [[ $2 == "--k8s" || $2 == "k8s" ]]; then
    ENV_TYPE="k8s"
else
    ENV_TYPE="kind"
fi

# 初始化環境變數
init_env ${1:-${CUR_ENV}} ${ENV_TYPE}

# 設定預設環境
set_default_env ${1:-${CUR_ENV}}

# 取得前次 volume 路徑設定
source ${ENV_PATH}/volume.env

# 根據第一個參數來選擇不同的處理流程
case "${ENV_TYPE}" in
    k8s)
        ;;
    k3d)
        echo "啟動 k3d 環境"
        source ${KDE_SCRIPTS_PATH}/start/k3d/init.sh
        ;;
    *)
        echo "啟動 kind 環境"
        source ${KDE_SCRIPTS_PATH}/start/kind/init.sh
        ;;
esac