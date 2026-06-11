#!/bin/bash

# 測試 kind-config.yaml 的環境變數渲染
# 驗證 k8s.env / .env 的變數能正確被 envsubst 替換到 kind-config.yaml
# (envsubst 只看得到 exported 的環境變數，load_enviroment_env 必須用 set -a 載入)

echo "===== kind-config 環境變數渲染測試 ====="
echo ""

TEST_ROOT=$(mktemp -d)
trap "rm -rf ${TEST_ROOT}" EXIT

# 模擬 kde.sh 的全域變數
export KDE_PATH=${TEST_ROOT}
export ENVIROMENTS_PATH=${KDE_PATH}/environments
export KDE_SCRIPTS_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")/../scripts" && pwd)"
export KUBE_CONFIG_DIR=kubeconfig
export VOLUMES_DIR=namespaces

# 載入被測腳本
source ${KDE_SCRIPTS_PATH}/utils/environment/k8s.sh
source ${KDE_SCRIPTS_PATH}/utils/environment/kind.sh

# 測試統計
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0

assert_contains() {
    local test_name=$1
    local file=$2
    local expected=$3
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    if grep -q "${expected}" "${file}"; then
        echo "  ✓ ${test_name}"
        PASSED_TESTS=$((PASSED_TESTS + 1))
    else
        echo "  ✗ ${test_name}"
        echo "    預期包含：${expected}"
        echo "    實際內容："
        grep -E "apiServerPort|hostPort" "${file}" | sed 's/^/      /'
        FAILED_TESTS=$((FAILED_TESTS + 1))
    fi
}

# 建立測試環境（模擬已存在 k8s.env 與 .env、但 kubeconfig 尚未建立的重新初始化情境）
setup_env() {
    ENV_NAME=$1
    export ENV_PATH=${ENVIROMENTS_PATH}/${ENV_NAME}
    mkdir -p ${ENV_PATH}
    cat > ${ENV_PATH}/k8s.env <<EOF
ENV_NAME=${ENV_NAME}
ENV_TYPE=kind
K8S_CONTAINER_NAME=${ENV_NAME}-control-plane
DOCKER_NETWORK=kde-${ENV_NAME}
STORAGE_CLASS=local-path
EOF
    cat > ${ENV_PATH}/.env <<EOF
VOLUMES_PATH=${ENV_PATH}/namespaces
K8S_API_SERVER_PORT=6443
K8S_INGRESS_NGINX_PORT=8088
EOF
}

echo "測試 1：重新初始化情境（kubeconfig 不存在、.env 已有 port 設定）使用預設模板"
(
    FAILED_TESTS=0
    setup_env env1
    load_enviroment_env env1
    init_kind_config > /dev/null
    assert_contains "apiServerPort 有值" ${ENV_PATH}/kind-config.yaml "apiServerPort: 6443"
    assert_contains "ingress hostPort 有值" ${ENV_PATH}/kind-config.yaml "hostPort: 8088"
    exit ${FAILED_TESTS}
)
FAILED_TESTS=$((FAILED_TESTS + $?))

echo ""
echo "測試 2：自訂模板引用 .env 與 KDE_PATH 變數"
(
    FAILED_TESTS=0
    setup_env env2
    cat > ${ENV_PATH}/kind-config.template.yaml <<'EOF'
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
name: ${ENV_NAME}
networking:
  apiServerPort: ${K8S_API_SERVER_PORT}
nodes:
  - role: control-plane
    extraPortMappings:
      - containerPort: 30080
        hostPort: ${K8S_INGRESS_NGINX_PORT}
        protocol: TCP
    extraMounts:
      - hostPath: ${KDE_PATH}/environments/env2/namespaces
        containerPath: /opt/local-path-provisioner
EOF
    load_enviroment_env env2
    init_kind_config > /dev/null
    assert_contains "apiServerPort 有值" ${ENV_PATH}/kind-config.yaml "apiServerPort: 6443"
    assert_contains "ingress hostPort 有值" ${ENV_PATH}/kind-config.yaml "hostPort: 8088"
    assert_contains "KDE_PATH 路徑有值" ${ENV_PATH}/kind-config.yaml "hostPath: ${KDE_PATH}/environments/env2/namespaces"
    exit ${FAILED_TESTS}
)
FAILED_TESTS=$((FAILED_TESTS + $?))

echo ""
echo "測試 3：修改 .env 設定後重新渲染要吃到新值"
(
    FAILED_TESTS=0
    setup_env env3
    load_enviroment_env env3
    init_kind_config > /dev/null
    sed -i 's/K8S_INGRESS_NGINX_PORT=8088/K8S_INGRESS_NGINX_PORT=9099/' ${ENV_PATH}/.env
    load_enviroment_env env3
    init_kind_config > /dev/null
    assert_contains "ingress hostPort 為新值" ${ENV_PATH}/kind-config.yaml "hostPort: 9099"
    exit ${FAILED_TESTS}
)
FAILED_TESTS=$((FAILED_TESTS + $?))

echo ""
echo "===== 測試結果 ====="
if [[ ${FAILED_TESTS} -eq 0 ]]; then
    echo "全部通過"
    exit 0
else
    echo "失敗：${FAILED_TESTS} 項"
    exit 1
fi
