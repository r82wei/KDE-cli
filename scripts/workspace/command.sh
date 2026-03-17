#!/bin/bash

source ${KDE_SCRIPTS_PATH}/utils/workspace/workspace.sh

show_help() {
    echo "usage: kde workspace <command>"
    echo ""
    echo "管理 workspace（開發環境隔離空間）"
    echo ""
    echo "command:"
    echo "  status                      查看 workspace 狀態"
    echo "  info                        顯示 workspace 資訊"
    echo "  exec [command]              在 workspace 中執行指令"
    echo "  connect                     連線進入 workspace"
    if workspace_supports create; then
    echo "  create                      建立 workspace"
    fi
    if workspace_supports start; then
    echo "  start                       啟動 workspace"
    fi
    if workspace_supports stop; then
    echo "  stop                        停止 workspace"
    fi
    if workspace_supports delete; then
    echo "  delete [--force]            刪除 workspace"
    fi
    if workspace_supports snapshot; then
    echo "  snapshot create <tag>       建立快照"
    echo "  snapshot list               列出所有快照"
    echo "  snapshot restore <tag>      還原快照"
    fi
    if workspace_supports expose; then
    echo "  expose <guest_port> [host_port]  port 轉發"
    echo "  expose list                      列出轉發"
    echo "  expose stop <host_port>          停止轉發"
    echo "  expose stop-all                  停止所有轉發"
    fi
    echo ""
    echo "環境變數:"
    echo "  KDE_WORKSPACE_BACKEND       後端類型（預設 local）"
}

# For backends that need an instance name (lima, dind, etc.)
INSTANCE_NAME=""
if declare -f get_workspace_instance_name > /dev/null 2>&1; then
    INSTANCE_NAME=$(get_workspace_instance_name)
fi
WORKSPACE_PATH=${KDE_PATH}

COMMAND=$1

case "${COMMAND}" in
    create)
        workspace_create "${INSTANCE_NAME}" "${WORKSPACE_PATH}"
        ;;
    start)
        workspace_start "${INSTANCE_NAME}" "${WORKSPACE_PATH}"
        ;;
    stop)
        workspace_stop "${INSTANCE_NAME}"
        ;;
    delete)
        shift
        FORCE="false"
        if [[ "$1" == "--force" || "$1" == "-f" ]]; then
            FORCE="true"
        fi
        workspace_delete "${INSTANCE_NAME}" "${FORCE}"
        ;;
    exec)
        shift
        workspace_exec "${INSTANCE_NAME}" "$@"
        ;;
    connect)
        workspace_connect "${INSTANCE_NAME}"
        ;;
    status)
        workspace_status "${INSTANCE_NAME}"
        ;;
    info)
        workspace_info "${INSTANCE_NAME}"
        ;;
    expose)
        shift
        SUBCMD=$1
        case "${SUBCMD}" in
            list|ls)
                workspace_expose "${INSTANCE_NAME}" "list"
                ;;
            stop)
                shift
                workspace_expose "${INSTANCE_NAME}" "stop" "$1"
                ;;
            stop-all)
                workspace_expose "${INSTANCE_NAME}" "stop-all"
                ;;
            *)
                GUEST_PORT="${SUBCMD}"
                shift
                HOST_PORT="${1:-${GUEST_PORT}}"
                workspace_expose "${INSTANCE_NAME}" "${GUEST_PORT}" "${HOST_PORT}"
                ;;
        esac
        ;;
    snapshot)
        shift
        SUBCMD=$1
        case "${SUBCMD}" in
            create)
                shift
                workspace_snapshot "${INSTANCE_NAME}" "create" "$1"
                ;;
            list|ls)
                workspace_snapshot "${INSTANCE_NAME}" "list"
                ;;
            restore)
                shift
                workspace_snapshot "${INSTANCE_NAME}" "restore" "$1"
                ;;
            *)
                echo "usage: kde workspace snapshot <create|list|restore> [tag]"
                exit 1
                ;;
        esac
        ;;
    -h|--help|"")
        show_help
        ;;
    *)
        echo "未知的 workspace 指令: ${COMMAND}"
        echo "使用 kde workspace -h 查看說明"
        exit 1
        ;;
esac
