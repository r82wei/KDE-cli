#!/bin/bash

check_project_name() {
    if [[ -z "${PROJECT_NAME}" ]]; then
        read -p "請輸入專案名稱: " PROJECT_NAME
    fi
}

is_project_exist() {
    if [[ ! -d ${ENVIROMENTS_PATH}/${CUR_ENV}/${VOLUMES_DIR}/$1 ]]; then
        echo "false"
    else
        echo "true"
    fi
}

is_project_env_exist() {
    if [[ ! -f ${ENVIROMENTS_PATH}/${CUR_ENV}/${VOLUMES_DIR}/${PROJECT_NAME}/project.env ]]; then
        echo "false"
    else
        echo "true"
    fi
}

exit_if_project_exist() {
    PROJECT_NAME=$1
    if [[ $(is_project_exist ${PROJECT_NAME}) == "true" ]]; then
        echo "專案 ${1} 已存在"
        exit 1
    fi
}

exit_if_project_not_exist() {
    PROJECT_NAME=$1
    if [[ $(is_project_exist ${PROJECT_NAME}) == "false" ]]; then
        echo "專案 ${1} 不存在"
        exit 1
    fi
}

exit_if_project_env_not_exist() {
    PROJECT_NAME=$1
    if [[ $(is_project_env_exist ${PROJECT_NAME}) == "false" ]]; then
        echo "專案 ${PROJECT_NAME} 設定檔(project.env) 不存在"
        exit 1
    fi
}

load_project_env() {
    PROJECT_NAME=$1
    if [[ $(is_project_env_exist ${PROJECT_NAME}) == "true" ]]; then
        source ${ENVIROMENTS_PATH}/${CUR_ENV}/${VOLUMES_DIR}/${PROJECT_NAME}/project.env
    fi
}

# 建立專案資料夾、namespace
create_project() {
    PROJECT_NAME=$1
    exit_if_project_exist ${PROJECT_NAME}
    mkdir -p ${ENVIROMENTS_PATH}/${CUR_ENV}/${VOLUMES_DIR}/${PROJECT_NAME}
    read -p "Is this project a git repo? (y/n): " IS_GIT_REPO
    if [[ ${IS_GIT_REPO} == "y" ]]; then
        set_git_repo ${PROJECT_NAME}
        source ${ENVIROMENTS_PATH}/${CUR_ENV}/${VOLUMES_DIR}/${PROJECT_NAME}/project.env
        REPO_PATH=${ENVIROMENTS_PATH}/${CUR_ENV}/${VOLUMES_DIR}/${PROJECT_NAME}/$(git_repo_name ${GIT_REPO_URL})
        download_git_repo ${PROJECT_NAME} ${GIT_REPO_URL} ${GIT_REPO_BRANCH} ${REPO_PATH}
    else
        echo "GIT_REPO_URL=${PROJECT_NAME}" >> ${ENVIROMENTS_PATH}/${CUR_ENV}/${VOLUMES_DIR}/${PROJECT_NAME}/project.env
        echo "GIT_REPO_BRANCH=main" >> ${ENVIROMENTS_PATH}/${CUR_ENV}/${VOLUMES_DIR}/${PROJECT_NAME}/project.env
        REPO_PATH=${ENVIROMENTS_PATH}/${CUR_ENV}/${VOLUMES_DIR}/${PROJECT_NAME}/${PROJECT_NAME}
        mkdir -p ${REPO_PATH}
    fi
    read -p "請輸入專案執行(建置)環境 Image (執行 build.sh 的環境): " DEVELOP_IMAGE
    echo "DEVELOP_IMAGE=${DEVELOP_IMAGE}" >> ${ENVIROMENTS_PATH}/${CUR_ENV}/${VOLUMES_DIR}/${PROJECT_NAME}/project.env
    read -p "請輸入專案部署環境 Image (執行 deploy.sh 的環境): " DEPLOY_IMAGE
    echo "DEPLOY_IMAGE=${DEPLOY_IMAGE}" >> ${ENVIROMENTS_PATH}/${CUR_ENV}/${VOLUMES_DIR}/${PROJECT_NAME}/project.env
    init_project_deploy_script ${PROJECT_NAME}
    echo "專案 ${PROJECT_NAME} 已建立"
}

fetch_project() {
    PROJECT_NAME=$1
    PROJECT_GIT_REPO_URL=$2
    PROJECT_GIT_REPO_BRANCH=$3
    PROJECT_REPO_PATH=${ENVIROMENTS_PATH}/${CUR_ENV}/${VOLUMES_DIR}/${PROJECT_NAME}
    download_git_repo ${PROJECT_NAME} ${PROJECT_GIT_REPO_URL} ${PROJECT_GIT_REPO_BRANCH} ${PROJECT_REPO_PATH}
    pull_project ${PROJECT_NAME}
}

pull_project() {
    PROJECT_NAME=$1
    if [[ $(is_project_env_exist ${PROJECT_NAME}) == "false" ]]; then
        echo "專案 ${PROJECT_NAME} 設定檔(project.env) 不存在"
        return 1
    fi

    load_project_env ${PROJECT_NAME}

    # 如果 GIT_REPO_URL 是 ./ 開頭，則繼續迴圈
    if [[ ${GIT_REPO_URL} == "./"* ]]; then
        echo "專案 ${PROJECT_NAME} 使用本地專案"
        return 0
    fi
    
    PROJECT_REPO_PATH=${ENVIROMENTS_PATH}/${CUR_ENV}/${VOLUMES_DIR}/${PROJECT_NAME}
    download_git_repo ${PROJECT_NAME} ${GIT_REPO_URL} ${GIT_REPO_BRANCH} ${PROJECT_REPO_PATH}/$(git_repo_name ${GIT_REPO_URL})
}

init_project_deploy_script() {
    PROJECT_NAME=$1
    PROJECT_REPO_PATH=${ENVIROMENTS_PATH}/${CUR_ENV}/${VOLUMES_DIR}/${PROJECT_NAME}
    touch ${PROJECT_REPO_PATH}/build.sh
    chmod +x ${PROJECT_REPO_PATH}/build.sh
    touch ${PROJECT_REPO_PATH}/pre-deploy.sh
    chmod +x ${PROJECT_REPO_PATH}/pre-deploy.sh
    touch ${PROJECT_REPO_PATH}/deploy.sh
    chmod +x ${PROJECT_REPO_PATH}/deploy.sh
}

git_repo_name() {
    GIT_REPO_URL=$1
    echo $(basename -s .git ${GIT_REPO_URL})
}

set_git_repo() {
    PROJECT_NAME=$1
    exit_if_project_not_exist ${PROJECT_NAME}
    read -p "請輸入 git repo HTTPS URL: " GIT_REPO_URL
    echo "GIT_REPO_URL=${GIT_REPO_URL}" >> ${ENVIROMENTS_PATH}/${CUR_ENV}/${VOLUMES_DIR}/${PROJECT_NAME}/project.env
    read -p "請輸入分支名稱(default: main): " GIT_REPO_BRANCH
    echo "GIT_REPO_BRANCH=${GIT_REPO_BRANCH:-main}" >> ${ENVIROMENTS_PATH}/${CUR_ENV}/${VOLUMES_DIR}/${PROJECT_NAME}/project.env
}

download_git_repo() {
    PROJECT_NAME=$1
    GIT_REPO_URL=$2
    GIT_REPO_BRANCH=$3
    REPO_PATH=$4

    if [[ -d ${REPO_PATH} ]]; then
        read -p "${REPO_PATH} 專案已存在，是否要刪除？(y/n): " DELETE_PROJECT
        if [[ ${DELETE_PROJECT} == "y" ]]; then
            rm -rf ${REPO_PATH}
        else
            return 1
        fi
    fi

    # 下載 git repo
    git clone --recursive -b ${GIT_REPO_BRANCH} ${GIT_REPO_URL} ${REPO_PATH}
}

# 建立資料夾軟連結
create_link() {
    PROJECT_NAME=$1
    exit_if_project_not_exist ${PROJECT_NAME}
    read -p "請輸入資料夾路徑: " DIR_PATH
    if [[ ! -d ${DIR_PATH} ]]; then
        echo "資料夾 ${DIR_PATH} 不存在"
        exit 1
    fi
    # 透過資料夾路徑取得資料夾名稱
    DIR_NAME=$(basename ${DIR_PATH})
    ln -s ${DIR_PATH} ${ENVIROMENTS_PATH}/${CUR_ENV}/${VOLUMES_DIR}/${PROJECT_NAME}/${DIR_NAME}
}

deploy_project() {
    PROJECT_NAME=$1
    exit_if_project_not_exist ${PROJECT_NAME}
    source ${ENVIROMENTS_PATH}/${CUR_ENV}/${VOLUMES_DIR}/${PROJECT_NAME}/project.env
    if [[ $(is_namespace_exist ${PROJECT_NAME}) == "false" ]]; then
        create_namespace ${PROJECT_NAME}
    fi
    if [[ -f ${ENVIROMENTS_PATH}/${CUR_ENV}/${VOLUMES_DIR}/${PROJECT_NAME}/build.sh ]]; then
        exec_script_in_container_with_project ${PROJECT_NAME} ${DEVELOP_IMAGE} ./build.sh
    fi
    if [[ -f ${ENVIROMENTS_PATH}/${CUR_ENV}/${VOLUMES_DIR}/${PROJECT_NAME}/pre-deploy.sh ]]; then
        exec_script_in_container_with_project ${PROJECT_NAME} ${DEPLOY_IMAGE} ./pre-deploy.sh
    fi
    if [[ -f ${ENVIROMENTS_PATH}/${CUR_ENV}/${VOLUMES_DIR}/${PROJECT_NAME}/deploy.sh ]]; then
        exec_script_in_container_with_project ${PROJECT_NAME} ${DEPLOY_IMAGE} ./deploy.sh
    fi
    if [[ -f ${ENVIROMENTS_PATH}/${CUR_ENV}/${VOLUMES_DIR}/${PROJECT_NAME}/post-deploy.sh ]]; then
        exec_script_in_container_with_project ${PROJECT_NAME} ${DEPLOY_IMAGE} ./post-deploy.sh
    fi
    echo "專案 ${PROJECT_NAME} 已部署完成"
}

undeploy_project() {
    PROJECT_NAME=$1
    exec_script_in_deploy_env "kubectl delete ns ${PROJECT_NAME}"
    echo "專案 ${PROJECT_NAME} 已解除部署"
}

remove_project() {
    PROJECT_NAME=$1
    exit_if_project_not_exist ${PROJECT_NAME}
    if [[ $(is_env_running ${CUR_ENV}) == "true" ]]; then
        undeploy_project ${PROJECT_NAME}
    fi
    rm -rf ${ENVIROMENTS_PATH}/${CUR_ENV}/${VOLUMES_DIR}/${PROJECT_NAME}
    echo "專案 ${PROJECT_NAME} 已刪除"
}

exec_project_develop_container() {
    PROJECT_NAME=$1
    exit_if_project_not_exist ${PROJECT_NAME}
    source ${ENVIROMENTS_PATH}/${CUR_ENV}/${VOLUMES_DIR}/${PROJECT_NAME}/project.env
    REPO_NAME=$(git_repo_name ${GIT_REPO_URL})
    echo "REPO_NAME: ${REPO_NAME}"
    exec_script_in_container_with_project ${PROJECT_NAME} ${DEVELOP_IMAGE} "cd ${REPO_NAME} && bash"
}

exec_project_deploy_container() {
    PROJECT_NAME=$1
    exit_if_project_not_exist ${PROJECT_NAME}
    source ${ENVIROMENTS_PATH}/${CUR_ENV}/${VOLUMES_DIR}/${PROJECT_NAME}/project.env
    exec_script_in_container_with_project ${PROJECT_NAME} ${DEPLOY_IMAGE} bash
}
