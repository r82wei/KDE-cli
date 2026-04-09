#!/bin/bash
set -eo pipefail

# 測試 exec_script_in_container_with_project_no_tty 以及 KDE_MOUNT_CLI_N 的整合

echo "===== kde proj exec -v / --command 整合測試 ====="
echo ""

export KDE_PATH="/tmp/kde-test-volumes"
export ENVIROMENTS_PATH="${KDE_PATH}/environments"
export CUR_ENV="test-env"
export ENV_NAME="test-env"
export VOLUMES_DIR="volumes"
export DOCKER_NETWORK="kde-test"
export KUBECONFIG="${ENVIROMENTS_PATH}/${ENV_NAME}/kubeconfig/config"
export KDE_DEPLOY_ENV_IMAGE="test-image:latest"
export KDE_ENV_FILE="${KDE_PATH}/kde.env"

mkdir -p "${ENVIROMENTS_PATH}/${ENV_NAME}/volumes/test-project"
mkdir -p "${ENVIROMENTS_PATH}/${ENV_NAME}/kubeconfig"
touch "${ENVIROMENTS_PATH}/${ENV_NAME}/kubeconfig/config"
touch "${KDE_ENV_FILE}"
touch "${ENVIROMENTS_PATH}/${ENV_NAME}/.env"
cat > "${ENVIROMENTS_PATH}/${ENV_NAME}/k8s.env" << 'EOF'
ENV_NAME=test-env
EOF
cat > "${ENVIROMENTS_PATH}/${ENV_NAME}/volumes/test-project/project.env" << 'EOF'
PROJECT_NAME=test-project
DEVELOP_IMAGE=node:18
DEPLOY_IMAGE=nginx:latest
GIT_REPO_URL=https://github.com/example/repo.git
EOF
touch "${ENVIROMENTS_PATH}/${ENV_NAME}/volumes/test-project/.env"
touch "${HOME}/.netrc"

source "$(dirname "${BASH_SOURCE[0]}")/../scripts/utils/environment/k8s.sh"

TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0

docker() {
    if [[ "$1" == "run" ]]; then
        echo "DOCKER_ARGS: $*"
    fi
}

# 測試 1：exec_script_in_container_with_project_no_tty 應使用 -i 而非 -it
echo "測試 1：no-tty 版本應使用 -i 而非 -it"
echo "----------------------------------------"
TOTAL_TESTS=$((TOTAL_TESTS + 1))

output=$(exec_script_in_container_with_project_no_tty "test-project" "test-image" "ls -la" 2>&1)
echo "${output}"

if echo "${output}" | grep -q " -i " && \
   ! echo "${output}" | grep -q " -it " && \
   echo "${output}" | grep -q "ls -la"; then
    echo "✅ 通過：使用非互動式模式並傳遞指令"
    PASSED_TESTS=$((PASSED_TESTS + 1))
else
    echo "❌ 失敗：docker run 參數不正確"
    FAILED_TESTS=$((FAILED_TESTS + 1))
fi
echo ""

# 測試 2：KDE_MOUNT_CLI_N 應出現在 no-tty 版本的 docker run 中
echo "測試 2：KDE_MOUNT_CLI_N 應被 no-tty 版本接收"
echo "------------------------------------------------"
TOTAL_TESTS=$((TOTAL_TESTS + 1))

export KDE_MOUNT_CLI_1="/tmp/vol1:/mnt/vol1"
export KDE_MOUNT_CLI_2="/tmp/vol2:/mnt/vol2"

output=$(exec_script_in_container_with_project_no_tty "test-project" "test-image" "ls -la" 2>&1)
echo "${output}"

if echo "${output}" | grep -q "/tmp/vol1:/mnt/vol1" && \
   echo "${output}" | grep -q "/tmp/vol2:/mnt/vol2"; then
    echo "✅ 通過：CLI volume mount 正確傳遞到 no-tty 版本"
    PASSED_TESTS=$((PASSED_TESTS + 1))
else
    echo "❌ 失敗：CLI volume mount 未出現在 docker run 參數中"
    FAILED_TESTS=$((FAILED_TESTS + 1))
fi
unset KDE_MOUNT_CLI_1
unset KDE_MOUNT_CLI_2
echo ""

# 測試 3：KDE_MOUNT_CLI_N 也應被互動式版本接收（驗證現有機制）
echo "測試 3：KDE_MOUNT_CLI_N 應被互動式版本接收（現有機制）"
echo "--------------------------------------------------------"
TOTAL_TESTS=$((TOTAL_TESTS + 1))

export KDE_MOUNT_CLI_1="/tmp/vol3:/mnt/vol3"

output=$(exec_script_in_container_with_project "test-project" "test-image" "bash" 2>&1)
echo "${output}"

if echo "${output}" | grep -q "/tmp/vol3:/mnt/vol3"; then
    echo "✅ 通過：互動式版本也接收 KDE_MOUNT_CLI_N"
    PASSED_TESTS=$((PASSED_TESTS + 1))
else
    echo "❌ 失敗：互動式版本未接收 KDE_MOUNT_CLI_N"
    FAILED_TESTS=$((FAILED_TESTS + 1))
fi
unset KDE_MOUNT_CLI_1
echo ""

rm -rf "${KDE_PATH}"

echo "===== 測試完成 ====="
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
