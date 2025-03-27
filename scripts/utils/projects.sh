#!/bin/bash

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
    for PROJECT_NAME in $(ls ${PROJECTS_REPO_PATH}); do
        if [[ $(is_project_env_exist ${PROJECT_NAME}) == "false" ]]; then
            echo "專案 ${PROJECT_NAME} 設定檔(project.env) 不存在"
            continue
        fi

        source ${ENVIROMENTS_PATH}/${CUR_ENV}/${VOLUMES_DIR}/${PROJECT_NAME}/project.env

        # 如果 GIT_REPO_URL 是 ./ 開頭，則繼續迴圈
        if [[ ${GIT_REPO_URL} == "./"* ]]; then
            echo "專案 ${PROJECT_NAME} 使用本地專案"
            continue
        fi
        
        # 詢問使用者是否要下載 git repo
        read -p "是否要下載 ${PROJECT_NAME} 的 git repo？(y/n): " DOWNLOAD_GIT_REPO 
        if [[ ${DOWNLOAD_GIT_REPO} == "y" ]]; then
            download_git_repo ${PROJECT_NAME} ${GIT_REPO_URL} ${GIT_REPO_BRANCH} ${PROJECTS_REPO_PATH}/${PROJECT_NAME}/$(git_repo_name ${GIT_REPO_URL})
        fi
    done
}

download_projects_git_repo() {
    GIT_REPO_URL=$1
    GIT_REPO_BRANCH=$2
    REPO_PATH=$3

    if [[ -d ${REPO_PATH} ]]; then
        read -p "${REPO_PATH} 專案集合已存在，是否要刪除？(y/n): " DELETE_PROJECTS
        if [[ ${DELETE_PROJECTS} == "y" ]]; then
            rm -r ${REPO_PATH}
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