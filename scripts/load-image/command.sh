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

IMAGE=${1}
ENV_NAME=${2:-${CUR_ENV}}

# 根據環境類型來選擇不同的處理流程
case "${ENV_TYPE}" in
    k3d)
        k3d_load_image ${IMAGE} ${ENV_NAME}
        ;;
    kind)
        kind_load_image ${IMAGE} ${ENV_NAME}
        ;;
    k8s)
        echo "目前只支援 kind & k3d 環境"
        ;;
    *)
        show_help
        ;;
esac
