# K3D 環境 (K3s in Docker)
**透過 Docker 容器運行輕量級 K3s，提供快速本地開發環境**

## 功能說明
- **輕量級 K8s 開發環境**
    - 基於 K3s（輕量級 Kubernetes）的 Docker 容器
    - 啟動速度極快，資源佔用低
    - 適合快速開發、測試和 CI/CD
- **環境管理功能**
    - 建立、啟動、停止、重啟 K3D 環境
    - 支援多環境管理，可同時維護多個 K3D 環境
    - 環境狀態檢查與監控
    - 環境切換與配置管理
- **網路整合**
    - 自動建立專屬 Docker 網路（`kde-${ENV_NAME}`）
    - 開發容器可直接透過服務名稱存取 K8s 內部服務
    - 支援 Ingress、Service、Pod 的網路存取
    - Port Forward 功能，將 K8s 服務端口轉發到本地
- **儲存管理**
    - 自動配置 `local-path` StorageClass（預設）
    - 支援 PersistentVolume 和 PersistentVolumeClaim
    - **PVC 自動掛載專案資料夾**：建立 PVC 時會自動掛載到專案資料夾下與 PVC 同名的目錄
    - Volume 資料夾管理（`environments/<env_name>/volumes/`）
- **映像管理**
    - 支援 `kde load-image` 直接載入本地 Docker 映像到 K3D 集群
    - 無需推送到遠端 Registry，加速開發流程
- **Kubernetes 整合**
    - 自動生成並管理 kubeconfig 檔案
    - 支援 kubectl 指令直接操作集群
    - 與 KDE 所有工具深度整合（K9s、Dashboard、Telepresence 等）
- **自訂配置支援**
    - 支援自訂 `k3d-config.yaml` 配置檔案
    - 可自訂 server 數量、API Server 端口、Ingress 端口等
    - 使用環境變數替換（`envsubst`）提高配置靈活性
- **預設服務自動安裝**
    - 自動安裝 Ingress Nginx Controller
    - 自動配置 local-path-provisioner
    - 自動設定 PKI 憑證
- **環境初始化腳本**
    - 支援 `init.sh` 自動執行環境初始化任務
    - 可用於安裝額外的 K8s 組件（Prometheus、Grafana、ArgoCD 等）
    - 在 DEPLOY_IMAGE 容器環境中執行，可使用 kubectl、helm 等工具

### 與 Kind 的比較
| 特性 | K3D | Kind |
|------|-----|------|
| 啟動速度 | 極快（5-10 秒） | 快速（15-30 秒） |
| 資源佔用 | 極低（~200MB） | 中等（~500MB） |
| K8s 版本 | K3s（精簡版） | 完整 K8s |
| 適用場景 | 快速開發、CI/CD | 複雜應用、完整測試 |
| 組件完整性 | 精簡（去除雲端組件） | 完整 |

### 環境變數
| 環境變數 | 說明 | 範例 |
|---------|------|------|
| `ENV_NAME` | 環境名稱 | `ENV_NAME=test-env` |
| `ENV_TYPE` | 環境類型（固定為 k3d） | `ENV_TYPE=k3d` |
| `K8S_CONTAINER_NAME` | K3D serverlb 容器名稱 | `K8S_CONTAINER_NAME=k3d-test-env-serverlb` |
| `DOCKER_NETWORK` | Docker 網路名稱 | `DOCKER_NETWORK=kde-test-env` |
| `STORAGE_CLASS` | 預設儲存類別 | `STORAGE_CLASS=local-path` |
| `K8S_API_SERVER_PORT` | K8s API Server 端口 | `K8S_API_SERVER_PORT=6443` |
| `K8S_INGRESS_NGINX_PORT` | Ingress Nginx 端口 | `K8S_INGRESS_NGINX_PORT=80` |
| `KUBECONFIG` | Kubeconfig 檔案路徑 | `KUBECONFIG=/opt/kde/environments/test-env/kubeconfig/config` |
| `VOLUMES_PATH` | Volume 資料夾路徑 | `VOLUMES_PATH=/opt/kde/environments/test-env/volumes` |

## 使用說明

### 建立/啟動 K3D 環境
```bash
kde start <env_name> k3d [config_path]
```
- `env_name`: 環境名稱（必填）
- `k3d`: 指定使用 K3D 環境類型
- `[config_path]`: 自訂 `k3d-config.yaml` 配置檔案路徑（可選）

建立流程：
1. 建立環境目錄結構
2. 生成環境配置檔案（`k8s.env`、`.env`）
3. 生成 PKI 憑證
4. 詢問 API Server 和 Ingress 端口配置
5. 生成或使用自訂的 `k3d-config.yaml`
6. 建立 Docker 網路
7. 啟動 K3D 集群（極快速度）
8. 安裝預設服務（Ingress Nginx、local-path StorageClass）
9. 配置 kubeconfig
10. 執行環境初始化腳本（如果 `init.sh` 存在）

### 其他管理指令
```bash
# 停止 K3D 環境
kde stop [env_name] [-f|--force]

# 重啟 K3D 環境
kde restart [env_name]

# 刪除 K3D 環境
kde remove <env_name>

# 重置 K3D 環境（保留配置）
kde reset [env_name]

# 切換到 K3D 環境
kde use <env_name>

# 查看環境狀態
kde status

# 列出所有環境
kde list
```

### 進入 K3D 節點容器
```bash
kde exec [env_name]
```
進入 K3D server 容器的 Bash 環境，可以：
- 直接使用 Docker 指令查看容器
- 檢查網路配置
- 檢查檔案系統
- 執行除錯操作

### 載入映像到 K3D 環境
```bash
kde load-image <image> [env_name]
```
將本地 Docker 映像載入到 K3D 集群中，無需推送到 Registry。

## 使用範例

### 範例 1：建立快速 K3D 測試環境

使用預設配置建立 K3D 環境：
```bash
# 建立名為 test-env 的 K3D 環境
kde start test-env k3d

# 系統會詢問：
# - K8S API Server port (預設: 6443)
# - K8S Ingress Nginx port (預設: 80)

# 環境建立極快（約 5-10 秒）
# 可以立即使用 kubectl 操作
kubectl get nodes
kubectl get pods -A
```

輸出範例：
```
開始初始化 test-env 環境...
使用預設模板: /opt/kde/scripts/utils/environment/k3d-config.yaml
請輸入 K8S api server port (預設: 6443): 
K8S_API_SERVER_PORT=6443
請輸入 K8S ingress nginx port (預設: 80): 
K8S_INGRESS_NGINX_PORT=80
當前 k8s 環境已變更為: test-env
啟動 k3d 環境
INFO[0000] Creating cluster "test-env"...
...
安裝預設服務...
✅ 環境 test-env 已成功啟動
```

### 範例 2：CI/CD 環境快速建立與清理

K3D 非常適合 CI/CD 流程：
```bash
#!/bin/bash
# CI/CD 腳本範例

# 1. 建立測試環境（極快速度）
kde start ci-test-env k3d

# 2. 載入應用映像
kde load-image myapp:${CI_COMMIT_SHA}

# 3. 部署應用
kubectl apply -f k8s/

# 4. 執行整合測試
./run-integration-tests.sh

# 5. 清理環境
kde remove ci-test-env

# 整個流程只需 1-2 分鐘
```

### 範例 3：使用自訂配置建立多 server K3D 環境

準備自訂的 K3D 配置檔案：
```bash
# 建立自訂配置檔案 my-k3d-config.yaml
cat > my-k3d-config.yaml <<EOF
apiVersion: k3d.io/v1alpha4
kind: Simple
metadata:
  name: \${ENV_NAME}
servers: 3
agents: 0
network: \${DOCKER_NETWORK}
ports:
  - port: \${K8S_INGRESS_NGINX_PORT}:80
    nodeFilters:
      - loadbalancer
  - port: \${K8S_API_SERVER_PORT}:6443
    nodeFilters:
      - loadbalancer
volumes:
  - volume: \${ENV_PATH}/\${VOLUMES_DIR}:/var/lib/rancher/k3s/storage
    nodeFilters:
      - server:*
  - volume: \${ENV_PATH}/pki/ca.crt:/var/lib/rancher/k3s/server/tls/server-ca.crt
    nodeFilters:
      - server:*
  - volume: \${ENV_PATH}/pki/ca.key:/var/lib/rancher/k3s/server/tls/server-ca.key
    nodeFilters:
      - server:*
EOF

# 使用自訂配置建立高可用環境
kde start ha-cluster k3d ./my-k3d-config.yaml

# 此環境會有 3 個 server 節點（高可用）
kubectl get nodes
```

### 範例 4：快速開發迭代

K3D 的快速啟動特性非常適合快速迭代：
```bash
# 1. 建立開發環境
kde start dev-env k3d

# 2. 開發並測試
docker build -t myapp:v1 .
kde load-image myapp:v1
kubectl apply -f deploy.yaml
# ... 測試 ...

# 3. 發現問題，快速重建環境
kde remove dev-env
kde start dev-env k3d

# 4. 再次測試修正後的版本
docker build -t myapp:v2 .
kde load-image myapp:v2
kubectl apply -f deploy.yaml
# ... 測試 ...
```

### 範例 5：PVC 自動掛載專案資料夾

**快速說明（你真正需要做的事）**：

1. 在 `專案` 同名的 namespace 中，建立 PVC 並掛載到對應的 Pod
2. 在 `專案` 的目錄下，找到與 PVC 名稱相同的資料夾：`environments/<env_name>/namespaces/<project_name>/<pvc_name>`。
3. Pod 內寫入的檔案會出現在這個資料夾裡，而你在宿主機這個資料夾中放的檔案，Pod 也能看到。

> 一般使用者只需要依照上述步驟操作即可；下面的內容是這個機制在 K3D 環境中的實作原理，主要提供進階使用者與維護者參考。

**技術原理**：

1. **K3D 配置**（`k3d-config.yaml`）：
```yaml
volumes:
  - volume: ${ENV_PATH}/${VOLUMES_DIR}:/var/lib/rancher/k3s/storage
    nodeFilters:
      - server:*
```
將宿主機的 `environments/<env_name>/volumes/` 掛載到 K3D server 容器內的 `/var/lib/rancher/k3s/storage`

2. **Local-Path-Provisioner 配置修改**：
```bash
# 設定 sharedFileSystemPath
kubectl patch configmap local-path-config -n kube-system --type merge \
  -p '{"data": {"config.json": "{\n  \"sharedFileSystemPath\": \"/var/lib/rancher/k3s/storage\"\n}"}}'

# 修改 teardown 腳本，跳過資料刪除
kubectl patch configmap local-path-config -n kube-system --type merge \
  -p '{"data":{"teardown":"#!/bin/sh\nset -eu\necho \"[INFO] Skipping data deletion for ${VOL_DIR}\"\ntrue"}}'
```

3. **自訂 StorageClass 配置**：
```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: local-path
  annotations:
    storageclass.kubernetes.io/is-default-class: "true"
provisioner: rancher.io/local-path
parameters:
  archiveOnDelete: 'false'
  pathPattern: "{{ .PVC.Namespace }}/{{ .PVC.Name }}"  # 關鍵配置
reclaimPolicy: Delete
volumeBindingMode: Immediate
```

**使用範例**：

```bash
# 建立 K3D 環境
kde start test-env k3d

# 在專案資料夾下建立 PVC 對應的目錄
cd environments/test-env/volumes/myapp/
mkdir my-pvc
echo "Hello from host!" > my-pvc/test.txt

# 建立 PVC
kubectl create namespace myapp
kubectl apply -f - <<EOF
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: my-pvc
  namespace: myapp
spec:
  accessModes: [ReadWriteOnce]
  storageClassName: local-path
  resources:
    requests:
      storage: 1Gi
EOF

# 建立測試 Pod
kubectl run test --image=busybox -n myapp --command -- sleep 3600
kubectl set volume pod/test -n myapp --add --name=data --claim-name=my-pvc --mount-path=/data

# 驗證資料
kubectl exec test -n myapp -- cat /data/test.txt
# 輸出：Hello from host!
```

### 範例 6：使用 init.sh 自動安裝額外組件

環境啟動後自動執行初始化任務：

```bash
# 建立環境
kde start test-env k3d

# 建立 init.sh 腳本
cat > environments/test-env/init.sh <<'EOF'
#!/bin/bash
set -e

echo "開始執行環境初始化..."

# 安裝 Metrics Server（K3D 不像 K3s 預設安裝）
echo "安裝 Metrics Server..."
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml

# 修改 Metrics Server 部署（跳過 TLS 驗證，適合開發環境）
kubectl patch deployment metrics-server -n kube-system --type='json' \
  -p='[{"op": "add", "path": "/spec/template/spec/containers/0/args/-", "value": "--kubelet-insecure-tls"}]'

# 安裝 Istio
echo "安裝 Istio..."
curl -L https://istio.io/downloadIstio | sh -
cd istio-*/
export PATH=$PWD/bin:$PATH
istioctl install --set profile=demo -y

# 啟用 Istio injection
kubectl label namespace default istio-injection=enabled

echo "環境初始化完成！"
EOF

# 設定執行權限
chmod +x environments/test-env/init.sh

# 重新啟動環境（會自動執行 init.sh）
kde restart test-env

# init.sh 會在環境啟動後自動執行
# 安裝 Metrics Server 和 Istio

# 驗證安裝結果
kubectl get pods -n kube-system | grep metrics
kubectl get pods -n istio-system
```

**init.sh 特點**：
- 在 `DEPLOY_IMAGE` 容器環境中執行，預設包含 kubectl、helm、docker 等工具
- 自動載入環境變數（`kde.env`、`k8s.env`、`.env`）
- 可以執行任何 shell 指令
- 適合安裝額外的 K8s 組件或進行環境配置

**CI/CD 環境初始化範例**：
```bash
#!/bin/bash
# init.sh for CI environment

set -e

echo "設定 CI 環境..."

# 1. 建立測試 Namespace
kubectl create namespace ci-test
kubectl create namespace ci-staging

# 2. 安裝測試資料庫
helm install test-db bitnami/postgresql \
    --namespace ci-test \
    --set auth.database=testdb \
    --set auth.username=testuser \
    --set auth.password=testpass

# 3. 建立 ImagePullSecret（如果需要）
kubectl create secret docker-registry regcred \
    --docker-server=${REGISTRY_URL} \
    --docker-username=${REGISTRY_USER} \
    --docker-password=${REGISTRY_PASS} \
    -n ci-test

# 4. 設定資源配額（避免測試吃掉太多資源）
cat <<YAML | kubectl apply -f -
apiVersion: v1
kind: ResourceQuota
metadata:
  name: ci-quota
  namespace: ci-test
spec:
  hard:
    requests.cpu: "2"
    requests.memory: 4Gi
    limits.cpu: "4"
    limits.memory: 8Gi
YAML

echo "CI 環境初始化完成！"
```

**除錯 init.sh**：
```bash
# 如果 init.sh 執行失敗，可以手動執行
kde proj exec deploy

# 在容器內
cd ${ENV_PATH}
bash -x init.sh  # 使用 -x 顯示執行過程
```

### 範例 7：多環境並行開發

利用 K3D 的輕量特性同時運行多個環境：
```bash
# 建立多個 K3D 環境（使用不同端口）
kde start dev-env k3d
# API: 6443, Ingress: 80

kde start test-env k3d
# API: 6444, Ingress: 8080

kde start staging-env k3d
# API: 6445, Ingress: 8081

# 在不同環境中並行開發
kde use dev-env
kubectl apply -f dev-config.yaml

kde use test-env
kubectl apply -f test-config.yaml

kde use staging-env
kubectl apply -f staging-config.yaml

# 查看所有環境
kde list
```

### 範例 8：資源受限環境

K3D 非常適合資源受限的開發環境：
```bash
# 在低配置機器上建立 K3D 環境
kde start mini-env k3d

# K3D 只需約 200MB 記憶體
# 可以在筆電、小型虛擬機上運行

# 部署輕量應用測試
kubectl create deployment nginx --image=nginx:alpine
kubectl expose deployment nginx --port=80
```

## Best Practice（K3D 特有建議）

共用的 Kubernetes 環境命名、工作流程與除錯建議已整理在 `docs/core/environment/kubernetes.md` 的「共通 Best Practice」章節，這裡只補充 K3D 環境特有或差異較大的部分：

- **資源與環境配置**
    - K3D 預設配置已經很輕量，適合在筆電、開發 VM 或 CI runner 上頻繁建立/刪除環境。
    - 如需高可用，可配置多個 server 節點；一般開發與測試場景通常 1 個 server 即可。
- **CI/CD 整合**
    - 在 CI pipeline 中使用 K3D 進行整合測試，可以將「建環境 → 測試 → 清理」控制在數分鐘內完成。
    - 測試完成後建議直接 `kde remove <env_name>` 釋放資源，避免留下長時間閒置的集群。
- **儲存與 Volume**
    - Volume 資料實際存放在 `environments/<env_name>/namespaces/<namespace>/<pvc-name>/`，可直接在宿主機上檢查與備份。
    - 若你的 CI 需要保留測試輸出或快取，可善用這個目錄結構進行快取掛載。
- **快速迭代**
    - 當遇到疑難雜症或懷疑環境髒掉時，最簡單的做法通常是：`kde remove <env_name>` 後重新 `kde start` 一個乾淨的 K3D 環境。
