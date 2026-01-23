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
    read -p "Is this project a git remote repo? (y/n): " IS_GIT_REMOTE_REPO
    if [[ ${IS_GIT_REMOTE_REPO} == "y" ]]; then
        set_git_repo ${PROJECT_NAME}
        source ${ENVIROMENTS_PATH}/${CUR_ENV}/${VOLUMES_DIR}/${PROJECT_NAME}/project.env
        REPO_PATH=${ENVIROMENTS_PATH}/${CUR_ENV}/${VOLUMES_DIR}/${PROJECT_NAME}/$(git_repo_name ${GIT_REPO_URL})
        download_git_repo ${PROJECT_NAME} ${GIT_REPO_URL} ${GIT_REPO_BRANCH} ${REPO_PATH}
    else
        echo "GIT_REPO_URL=./${PROJECT_NAME}" >> ${ENVIROMENTS_PATH}/${CUR_ENV}/${VOLUMES_DIR}/${PROJECT_NAME}/project.env
        echo "GIT_REPO_BRANCH=main" >> ${ENVIROMENTS_PATH}/${CUR_ENV}/${VOLUMES_DIR}/${PROJECT_NAME}/project.env
        REPO_PATH=${ENVIROMENTS_PATH}/${CUR_ENV}/${VOLUMES_DIR}/${PROJECT_NAME}/${PROJECT_NAME}
        mkdir -p ${REPO_PATH}
    fi
    read -p "請輸入專案開發(建置)環境 Image (執行 build.sh 的環境): " DEVELOP_IMAGE
    echo "DEVELOP_IMAGE=${DEVELOP_IMAGE}" >> ${ENVIROMENTS_PATH}/${CUR_ENV}/${VOLUMES_DIR}/${PROJECT_NAME}/project.env
    read -p "請輸入專案部署環境 Image (執行 deploy 相關 shell 的環境，預設為 ${KDE_DEPLOY_ENV_IMAGE}): " DEPLOY_IMAGE
    DEPLOY_IMAGE=${DEPLOY_IMAGE:-${KDE_DEPLOY_ENV_IMAGE}}
    echo "DEPLOY_IMAGE=${DEPLOY_IMAGE}" >> ${ENVIROMENTS_PATH}/${CUR_ENV}/${VOLUMES_DIR}/${PROJECT_NAME}/project.env
    # 匯出常用變數
    echo 'HELM_CONFIG_HOME=${PROJECT_PATH}/.helm/config' >> ${ENVIROMENTS_PATH}/${CUR_ENV}/${VOLUMES_DIR}/${PROJECT_NAME}/project.env
    echo 'HELM_CACHE_HOME=${PROJECT_PATH}/.helm/cache' >> ${ENVIROMENTS_PATH}/${CUR_ENV}/${VOLUMES_DIR}/${PROJECT_NAME}/project.env
    echo 'HELM_DATA_HOME=${PROJECT_PATH}/.helm/data' >> ${ENVIROMENTS_PATH}/${CUR_ENV}/${VOLUMES_DIR}/${PROJECT_NAME}/project.env
    echo 'HELM_PLUGINS=${PROJECT_PATH}/.helm/plugins' >> ${ENVIROMENTS_PATH}/${CUR_ENV}/${VOLUMES_DIR}/${PROJECT_NAME}/project.env
    init_project_deploy_script ${PROJECT_NAME}
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

init_project_deploy_script() {
    PROJECT_NAME=$1
    PROJECT_REPO_PATH=${ENVIROMENTS_PATH}/${CUR_ENV}/${VOLUMES_DIR}/${PROJECT_NAME}

    touch ${PROJECT_REPO_PATH}/build.sh
    chmod +x ${PROJECT_REPO_PATH}/build.sh
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

# 解析要執行的 CICD 腳本（支援自訂腳本）
# 參數：
#   $1 - 標準腳本名稱（如 build.sh）
#   $2 - 自訂腳本環境變數的值（如 ${KDE_PROJECT_BUILD_SCRIPT}）
#   $3 - 專案路徑
# 返回：實際要執行的腳本名稱（透過 echo 輸出）
resolve_cicd_script() {
    local STANDARD_SCRIPT=$1
    local CUSTOM_SCRIPT=$2
    local PROJECT_PATH=$3
    
    local RESOLVED_SCRIPT="${STANDARD_SCRIPT}"
    
    # 如果設定了自訂腳本
    if [[ -n "${CUSTOM_SCRIPT}" ]]; then
        # 檢查使用者是否已經加上 ./ 前綴，如果是，就把 ./ 去掉
        if [[ "${CUSTOM_SCRIPT}" == "./"* ]]; then
            CUSTOM_SCRIPT="${CUSTOM_SCRIPT#./}"
        fi
        # 檢查使用者是否已經加上 ${PROJECT_PATH} 前綴，如果是，就把 ${PROJECT_PATH} 前綴去掉
        if [[ "${CUSTOM_SCRIPT}" == "${PROJECT_PATH}/"* ]]; then
            CUSTOM_SCRIPT="${CUSTOM_SCRIPT#${PROJECT_PATH}/}"
        fi

        echo "CUSTOM_SCRIPT: ${CUSTOM_SCRIPT}" >&2
        
        # 檢查自訂腳本是否存在
        if [[ -f "${PROJECT_PATH}/${CUSTOM_SCRIPT}" ]]; then
            # Guardrail: 如果標準腳本也存在，給予警告
            if [[ -f "${PROJECT_PATH}/${STANDARD_SCRIPT}" && "${CUSTOM_SCRIPT}" != "${STANDARD_SCRIPT}" ]]; then
                echo "⚠️  警告：檢測到同時存在 ${STANDARD_SCRIPT} 和 ${CUSTOM_SCRIPT}" >&2
                echo "    將使用 project.env 中指定的: ${CUSTOM_SCRIPT}" >&2
                echo "    如果這不是預期行為，請移除 project.env 中的相關環境變數設定" >&2
                echo "" >&2
            fi
            RESOLVED_SCRIPT="${CUSTOM_SCRIPT}"
        else
            echo "❌ 錯誤：自訂腳本 ${CUSTOM_SCRIPT} 不存在" >&2
            echo "    請確認自訂腳本是否存在" >&2
            # 返回空字符串並標記錯誤
            echo ""
            return 1
        fi
    fi
    
    echo "${RESOLVED_SCRIPT}"
    return 0
}

# ============================================================================
# 自定義 Pipeline 系統
# ============================================================================

# 將階段名稱轉換為環境變數名稱格式（將 - 轉換為 _）
# 參數：$1 - 階段名稱
# 返回：轉換後的名稱
normalize_stage_name() {
    local STAGE_NAME=$1
    echo "${STAGE_NAME//-/_}"
}

# 取得階段的腳本路徑
# 參數：$1 - 階段名稱, $2 - 專案路徑
# 返回：腳本路徑
get_stage_script() {
    local STAGE_NAME=$1
    local PROJECT_PATH=$2
    local NORMALIZED_NAME=$(normalize_stage_name "${STAGE_NAME}")
    
    # 檢查 KDE_STAGE_{stage}_SCRIPT 環境變數
    local SCRIPT_VAR="KDE_STAGE_${NORMALIZED_NAME}_SCRIPT"
    local SCRIPT_PATH="${!SCRIPT_VAR}"
    
    # 如果未設定，使用預設的 {stage}.sh
    if [[ -z "${SCRIPT_PATH}" ]]; then
        SCRIPT_PATH="${STAGE_NAME}.sh"
    fi
    
    # 處理路徑前綴
    if [[ "${SCRIPT_PATH}" == "./"* ]]; then
        SCRIPT_PATH="${SCRIPT_PATH#./}"
    fi
    if [[ "${SCRIPT_PATH}" == "${PROJECT_PATH}/"* ]]; then
        SCRIPT_PATH="${SCRIPT_PATH#${PROJECT_PATH}/}"
    fi
    
    echo "${SCRIPT_PATH}"
}

# 取得階段的 Docker 映像
# 參數：$1 - 階段名稱
# 返回：Docker 映像名稱
get_stage_image() {
    local STAGE_NAME=$1
    local NORMALIZED_NAME=$(normalize_stage_name "${STAGE_NAME}")
    
    # 檢查 KDE_STAGE_{stage}_IMAGE 環境變數
    local IMAGE_VAR="KDE_STAGE_${NORMALIZED_NAME}_IMAGE"
    local IMAGE="${!IMAGE_VAR}"
    
    # 如果未設定，使用 DEPLOY_IMAGE
    if [[ -z "${IMAGE}" ]]; then
        IMAGE="${DEPLOY_IMAGE}"
    fi
    
    echo "${IMAGE}"
}

# 檢查階段是否應該被跳過
# 參數：$1 - 階段名稱
# 返回：true 或 false
should_skip_stage() {
    local STAGE_NAME=$1
    local NORMALIZED_NAME=$(normalize_stage_name "${STAGE_NAME}")
    
    # 檢查 KDE_STAGE_{stage}_SKIP 環境變數
    local SKIP_VAR="KDE_STAGE_${NORMALIZED_NAME}_SKIP"
    local SKIP="${!SKIP_VAR}"
    
    if [[ "${SKIP}" == "true" ]]; then
        echo "true"
    else
        echo "false"
    fi
}

# 執行單一 Pipeline 階段
# 參數：$1 - 專案名稱, $2 - 階段名稱, $3 - 專案路徑
# 返回：0 成功, 1 失敗, 2 跳過
execute_pipeline_stage() {
    local PROJECT_NAME=$1
    local STAGE_NAME=$2
    local PROJECT_PATH=$3
    
    local SCRIPT_PATH=$(get_stage_script "${STAGE_NAME}" "${PROJECT_PATH}")
    local IMAGE=$(get_stage_image "${STAGE_NAME}")
    local FULL_SCRIPT_PATH="${PROJECT_PATH}/${SCRIPT_PATH}"
    
    # 檢查是否應該跳過
    if [[ $(should_skip_stage "${STAGE_NAME}") == "true" ]]; then
        echo "⏭️  跳過階段: ${STAGE_NAME} (KDE_STAGE_${STAGE_NAME}_SKIP=true)"
        return 2
    fi
    
    # 檢查映像是否設定
    if [[ -z "${IMAGE}" ]]; then
        echo "⏭️  跳過階段: ${STAGE_NAME} (未設定 Docker 映像)"
        return 2
    fi
    
    # 檢查腳本是否存在
    if [[ ! -f "${FULL_SCRIPT_PATH}" ]]; then
        echo "⏭️  跳過階段: ${STAGE_NAME} (腳本 ${SCRIPT_PATH} 不存在)"
        return 2
    fi
    
    echo ""
    echo "🔄 執行階段: ${STAGE_NAME}"
    echo "   📄 腳本: ${SCRIPT_PATH}"
    echo "   🐳 映像: ${IMAGE}"
    echo ""
    
    # 執行腳本
    exec_script_in_container_with_project "${PROJECT_NAME}" "${IMAGE}" "./${SCRIPT_PATH}"
    local RESULT=$?
    
    if [[ ${RESULT} -ne 0 ]]; then
        echo "❌ 階段 ${STAGE_NAME} 執行失敗 (exit code: ${RESULT})"
        return 1
    fi
    
    echo "✅ 階段 ${STAGE_NAME} 執行完成"
    return 0
}

# 執行自定義 Pipeline
# 參數：$1 - 專案名稱, $2 - 專案路徑
# 返回：0 成功, 1 失敗
execute_custom_pipeline() {
    local PROJECT_NAME=$1
    local PROJECT_PATH=$2
    
    # 解析階段列表（支援空格或逗號分隔）
    local STAGES_STR="${KDE_PIPELINE_STAGES}"
    # 將逗號替換為空格
    STAGES_STR="${STAGES_STR//,/ }"
    # 轉換為陣列
    read -ra STAGES <<< "${STAGES_STR}"
    
    if [[ ${#STAGES[@]} -eq 0 ]]; then
        echo "❌ 錯誤：KDE_PIPELINE_STAGES 為空"
        return 1
    fi
    
    echo ""
    echo "🚀 執行自定義 Pipeline..."
    echo "📋 階段列表: ${STAGES[*]}"
    echo ""
    
    local EXECUTED_STAGES=()
    local FAILED_STAGE=""
    
    for STAGE in "${STAGES[@]}"; do
        # 移除前後空白
        STAGE=$(echo "${STAGE}" | xargs)
        
        if [[ -z "${STAGE}" ]]; then
            continue
        fi
        
        execute_pipeline_stage "${PROJECT_NAME}" "${STAGE}" "${PROJECT_PATH}"
        local RESULT=$?
        
        if [[ ${RESULT} -eq 1 ]]; then
            FAILED_STAGE="${STAGE}"
            
            # 檢查是否啟用 Fail Fast
            if [[ "${KDE_DEVOPS_FAIL_FAST}" == "true" ]]; then
                echo ""
                echo "🛑 Fail Fast 模式：Pipeline 已停止"
                
                # 檢查是否需要自動回滾
                if [[ "${KDE_DEVOPS_AUTO_ROLLBACK}" == "true" && "${STAGE}" == *"deploy"* ]]; then
                    echo "🔄 嘗試自動回滾..."
                    # 執行 undeploy 腳本（如果存在）
                    if [[ -f "${PROJECT_PATH}/undeploy.sh" ]]; then
                        exec_script_in_container_with_project "${PROJECT_NAME}" "${DEPLOY_IMAGE}" "./undeploy.sh"
                        echo "✅ 回滾完成"
                    else
                        echo "⚠️  未找到 undeploy.sh，跳過回滾"
                    fi
                fi
                
                return 1
            fi
        elif [[ ${RESULT} -eq 0 ]]; then
            EXECUTED_STAGES+=("${STAGE}")
        fi
    done
    
    echo ""
    if [[ -n "${FAILED_STAGE}" ]]; then
        echo "⚠️  Pipeline 完成，但有階段失敗"
        return 1
    else
        echo "✅ Pipeline 執行完成"
        echo "   已執行階段: ${EXECUTED_STAGES[*]}"
    fi
    
    return 0
}

# 檢查是否使用自定義 Pipeline
# 返回：true 或 false
is_custom_pipeline_enabled() {
    if [[ -n "${KDE_PIPELINE_STAGES}" ]]; then
        echo "true"
    else
        echo "false"
    fi
}

build_project() {
    PROJECT_NAME=$1
    PROJECT_PATH=${ENVIROMENTS_PATH}/${CUR_ENV}/${VOLUMES_DIR}/${PROJECT_NAME}

    pull_if_project_repo_not_exist ${PROJECT_NAME}
    source ${PROJECT_PATH}/project.env
    
    # 如果有專案本地 .env 檔案，也載入它
    if [[ -f "${PROJECT_PATH}/.env" ]]; then
        source ${PROJECT_PATH}/.env
    fi
    
    # 檢查是否使用自定義 Pipeline
    # 當使用自定義 Pipeline 時，build 階段會在 deploy_project 中一起執行
    if [[ $(is_custom_pipeline_enabled) == "true" ]]; then
        echo "ℹ️  使用自定義 Pipeline 模式，build 階段將在 deploy 時一起執行"
        echo "   如需單獨執行 build，請使用: kde project deploy ${PROJECT_NAME}"
        return 0
    fi
    
    # 標準 DevOps Loops 模式（向後相容）
    # 解析要執行的腳本，檢查返回狀態
    local PRE_BUILD_SCRIPT
    PRE_BUILD_SCRIPT=$(resolve_cicd_script "pre-build.sh" "${KDE_PROJECT_PRE_BUILD_SCRIPT}" "${PROJECT_PATH}")
    if [[ $? -ne 0 ]]; then
        echo "❌ 建置失敗：pre-build 腳本解析錯誤" >&2
        return 1
    fi
    
    local BUILD_SCRIPT
    BUILD_SCRIPT=$(resolve_cicd_script "build.sh" "${KDE_PROJECT_BUILD_SCRIPT}" "${PROJECT_PATH}")
    if [[ $? -ne 0 ]]; then
        echo "❌ 建置失敗：build 腳本解析錯誤" >&2
        return 1
    fi
    
    local POST_BUILD_SCRIPT
    POST_BUILD_SCRIPT=$(resolve_cicd_script "post-build.sh" "${KDE_PROJECT_POST_BUILD_SCRIPT}" "${PROJECT_PATH}")
    if [[ $? -ne 0 ]]; then
        echo "❌ 建置失敗：post-build 腳本解析錯誤" >&2
        return 1
    fi

    if [[ -f ${PROJECT_PATH}/${PRE_BUILD_SCRIPT} ]]; then
        exec_script_in_container_with_project ${PROJECT_NAME} ${PRE_BUILD_IMAGE:-${DEVELOP_IMAGE}} ./${PRE_BUILD_SCRIPT}
    fi
    if [[ -f ${PROJECT_PATH}/${BUILD_SCRIPT} ]]; then
        exec_script_in_container_with_project ${PROJECT_NAME} ${BUILD_IMAGE:-${DEVELOP_IMAGE}} ./${BUILD_SCRIPT}
    fi
    if [[ -f ${PROJECT_PATH}/${POST_BUILD_SCRIPT} ]]; then
        exec_script_in_container_with_project ${PROJECT_NAME} ${POST_BUILD_IMAGE:-${DEVELOP_IMAGE}} ./${POST_BUILD_SCRIPT}
    fi

    if [[ -f ${PROJECT_PATH}/${PRE_BUILD_SCRIPT} || -f ${PROJECT_PATH}/${BUILD_SCRIPT} || -f ${PROJECT_PATH}/${POST_BUILD_SCRIPT} ]]; then
        echo "專案 ${PROJECT_NAME} 已建置完成"
    fi
}

deploy_project() {
    PROJECT_NAME=$1
    PROJECT_PATH=${ENVIROMENTS_PATH}/${CUR_ENV}/${VOLUMES_DIR}/${PROJECT_NAME}

    pull_if_project_repo_not_exist ${PROJECT_NAME}
    source ${PROJECT_PATH}/project.env
    
    # 如果有專案本地 .env 檔案，也載入它
    if [[ -f "${PROJECT_PATH}/.env" ]]; then
        source ${PROJECT_PATH}/.env
    fi
    
    # 檢查是否使用自定義 Pipeline
    if [[ $(is_custom_pipeline_enabled) == "true" ]]; then
        execute_custom_pipeline "${PROJECT_NAME}" "${PROJECT_PATH}"
        return $?
    fi
    
    # 標準 DevOps Loops 模式（向後相容）
    # 解析要執行的腳本，檢查返回狀態
    local PRE_DEPLOY_SCRIPT
    PRE_DEPLOY_SCRIPT=$(resolve_cicd_script "pre-deploy.sh" "${KDE_PROJECT_PRE_DEPLOY_SCRIPT}" "${PROJECT_PATH}")
    if [[ $? -ne 0 ]]; then
        echo "❌ 部署失敗：pre-deploy 腳本解析錯誤" >&2
        return 1
    fi
    
    local DEPLOY_SCRIPT
    DEPLOY_SCRIPT=$(resolve_cicd_script "deploy.sh" "${KDE_PROJECT_DEPLOY_SCRIPT}" "${PROJECT_PATH}")
    if [[ $? -ne 0 ]]; then
        echo "❌ 部署失敗：deploy 腳本解析錯誤" >&2
        return 1
    fi
    
    local POST_DEPLOY_SCRIPT
    POST_DEPLOY_SCRIPT=$(resolve_cicd_script "post-deploy.sh" "${KDE_PROJECT_POST_DEPLOY_SCRIPT}" "${PROJECT_PATH}")
    if [[ $? -ne 0 ]]; then
        echo "❌ 部署失敗：post-deploy 腳本解析錯誤" >&2
        return 1
    fi
    
    if [[ -f ${PROJECT_PATH}/${PRE_DEPLOY_SCRIPT} ]]; then
        exec_script_in_container_with_project ${PROJECT_NAME} ${PRE_DEPLOY_IMAGE:-${DEPLOY_IMAGE}} ./${PRE_DEPLOY_SCRIPT}
    fi
    if [[ -f ${PROJECT_PATH}/${DEPLOY_SCRIPT} ]]; then
        exec_script_in_container_with_project ${PROJECT_NAME} ${DEPLOY_IMAGE} ./${DEPLOY_SCRIPT}
    fi
    if [[ -f ${PROJECT_PATH}/${POST_DEPLOY_SCRIPT} ]]; then
        exec_script_in_container_with_project ${PROJECT_NAME} ${POST_DEPLOY_IMAGE:-${DEPLOY_IMAGE}} ./${POST_DEPLOY_SCRIPT}
    fi

    if [[ -f ${PROJECT_PATH}/${PRE_DEPLOY_SCRIPT} || -f ${PROJECT_PATH}/${DEPLOY_SCRIPT} || -f ${PROJECT_PATH}/${POST_DEPLOY_SCRIPT} ]]; then
        echo "專案 ${PROJECT_NAME} 已部署完成"
    fi
}

undeploy_project() {
    PROJECT_NAME=$1

    exit_if_project_not_exist ${PROJECT_NAME}
    source ${ENVIROMENTS_PATH}/${CUR_ENV}/${VOLUMES_DIR}/${PROJECT_NAME}/project.env
    
    # 解析要執行的腳本，檢查返回狀態
    local PROJECT_PATH=${ENVIROMENTS_PATH}/${CUR_ENV}/${VOLUMES_DIR}/${PROJECT_NAME}
    local UNDEPLOY_SCRIPT
    UNDEPLOY_SCRIPT=$(resolve_cicd_script "undeploy.sh" "${KDE_PROJECT_UNDEPLOY_SCRIPT}" "${PROJECT_PATH}")
    if [[ $? -ne 0 ]]; then
        echo "❌ 解除部署失敗：undeploy 腳本解析錯誤" >&2
        return 1
    fi
    
    if [[ -f ${PROJECT_PATH}/${UNDEPLOY_SCRIPT} ]]; then
        exec_script_in_container_with_project ${PROJECT_NAME} ${UNDEPLOY_IMAGE:-${DEPLOY_IMAGE}} ./${UNDEPLOY_SCRIPT}
    else
        exec_script_in_deploy_env "kubectl delete ns ${PROJECT_NAME}"
    fi
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
    PORT=$2

    exit_if_project_not_exist ${PROJECT_NAME}
    source ${ENVIROMENTS_PATH}/${CUR_ENV}/${VOLUMES_DIR}/${PROJECT_NAME}/project.env
    REPO_NAME=$(git_repo_name ${GIT_REPO_URL})
    echo "REPO_NAME: ${REPO_NAME}"
    if [[ -z "${PORT}" ]]; then
        exec_script_in_container_with_project ${PROJECT_NAME} ${DEVELOP_IMAGE} "cd ${REPO_NAME} && bash"
    else
        exec_script_in_container_with_project_and_port ${PROJECT_NAME} ${DEVELOP_IMAGE} "cd ${REPO_NAME} && bash" ${PORT}
    fi
}

exec_project_deploy_container() {
    PROJECT_NAME=$1
    PORT=$2

    exit_if_project_not_exist ${PROJECT_NAME}
    source ${ENVIROMENTS_PATH}/${CUR_ENV}/${VOLUMES_DIR}/${PROJECT_NAME}/project.env
    if [[ -z "${PORT}" ]]; then
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