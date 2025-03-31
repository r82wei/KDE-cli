#!/bin/bash

source ${KDE_SCRIPTS_PATH}/utils/project.sh

# 定義顯示說明的函數
show_help() {
    echo "usage:"
    echo "  kde [project|proj|namespace|ns] <command> <project_name> [option]  專案相關指令"
    echo ""
    echo "command:"
    echo "  list, ls        列出專案"
    echo "  create          建立專案"
    echo "  link            連結專案"
    echo "  fetch           透過 git url 抓取專案"
    echo "  pull            透過 project.env 內的 git repo 設定重新抓取專案"
    echo "  deploy          部署專案"
    echo "  undeploy        卸載專案"
    echo "  redeploy        重新部署專案"
    echo "  remove, rm      刪除專案"
    echo "  exec            進入專案"
}

show_exec_help() {
    echo "usage:"
    echo "  kde [project|proj|namespace|ns] exec <project_name> [option]  進入專案相關環境 container"
    echo ""
    echo "option:"
    echo "  develop, dev        進入專案 DEVELOP_IMAGE 啟動的 container (default)"
    echo "  deploy, dep         進入專案 DEPLOY_IMAGE 啟動的 container"
}

show_fetch_help() {
    echo "usage:"
    echo "  kde [project|proj|namespace|ns] fetch <project_name> <git repo url> <git repo branch>  從 git 直接抓取 KDE 專案"
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
        check_project_name
        create_project ${PROJECT_NAME}
        ;;
    link)
        check_project_name
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
        pull_project ${PROJECT_NAME}
        ;;
    deploy)
        exit_if_env_not_running ${CUR_ENV}
        check_project_name
        deploy_project ${PROJECT_NAME}
        ;;
    undeploy)
        exit_if_env_not_running ${CUR_ENV}
        check_project_name
        undeploy_project ${PROJECT_NAME}
        ;;
    redeploy)
        exit_if_env_not_running ${CUR_ENV}
        check_project_name
        undeploy_project ${PROJECT_NAME}
        deploy_project ${PROJECT_NAME}
        ;;
    remove|rm)
        check_project_name
        remove_project ${PROJECT_NAME}
        ;;
    exec)
        check_project_name
        IMAGE_TYPE=$3
        if [[ "${IMAGE_TYPE}" == "-h" || "${IMAGE_TYPE}" == "--help" ]]; then
            show_exec_help
            exit 1
        fi
        case "${IMAGE_TYPE}" in
            deploy|dep)
                exit_if_env_not_running ${CUR_ENV}
                exec_project_deploy_container ${PROJECT_NAME}
                ;;
            develop|dev|"")
                exec_project_develop_container ${PROJECT_NAME}
                ;;
            *)
                show_exec_help
                exit 1
                ;;
        esac
        ;;
    *)
        echo "不支援的指令: $1"
        show_help
        exit 1
        ;;
esac