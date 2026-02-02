#!/bin/bash

# 測試 exec_script_in_container_with_project 整合
# 驗證函式是否正確支援可選的 STAGE 參數

echo "===== exec_script_in_container_with_project 整合測試 ====="
echo ""

# 設定測試環境變數
export KDE_PATH="/tmp/kde-test"
export ENVIROMENTS_PATH="${KDE_PATH}/environments"
export CUR_ENV="test-env"
export ENV_NAME="test-env"
export VOLUMES_DIR="volumes"
export DOCKER_NETWORK="kde-test"
export KUBECONFIG="${ENVIROMENTS_PATH}/${ENV_NAME}/kubeconfig/config"
export KDE_DEPLOY_ENV_IMAGE="test-image:latest"

# 建立測試目錄結構
mkdir -p "${ENVIROMENTS_PATH}/${ENV_NAME}/volumes/test-project"
cat > "${ENVIROMENTS_PATH}/${ENV_NAME}/volumes/test-project/project.env" << 'EOF'
PROJECT_NAME=test-project
DEVELOP_IMAGE=node:18
DEPLOY_IMAGE=nginx:latest
EOF

# 設定全局掛載
export KDE_MOUNT_1="/tmp/test1:/data1"
export KDE_MOUNT_2="/tmp/test2:/data2"

# 設定階段特定掛載
export KDE_PIPELINE_STAGE_build_MOUNT_1="/tmp/build1:/build1"
export KDE_PIPELINE_STAGE_build_MOUNT_2="/tmp/build2:/build2"
export KDE_PIPELINE_STAGE_test_MOUNT_1="/tmp/test-stage:/test-stage"

# 載入函式
source "$(dirname "${BASH_SOURCE[0]}")/../scripts/utils/environment/k8s.sh"

# 測試統計
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0

# 模擬 docker run 來測試參數
docker() {
    if [[ "$1" == "run" ]]; then
        echo "Docker 參數："
        for arg in "$@"; do
            if [[ "$arg" == -v* ]] || [[ "$arg" == /tmp/* ]]; then
                echo "  $arg"
            fi
        done
        return 0
    fi
}

# 測試 1：不帶 STAGE 參數（向後相容性測試）
echo "測試 1：不帶 STAGE 參數（應該只有全局掛載）"
echo "-----------------------------------------------"
TOTAL_TESTS=$((TOTAL_TESTS + 1))

output=$(exec_script_in_container_with_project "test-project" "test-image" "echo test" 2>&1)
echo "${output}"

if echo "${output}" | grep -q "/tmp/test1:/data1" && \
   echo "${output}" | grep -q "/tmp/test2:/data2" && \
   ! echo "${output}" | grep -q "/tmp/build1:/build1"; then
    echo "✅ 通過：只包含全局掛載"
    PASSED_TESTS=$((PASSED_TESTS + 1))
else
    echo "❌ 失敗：掛載參數不正確"
    FAILED_TESTS=$((FAILED_TESTS + 1))
fi
echo ""

# 測試 2：帶 STAGE 參數（build 階段）
echo "測試 2：帶 STAGE 參數 'build'（應該包含全局 + build 階段掛載）"
echo "---------------------------------------------------------------"
TOTAL_TESTS=$((TOTAL_TESTS + 1))

output=$(exec_script_in_container_with_project "test-project" "test-image" "echo test" "build" 2>&1)
echo "${output}"

if echo "${output}" | grep -q "/tmp/test1:/data1" && \
   echo "${output}" | grep -q "/tmp/test2:/data2" && \
   echo "${output}" | grep -q "/tmp/build1:/build1" && \
   echo "${output}" | grep -q "/tmp/build2:/build2" && \
   ! echo "${output}" | grep -q "/tmp/test-stage:/test-stage"; then
    echo "✅ 通過：包含全局掛載 + build 階段掛載"
    PASSED_TESTS=$((PASSED_TESTS + 1))
else
    echo "❌ 失敗：掛載參數不正確"
    FAILED_TESTS=$((FAILED_TESTS + 1))
fi
echo ""

# 測試 3：帶 STAGE 參數（test 階段）
echo "測試 3：帶 STAGE 參數 'test'（應該包含全局 + test 階段掛載）"
echo "--------------------------------------------------------------"
TOTAL_TESTS=$((TOTAL_TESTS + 1))

output=$(exec_script_in_container_with_project "test-project" "test-image" "echo test" "test" 2>&1)
echo "${output}"

if echo "${output}" | grep -q "/tmp/test1:/data1" && \
   echo "${output}" | grep -q "/tmp/test2:/data2" && \
   echo "${output}" | grep -q "/tmp/test-stage:/test-stage" && \
   ! echo "${output}" | grep -q "/tmp/build1:/build1"; then
    echo "✅ 通過：包含全局掛載 + test 階段掛載"
    PASSED_TESTS=$((PASSED_TESTS + 1))
else
    echo "❌ 失敗：掛載參數不正確"
    FAILED_TESTS=$((FAILED_TESTS + 1))
fi
echo ""

# 測試 4：直接使用新的呼叫方式（推薦）
echo "測試 4：直接使用新的呼叫方式（推薦）"
echo "----------------------------------------"
TOTAL_TESTS=$((TOTAL_TESTS + 1))

output=$(exec_script_in_container_with_project "test-project" "test-image" "echo test" "build" 2>&1)
echo "${output}"

if echo "${output}" | grep -q "/tmp/test1:/data1" && \
   echo "${output}" | grep -q "/tmp/build1:/build1"; then
    echo "✅ 通過：新的呼叫方式正確"
    PASSED_TESTS=$((PASSED_TESTS + 1))
else
    echo "❌ 失敗：新的呼叫方式不正確"
    FAILED_TESTS=$((FAILED_TESTS + 1))
fi
echo ""

# 測試 5：階段名稱包含連字號（應該轉換為底線）
echo "測試 5：階段名稱包含連字號 'pre-build'"
echo "----------------------------------------"
export KDE_PIPELINE_STAGE_pre_build_MOUNT_1="/tmp/pre-build:/pre-build"
TOTAL_TESTS=$((TOTAL_TESTS + 1))

output=$(exec_script_in_container_with_project "test-project" "test-image" "echo test" "pre-build" 2>&1)
echo "${output}"

if echo "${output}" | grep -q "/tmp/pre-build:/pre-build"; then
    echo "✅ 通過：連字號正確轉換為底線"
    PASSED_TESTS=$((PASSED_TESTS + 1))
else
    echo "❌ 失敗：連字號轉換失敗"
    FAILED_TESTS=$((FAILED_TESTS + 1))
fi
echo ""

# 清理測試環境
rm -rf "${KDE_PATH}"

# 測試結果
echo "===== 測試完成 ====="
echo ""
echo "總測試數：${TOTAL_TESTS}"
echo "通過：${PASSED_TESTS}"
echo "失敗：${FAILED_TESTS}"
echo ""

if [[ ${FAILED_TESTS} -eq 0 ]]; then
    echo "🎉 所有測試都通過了！"
    exit 0
else
    echo "❌ 有 ${FAILED_TESTS} 個測試失敗"
    exit 1
fi

