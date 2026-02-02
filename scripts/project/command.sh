#!/bin/bash

source ${KDE_SCRIPTS_PATH}/utils/project.sh

# 定義顯示說明的函數
show_help() {
    echo "usage:"
    echo "  kde [project|proj] <command> <project_name> [option]  專案相關指令"
    echo ""
    echo "command:"
    echo "  list, ls        列出專案"
    echo "  create          建立專案"
    echo "  link            連結專案"
    echo "  fetch           透過 git url 抓取專案"
    echo "  pull            透過 project.env 內的 git repo 設定更新專案（git pull）"
    echo "                  使用 --force 或 -f 參數可刪除 repo 目錄並重新 clone"
    echo "  build           建置專案 (預設 CICD pipeline 的 build 階段)"
    echo "  deploy          部署專案 (預設 CICD pipeline 的 deploy 階段)"
    echo "  redeploy        重新部署專案 (預設 CICD pipeline 的 deploy 階段)"
    echo "  pipeline        執行自定義的 CICD Pipeline（支援 --from, --to, --only, --manual）"
    echo "  undeploy        解除部署專案 (預設 CICD pipeline 的 undeploy 階段)"
    echo "  tail            查看 pod 的 log，預設查看最後 100 行"
    echo "  remove, rm      刪除專案"
    echo "  exec            進入專案 container"
    echo "  ingress         建立 ingress"
}

show_exec_help() {
    echo "usage:"
    echo "  kde [project|proj] exec <project_name> [option] [port] 進入專案相關環境 container"
    echo ""
    echo "option:"
    echo "  develop, dev        進入專案 DEVELOP_IMAGE 啟動的 container (default)"
    echo "  deploy, dep         進入專案 DEPLOY_IMAGE 啟動的 container"
    echo ""
    echo "port:                 專案使用的 port"
}

show_fetch_help() {
    echo "usage:"
    echo "  kde [project|proj] fetch <project_name> <git repo url> <git repo branch>  從 git 直接抓取 KDE 專案"
}


COMMAND=$1
PROJECT_NAME=$2

if [[ -z "${COMMAND}" || "${COMMAND}" == "-h" || "${COMMAND}" == "--help" ]]; then
    show_help
    exit 1
fi

case "${COMMAND}" in
    ls|list)
        ls ${ENVIROMENTS_PATH}/${CUR_ENV}/${VOLUMES_DIR}
        exit 0
        ;;
    create)
        if [[ -z "${PROJECT_NAME}" ]]; then
            read -p "請輸入專案名稱: " PROJECT_NAME
        fi
        create_project ${PROJECT_NAME}
        ;;
    link)
        check_project_name ${PROJECT_NAME}
        create_link ${PROJECT_NAME}
        ;;
    fetch)
        PROJECT_GIT_REPO_URL=$3
        PROJECT_GIT_REPO_BRANCH=$4
        if [[ -z "${PROJECT_GIT_REPO_URL}" || -z "${PROJECT_GIT_REPO_BRANCH}" ]]; then
            show_fetch_help
            exit 1
        fi
        fetch_project ${PROJECT_NAME} ${PROJECT_GIT_REPO_URL} ${PROJECT_GIT_REPO_BRANCH}
        ;;
    pull)
        FORCE_FLAG=""
        # 檢查是否有 --force 參數
        if [[ "$3" == "--force" || "$3" == "-f" ]]; then
            FORCE_FLAG="--force"
        elif [[ "$PROJECT_NAME" == "--force" || "$PROJECT_NAME" == "-f" ]]; then
            FORCE_FLAG="--force"
            PROJECT_NAME=""
        fi
        
        if [[ -z "${PROJECT_NAME}" ]]; then
            projects=($(kde project list))
            PS3="請選擇一個 project（輸入編號）："
            select PROJECT_NAME in "${projects[@]}" "退出"
            do
                case $PROJECT_NAME in
                    "退出")
                        echo "退出"
                        exit 0
                        ;;
                    "")
                        echo "無效選擇，請重新輸入。"
                        ;;
                    *)
                        echo "你選擇了: $PROJECT_NAME"
                        break
                        ;;
                esac
            done
        fi
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
        if [[ -z "${PROJECT_NAME}" ]]; then
            check_project_name ${PROJECT_NAME}
        fi
        TARGET_POD=$3
        if [[ -z "${TARGET_POD}" ]]; then
            select_pod ${PROJECT_NAME}
        fi
        TAIL_COUNT=$4
        tail_pod_logs ${PROJECT_NAME} ${TARGET_POD} ${TAIL_COUNT}
        ;;
    pod)
        if [[ -z "${PROJECT_NAME}" ]]; then
            check_project_name ${PROJECT_NAME}
        fi
        pods=($(get_pods ${PROJECT_NAME}))
        for pod in "${pods[@]}"; do
            echo "$pod"
        done
        ;;
    pod-exec)
        if [[ -z "${PROJECT_NAME}" ]]; then
            check_project_name ${PROJECT_NAME}
        fi
        TARGET_POD=$3
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
        IMAGE_TYPE=$3
        PORT=$4
        if [[ "${IMAGE_TYPE}" == "-h" || "${IMAGE_TYPE}" == "--help" ]]; then
            show_exec_help
            exit 1
        fi
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
    pipeline)
        # 載入 pipeline 工具
        source ${KDE_SCRIPTS_PATH}/utils/pipeline.sh
        
        # 重置 PROJECT_NAME，避免使用到前面 $2 的值
        PROJECT_NAME=""
        
        # 解析命令行參數（直接調用，不使用 $()，以便全局變數能正確設置）
        shift  # 移除 "pipeline" 指令
        parse_pipeline_args "$@"
        PARSE_EXIT_CODE=$?
        
        # 檢查參數解析結果
        if [[ ${PARSE_EXIT_CODE} -eq 2 ]]; then
            # 顯示了說明，正常退出
            exit 0
        elif [[ ${PARSE_EXIT_CODE} -ne 0 ]]; then
            # 參數錯誤
            exit 1
        fi
        
        # 從 REMAINING_ARGS（由 parse_pipeline_args 設置）中取得專案名稱
        if [[ ${#REMAINING_ARGS[@]} -gt 0 ]]; then
            PROJECT_NAME="${REMAINING_ARGS[0]}"
        fi
        
        # 檢查專案名稱（如果未提供，會跳出選單讓使用者選擇）
        check_project_name ${PROJECT_NAME}
        
        # 防呆檢查：驗證專案是否存在於當前環境的 namespaces 內
        if [[ $(is_project_exist ${PROJECT_NAME}) == "false" ]]; then
            echo "❌ 錯誤：專案 '${PROJECT_NAME}' 不存在於當前環境 '${CUR_ENV}' 的 namespaces 內" >&2
            echo "" >&2
            echo "可用的專案列表：" >&2
            kde project list | sed 's/^/  - /' >&2
            exit 1
        fi
        
        # 執行 Pipeline
        execute_pipeline ${PROJECT_NAME}
        ;;
    ingress)
        check_project_name ${PROJECT_NAME}
        TARGET_NAMESPACE=${PROJECT_NAME}
        read -p "請輸入 ingress 的 domain: " DOMAIN
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
        echo "不支援的指令: $1"
        show_help
        exit 1
        ;;
esac