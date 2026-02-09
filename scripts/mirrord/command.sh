#!/bin/bash

source ${KDE_SCRIPTS_PATH}/utils/project.sh
source ${KDE_SCRIPTS_PATH}/utils/mirrord.sh

# 定義顯示說明的函數
show_help() {
    echo "usage:"
    echo "  kde mirrord <command> --namespace|-n <namespace> --pod <pod>"
    echo ""
    echo "command:"
    echo "  list            列出指定 namespace 中可用的 Pod"
    echo "  mirror          鏡像 Pod 流量到本地（不干擾遠端）"
    echo "  steal           攔截 Pod 流量到本地（不干擾遠端）"
    echo "  connect         僅連線環境，不處理流量"
    echo "  clear           停止所有 Mirrord Session"
    echo ""
    echo "options:"
    echo "  --namespace, -n <namespace>    K8s namespace (必填，除非使用互動模式)"
    echo "  --pod <pod>                    Pod 名稱 (必填，除非使用互動模式)"
    echo ""
    echo "example:"
    echo "  kde mirrord mirror -n myapp --pod api-service-abc123"
    echo "  kde mirrord steal --pod worker-pod-xyz789 -n production"
    echo "  kde mirrord list -n staging"
    echo "  kde mirrord connect              # 互動模式"
    echo ""
    echo "互動模式："
    echo "  當不提供 --namespace 或 --pod 參數時，系統會進入互動模式"
    echo "  依序詢問 namespace 和 pod"
}

# 解析參數
COMMAND=$1
shift || true

NAMESPACE=""
POD=""

# 解析選項參數（順序可任意）
while [[ $# -gt 0 ]]; do
    case $1 in
        -n|--namespace)
            NAMESPACE="$2"
            shift 2
            ;;
        --pod)
            POD="$2"
            shift 2
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            echo "❌ 未知選項: $1"
            echo ""
            show_help
            exit 1
            ;;
    esac
done

# 處理不需要參數的指令
case "${COMMAND}" in
    "clear")
        stop_all_mirrord_containers
        exit 0
        ;;
    "-h"|"--help"|"")
        show_help
        exit 0
        ;;
esac

# list 指令處理
if [[ "${COMMAND}" == "list" ]]; then
    if [[ -z "${NAMESPACE}" ]]; then
        select_namespace
        NAMESPACE=${TARGET_NAMESPACE}
    fi
    list_pods ${NAMESPACE}
    exit 0
fi

# 其他指令需要 namespace 和 pod
# 互動模式：如果沒有提供 namespace
if [[ -z "${NAMESPACE}" ]]; then
    echo "請選擇 Namespace..."
    select_namespace
    NAMESPACE=${TARGET_NAMESPACE}
fi

# 互動模式：如果沒有提供 pod
if [[ -z "${POD}" ]]; then
    echo "請選擇目標 Pod..."
    select_pod ${NAMESPACE}
    # POD 會由 select_pod 函式設定
fi

# 驗證指令
case "${COMMAND}" in
    "mirror"|"steal"|"connect")
        # 有效指令，繼續執行
        ;;
    *)
        echo "❌ 未知指令: ${COMMAND}"
        echo ""
        show_help
        exit 1
        ;;
esac

# 選擇專案
echo ""
echo "請選擇要開發的專案..."
select_project ${NAMESPACE}

# 載入專案配置
load_project_env ${PROJECT_NAME}

# 提示使用者輸入啟動命令
prompt_user_command

# 組合 docker run 命令
build_mirrord_docker_command ${PROJECT_NAME} "${USER_COMMAND}"

# 設定模式
case "${COMMAND}" in
    "mirror")
        MODE="mirror"
        ;;
    "steal")
        MODE="steal"
        ;;
    "connect")
        MODE="off"
        ;;
esac

echo ""
echo "=========================================="
echo "Mirrord 連線資訊"
echo "=========================================="
echo "環境: ${CUR_ENV}"
echo "Namespace: ${NAMESPACE}"
echo "Pod: ${POD}"
echo "模式: ${COMMAND}"
echo "專案: ${PROJECT_NAME}"
echo "啟動命令: ${USER_COMMAND}"
echo "=========================================="
echo ""

# 執行 mirrord container（前台執行，會阻塞直到結束）
run_mirrord_container ${NAMESPACE} ${POD} "${DOCKER_CMD}" ${MODE}

echo ""
echo "✅ Mirrord 會話已結束"
