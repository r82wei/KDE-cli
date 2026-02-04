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
...
INFO[0005] All agents already running.                  
INFO[0005] Starting helpers...                          
INFO[0005] Starting node 'k3d-test-serverlb'            
INFO[0011] Injecting records for hostAliases (incl. host.k3d.internal) and for 3 network members into CoreDNS configmap... 
INFO[0013] Cluster 'test' created successfully!         
INFO[0013] You can now use it like this:                
kubectl cluster-info
...
k3d 初始化已完成

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

**功能說明**：
在 K3D 環境中，KDE 透過修改 `local-path-provisioner` 的 StorageClass 配置，實現了 PVC 自動掛載到專案資料夾的功能。當你建立 PVC 時，只需在專案資料夾（`$PROJECT_PATH`）下建立與 PVC 同名的資料夾，PVC 就會自動掛載到這個資料夾，實現資料持久化。

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

### 範例 6：多環境並行開發

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

### 範例 7：資源受限環境

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

## Best Practice

- **環境配置**
    - API Server Port: 建議使用預設值 6443，多環境時使用 6443、6444、6445 等
    - Ingress Nginx Port: 本地開發可使用 80，多環境時使用 80、8080、8081 等
    - 避免端口衝突，確保每個環境使用不同的端口
- **資源配置**
    - K3D 預設配置已經很輕量，通常不需要額外調整
    - 如需高可用，可配置 3 個 server 節點
    - Agent 節點通常不需要，server 節點也可以運行工作負載
- **網路整合**
    - 充分利用 Docker 網路，開發容器可直接存取 K8s 服務
    - 使用服務名稱進行內部通訊（如：`http://backend-service:8080`）
    - 開發容器與 K8s 在同一個 Docker 網路，無需 Port Forward
- **儲存管理**
    - Volume 資料存放在 `environments/<env_name>/volumes/`
    - PVC 名稱必須與專案資料夾下的子目錄名稱完全相同
    - 目錄結構：`environments/<env_name>/volumes/<namespace>/<pvc-name>/`
    - 可以在建立 PVC 前預先準備資料
    - 資料會自動持久化到宿主機，即使刪除 PVC 也不會遺失
    - 建議將 `volumes/` 加入 `.gitignore`，避免提交大量資料
- **映像管理**
    - 使用 `kde load-image` 載入本地映像，無需推送到 Registry
    - 建置映像後立即載入，加速開發流程
    - 部署時設定 `imagePullPolicy: Never` 或 `imagePullPolicy: IfNotPresent`
- **CI/CD 整合**
    - K3D 非常適合 CI/CD 流程，啟動和清理都極快
    - 在 CI pipeline 中使用 K3D 進行整合測試
    - 測試完成後立即清理環境，節省資源
- **快速迭代**
    - 利用 K3D 的快速啟動特性進行快速迭代
    - 遇到環境問題時，快速重建環境
    - 測試不同配置時，快速建立多個環境
- **開發工作流程**
    1. 建立 K3D 環境：`kde start test-env k3d`（5-10 秒）
    2. 建立專案：`kde proj create myapp`
    3. 建置並載入映像：`docker build -t myapp:test . && kde load-image myapp:test`
    4. 部署專案：`kde proj deploy myapp`
    5. 執行測試
    6. 清理環境：`kde remove test-env`（2-3 秒）
- **除錯技巧**
    - 使用 `kubectl get events -A` 查看集群事件
    - 使用 `kubectl logs` 查看 Pod 日誌
    - 進入節點容器檢查：`kde exec`
    - 使用 K9s 進行即時監控：`kde k9s`
    - 檢查 Volume 目錄：`ls -la environments/<env_name>/volumes/`
- **故障處理**
    - 環境無法啟動：檢查 Docker 狀態和端口佔用
    - 節點未就緒：使用 `kde exec` 進入容器檢查
    - 網路問題：檢查 Docker 網路配置（`docker network ls`）
    - 儲存問題：檢查 Volume 目錄權限和空間
    - 快速修復：直接刪除並重建環境（只需 10-15 秒）
- **何時選擇 K3D**
    - 快速開發與測試
    - CI/CD 整合測試
    - 資源受限環境
    - 需要快速環境重建
    - 不需要完整 K8s 組件
    - 學習 Kubernetes 基礎
