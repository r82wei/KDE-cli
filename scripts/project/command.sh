#!/bin/bash

source ${KDE_SCRIPTS_PATH}/utils/project.sh

# 定義顯示說明的函數
show_help() {
    echo "usage:"
    echo "  kde [project|proj] <command> <project_name> [option]  專案相關指令"
    echo ""
    echo "command:"
    echo "  list, ls            列出專案"
    echo "  create              建立專案"
    echo "  link                連結專案"
    echo "  fetch               透過 git url 抓取專案"
    echo "  pull                透過 project.env 內的 git repo 設定更新專案（git pull）"
    echo "                      使用 --force 或 -f 參數可刪除 repo 目錄並重新 clone"
    echo "  pipeline, deploy    執行自定義的 CICD Pipeline（支援 --from, --to, --only, --manual）"
    echo "  undeploy            解除部署專案"
    echo "  redeploy            重新部署專案 (解除部署後再執行 Pipeline)"
    echo "  tail                查看 pod 的 log，預設查看最後 100 行（--no-tty 供非互動式環境使用）"
    echo "  pod                 列出專案內所有的 pod"
    echo "  pod-exec [pod] [--command <script>]"
    echo "                      進入專案內指定的 pod；--command 供非互動式執行指定指令（AI agent 適用）"
    echo "  remove, rm          刪除專案"
    echo "  exec                進入專案 container"
    echo "  ingress             建立 ingress"
}

show_exec_help() {
    echo "usage:"
    echo "  kde project exec <project_name> [develop|deploy] [port] [-v host:container ...] [--command <script>]"
    echo ""
    echo "  進入專案開發或部署容器。"
    echo "  使用 -v 掛載多個額外 Volume，使用 --command 在非互動式模式下執行指定指令。"
    echo ""
    echo "  範例："
    echo "    kde proj exec myapp"
    echo "    kde proj exec myapp develop"
    echo "    kde proj exec myapp deploy 8080"
    echo "    kde proj exec myapp -v /local/path:/container/path"
    echo "    kde proj exec myapp develop -v /path1:/path1 -v /path2:/path2"
    echo "    kde proj exec myapp --command \"ls -la\""
    echo "    kde proj exec myapp deploy --command \"kubectl get pods\" -v /tmp:/tmp"
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
        list_projects | sed 's/^/  - /'
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
            projects=($(list_projects))
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
    pipeline|deploy)
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
        
        # 驗證專案是否存在
        exit_if_project_not_exist ${PROJECT_NAME}
        
        # 執行 Pipeline
        execute_pipeline ${PROJECT_NAME}
        ;;
    undeploy)
        # 檢查專案名稱（如果未提供，會跳出選單讓使用者選擇）
        check_project_name ${PROJECT_NAME}
        # 解除部署專案（undeploy_project 內部會檢查專案是否存在）
        undeploy_project ${PROJECT_NAME}
        ;;
    redeploy)
        # 檢查專案名稱（如果未提供，會跳出選單讓使用者選擇）
        check_project_name ${PROJECT_NAME}
        # 解除部署專案（undeploy_project 內部會檢查專案是否存在）
        undeploy_project ${PROJECT_NAME} || exit 1
        # 執行 Pipeline
        execute_pipeline ${PROJECT_NAME}
        ;;
    tail)
        # 解析 --no-tty 旗標（供 AI agent 等非互動式環境使用）
        NO_TTY=false
        TARGET_POD=$3
        TAIL_COUNT=$4

        # 掃描所有參數，找出 --no-tty 旗標
        for arg in "$@"; do
            if [[ "$arg" == "--no-tty" ]]; then
                NO_TTY=true
            fi
        done
        # 若 --no-tty 出現在位置參數中，清除對應位置
        [[ "${TARGET_POD}" == "--no-tty" ]] && TARGET_POD="" && TAIL_COUNT=""
        [[ "${TAIL_COUNT}" == "--no-tty" ]] && TAIL_COUNT=""

        if [[ -z "${PROJECT_NAME}" ]]; then
            check_project_name "${PROJECT_NAME}"
        fi

        if [[ -z "${TARGET_POD}" ]]; then
            if [[ "${NO_TTY}" == "true" ]]; then
                echo "錯誤：使用 --no-tty 模式時，必須提供 pod 名稱" >&2
                exit 1
            fi
            select_pod "${PROJECT_NAME}"
        fi

        if [[ "${NO_TTY}" == "true" ]]; then
            tail_pod_logs_no_tty "${PROJECT_NAME}" "${TARGET_POD}" "${TAIL_COUNT}"
        else
            tail_pod_logs "${PROJECT_NAME}" "${TARGET_POD}" "${TAIL_COUNT}"
        fi
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
        EXEC_COMMAND=""

        # 掃描所有參數，找出 --command 旗標
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
            fi
            i=$((i+1))
        done
        # 若 pod 名稱位置的參數是旗標，清除 TARGET_POD
        [[ "${TARGET_POD}" == "--command" ]] && TARGET_POD=""

        if [[ -n "${EXEC_COMMAND}" ]]; then
            if [[ -z "${TARGET_POD}" ]]; then
                echo "錯誤：使用 --command 時必須明確指定 pod 名稱" >&2
                exit 1
            fi
            exec_pod_no_tty "${PROJECT_NAME}" "${TARGET_POD}" "${EXEC_COMMAND}"
        else
            if [[ -z "${TARGET_POD}" ]]; then
                select_pod "${PROJECT_NAME}"
            fi
            exec_pod "${PROJECT_NAME}" "${TARGET_POD}"
        fi
        ;;
    remove|rm)
        check_project_name ${PROJECT_NAME}
        remove_project ${PROJECT_NAME}
        ;;
    exec)
        check_project_name ${PROJECT_NAME}
        IMAGE_TYPE=""
        PORT=""
        EXEC_COMMAND=""
        MOUNT_COUNT=0

        # 掃描所有參數，找出 image 類型、port、-v 掛載旗標與 --command 旗標
        args=("$@")
        i=2  # 跳過子命令（args[0]）與專案名稱（args[1]）
        while [[ $i -lt ${#args[@]} ]]; do
            if [[ "${args[$i]}" == "-h" || "${args[$i]}" == "--help" ]]; then
                show_exec_help
                exit 1
            elif [[ "${args[$i]}" == "-v" ]]; then
                i=$((i+1))
                if [[ $i -ge ${#args[@]} ]]; then
                    echo "錯誤：-v 需要一個掛載路徑參數（格式：host:container）" >&2
                    exit 1
                fi
                MOUNT_COUNT=$((MOUNT_COUNT+1))
                export KDE_MOUNT_CLI_${MOUNT_COUNT}="${args[$i]}"
            elif [[ "${args[$i]}" == "--command" ]]; then
                i=$((i+1))
                if [[ $i -ge ${#args[@]} ]]; then
                    echo "錯誤：--command 需要一個指令參數" >&2
                    exit 1
                fi
                EXEC_COMMAND="${args[$i]}"
            elif [[ -z "${IMAGE_TYPE}" && "${args[$i]}" =~ ^(deploy|dep|develop|dev)$ ]]; then
                IMAGE_TYPE="${args[$i]}"
            elif [[ -z "${PORT}" && "${args[$i]}" =~ ^[0-9]+$ ]]; then
                PORT="${args[$i]}"
            fi
            i=$((i+1))
        done

        case "${IMAGE_TYPE}" in
            deploy|dep)
                exec_project_deploy_container ${PROJECT_NAME} "${PORT}" "${EXEC_COMMAND}"
                ;;
            develop|dev|"")
                exec_project_develop_container ${PROJECT_NAME} "${PORT}" "${EXEC_COMMAND}"
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