#!/bin/bash

source ${KDE_SCRIPTS_PATH}/utils/headlamp.sh

# 定義顯示說明的函數
show_help() {
    echo "usage: kde headlamp [-p port] [-d]"
    echo ""
    echo "options:"
    echo "  -p, --port          透過指定的 Port 啟動 K8S Headlamp (預設為 4466)"
    echo "  -d                  在背景執行"
    echo "  -h, --help          顯示此幫助訊息"
    echo ""
    echo "example:"
    echo "  kde headlamp                    # 在預設 port 4466 啟動"
    echo "  kde headlamp -p 8080            # 在 port 8080 啟動"
    echo "  kde headlamp -d                 # 在背景執行"
    echo "  kde headlamp -p 8080 -d         # 在 port 8080 背景執行"
}

if [[ $(is_env_exist ${CUR_ENV}) == "false" ]]; then
    echo "請先啟動 k8s 環境"
    exit 1
fi

# 預設值
PORT=4466
BACKGROUND=false

# 解析多個參數
while [[ $# -gt 0 ]]; do
    case "$1" in
        --help|-h)
            show_help
            exit 0
            ;;
        --port|-p)
            if [[ -z "$2" ]] || [[ "$2" == -* ]]; then
                echo "錯誤：--port 需要指定端口號"
                exit 1
            fi
            PORT="$2"
            shift 2
            ;;
        -d)
            BACKGROUND=true
            shift
            ;;
        *)
            echo "未知的參數：$1"
            show_help
            exit 1
            ;;
    esac
done

# 啟動 headlamp
start_headlamp "${PORT}" "${BACKGROUND}"