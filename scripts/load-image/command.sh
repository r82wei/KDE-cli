#!/bin/bash

# 定義顯示說明的函數
show_help() {
    echo "usage:"
    echo "  kde load-image <image> [env_name]       載入 docker image 到 k8s 環境，如果沒有輸入環境名稱，預設使用 current.env 的環境"
}

if [[ -z "${1}" ]]; then
    show_help
    exit 1
fi


# 根據第一個參數來選擇不同的處理流程
case "$1" in
    -h|--help)
        show_help
        ;;
    *)
        IMAGE=${1}
        ENV_NAME=${2:-${CUR_ENV}}

        echo "IMAGE: ${IMAGE}"
        echo "ENV_NAME: ${ENV_NAME}"
        exit_if_env_not_exist ${ENV_NAME}
        if [[ "${ENV_TYPE}" == "kind" ]]; then
            kind_load_image ${IMAGE} ${ENV_NAME}
        else
            echo "目前只支援 kind 環境"
        fi
        ;;
esac