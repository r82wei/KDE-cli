#!/bin/bash

source ${KDE_SCRIPTS_PATH}/utils/project.sh

# 定義顯示說明的函數
show_help() {
    echo "usage:"
    echo "  kde [project|proj] [command] <project_name> [options]  專案相關指令"
    echo ""
    echo "note:"
    echo "  專案名稱不應以 - 開頭，以避免與選項混淆"
    echo ""
    echo "command:"
    echo "  list, ls        列出專案"
    echo "  create          建立專案"
    echo "  link            連結專案"
    echo "  fetch           透過 git url 抓取專案"
    echo "  pull            透過 project.env 內的 git repo 設定更新專案（git pull）"
    echo "  build           建置專案"
    echo "  deploy          建置 & 部署專案"
    echo "  deploy-only     不執行建置，只部署專案"
    echo "  undeploy        卸載專案"
    echo "  redeploy        重新部署專案"
    echo "  tail            查看 pod 的 log，預設查看最後 100 行"
    echo "  remove, rm      刪除專案"
    echo "  exec            進入專案"
    echo "  ingress         建立 ingress"
    echo ""
    echo "options:"
    echo "  -h, --help              顯示說明"
    echo "  -f, --force             強制執行（用於 pull 指令）"
    echo "  -p, --port <port>       指定端口（用於 exec 指令）"
    echo "  --pod <pod_name>        指定 Pod 名稱（用於 tail 和 pod-exec 指令）"
    echo "  --tail <count>          指定顯示的日誌行數（用於 tail 指令）"
    echo "  --domain <domain>       指定域名（用於 ingress 指令）"
    echo "  --image-type <type>     指定映像類型：develop/dev/deploy/dep（用於 exec 指令）"
    echo "  --git-url <url>         指定 Git 倉庫 URL（用於 fetch 指令）"
    echo "  --branch <branch>       指定 Git 分支（用於 fetch 指令）"
}

show_exec_help() {
    echo "usage:"
    echo "  kde [project|proj] exec <project_name> [image_type] [port] [options]"
    echo ""
    echo "description:"
    echo "  進入專案相關環境 container"
    echo ""
    echo "image_type:"
    echo "  develop, dev        進入專案 DEVELOP_IMAGE 啟動的 container (default)"
    echo "  deploy, dep         進入專案 DEPLOY_IMAGE 啟動的 container"
    echo ""
    echo "options:"
    echo "  -h, --help              顯示說明"
    echo "  --image-type <type>     指定映像類型（與位置參數二選一）"
    echo "  -p, --port <port>       指定端口"
    echo ""
    echo "examples:"
    echo "  kde project exec myapp"
    echo "  kde project exec myapp develop 3000"
    echo "  kde project exec myapp --image-type deploy --port 8080"
    echo "  kde project exec myapp deploy --port 8080"
}

show_fetch_help() {
    echo "usage:"
    echo "  kde [project|proj] fetch <project_name> <git_url> <branch> [options]"
    echo ""
    echo "description:"
    echo "  從 git 直接抓取 KDE 專案"
    echo ""
    echo "options:"
    echo "  -h, --help              顯示說明"
    echo "  --git-url <url>         指定 Git 倉庫 URL（與位置參數二選一）"
    echo "  --branch <branch>       指定 Git 分支（與位置參數二選一）"
    echo ""
    echo "examples:"
    echo "  kde project fetch myapp https://github.com/user/repo.git main"
    echo "  kde project fetch myapp --git-url https://github.com/user/repo.git --branch main"
}


COMMAND=$1
if [[ -z "${COMMAND}" ]]; then
    show_help
    exit 1
fi
# 移除第一個參數（COMMAND）
shift 1

# 不需要 project_name 的指令
case "${COMMAND}" in
    ls|list)
        ls ${ENVIROMENTS_PATH}/${CUR_ENV}/${VOLUMES_DIR}
        exit 0
        ;;
    -h|--help)
        show_help
        exit 0
        ;;
esac

# 如果 $1 不是選項（不以 - 開頭），則作為 PROJECT_NAME
if [[ -n "$1" && "$1" != -* ]]; then
    PROJECT_NAME=$1
    shift 1
else
    PROJECT_NAME=""
fi

check_project_name ${PROJECT_NAME}

# 初始化變數
FORCE_FLAG=""
IMAGE_TYPE=""
PORT=""
TARGET_POD=""
TAIL_COUNT=""
PROJECT_GIT_REPO_URL=""
PROJECT_GIT_REPO_BRANCH=""
DOMAIN=""

# 解析 options
while [[ $# -gt 0 ]]; do
    case "$1" in
        -h|--help)
            case "${COMMAND}" in
                exec)
                    show_exec_help
                    ;;
                fetch)
                    show_fetch_help
                    ;;
                *)
                    show_help
                    ;;
            esac
            exit 0
            ;;
        -f|--force)
            FORCE_FLAG="--force"
            shift 1
            ;;
        -p|--port)
            PORT="$2"
            shift 2
            ;;
        --pod)
            TARGET_POD="$2"
            shift 2
            ;;
        --tail)
            TAIL_COUNT="$2"
            shift 2
            ;;
        --domain)
            DOMAIN="$2"
            shift 2
            ;;
        --image-type)
            IMAGE_TYPE="$2"
            shift 2
            ;;
        --git-url)
            PROJECT_GIT_REPO_URL="$2"
            shift 2
            ;;
        --branch)
            PROJECT_GIT_REPO_BRANCH="$2"
            shift 2
            ;;
        develop|dev|deploy|dep)
            # 支援作為位置參數的 image type
            if [[ -z "${IMAGE_TYPE}" ]]; then
                IMAGE_TYPE="$1"
            fi
            shift 1
            ;;
        -*)
            echo "未知選項: $1"
            show_help
            exit 1
            ;;
        *)
            # 支援位置參數
            if [[ "${COMMAND}" == "fetch" && -z "${PROJECT_GIT_REPO_URL}" ]]; then
                PROJECT_GIT_REPO_URL="$1"
            elif [[ "${COMMAND}" == "fetch" && -z "${PROJECT_GIT_REPO_BRANCH}" ]]; then
                PROJECT_GIT_REPO_BRANCH="$1"
            elif [[ "${COMMAND}" == "tail" && -z "${TARGET_POD}" ]]; then
                TARGET_POD="$1"
            elif [[ "${COMMAND}" == "tail" && -z "${TAIL_COUNT}" ]]; then
                TAIL_COUNT="$1"
            elif [[ "${COMMAND}" == "pod-exec" && -z "${TARGET_POD}" ]]; then
                TARGET_POD="$1"
            elif [[ "${COMMAND}" == "exec" && -z "${PORT}" ]]; then
                PORT="$1"
            fi
            shift 1
            ;;
    esac
done

case "${COMMAND}" in
    ls|list)
        ls ${ENVIROMENTS_PATH}/${CUR_ENV}/${VOLUMES_DIR}
        exit 0
        ;;
    create)
        check_project_name ${PROJECT_NAME}
        create_project ${PROJECT_NAME}
        ;;
    link)
        check_project_name ${PROJECT_NAME}
        create_link ${PROJECT_NAME}
        ;;
    fetch)
        check_project_name ${PROJECT_NAME}
        if [[ -z "${PROJECT_GIT_REPO_URL}" || -z "${PROJECT_GIT_REPO_BRANCH}" ]]; then
            show_fetch_help
            exit 1
        fi
        fetch_project ${PROJECT_NAME} ${PROJECT_GIT_REPO_URL} ${PROJECT_GIT_REPO_BRANCH}
        ;;
    pull)
        check_project_name ${PROJECT_NAME}
        pull_project_repo ${PROJECT_NAME} ${FORCE_FLAG}
        ;;
    build)
        check_project_name ${PROJECT_NAME}
        build_project ${PROJECT_NAME}
        ;;
    deploy)
        check_project_name ${PROJECT_NAME}
        build_project ${PROJECT_NAME}
        deploy_project ${PROJECT_NAME}
        ;;
    deploy-only)
        check_project_name ${PROJECT_NAME}
        deploy_project ${PROJECT_NAME}
        ;;
    undeploy)
        check_project_name ${PROJECT_NAME}
        undeploy_project ${PROJECT_NAME}
        ;;
    redeploy)
        check_project_name ${PROJECT_NAME}
        undeploy_project ${PROJECT_NAME}
        build_project ${PROJECT_NAME}
        deploy_project ${PROJECT_NAME}
        ;;
    tail)
        check_project_name ${PROJECT_NAME}
        select_pod ${PROJECT_NAME}
        tail_pod_logs ${PROJECT_NAME} ${TARGET_POD} ${TAIL_COUNT}
        ;;
    pod)
        check_project_name ${PROJECT_NAME}
        pods=($(get_pods ${PROJECT_NAME}))
        for pod in "${pods[@]}"; do
            echo "$pod"
        done
        ;;
    pod-exec)
        check_project_name ${PROJECT_NAME}
        if [[ -z "${TARGET_POD}" ]]; then
            select_pod ${PROJECT_NAME}
        fi
        exec_pod ${PROJECT_NAME} ${TARGET_POD}
        ;;
    remove|rm)
        check_project_name ${PROJECT_NAME}
        remove_project ${PROJECT_NAME}
        ;;
    exec)
        check_project_name ${PROJECT_NAME}
        case "${IMAGE_TYPE}" in
            deploy|dep)
                exec_project_deploy_container ${PROJECT_NAME} ${PORT}
                ;;
            develop|dev|"")
                exec_project_develop_container ${PROJECT_NAME} ${PORT}
                ;;
            *)
                show_exec_help
                exit 1
                ;;
        esac
        ;;
    ingress)
        check_project_name ${PROJECT_NAME}
        TARGET_NAMESPACE=${PROJECT_NAME}
        if [[ -z "${DOMAIN}" ]]; then
            read -p "請輸入 ingress 的 domain: " DOMAIN
        fi
        if [[ -z "${DOMAIN}" ]]; then
            echo "無效的 domain"
            exit 1
        fi
        INGRESS_NAME=${DOMAIN//./-}-ingress
        select_service ${TARGET_NAMESPACE}
        select_port ${TARGET_NAMESPACE} "service" ${TARGET_SERVICE}
        create_ingress ${TARGET_NAMESPACE} ${INGRESS_NAME} ${DOMAIN} ${TARGET_SERVICE} ${TARGET_PORT}
        echo "Ingress 已建立：${DOMAIN} -> ${TARGET_SERVICE}:${TARGET_PORT}"
        ;;
    *)
        echo "不支援的指令: ${COMMAND}"
        show_help
        exit 1
        ;;
esac