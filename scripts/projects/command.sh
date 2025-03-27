#!/bin/bash

source ${KDE_SCRIPTS_PATH}/utils/project.sh
source ${KDE_SCRIPTS_PATH}/utils/projects.sh

# 定義顯示說明的函數
show_help() {
    echo "usage:"
    echo "  kde projects <command> 專案集合相關指令"
    echo ""
    echo "option:"
    echo "  fetch           透過 git url 抓取專案集合"
    echo "  link            連結專案集合"
}

show_fetch_help() {
    echo "usage:"
    echo "  kde projects fetch <git repo url> <git repo branch>  從 git 直接抓取 KDE 專案"
}


COMMAND=$1

if [[ -z "${COMMAND}" || "${COMMAND}" == "-h" || "${COMMAND}" == "--help" ]]; then
    show_help
    exit 1
fi

case "${COMMAND}" in
    fetch)
        PROJECTS_GIT_REPO_URL=$2
        PROJECTS_GIT_REPO_BRANCH=$3
        if [[ -z "${PROJECTS_GIT_REPO_URL}" || -z "${PROJECTS_GIT_REPO_BRANCH}" ]]; then
            show_fetch_help
            exit 1
        fi
        exit_if_env_not_exist ${CUR_ENV}
        fetch_projects ${PROJECTS_GIT_REPO_URL} ${PROJECTS_GIT_REPO_BRANCH}
        ;;
    link)
        create_projects_link
        ;;
    *)
        echo "不支援的指令: $1"
        show_help
        exit 1
        ;;
esac