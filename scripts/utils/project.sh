#!/bin/bash

list_projects() {
    ls ${ENVIROMENTS_PATH}/${CUR_ENV}/${VOLUMES_DIR}
}

check_project_name() {
    PROJECT_NAME=$1

    if [[ -z "${PROJECT_NAME}" ]]; then
        select_project
    fi
}

# 解析 kde proj pod-exec 專案名稱之後的參數（即 pod 名稱與旗標）。
# 輸出（全域變數）：
#   POD_EXEC_TARGET_POD  指定的 pod 名稱（未指定則為空，交由呼叫方決定互動選擇或報錯）
#   POD_EXEC_COMMAND     --command 指定的指令（未指定則為空）
# 第一個非旗標參數視為 pod 名稱；回傳非零代表參數錯誤（訊息已輸出至 stderr）。
parse_pod_exec_args() {
    POD_EXEC_TARGET_POD=""
    POD_EXEC_COMMAND=""

    local args=("$@")
    local i=0
    local seen_pod="false"
    while [[ $i -lt ${#args[@]} ]]; do
        case "${args[$i]}" in
            --command)
                i=$((i+1))
                if [[ $i -ge ${#args[@]} ]]; then
                    echo "錯誤：--command 需要一個指令參數" >&2
                    return 1
                fi
                POD_EXEC_COMMAND="${args[$i]}"
                ;;
            *)
                if [[ "${seen_pod}" == "false" ]]; then
                    POD_EXEC_TARGET_POD="${args[$i]}"
                    seen_pod="true"
                fi
                ;;
        esac
        i=$((i+1))
    done
    return 0
}

is_project_exist() {
    if [[ ! -d ${ENVIROMENTS_PATH}/${CUR_ENV}/${VOLUMES_DIR}/$1 ]]; then
        echo "false"
    else
        echo "true"
    fi
}

is_project_repo_exist() {
    PROJECT_NAME=$1

    if [[ ! -d ${ENVIROMENTS_PATH}/${CUR_ENV}/${VOLUMES_DIR}/${PROJECT_NAME}/$(git_repo_name ${GIT_REPO_URL}) ]]; then
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
        echo "❌ 錯誤：專案 '${PROJECT_NAME}' 不存在於當前環境 '${CUR_ENV}' 的 namespaces 內" >&2
        echo "" >&2
        echo "可用的專案列表：" >&2
        list_projects | sed 's/^/  - /' >&2
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
    local PROJECT_PATH=${ENVIROMENTS_PATH}/${CUR_ENV}/${VOLUMES_DIR}/${PROJECT_NAME}

    exit_if_project_exist ${PROJECT_NAME}
    mkdir -p ${PROJECT_PATH}
    read -p "是否需要從 Git 遠端倉庫抓取專案程式碼？(y/n): " IS_GIT_REMOTE_REPO
    if [[ ${IS_GIT_REMOTE_REPO} == "y" ]]; then
        set_git_repo ${PROJECT_NAME}
        source ${PROJECT_PATH}/project.env
        REPO_PATH=${ENVIROMENTS_PATH}/${CUR_ENV}/${VOLUMES_DIR}/${PROJECT_NAME}/$(git_repo_name ${GIT_REPO_URL})
        download_git_repo ${PROJECT_NAME} ${GIT_REPO_URL} ${GIT_REPO_BRANCH} ${REPO_PATH}
    else
        echo "GIT_REPO_URL=./${PROJECT_NAME}" >> ${PROJECT_PATH}/project.env
        echo "GIT_REPO_BRANCH=main" >> ${PROJECT_PATH}/project.env
        REPO_PATH=${ENVIROMENTS_PATH}/${CUR_ENV}/${VOLUMES_DIR}/${PROJECT_NAME}/${PROJECT_NAME}
        mkdir -p ${REPO_PATH}
    fi
    read -p "請輸入開發環境 Image（用於本地開發環境容器和 Pipeline build 階段，例如: node:20, python:3.11）: " DEVELOP_IMAGE
    echo "DEVELOP_IMAGE=${DEVELOP_IMAGE}" >> ${PROJECT_PATH}/project.env
    read -p "請輸入部署環境 Image（用於本地部署環境容器和 Pipeline deploy 階段，包含 kubectl/helm 等工具，預設為 ${KDE_DEPLOY_ENV_IMAGE}）: " DEPLOY_IMAGE
    DEPLOY_IMAGE=${DEPLOY_IMAGE:-${KDE_DEPLOY_ENV_IMAGE}}
    echo "DEPLOY_IMAGE=${DEPLOY_IMAGE}" >> ${PROJECT_PATH}/project.env
    # 匯出常用變數
    echo 'HELM_CONFIG_HOME=${PROJECT_PATH}/.helm/config' >> ${PROJECT_PATH}/project.env
    echo 'HELM_CACHE_HOME=${PROJECT_PATH}/.helm/cache' >> ${PROJECT_PATH}/project.env
    echo 'HELM_DATA_HOME=${PROJECT_PATH}/.helm/data' >> ${PROJECT_PATH}/project.env
    echo 'HELM_PLUGINS=${PROJECT_PATH}/.helm/plugins' >> ${PROJECT_PATH}/project.env
    # 配置快速 Pipeline 模式 (build → deploy)
    echo '' >> ${PROJECT_PATH}/project.env
    echo '# Pipeline 配置（快速模式：build → deploy）' >> ${PROJECT_PATH}/project.env
    echo 'KDE_PIPELINE_STAGES="build,deploy"' >> ${PROJECT_PATH}/project.env
    echo '' >> ${PROJECT_PATH}/project.env
    echo '# Build 階段配置' >> ${PROJECT_PATH}/project.env
    echo 'KDE_PIPELINE_STAGE_build_SCRIPT=build.sh' >> ${PROJECT_PATH}/project.env
    echo 'KDE_PIPELINE_STAGE_build_IMAGE=${DEVELOP_IMAGE}' >> ${PROJECT_PATH}/project.env
    echo '' >> ${PROJECT_PATH}/project.env
    echo '# Deploy 階段配置' >> ${PROJECT_PATH}/project.env
    echo 'KDE_PIPELINE_STAGE_deploy_SCRIPT=deploy.sh' >> ${PROJECT_PATH}/project.env
    echo 'KDE_PIPELINE_STAGE_deploy_IMAGE=${DEPLOY_IMAGE}' >> ${PROJECT_PATH}/project.env
    # 建立 build.sh 和 deploy.sh 檔案
    touch ${PROJECT_PATH}/build.sh
    chmod +x ${PROJECT_PATH}/build.sh
    touch ${PROJECT_PATH}/deploy.sh
    chmod +x ${PROJECT_PATH}/deploy.sh
    echo "專案 ${PROJECT_NAME} 已建立"
}

fetch_project() {
    PROJECT_NAME=$1
    PROJECT_GIT_REPO_URL=$2
    PROJECT_GIT_REPO_BRANCH=$3
    PROJECT_REPO_PATH=${ENVIROMENTS_PATH}/${CUR_ENV}/${VOLUMES_DIR}/${PROJECT_NAME}

    download_git_repo ${PROJECT_NAME} ${PROJECT_GIT_REPO_URL} ${PROJECT_GIT_REPO_BRANCH} ${PROJECT_REPO_PATH}
    pull_project_repo ${PROJECT_NAME}
}

pull_project_repo() {
    PROJECT_NAME=$1
    FORCE_FLAG=$2

    exit_if_project_not_exist ${PROJECT_NAME}
    exit_if_project_env_not_exist ${PROJECT_NAME}

    load_project_env ${PROJECT_NAME}

    # 檢查是否為本地專案 (是否為 ./ 開頭)
    if [[ ${GIT_REPO_URL} == "./"* ]]; then
        echo "專案 ${PROJECT_NAME} 使用本地專案，無法執行 pull 操作"
        return 0
    fi
    
    PROJECT_REPO_PATH=${ENVIROMENTS_PATH}/${CUR_ENV}/${VOLUMES_DIR}/${PROJECT_NAME}
    REPO_PATH=${PROJECT_REPO_PATH}/$(git_repo_name ${GIT_REPO_URL})
    
    # 處理 --force 參數：刪除現有 repository
    if [[ "${FORCE_FLAG}" == "--force" ]]; then
        if [[ -d ${REPO_PATH} ]]; then
            echo "使用強制模式：刪除 repository 目錄並重新 clone..."
            rm -rf ${REPO_PATH}
            echo "已刪除 repository 目錄：${REPO_PATH}"
        fi
    fi
    
    # 根據 repository 是否存在決定操作
    if [[ ! -d ${REPO_PATH} ]]; then
        # Repository 不存在：執行 clone
        echo "開始 clone repository..."
        download_git_repo ${PROJECT_NAME} ${GIT_REPO_URL} ${GIT_REPO_BRANCH} ${REPO_PATH}
    else
        # Repository 存在：執行 pull
        update_git_repo ${PROJECT_NAME} ${REPO_PATH} ${GIT_REPO_BRANCH}
    fi
}

pull_if_project_repo_not_exist() {
    PROJECT_NAME=$1

    load_project_env ${PROJECT_NAME}

    if [[ $(is_project_repo_exist ${PROJECT_NAME}) == "false" ]]; then
        pull_project_repo ${PROJECT_NAME}
    fi
}

git_repo_name() {
    GIT_REPO_URL=$1

    echo $(basename -s .git ${GIT_REPO_URL})
}

set_git_repo() {
    PROJECT_NAME=$1
    PROJECT_PATH=${ENVIROMENTS_PATH}/${CUR_ENV}/${VOLUMES_DIR}/${PROJECT_NAME}

    exit_if_project_not_exist ${PROJECT_NAME}
    read -p "請輸入 Git 倉庫網址 (支援 HTTPS 或 SSH，例如: https://github.com/user/repo.git 或 git@github.com:user/repo.git): " GIT_REPO_URL
    echo "GIT_REPO_URL=${GIT_REPO_URL}" >> ${PROJECT_PATH}/project.env
    read -p "請輸入分支名稱(default: main): " GIT_REPO_BRANCH
    echo "GIT_REPO_BRANCH=${GIT_REPO_BRANCH:-main}" >> ${PROJECT_PATH}/project.env
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

update_git_repo() {
    PROJECT_NAME=$1
    REPO_PATH=$2
    GIT_REPO_BRANCH=$3

    if [[ ! -d ${REPO_PATH} ]]; then
        echo "專案目錄 ${REPO_PATH} 不存在"
        return 1
    fi

    echo "正在更新專案 ${PROJECT_NAME}..."
    cd ${REPO_PATH}
    
    # 檢查是否為 git 倉庫
    if [[ ! -d .git ]]; then
        echo "錯誤：${REPO_PATH} 不是一個 git 倉庫"
        return 1
    fi
    
    # 檢查是否有未提交的修改
    if [[ -n $(git status --porcelain) ]]; then
        echo "錯誤：有未提交的修改，請先提交或 stash 後再執行 pull"
        echo ""
        git status --short
        return 1
    fi
    
    # 執行 git pull
    git fetch origin ${GIT_REPO_BRANCH}
    git checkout ${GIT_REPO_BRANCH}
    git pull origin ${GIT_REPO_BRANCH}
    
    if [[ $? -eq 0 ]]; then
        echo "專案 ${PROJECT_NAME} 已更新完成"
    else
        echo "專案 ${PROJECT_NAME} 更新失敗"
        return 1
    fi
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

undeploy_project() {
    PROJECT_NAME=$1

    exit_if_project_not_exist ${PROJECT_NAME}
    
    # 載入 Pipeline 工具函數
    source ${KDE_SCRIPTS_PATH}/utils/pipeline.sh
    
    # 載入專案環境變數
    local PROJECT_PATH=${ENVIROMENTS_PATH}/${CUR_ENV}/${VOLUMES_DIR}/${PROJECT_NAME}
    source ${PROJECT_PATH}/project.env
    
    # 使用 Pipeline 的腳本解析機制
    local UNDEPLOY_SCRIPT=$(get_stage_script "undeploy" ${PROJECT_PATH})
    
    # 如果 undeploy.sh 存在，使用 Pipeline 執行
    if [[ -n "${UNDEPLOY_SCRIPT}" ]]; then
        export PIPELINE_ONLY_STAGE="undeploy"
        execute_pipeline ${PROJECT_NAME}
        local EXIT_CODE=$?
        unset PIPELINE_ONLY_STAGE
        
        if [[ ${EXIT_CODE} -eq 0 ]]; then
            echo "專案 ${PROJECT_NAME} 已解除部署"
        fi
        return ${EXIT_CODE}
    else
        # 如果 undeploy.sh 不存在，根據環境類型執行預設動作
        if [[ "${ENV_TYPE}" == "kind" || "${ENV_TYPE}" == "k3d" ]]; then
            # 本地環境（kind/k3d）：執行預設動作刪除 namespace
            echo "⚠️  undeploy.sh 不存在，執行預設動作：刪除 namespace ${PROJECT_NAME}"
            exec_script_in_deploy_env "kubectl delete ns ${PROJECT_NAME}"
            local EXIT_CODE=$?
            if [[ ${EXIT_CODE} -ne 0 ]]; then
                echo "❌ 解除部署失敗（退出碼：${EXIT_CODE}）" >&2
                return ${EXIT_CODE}
            fi
            echo "專案 ${PROJECT_NAME} 已解除部署"
            return 0
        else
            # 外部 K8s 環境：不執行預設刪除動作，避免危險操作
            echo "❌ undeploy.sh 不存在且環境為外部 K8s (${ENV_TYPE})，為安全考量不執行預設刪除動作" >&2
            echo "   請建立 undeploy.sh 腳本來明確定義解除部署流程" >&2
            return 1
        fi
    fi
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
    PORT=$2
    COMMAND=$3  # 可選：指定要執行的指令（no-tty 模式）

    exit_if_project_not_exist ${PROJECT_NAME}
    source ${ENVIROMENTS_PATH}/${CUR_ENV}/${VOLUMES_DIR}/${PROJECT_NAME}/project.env
    REPO_NAME=$(git_repo_name ${GIT_REPO_URL})
    echo "REPO_NAME: ${REPO_NAME}"
    if [[ -n "${COMMAND}" ]]; then
        exec_script_in_container_with_project_no_tty ${PROJECT_NAME} ${DEVELOP_IMAGE} "cd ${REPO_NAME} && ${COMMAND}"
    elif [[ -z "${PORT}" ]]; then
        exec_script_in_container_with_project ${PROJECT_NAME} ${DEVELOP_IMAGE} "cd ${REPO_NAME} && bash"
    else
        exec_script_in_container_with_project_and_port ${PROJECT_NAME} ${DEVELOP_IMAGE} "cd ${REPO_NAME} && bash" ${PORT}
    fi
}

exec_project_deploy_container() {
    PROJECT_NAME=$1
    PORT=$2
    COMMAND=$3  # 可選：指定要執行的指令（no-tty 模式）

    exit_if_project_not_exist ${PROJECT_NAME}
    source ${ENVIROMENTS_PATH}/${CUR_ENV}/${VOLUMES_DIR}/${PROJECT_NAME}/project.env
    if [[ -n "${COMMAND}" ]]; then
        exec_script_in_container_with_project_no_tty ${PROJECT_NAME} ${DEPLOY_IMAGE} "${COMMAND}"
    elif [[ -z "${PORT}" ]]; then
        exec_script_in_container_with_project ${PROJECT_NAME} ${DEPLOY_IMAGE} bash
    else
        exec_script_in_container_with_project_and_port ${PROJECT_NAME} ${DEPLOY_IMAGE} bash ${PORT}
    fi
}

select_project() {
    TARGET_NAMESPACE=$1

    projects=($(list_projects))

    # 檢查是否存在
    if [ ${#projects[@]} -eq 0 ]; then
        echo "${ENVIROMENTS_PATH}/${CUR_ENV}/${VOLUMES_DIR} 目前沒有任何 project 存在。"
        exit 1
    fi

    PS3="請選擇一個 Project（輸入編號）："
    select project in "${projects[@]}" "退出"
    do
        case $project in
            "退出")
                echo "退出"
                exit 0
                ;;
            "")
                echo "無效選擇，請重新輸入。"
                ;;
            *)
                echo "你選擇了 Project: $project"
                export PROJECT_NAME=$project
                break
                ;;
        esac
    done
}