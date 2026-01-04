#!/bin/bash

source ${KDE_SCRIPTS_PATH}/utils/k9s.sh

# 定義顯示說明的函數
show_help() {
    echo "usage: kde k9s [options]"
    echo ""
    echo "如果想要在單一環境使用自訂的 k9s 設定檔，請在 ${KDE_PATH}/environments/[env-name]/k9s 目錄下建立 config.yaml 檔案"
    echo "如果想要在全部環境使用自訂的 k9s 設定檔，請在 ${KDE_PATH}/k9s 目錄下建立 config.yaml 檔案"
    echo ""
    echo "options:"
    echo "  -p, --port <port>          透過 docker run --expose 將 k9s 指定的 port 對應到本機"
    echo "  -n, --namespace <ns>       指定要查看的 namespace"
    echo "  -h, --help                 顯示此幫助訊息"
    echo ""
    echo "example:"
    echo "  kde k9s                              # 查看所有 namespace"
    echo "  kde k9s -n test                      # 查看 test namespace"
    echo "  kde k9s --port 8080                  # 將 k9s 的 8080 port 對應到本機"
    echo "  kde k9s --port 8080 --namespace test # 組合使用多個參數"
}

if [[ $ENABLE_K9S == "false" ]]; then
    exit 0
fi

if [[ $(is_env_exist ${CUR_ENV}) == "false" ]]; then
    echo "請先建立 k8s 環境"
    exit 1
fi

# 初始化變數
K9S_PORT=""
K9S_NAMESPACE=""

# 解析參數
while [[ $# -gt 0 ]]; do
    case "$1" in
        --port|-p)
            K9S_PORT="$2"
            shift 2
            ;;
        --namespace|-n)
            K9S_NAMESPACE="$2"
            shift 2
            ;;
        --help|-h)
            show_help
            exit 0
            ;;
        *)
            echo "未知的參數: $1"
            show_help
            exit 1
            ;;
    esac
done

# 啟動 k9s
start_k9s "$K9S_PORT" "$K9S_NAMESPACE"