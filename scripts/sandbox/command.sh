#!/bin/bash

source ${KDE_SCRIPTS_PATH}/utils/sandbox.sh

show_help() {
    echo "usage: kde sandbox <command>"
    echo ""
    echo "透過 microVM 提供工作區級別的系統隔離，支援多租戶開發和 AI Agent 安全沙箱。"
    echo ""
    echo "command:"
    echo "  start                       啟動 Sandbox microVM（將當前 workspace 掛載進 VM）"
    echo "  stop                        停止 Sandbox microVM"
    echo "  exec [command]              進入 Sandbox（預設使用 tmux），或執行指定指令"
    echo "  status                      查看 Sandbox 狀態"
    echo "  snapshot create <tag>       建立快照"
    echo "  snapshot list               列出所有快照"
    echo "  snapshot restore <tag>      還原快照"
    echo ""
    echo "環境變數:"
    echo "  KDE_SANDBOX_BACKEND         後端類型（預設 lima）"
    echo "  KDE_SANDBOX_CPUS            CPU 數量（預設 2）"
    echo "  KDE_SANDBOX_MEMORY          記憶體大小（預設 4GiB）"
    echo "  KDE_SANDBOX_DISK            磁碟大小（預設 50GiB）"
}

INSTANCE_NAME=$(get_sandbox_instance_name)
WORKSPACE_PATH=${KDE_PATH}

COMMAND=$1

case "${COMMAND}" in
    start)
        sandbox_start "${INSTANCE_NAME}" "${WORKSPACE_PATH}"
        ;;
    stop)
        sandbox_stop "${INSTANCE_NAME}"
        ;;
    exec)
        shift
        sandbox_exec "${INSTANCE_NAME}" "$@"
        ;;
    status)
        sandbox_status "${INSTANCE_NAME}"
        ;;
    snapshot)
        shift
        SUBCMD=$1
        case "${SUBCMD}" in
            create)
                shift
                sandbox_snapshot_create "${INSTANCE_NAME}" "$1"
                ;;
            list|ls)
                sandbox_snapshot_list "${INSTANCE_NAME}"
                ;;
            restore)
                shift
                sandbox_snapshot_restore "${INSTANCE_NAME}" "$1"
                ;;
            -h|--help|"")
                echo "usage: kde sandbox snapshot <command>"
                echo ""
                echo "command:"
                echo "  create <tag>     建立快照"
                echo "  list             列出所有快照"
                echo "  restore <tag>    還原快照"
                ;;
            *)
                echo "未知的 snapshot 子指令: ${SUBCMD}"
                echo "使用 kde sandbox snapshot -h 查看說明"
                exit 1
                ;;
        esac
        ;;
    -h|--help|"")
        show_help
        ;;
    *)
        echo "未知的 sandbox 指令: ${COMMAND}"
        echo "使用 kde sandbox -h 查看說明"
        exit 1
        ;;
esac
