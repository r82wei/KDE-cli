#!/bin/bash
set -eo pipefail

# 測試 exec_k8s_node_no_tty 函式行為

echo "===== exec_k8s_node_no_tty 單元測試 ====="
echo ""

export K8S_CONTAINER_NAME="test-k8s-node"

source "$(dirname "${BASH_SOURCE[0]}")/../scripts/utils/environment/k8s.sh"

TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0

docker() {
    echo "DOCKER_ARGS: $*"
}

# 測試 1：應使用 -i 而非 -it，並傳入正確容器名稱與指令
echo "測試 1：exec_k8s_node_no_tty 應使用 -i 而非 -it"
echo "----------------------------------------------------"
TOTAL_TESTS=$((TOTAL_TESTS + 1))

output=$(exec_k8s_node_no_tty "ls -la /tmp" 2>&1)
echo "${output}"

if echo "${output}" | grep -q " -i " && \
   ! echo "${output}" | grep -q " -it " && \
   echo "${output}" | grep -q "test-k8s-node" && \
   echo "${output}" | grep -q "ls -la /tmp"; then
    echo "✅ 通過：使用非互動式模式執行指令"
    PASSED_TESTS=$((PASSED_TESTS + 1))
else
    echo "❌ 失敗：執行參數不正確"
    FAILED_TESTS=$((FAILED_TESTS + 1))
fi
echo ""

# 測試 2：包含空格的指令應正確傳遞
echo "測試 2：包含空格的指令應正確傳遞"
echo "------------------------------------"
TOTAL_TESTS=$((TOTAL_TESTS + 1))

output=$(exec_k8s_node_no_tty "kubectl get pods -n default" 2>&1)
echo "${output}"

if echo "${output}" | grep -q "kubectl get pods -n default"; then
    echo "✅ 通過：包含空格的指令正確傳遞"
    PASSED_TESTS=$((PASSED_TESTS + 1))
else
    echo "❌ 失敗：指令傳遞有誤"
    FAILED_TESTS=$((FAILED_TESTS + 1))
fi
echo ""

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
