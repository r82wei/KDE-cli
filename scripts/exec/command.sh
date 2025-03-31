#!/bin/bash

# 定義顯示說明的函數
show_help() {
    echo "usage:"
    echo "  kde exec [name]       啟動連結特定 k8s 的部署環境，如果沒有輸入環境名稱，預設使用 current.env 的環境"
}


# 根據第一個參數來選擇不同的處理流程
case "$1" in
    -h|--help)
        show_help
        ;;
    *)
        exit_if_env_not_exist ${1:-${CUR_ENV}}
        load_enviroment_env ${1:-${CUR_ENV}}
        exec_k8s_node
        ;;
esac