#!/bin/bash
# 設置 -e 旗標，讓腳本在任何指令失敗時立即退出
set -e

# 定義清理函式，這個函式將在容器關閉時被呼叫
cleanup() {
    echo "---"
    echo ">>> 偵測到容器關閉信號，正在自動執行清理程序..."

    echo ">>> 正在離開所有 Intercepts 並關閉 Telepresence 連線..."
    telepresence quit

    echo ">>> 清理完成。容器即將關閉。"
    echo "---"
}


# 使用 trap 指令捕捉信號
# EXIT 是一個虛擬信號，無論腳本是正常結束、被 Ctrl+C (SIGINT) 或被 'docker stop' (SIGTERM) 中斷，都會觸發
trap cleanup EXIT

# 檢查並安裝 Traffic Manager
# ------------------------------------------------
# 從環境變數讀取命名空間，如果未設定，則預設為 'ambassador'
TM_NAMESPACE=${TELEPRESENCE_MANAGER_NAMESPACE:-ambassador}

echo "---"
echo ">>> 正在命名空間 '$TM_NAMESPACE' 中檢查 Traffic Manager 是否已安裝..."

# 使用 'kubectl get' 檢查。我們將標準輸出和錯誤都重導向到 /dev/null
# 因為我們只關心指令的結束代碼 (成功為 0，失敗為非 0)
if kubectl get deployment traffic-manager -n "$TM_NAMESPACE" >/dev/null 2>&1; then
    # 如果指令成功 (結束代碼為 0)，表示已安裝
    echo ">>> Traffic Manager 已存在於命名空間 '$TM_NAMESPACE'。"
else
    # 如果指令失敗 (結束代碼非 0)，表示未安裝
    echo ">>> Traffic Manager 未找到，現在開始自動安裝..."
    telepresence helm install -n "$TM_NAMESPACE"
    echo ">>> Traffic Manager 安裝完成。"
fi
echo "---"

# --- 主程式邏輯 ---

# 透過 kubeconfig 取得目前連線的 apiserver 的 IP，並且加上 /24 的子網路遮罩，避免因為 traffic-manager 推測的 subnet 與 apiserver 的 subnet 相同，導致連線失敗
K8S_APISERVER_IP=$(kubectl config view -o jsonpath='{.clusters[?(@.name=="'$(kubectl config view -o jsonpath='{.contexts[?(@.name=="'$(kubectl config current-context)'")].context.cluster}')'")].cluster.server}' | awk -F'//' '{print $2}' | awk -F':' '{print $1}' | awk -F'.' '{print $1"."$2".0.0"}')/24

echo ">>> Entrypoint 啟動"
if [[ -n $TELEPRESENCE_ALSO_PROXY_CIDR ]]; then
    telepresence connect --never-proxy ${K8S_APISERVER_IP} -n $TELEPRESENCE_CONNECT_NAMESPACE --also-proxy $TELEPRESENCE_ALSO_PROXY_CIDR
else
    telepresence connect --never-proxy ${K8S_APISERVER_IP} -n $TELEPRESENCE_CONNECT_NAMESPACE
fi

# 設定 resolv.conf 使用 kube-dns 的 IP
echo "nameserver $(kubectl get svc -n kube-system kube-dns -o jsonpath='{.spec.clusterIP}')" > /etc/resolv.conf
echo "search ${TELEPRESENCE_CONNECT_NAMESPACE}.svc.cluster.local .svc.cluster.local .cluster.local" >> /etc/resolv.conf

# 如果 telepresence connect 失敗，則輸出日誌並退出
if [ $? -ne 0 ]; then
    echo ">>> telepresence connect 失敗"
    cat /root/.cache/telepresence/logs/connector.log
    exit $?
fi

tail -f /root/.cache/telepresence/logs/connector.log