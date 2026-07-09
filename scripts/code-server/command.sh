#!/bin/bash

source ${KDE_SCRIPTS_PATH}/utils/code-server.sh

# 定義顯示說明的函數
show_help() {
    echo "usage: kde code-server [option]"
    echo ""
    echo "example:"
    echo "  -d, --daemon        在背景執行"
    echo "  -p, --port          指定 code-server 的 port (預設為 8080)"
    echo "  -n, --name          指定 code-server 的容器名稱 (預設為 code-server，可用來同時啟動多個實例)"
    echo "  -v, --volume        指定掛載到 container 的目錄 (預設為當前路徑)"
    echo "  -w, --workdir       指定 code-server 開啟的資料夾 (預設與 --volume 相同，必須位於掛載目錄底下)"
    echo "  -h, --help          顯示此幫助訊息"
}

DAEMON=false
PORT=8080
NAME=code-server
MOUNT_PATH=""
OPEN_PATH=""

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
        --name|-n)
            NAME="$2"
            if [[ -z "${NAME}" || ! ${NAME} =~ ^[a-zA-Z0-9][a-zA-Z0-9_.-]*$ ]]; then
                echo "無效的名稱：${NAME}"
                exit 1
            fi
            shift 2
            ;;
        --volume|-v)
            MOUNT_PATH="$2"
            if [[ -z "${MOUNT_PATH}" ]]; then
                echo "無效的掛載路徑：${MOUNT_PATH}"
                exit 1
            fi
            shift 2
            ;;
        --workdir|-w)
            OPEN_PATH="$2"
            if [[ -z "${OPEN_PATH}" ]]; then
                echo "無效的開啟資料夾路徑：${OPEN_PATH}"
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
start_code_server ${PORT} ${DAEMON} ${NAME} "${MOUNT_PATH}" "${OPEN_PATH}"