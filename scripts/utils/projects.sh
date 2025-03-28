#!/bin/bash

has_any_project() {
    if [[ -z "$(ls -A ${ENVIROMENTS_PATH}/${CUR_ENV}/${VOLUMES_DIR} 2>/dev/null)" ]]; then
        echo "false"
    else
        echo "true"
    fi
}

is_projects_exist() {
    if [[ ! -d ${ENVIROMENTS_PATH}/${CUR_ENV}/${VOLUMES_DIR} ]]; then
        echo "false"
    else
        echo "true"
    fi
}

exit_if_projects_not_exist() {
    if [[ $(is_projects_exist) == "false" ]]; then
        echo "${VOLUMES_DIR} 專案集合不存在"
        exit 1
    fi
}

fetch_projects() {
    PROJECTS_GIT_REPO_URL=$1
    PROJECTS_GIT_REPO_BRANCH=$2
    PROJECTS_REPO_PATH=${ENVIROMENTS_PATH}/${CUR_ENV}/${VOLUMES_DIR}
    download_projects_git_repo ${PROJECTS_GIT_REPO_URL} ${PROJECTS_GIT_REPO_BRANCH} ${PROJECTS_REPO_PATH}
    pull_projects
}

pull_projects() {
    PROJECTS_REPO_PATH=${ENVIROMENTS_PATH}/${CUR_ENV}/${VOLUMES_DIR}
    for PROJECT_NAME in $(ls -d ${PROJECTS_REPO_PATH}/*/ 2>/dev/null | xargs -n 1 basename); do
        # 詢問使用者是否要下載 git repo
        read -p "是否要下載 ${PROJECT_NAME} 的 git repo？(y/n): " DOWNLOAD_GIT_REPO 
        if [[ ${DOWNLOAD_GIT_REPO} == "y" ]]; then
            pull_project ${PROJECT_NAME}
        fi
    done
}

download_projects_git_repo() {
    GIT_REPO_URL=$1
    GIT_REPO_BRANCH=$2
    REPO_PATH=$3

    if [[ -d ${REPO_PATH} && $(has_any_project) == "true" ]]; then
        read -p "${REPO_PATH} 專案集合已存在，是否要刪除？(y/n): " DELETE_PROJECTS
        if [[ ${DELETE_PROJECTS} == "y" ]]; then
            rm -rf ${REPO_PATH}
        else
            exit 1
        fi
    fi

    # 下載 git repo
    git clone --recursive -b ${GIT_REPO_BRANCH} ${GIT_REPO_URL} ${REPO_PATH}
}

# 建立資料夾軟連結
create_projects_link() {
    exit_if_projects_not_exist
    read -p "請輸入資料夾路徑: " DIR_PATH
    if [[ ! -d ${DIR_PATH} ]]; then
        echo "資料夾 ${DIR_PATH} 不存在"
        exit 1
    fi

    ln -s ${VOLUMES_DIR} ${ENVIROMENTS_PATH}/${CUR_ENV}/${VOLUMES_DIR}
}