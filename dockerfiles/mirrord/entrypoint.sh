#!/bin/bash
set -e

# 清理函式
cleanup() {
    echo "---"
    echo ">>> Mirrord 會話結束"
    echo "---"
}

trap cleanup EXIT

echo "---"
echo ">>> Mirrord Container 啟動"
echo ">>> 目標 Namespace: ${MIRRORD_TARGET_NAMESPACE}"
echo ">>> 目標 Pod: ${MIRRORD_TARGET_POD}"
echo ">>> 工作模式: ${MIRRORD_MODE:-mirror}"
echo "---"

# 驗證必要的環境變數
if [[ -z "${MIRRORD_TARGET_NAMESPACE}" ]] || [[ -z "${MIRRORD_TARGET_POD}" ]] || [[ -z "${CONTAINER_COMMAND}" ]]; then
    echo "❌ 錯誤：缺少必要的環境變數"
    echo "   MIRRORD_TARGET_NAMESPACE: ${MIRRORD_TARGET_NAMESPACE}"
    echo "   MIRRORD_TARGET_POD: ${MIRRORD_TARGET_POD}"
    echo "   CONTAINER_COMMAND: ${CONTAINER_COMMAND}"
    exit 1
fi

# 驗證 K8s 連線
echo ">>> 驗證 Kubernetes 連線..."
if ! kubectl cluster-info >/dev/null 2>&1; then
    echo "❌ 無法連接到 Kubernetes 集群"
    echo "請檢查 kubeconfig 設定"
    exit 1
fi

# 驗證目標 Pod 是否存在並運行中
echo ">>> 驗證目標 Pod..."
POD_STATUS=$(kubectl get pod ${MIRRORD_TARGET_POD} -n ${MIRRORD_TARGET_NAMESPACE} -o jsonpath='{.status.phase}' 2>/dev/null || echo "NotFound")
if [[ "${POD_STATUS}" != "Running" ]]; then
    echo "❌ Pod '${MIRRORD_TARGET_POD}' 狀態異常: ${POD_STATUS}"
    echo "   請確保 Pod 在 namespace '${MIRRORD_TARGET_NAMESPACE}' 中且狀態為 Running"
    exit 1
fi

echo "✅ 目標 Pod 驗證成功（狀態: ${POD_STATUS}）"

# 取得 Pod IP
POD_IP=$(kubectl get pod ${MIRRORD_TARGET_POD} -n ${MIRRORD_TARGET_NAMESPACE} -o jsonpath='{.status.podIP}')
echo ">>> Pod IP: ${POD_IP}"

echo "---"
echo ">>> 執行 mirrord container..."
echo ">>> 目標: pod/${MIRRORD_TARGET_POD}"
echo ">>> 命令: ${CONTAINER_COMMAND}"
echo "---"

# 執行 mirrord container
exec mirrord container \
    --target pod/${MIRRORD_TARGET_POD} \
    -n ${MIRRORD_TARGET_NAMESPACE} \
    -- ${CONTAINER_COMMAND}
