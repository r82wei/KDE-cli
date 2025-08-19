#!/bin/bash

source ${KDE_SCRIPTS_PATH}/utils/code-server.sh

# 定義顯示說明的函數
show_help() {
    echo "usage: kde code-server [option]"
    echo ""
    echo "example:"
    echo "  -d, --daemon        在背景執行"
    echo "  -p, --port          指定 code-server 的 port (預設為 8080)"
    echo "  -h, --help          顯示此幫助訊息"
}

DAEMON=false
PORT=8080

# 參數解析（支援任意順序的 -d 與 -p <port>）
while [[ $# -gt 0 ]]; do
    case "$1" in
        --daemon|-d)
            DAEMON=true
            shift
            ;;
        --port|-p)
            PORT="$2"
            if [[ -z "${PORT}" || ! ${PORT} =~ ^[0-9]+$ ]]; then
                echo "無效的 port：${PORT}"
                exit 1
            fi
            shift 2
            ;;
        --help|-h)
            show_help
            exit 0
            ;;
        *)
            echo "未知參數：$1"
            show_help
            exit 1
            ;;
    esac
done

read -p "請輸入 code-server 的 password: " PASSWORD
start_code_server ${PORT} ${DAEMON} ${PASSWORD}