#!/bin/bash

# 定義顯示說明的函數
show_help() {
    echo "usage:"
    echo "  kde exec [name]                        進入 k8s node container 環境，如果沒有輸入環境名稱，預設使用 current.env 的環境"
    echo "  kde exec [name] --command <command>    在 k8s node container 中執行指定指令（不使用 TTY）"
}

# 根據第一個參數來選擇不同的處理流程
case "$1" in
    -h|--help)
        show_help
        ;;
    *)
        ENV_NAME=""
        EXEC_COMMAND=""

        # 掃描所有參數，找出環境名稱與 --command 旗標
        args=("$@")
        i=0
        while [[ $i -lt ${#args[@]} ]]; do
            if [[ "${args[$i]}" == "--command" ]]; then
                i=$((i+1))
                if [[ $i -ge ${#args[@]} ]]; then
                    echo "錯誤：--command 需要一個指令參數" >&2
                    exit 1
                fi
                EXEC_COMMAND="${args[$i]}"
            elif [[ -z "${ENV_NAME}" && "${args[$i]}" != --* ]]; then
                ENV_NAME="${args[$i]}"
            fi
            i=$((i+1))
        done

        exit_if_env_not_exist ${ENV_NAME:-${CUR_ENV}}
        load_enviroment_env ${ENV_NAME:-${CUR_ENV}}

        if [[ -n "${EXEC_COMMAND}" ]]; then
            exec_k8s_node_no_tty "${EXEC_COMMAND}"
        else
            exec_k8s_node
        fi
        ;;
esac