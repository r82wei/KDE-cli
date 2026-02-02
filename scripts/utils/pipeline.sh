#!/bin/bash

# Pipeline 執行工具
# 支援快速 CICD 流程和自定義 Pipeline

# 快速 CICD 階段定義
readonly STANDARD_CICD_STAGES="build test release deploy"

# Pipeline 選項變數（全局變數，由 parse_pipeline_args 設置）
PIPELINE_FROM_STAGE=""
PIPELINE_TO_STAGE=""
PIPELINE_ONLY_STAGE=""
PIPELINE_MANUAL_MODE=false
REMAINING_ARGS=()

# 解析 Pipeline 階段列表
# 參數：
#   $1 - KDE_PIPELINE_STAGES 的值（空格或逗號分隔）
# 返回：標準化的階段列表（空格分隔）
parse_pipeline_stages() {
    local STAGES=$1
    
    # 如果未定義，返回空（使用標準流程）
    if [[ -z "${STAGES}" ]]; then
        echo ""
        return 0
    fi
    
    # 將逗號替換為空格，並去除多餘空格
    STAGES=$(echo "${STAGES}" | tr ',' ' ' | tr -s ' ')
    
    echo "${STAGES}"
}

# 檢查是否使用快速 CICD 流程
# 參數：
#   $1 - KDE_PIPELINE_STAGES 的值
# 返回：true 或 false
is_standard_cicd_pipeline() {
    local STAGES=$1
    
    if [[ -z "${STAGES}" ]]; then
        echo "true"
    else
        echo "false"
    fi
}

# 取得階段的腳本名稱
# 參數：
#   $1 - 階段名稱
#   $2 - 專案路徑
# 返回：腳本名稱（可能為空）
get_stage_script() {
    local STAGE=$1
    local PROJECT_PATH=$2
    
    # 將 stage 中的連字號轉換為底線（環境變數命名規則）
    local STAGE_VAR=$(echo "${STAGE}" | tr '-' '_')
    
    # 取得自訂腳本名稱
    local VAR_NAME="KDE_PIPELINE_STAGE_${STAGE_VAR}_SCRIPT"
    local CUSTOM_SCRIPT="${!VAR_NAME}"
    
    # 如果有自訂腳本，使用自訂腳本
    if [[ -n "${CUSTOM_SCRIPT}" ]]; then
        echo "${CUSTOM_SCRIPT}"
        return 0
    fi
    
    # 否則使用預設腳本名稱：{stage}.sh
    local DEFAULT_SCRIPT="${STAGE}.sh"
    
    # 檢查預設腳本是否存在
    if [[ -f "${PROJECT_PATH}/${DEFAULT_SCRIPT}" ]]; then
        echo "${DEFAULT_SCRIPT}"
    else
        # 腳本不存在，返回空
        echo ""
    fi
}

# 取得階段的 Docker 映像
# 參數：
#   $1 - 階段名稱
#   $2 - 預設映像
# 返回：映像名稱
get_stage_image() {
    local STAGE=$1
    local DEFAULT_IMAGE=$2
    
    # 將 stage 中的連字號轉換為底線（環境變數命名規則）
    local STAGE_VAR=$(echo "${STAGE}" | tr '-' '_')
    
    # 取得自訂映像名稱
    local VAR_NAME="KDE_PIPELINE_STAGE_${STAGE_VAR}_IMAGE"
    local CUSTOM_IMAGE="${!VAR_NAME}"
    
    # 如果有自訂映像，使用自訂映像
    if [[ -n "${CUSTOM_IMAGE}" ]]; then
        echo "${CUSTOM_IMAGE}"
    else
        # 否則使用預設映像（通常是 DEPLOY_IMAGE）
        echo "${DEFAULT_IMAGE}"
    fi
}

# 檢查階段是否應該跳過
# 參數：
#   $1 - 階段名稱
# 返回：true 或 false
is_stage_skip() {
    local STAGE=$1
    
    # 將 stage 中的連字號轉換為底線（環境變數命名規則）
    local STAGE_VAR=$(echo "${STAGE}" | tr '-' '_')
    
    # 取得跳過標記
    local VAR_NAME="KDE_PIPELINE_STAGE_${STAGE_VAR}_SKIP"
    local SKIP="${!VAR_NAME}"
    
    if [[ "${SKIP}" == "true" ]]; then
        echo "true"
    else
        echo "false"
    fi
}

# 過濾階段列表（根據 --from, --to, --only 選項）
# 參數：
#   $1 - 原始階段列表（空格分隔）
# 返回：過濾後的階段列表
filter_pipeline_stages() {
    local ALL_STAGES=$1
    local FILTERED_STAGES=""
    local IN_RANGE=false
    
    # 如果指定 --only，只返回該階段
    if [[ -n "${PIPELINE_ONLY_STAGE}" ]]; then
        echo "${PIPELINE_ONLY_STAGE}"
        return 0
    fi
    
    # 如果沒有指定 --from，則從頭開始
    if [[ -z "${PIPELINE_FROM_STAGE}" ]]; then
        IN_RANGE=true
    fi
    
    for STAGE in ${ALL_STAGES}; do
        # 檢查是否到達 --from 階段
        if [[ -n "${PIPELINE_FROM_STAGE}" && "${STAGE}" == "${PIPELINE_FROM_STAGE}" ]]; then
            IN_RANGE=true
        fi
        
        # 如果在範圍內，加入結果
        if [[ "${IN_RANGE}" == "true" ]]; then
            FILTERED_STAGES="${FILTERED_STAGES} ${STAGE}"
        fi
        
        # 檢查是否到達 --to 階段
        if [[ -n "${PIPELINE_TO_STAGE}" && "${STAGE}" == "${PIPELINE_TO_STAGE}" ]]; then
            break
        fi
    done
    
    echo "${FILTERED_STAGES}" | xargs
}

# 執行單一階段
# 參數：
#   $1 - 專案名稱
#   $2 - 階段名稱
#   $3 - 腳本名稱
#   $4 - Docker 映像
# 返回：執行狀態（0 成功，非 0 失敗）
execute_stage() {
    local PROJECT_NAME=$1
    local STAGE=$2
    local SCRIPT=$3
    local IMAGE=$4
    local PROJECT_PATH=${ENVIROMENTS_PATH}/${CUR_ENV}/${VOLUMES_DIR}/${PROJECT_NAME}
    
    echo ""
    echo "🔄 執行階段: ${STAGE}"
    echo "   📄 腳本: ${SCRIPT}"
    echo "   🐳 映像: ${IMAGE}"
    echo ""
    
    # 如果是手動模式，進入互動式環境
    if [[ "${PIPELINE_MANUAL_MODE}" == "true" ]]; then
        echo "🔧 手動模式：進入階段 ${STAGE} 的執行環境"
        echo "   提示：執行 ./${SCRIPT} 來手動運行腳本，或執行其他命令進行調試"
        echo "   退出環境後將自動進入下一階段（如果有的話）"
        echo ""
        exec_script_in_container_with_project_for_stage ${PROJECT_NAME} ${STAGE} ${IMAGE} "bash"
        local EXIT_CODE=$?
        echo ""
        echo "✅ 已退出階段 ${STAGE} 的執行環境"
        return 0
    fi
    
    # 載入上一階段的環境變數（如果存在 .pipeline.env）
    local PIPELINE_ENV_FILE="${PROJECT_PATH}/.pipeline.env"
    local LOAD_PIPELINE_ENV=""
    if [[ -f "${PIPELINE_ENV_FILE}" ]]; then
        LOAD_PIPELINE_ENV="source .pipeline.env 2>/dev/null || true; "
    fi
    
    # 執行腳本
    exec_script_in_container_with_project_for_stage ${PROJECT_NAME} ${STAGE} ${IMAGE} "${LOAD_PIPELINE_ENV}./${SCRIPT}"
    local EXIT_CODE=$?
    
    if [[ ${EXIT_CODE} -ne 0 ]]; then
        echo ""
        echo "❌ 階段 ${STAGE} 執行失敗（退出碼：${EXIT_CODE}）"
        return ${EXIT_CODE}
    fi
    
    echo ""
    echo "✅ 階段 ${STAGE} 執行完成"
    return 0
}

# 執行 Pipeline
# 參數：
#   $1 - 專案名稱
#   $2 - Pipeline 類型（build 或 deploy）
# 返回：執行狀態（0 成功，非 0 失敗）
execute_pipeline() {
    local PROJECT_NAME=$1
    local PIPELINE_TYPE=$2
    local PROJECT_PATH=${ENVIROMENTS_PATH}/${CUR_ENV}/${VOLUMES_DIR}/${PROJECT_NAME}
    
    # 載入專案環境變數
    source ${PROJECT_PATH}/project.env
    
    # 檢查是否使用自定義 Pipeline
    if [[ $(is_standard_cicd_pipeline "${KDE_PIPELINE_STAGES}") == "true" ]]; then
        # 使用快速流程
        execute_quick_pipeline ${PROJECT_NAME} ${PIPELINE_TYPE}
        return $?
    else
        # 使用自定義 Pipeline
        execute_custom_pipeline ${PROJECT_NAME}
        return $?
    fi
}

# 執行快速 CICD Pipeline
# 參數：
#   $1 - 專案名稱
#   $2 - Pipeline 類型（build 或 deploy）
# 返回：執行狀態（0 成功，非 0 失敗）
execute_quick_pipeline() {
    local PROJECT_NAME=$1
    local PIPELINE_TYPE=$2
    local PROJECT_PATH=${ENVIROMENTS_PATH}/${CUR_ENV}/${VOLUMES_DIR}/${PROJECT_NAME}
    
    echo ""
    echo "📋 執行快速 CICD Pipeline"
    echo ""
    
    # 標準階段：build deploy
    local ALL_STAGES="build deploy"
    
    # 過濾階段（根據 --from, --to, --only 選項）
    local STAGES=$(filter_pipeline_stages "${ALL_STAGES}")
    
    # 顯示將要執行的階段
    echo "📋 階段列表: ${STAGES}"
    if [[ -n "${PIPELINE_ONLY_STAGE}" ]]; then
        echo "   模式: 僅執行 ${PIPELINE_ONLY_STAGE}"
    elif [[ -n "${PIPELINE_FROM_STAGE}" || -n "${PIPELINE_TO_STAGE}" ]]; then
        [[ -n "${PIPELINE_FROM_STAGE}" ]] && echo "   從: ${PIPELINE_FROM_STAGE}"
        [[ -n "${PIPELINE_TO_STAGE}" ]] && echo "   到: ${PIPELINE_TO_STAGE}"
    fi
    [[ "${PIPELINE_MANUAL_MODE}" == "true" ]] && echo "   模式: 手動模式"
    echo ""
    
    # 執行每個階段
    local EXECUTED_COUNT=0
    for STAGE in ${STAGES}; do
        # 檢查是否跳過
        if [[ $(is_stage_skip ${STAGE}) == "true" ]]; then
            echo "⏭️  跳過階段: ${STAGE}"
            continue
        fi
        
        # 取得腳本名稱
        local SCRIPT=$(get_stage_script ${STAGE} ${PROJECT_PATH})
        
        # 如果腳本不存在，跳過
        if [[ -z "${SCRIPT}" ]]; then
            echo "⏭️  階段 ${STAGE} 的腳本不存在，跳過"
            continue
        fi
        
        # 取得映像名稱（預設使用 DEPLOY_IMAGE）
        local IMAGE=$(get_stage_image ${STAGE} ${DEPLOY_IMAGE})
        
        # 執行階段
        execute_stage ${PROJECT_NAME} ${STAGE} ${SCRIPT} ${IMAGE}
        local EXIT_CODE=$?
        
        EXECUTED_COUNT=$((EXECUTED_COUNT + 1))
        
        # 檢查是否失敗
        if [[ ${EXIT_CODE} -ne 0 ]]; then
            # 手動模式不算失敗
            if [[ "${PIPELINE_MANUAL_MODE}" == "true" ]]; then
                continue
            fi
            
            # 檢查是否啟用 Fail Fast
            if [[ "${KDE_DEVOPS_FAIL_FAST}" == "true" ]]; then
                echo ""
                echo "❌ Pipeline 執行失敗（Fail Fast 模式）"
                return ${EXIT_CODE}
            else
                echo ""
                echo "⚠️  階段 ${STAGE} 執行失敗，但繼續執行後續階段"
            fi
        fi
    done
    
    if [[ ${EXECUTED_COUNT} -eq 0 ]]; then
        echo "⚠️  沒有執行任何階段"
        return 0
    fi
    
    echo ""
    echo "✅ Pipeline 執行完成（執行了 ${EXECUTED_COUNT} 個階段）"
    return 0
}

# 執行自定義 Pipeline
# 參數：
#   $1 - 專案名稱
# 返回：執行狀態（0 成功，非 0 失敗）
execute_custom_pipeline() {
    local PROJECT_NAME=$1
    local PROJECT_PATH=${ENVIROMENTS_PATH}/${CUR_ENV}/${VOLUMES_DIR}/${PROJECT_NAME}
    
    echo ""
    echo "📋 執行自定義 Pipeline"
    echo ""
    
    # 解析階段列表
    local ALL_STAGES=$(parse_pipeline_stages "${KDE_PIPELINE_STAGES}")
    
    # 過濾階段（根據 --from, --to, --only 選項）
    local STAGES=$(filter_pipeline_stages "${ALL_STAGES}")
    
    # 顯示將要執行的階段
    echo "📋 階段列表: ${STAGES}"
    if [[ -n "${PIPELINE_ONLY_STAGE}" ]]; then
        echo "   模式: 僅執行 ${PIPELINE_ONLY_STAGE}"
    elif [[ -n "${PIPELINE_FROM_STAGE}" || -n "${PIPELINE_TO_STAGE}" ]]; then
        [[ -n "${PIPELINE_FROM_STAGE}" ]] && echo "   從: ${PIPELINE_FROM_STAGE}"
        [[ -n "${PIPELINE_TO_STAGE}" ]] && echo "   到: ${PIPELINE_TO_STAGE}"
    fi
    [[ "${PIPELINE_MANUAL_MODE}" == "true" ]] && echo "   模式: 手動模式"
    echo ""
    
    # 執行每個階段
    local EXECUTED_COUNT=0
    for STAGE in ${STAGES}; do
        # 檢查是否跳過
        if [[ $(is_stage_skip ${STAGE}) == "true" ]]; then
            echo "⏭️  跳過階段: ${STAGE}"
            continue
        fi
        
        # 取得腳本名稱
        local SCRIPT=$(get_stage_script ${STAGE} ${PROJECT_PATH})
        
        # 如果腳本不存在，顯示錯誤
        if [[ -z "${SCRIPT}" ]]; then
            echo "❌ 階段 ${STAGE} 的腳本不存在"
            if [[ "${KDE_DEVOPS_FAIL_FAST}" == "true" ]]; then
                return 1
            else
                continue
            fi
        fi
        
        # 取得映像名稱（預設使用 DEPLOY_IMAGE）
        local IMAGE=$(get_stage_image ${STAGE} ${DEPLOY_IMAGE})
        
        # 執行階段
        execute_stage ${PROJECT_NAME} ${STAGE} ${SCRIPT} ${IMAGE}
        local EXIT_CODE=$?
        
        EXECUTED_COUNT=$((EXECUTED_COUNT + 1))
        
        # 檢查是否失敗
        if [[ ${EXIT_CODE} -ne 0 ]]; then
            # 手動模式不算失敗
            if [[ "${PIPELINE_MANUAL_MODE}" == "true" ]]; then
                continue
            fi
            
            # 檢查是否啟用 Fail Fast
            if [[ "${KDE_DEVOPS_FAIL_FAST}" == "true" ]]; then
                echo ""
                echo "❌ Pipeline 執行失敗（Fail Fast 模式）"
                
                # 檢查是否需要自動回滾（僅針對 deploy 相關階段）
                if [[ "${KDE_DEVOPS_AUTO_ROLLBACK}" == "true" && "${STAGE}" == *"deploy"* ]]; then
                    echo ""
                    echo "🔄 自動回滾中..."
                    # 這裡可以加入回滾邏輯
                fi
                
                return ${EXIT_CODE}
            else
                echo ""
                echo "⚠️  階段 ${STAGE} 執行失敗，但繼續執行後續階段"
            fi
        fi
    done
    
    if [[ ${EXECUTED_COUNT} -eq 0 ]]; then
        echo "⚠️  沒有執行任何階段"
        return 0
    fi
    
    echo ""
    echo "✅ Pipeline 執行完成（執行了 ${EXECUTED_COUNT} 個階段）"
    return 0
}

# 相容性函數：執行標準的 build 流程（pre-build, build, post-build）
# 這個函數用於向後相容，當沒有使用 Pipeline 機制時使用
# 參數：
#   $1 - 專案名稱
# 返回：執行狀態（0 成功，非 0 失敗）
execute_legacy_build() {
    local PROJECT_NAME=$1
    local PROJECT_PATH=${ENVIROMENTS_PATH}/${CUR_ENV}/${VOLUMES_DIR}/${PROJECT_NAME}
    
    source ${PROJECT_PATH}/project.env
    
    # 解析要執行的腳本
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
    
    # 執行腳本
    local EXECUTED=false
    
    if [[ -f ${PROJECT_PATH}/${PRE_BUILD_SCRIPT} ]]; then
        exec_script_in_container_with_project ${PROJECT_NAME} ${PRE_BUILD_IMAGE:-${DEVELOP_IMAGE}} ./${PRE_BUILD_SCRIPT}
        EXECUTED=true
    fi
    
    if [[ -f ${PROJECT_PATH}/${BUILD_SCRIPT} ]]; then
        exec_script_in_container_with_project ${PROJECT_NAME} ${BUILD_IMAGE:-${DEVELOP_IMAGE}} ./${BUILD_SCRIPT}
        EXECUTED=true
    fi
    
    if [[ -f ${PROJECT_PATH}/${POST_BUILD_SCRIPT} ]]; then
        exec_script_in_container_with_project ${PROJECT_NAME} ${POST_BUILD_IMAGE:-${DEVELOP_IMAGE}} ./${POST_BUILD_SCRIPT}
        EXECUTED=true
    fi
    
    if [[ "${EXECUTED}" == "true" ]]; then
        echo "專案 ${PROJECT_NAME} 已建置完成"
    fi
    
    return 0
}

# 相容性函數：執行標準的 deploy 流程（pre-deploy, deploy, post-deploy）
# 這個函數用於向後相容，當沒有使用 Pipeline 機制時使用
# 參數：
#   $1 - 專案名稱
# 返回：執行狀態（0 成功，非 0 失敗）
execute_legacy_deploy() {
    local PROJECT_NAME=$1
    local PROJECT_PATH=${ENVIROMENTS_PATH}/${CUR_ENV}/${VOLUMES_DIR}/${PROJECT_NAME}
    
    source ${PROJECT_PATH}/project.env
    
    # 解析要執行的腳本
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
    
    # 執行腳本
    local EXECUTED=false
    
    if [[ -f ${PROJECT_PATH}/${PRE_DEPLOY_SCRIPT} ]]; then
        exec_script_in_container_with_project ${PROJECT_NAME} ${PRE_DEPLOY_IMAGE:-${DEPLOY_IMAGE}} ./${PRE_DEPLOY_SCRIPT}
        EXECUTED=true
    fi
    
    if [[ -f ${PROJECT_PATH}/${DEPLOY_SCRIPT} ]]; then
        exec_script_in_container_with_project ${PROJECT_NAME} ${DEPLOY_IMAGE} ./${DEPLOY_SCRIPT}
        EXECUTED=true
    fi
    
    if [[ -f ${PROJECT_PATH}/${POST_DEPLOY_SCRIPT} ]]; then
        exec_script_in_container_with_project ${PROJECT_NAME} ${POST_DEPLOY_IMAGE:-${DEPLOY_IMAGE}} ./${POST_DEPLOY_SCRIPT}
        EXECUTED=true
    fi
    
    if [[ "${EXECUTED}" == "true" ]]; then
        echo "專案 ${PROJECT_NAME} 已部署完成"
    fi
    
    return 0
}

# 解析 Pipeline 命令行參數
# 參數：
#   $@ - 所有命令行參數
# 副作用：設置全局變數 PIPELINE_FROM_STAGE, PIPELINE_TO_STAGE, PIPELINE_ONLY_STAGE, PIPELINE_MANUAL_MODE, REMAINING_ARGS
# 返回：狀態碼（0=成功, 1=錯誤, 2=顯示說明）
parse_pipeline_args() {
    # 重置所有 Pipeline 選項變數，確保不會從環境變數繼承
    PIPELINE_FROM_STAGE=""
    PIPELINE_TO_STAGE=""
    PIPELINE_ONLY_STAGE=""
    PIPELINE_MANUAL_MODE=false
    REMAINING_ARGS=()
    
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --from=*)
                PIPELINE_FROM_STAGE="${1#*=}"
                if [[ -z "${PIPELINE_FROM_STAGE}" ]]; then
                    echo "❌ 錯誤：--from 需要指定階段名稱" >&2
                    return 1
                fi
                shift
                ;;
            --from)
                if [[ -n "$2" && "$2" != --* ]]; then
                    PIPELINE_FROM_STAGE="$2"
                    shift 2
                else
                    echo "❌ 錯誤：--from 需要指定階段名稱" >&2
                    return 1
                fi
                ;;
            --to=*)
                PIPELINE_TO_STAGE="${1#*=}"
                if [[ -z "${PIPELINE_TO_STAGE}" ]]; then
                    echo "❌ 錯誤：--to 需要指定階段名稱" >&2
                    return 1
                fi
                shift
                ;;
            --to)
                if [[ -n "$2" && "$2" != --* ]]; then
                    PIPELINE_TO_STAGE="$2"
                    shift 2
                else
                    echo "❌ 錯誤：--to 需要指定階段名稱" >&2
                    return 1
                fi
                ;;
            --only=*)
                PIPELINE_ONLY_STAGE="${1#*=}"
                if [[ -z "${PIPELINE_ONLY_STAGE}" ]]; then
                    echo "❌ 錯誤：--only 需要指定階段名稱" >&2
                    return 1
                fi
                shift
                ;;
            --only)
                if [[ -n "$2" && "$2" != --* ]]; then
                    PIPELINE_ONLY_STAGE="$2"
                    shift 2
                else
                    echo "❌ 錯誤：--only 需要指定階段名稱" >&2
                    return 1
                fi
                ;;
            --manual)
                PIPELINE_MANUAL_MODE=true
                shift
                ;;
            -h|--help)
                show_pipeline_help
                return 2
                ;;
            *)
                REMAINING_ARGS+=("$1")
                shift
                ;;
        esac
    done
    
    # 驗證參數組合
    if [[ -n "${PIPELINE_ONLY_STAGE}" && (-n "${PIPELINE_FROM_STAGE}" || -n "${PIPELINE_TO_STAGE}") ]]; then
        echo "❌ 錯誤：--only 不能與 --from 或 --to 一起使用" >&2
        return 1
    fi
    
    # 剩餘參數已存儲在全局變數 REMAINING_ARGS 中
    return 0
}

# 顯示 Pipeline 命令說明
show_pipeline_help() {
    echo "用法："
    echo "  kde [project|proj] pipeline <project_name> [options]"
    echo ""
    echo "描述："
    echo "  執行專案的 CICD Pipeline"
    echo ""
    echo "選項："
    echo "  --from <stage>    從指定階段開始執行（可與 --to 搭配使用）"
    echo "  --from=<stage>    等號語法"
    echo "  --to <stage>      執行到指定階段（可與 --from 搭配使用）"
    echo "  --to=<stage>      等號語法"
    echo "  --only <stage>    僅執行指定階段（不可與 --from/--to 一起使用）"
    echo "  --only=<stage>    等號語法"
    echo "  --manual          進入每個階段的執行環境手動測試"
    echo "  -h, --help        顯示此說明"
    echo ""
    echo "注意："
    echo "  - 所有選項都從命令行參數讀取，不會從環境變數繼承"
    echo "  - 支持空格和等號兩種語法：--only test 或 --only=test"
    echo ""
    echo "範例："
    echo "  # 執行完整 Pipeline"
    echo "  kde proj pipeline myapp"
    echo ""
    echo "  # 從 test 階段開始執行（兩種語法）"
    echo "  kde proj pipeline myapp --from test"
    echo "  kde proj pipeline myapp --from=test"
    echo ""
    echo "  # 只執行到 release 階段"
    echo "  kde proj pipeline myapp --to=release"
    echo ""
    echo "  # 只執行 test 階段"
    echo "  kde proj pipeline myapp --only=test"
    echo ""
    echo "  # 手動模式：進入每個階段環境"
    echo "  kde proj pipeline myapp --manual"
    echo ""
    echo "  # 從 build 到 test，手動模式"
    echo "  kde proj pipeline myapp --from=build --to=test --manual"
}
