# Kind 環境 (Kubernetes in Docker)
**透過 Docker 容器模擬 Kubernetes 節點，提供本地開發環境**

## 功能說明
- **本地 K8s 開發環境**
    - 使用 Docker 容器模擬完整的 Kubernetes 節點
    - 更接近真實 K8s 環境，適合複雜應用開發
    - 支援 control-plane 和 worker 節點配置
- **環境管理功能**
    - 建立、啟動、停止、重啟 Kind 環境
    - 支援多環境管理，可同時維護多個 Kind 環境
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
    - 支援 `kde load-image` 直接載入本地 Docker 映像到 Kind 集群
    - 無需推送到遠端 Registry，加速開發流程
- **Kubernetes 整合**
    - 自動生成並管理 kubeconfig 檔案
    - 支援 kubectl 指令直接操作集群
    - 與 KDE 所有工具深度整合（K9s、Dashboard、Telepresence 等）
- **自訂配置支援**
    - 支援自訂 `kind-config.yaml` 配置檔案
    - 可自訂節點數量、API Server 端口、Ingress 端口等
    - 使用環境變數替換（`envsubst`）提高配置靈活性
- **預設服務自動安裝**
    - 自動安裝 Ingress Nginx Controller
    - 自動配置 local-path-provisioner
    - 自動設定 PKI 憑證
- **環境初始化腳本**
    - 支援 `init.sh` 自動執行環境初始化任務
    - 可用於安裝額外的 K8s 組件（Prometheus、Grafana、ArgoCD 等）
    - 在 DEPLOY_IMAGE 容器環境中執行，可使用 kubectl、helm 等工具

### 環境變數
| 環境變數 | 說明 | 範例 |
|---------|------|------|
| `ENV_NAME` | 環境名稱 | `ENV_NAME=dev-env` |
| `ENV_TYPE` | 環境類型（固定為 kind） | `ENV_TYPE=kind` |
| `K8S_CONTAINER_NAME` | Kind 控制平面容器名稱 | `K8S_CONTAINER_NAME=dev-env-control-plane` |
| `DOCKER_NETWORK` | Docker 網路名稱 | `DOCKER_NETWORK=kde-dev-env` |
| `STORAGE_CLASS` | 預設儲存類別 | `STORAGE_CLASS=local-path` |
| `K8S_API_SERVER_PORT` | K8s API Server 端口 | `K8S_API_SERVER_PORT=6443` |
| `K8S_INGRESS_NGINX_PORT` | Ingress Nginx 端口 | `K8S_INGRESS_NGINX_PORT=80` |
| `KUBECONFIG` | Kubeconfig 檔案路徑 | `KUBECONFIG=/opt/kde/environments/dev-env/kubeconfig/config` |
| `VOLUMES_PATH` | Volume 資料夾路徑 | `VOLUMES_PATH=/opt/kde/environments/dev-env/volumes` |

## 使用說明

### 建立/啟動 Kind 環境
```bash
kde start <env_name> kind [config_path]
```
- `env_name`: 環境名稱（必填）
- `kind`: 指定使用 Kind 環境類型
- `[config_path]`: 自訂 `kind-config.yaml` 配置檔案路徑（可選）

建立流程：
1. 建立環境目錄結構
2. 生成環境配置檔案（`k8s.env`、`.env`）
3. 生成 PKI 憑證
4. 詢問 API Server 和 Ingress 端口配置
5. 生成或使用自訂的 `kind-config.yaml`
6. 建立 Docker 網路
7. 啟動 Kind 集群
8. 安裝預設服務（Ingress Nginx、local-path StorageClass）
9. 配置 kubeconfig
10. 執行環境初始化腳本（如果 `init.sh` 存在）

### 其他管理指令
```bash
# 停止 Kind 環境
kde stop [env_name] [-f|--force]

# 重啟 Kind 環境
kde restart [env_name]

# 刪除 Kind 環境
kde remove <env_name>

# 重置 Kind 環境（保留配置）
kde reset [env_name]

# 切換到 Kind 環境
kde use <env_name>

# 查看環境狀態
kde status

# 列出所有環境
kde list
```

### 進入 Kind 節點容器
```bash
kde exec [env_name]
```
進入 Kind 節點容器的 Bash 環境，可以：
- 直接使用 Docker 指令查看容器
- 檢查網路配置
- 檢查檔案系統
- 執行除錯操作

### 載入映像到 Kind 環境
```bash
kde load-image <image> [env_name]
```
將本地 Docker 映像載入到 Kind 集群中，無需推送到 Registry。

## 使用範例

### 範例 1：建立基本 Kind 開發環境

使用預設配置建立 Kind 環境：
```bash
# 建立名為 dev-env 的 Kind 環境
kde start dev-env kind

# 系統會詢問：
# - K8S API Server port (預設: 6443)
# - K8S Ingress Nginx port (預設: 80)

# 環境建立完成後會自動成為當前環境
# 可以直接使用 kubectl 操作
kubectl get nodes
kubectl get pods -A
```

輸出範例：
```
開始初始化 dev-env 環境...
使用預設模板: /opt/kde/scripts/utils/environment/kind-config.yaml
請輸入 K8S api server port (預設: 6443): 
K8S_API_SERVER_PORT=6443
請輸入 K8S ingress nginx port (預設: 80): 
K8S_INGRESS_NGINX_PORT=80
當前 k8s 環境已變更為: dev-env
啟動 kind 環境
Creating cluster "dev-env" ...
...
安裝預設服務...
✅ 環境 dev-env 已成功啟動
```

### 範例 2：使用自訂配置建立多節點 Kind 環境

準備自訂的 Kind 配置檔案：
```bash
# 建立自訂配置檔案 my-kind-config.yaml
cat > my-kind-config.yaml <<EOF
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
name: \${ENV_NAME}
nodes:
- role: control-plane
  kubeadmConfigPatches:
  - |
    kind: InitConfiguration
    nodeRegistration:
      kubeletExtraArgs:
        node-labels: "ingress-ready=true"
  extraPortMappings:
  - containerPort: 30080
    hostPort: \${K8S_INGRESS_NGINX_PORT}
    protocol: TCP
  extraMounts:
  - hostPath: \${ENV_PATH}/\${VOLUMES_DIR}
    containerPath: /opt/local-path-provisioner
  - hostPath: \${ENV_PATH}/pki/ca.crt
    containerPath: /etc/kubernetes/pki/ca.crt
  - hostPath: \${ENV_PATH}/pki/ca.key
    containerPath: /etc/kubernetes/pki/ca.key
- role: worker
- role: worker
networking:
  apiServerAddress: "0.0.0.0"
  apiServerPort: \${K8S_API_SERVER_PORT}
EOF

# 使用自訂配置建立環境
kde start my-cluster kind ./my-kind-config.yaml

# 此環境會有 1 個 control-plane 和 2 個 worker 節點
kubectl get nodes
```

### 範例 3：載入本地映像到 Kind 環境

開發並載入應用映像：
```bash
# 建立 Kind 環境
kde start dev-env kind

# 在本地建置應用映像
docker build -t myapp:dev .

# 載入映像到 Kind 環境
kde load-image myapp:dev

# 驗證映像已載入
kde exec dev-env
docker images | grep myapp
exit

# 在 K8s 中部署應用
kubectl create deployment myapp --image=myapp:dev --image-pull-policy=Never
```

### 範例 4：開發容器直接存取 K8s 服務

利用 Docker 網路整合：
```bash
# 建立 Kind 環境
kde start dev-env kind

# 部署一個測試服務
kubectl create deployment nginx --image=nginx
kubectl expose deployment nginx --port=80

# 進入專案開發容器
kde proj exec myapp develop

# 在開發容器內可以直接存取 K8s 服務
curl http://nginx.default.svc.cluster.local
# 或使用服務名稱
curl http://nginx:80
```

### 範例 5：PVC 自動掛載專案資料夾

**快速說明（你真正需要做的事）**：

1. 在 `專案` 同名的 namespace 中，建立 PVC 並掛載到對應的 Pod
2. 在 `專案` 的目錄下，找到與 PVC 名稱相同的資料夾：`environments/<env_name>/namespaces/<project_name>/<pvc_name>`。
3. Pod 內寫入的檔案會出現在這個資料夾裡，而你在宿主機這個資料夾中放的檔案，Pod 也能看到。

> 一般使用者只需要依照上述步驟操作即可；下面的內容是這個機制在 Kind 環境中的實作原理，主要提供進階使用者與維護者參考。

**技術原理**：

1. **Kind 節點容器掛載配置**（`kind-config.yaml`）：
```yaml
extraMounts:
  - hostPath: ${ENV_PATH}/${VOLUMES_DIR}
    containerPath: /opt/local-path-provisioner
```
將宿主機的 `environments/<env_name>/volumes/` 掛載到 Kind 節點容器內的 `/opt/local-path-provisioner`

2. **Local-Path-Provisioner 配置修改**：
```bash
# 設定 sharedFileSystemPath
kubectl patch configmap local-path-config -n local-path-storage --type merge \
  -p '{"data": {"config.json": "{\n  \"sharedFileSystemPath\": \"/opt/local-path-provisioner\"\n}"}}'

# 修改 teardown 腳本，跳過資料刪除（保留 PVC 資料）
kubectl patch configmap local-path-config -n local-path-storage --type merge \
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

**關鍵設定**：
- `pathPattern: "{{ .PVC.Namespace }}/{{ .PVC.Name }}"` - 這個設定讓 PVC 的儲存路徑遵循 `namespace/pvc-name` 的目錄結構

**資料流向與路徑結構**：
```
宿主機                    Kind 節點容器                  Kubernetes PVC
──────────────────────────────────────────────────────────────────────
environments/
└── dev-env/
    └── volumes/          ←→  /opt/local-path-provisioner/  ←→  PVC Storage
        └── myapp/            └── myapp/                        
            └── my-pvc/           └── my-pvc/                  
```

**使用範例**：

假設 namespace 為 `myapp`，對應的 Volume 根目錄為：

```bash
environments/dev-env/volumes/myapp/
```

> 注意：專案原始碼目錄通常為 `environments/<env_name>/namespaces/<project_name>/`，而這裡的 `volumes/myapp` 是用來存放該 namespace 內 PVC 資料的目錄，兩者用途不同。

1. 在對應 namespace 的 Volume 目錄下建立 PVC 對應的子目錄：
```bash
# 進入對應 namespace 的 Volume 目錄
cd environments/dev-env/volumes/myapp/

# 建立與 PVC 同名的資料夾
mkdir my-pvc

# 在資料夾中準備一些測試資料
echo "Hello from host!" > my-pvc/test.txt
```

2. 建立 PVC 和測試 Pod：
```yaml
# pvc.yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: my-pvc
  namespace: myapp
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: local-path
  resources:
    requests:
      storage: 1Gi
---
# test-pod.yaml
apiVersion: v1
kind: Pod
metadata:
  name: test-pod
  namespace: myapp
spec:
  containers:
  - name: test
    image: busybox
    command: ["/bin/sh", "-c", "while true; do sleep 3600; done"]
    volumeMounts:
    - name: data
      mountPath: /data
  volumes:
  - name: data
    persistentVolumeClaim:
      claimName: my-pvc
```

3. 部署並驗證：
```bash
# 建立 namespace
kubectl create namespace myapp

# 部署 PVC 和 Pod
kubectl apply -f pvc.yaml

# 進入 Pod 驗證
kubectl exec -it test-pod -n myapp -- sh

# 在 Pod 內查看掛載的資料
cat /data/test.txt
# 輸出：Hello from host!

# 在 Pod 內寫入新資料
echo "Hello from Pod!" > /data/pod-data.txt
exit

# 在宿主機上查看資料
cat environments/dev-env/volumes/myapp/my-pvc/pod-data.txt
# 輸出：Hello from Pod!
```

**實際應用場景**：

**資料庫持久化**：
```bash
# 在專案資料夾建立資料庫資料目錄
mkdir -p environments/dev-env/volumes/myapp/postgres-data

# 部署 PostgreSQL 使用 PVC
# 資料庫資料會儲存在宿主機的 postgres-data/ 目錄
```

**應用程式檔案上傳**：
```bash
# 建立上傳目錄
mkdir -p environments/dev-env/volumes/myapp/app-uploads

# 預先放置一些檔案
cp ~/sample-files/* environments/dev-env/volumes/myapp/app-uploads/

# 上傳的檔案會直接儲存在宿主機
```

**優勢**：
1. **資料可見性**：可以直接在宿主機上查看和編輯 PVC 的資料
2. **資料持久化**：環境重啟或 Pod 刪除，資料都不會遺失
3. **備份方便**：直接備份 `volumes/` 目錄即可
4. **除錯便利**：可以直接在宿主機上檢查資料內容
5. **資料預置**：可以在建立 PVC 前先準備好資料

### 範例 6：進入 Kind 節點容器除錯

除錯 Kind 環境：
```bash
# 進入 Kind 節點容器
kde exec dev-env

# 檢查節點狀態
kubectl get nodes

# 檢查容器狀態（直接存取 Docker）
docker ps

# 檢查網路配置
ip addr
ip route

# 檢查 Volume 掛載
ls -la /opt/local-path-provisioner/

# 檢查檔案系統
df -h
```

### 範例 7：使用 init.sh 自動安裝額外組件

環境啟動後自動執行初始化任務：

```bash
# 建立環境
kde start dev-env kind

# 建立 init.sh 腳本
cat > environments/dev-env/init.sh <<'EOF'
#!/bin/bash
set -e

echo "開始執行環境初始化..."

# 安裝 Prometheus
echo "安裝 Prometheus..."
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
helm install prometheus prometheus-community/kube-prometheus-stack \
    --namespace monitoring \
    --create-namespace \
    --wait

# 安裝 ArgoCD
echo "安裝 ArgoCD..."
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# 等待 ArgoCD 準備就緒
kubectl wait --for=condition=available --timeout=300s \
    deployment/argocd-server -n argocd

echo "環境初始化完成！"
EOF

# 設定執行權限
chmod +x environments/dev-env/init.sh

# 重新啟動環境（會自動執行 init.sh）
kde restart dev-env

# init.sh 會在環境啟動後自動執行
# 安裝 Prometheus 和 ArgoCD

# 驗證安裝結果
kubectl get pods -n monitoring
kubectl get pods -n argocd
```

**init.sh 特點**：
- 在 `DEPLOY_IMAGE` 容器環境中執行，預設包含 kubectl、helm、docker 等工具
- 自動載入環境變數（`kde.env`、`k8s.env`、`.env`）
- 可以執行任何 shell 指令
- 適合安裝額外的 K8s 組件或進行環境配置

**常見使用場景**：
```bash
#!/bin/bash
# init.sh 範例

# 1. 安裝監控工具
helm install prometheus prometheus-community/kube-prometheus-stack -n monitoring --create-namespace

# 2. 安裝日誌收集
helm install loki grafana/loki-stack -n logging --create-namespace

# 3. 建立自訂 Namespace
kubectl create namespace production
kubectl create namespace staging

# 4. 安裝 Cert Manager
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.0/cert-manager.yaml

# 5. 設定 RBAC
kubectl apply -f ./k8s/rbac.yaml

# 6. 預先部署基礎服務
kubectl apply -f ./k8s/base-services/
```

**除錯 init.sh**：
```bash
# 如果 init.sh 執行失敗，可以手動執行
kde proj exec deploy

# 在容器內
cd ${ENV_PATH}
bash -x init.sh  # 使用 -x 顯示執行過程
```

### 範例 8：多環境開發

建立多個 Kind 環境：
```bash
# 建立開發環境
kde start dev-env kind
# API Server: 6443, Ingress: 80

# 建立測試環境（使用不同端口）
kde start test-env kind
# API Server: 6444, Ingress: 8080

# 建立驗證環境
kde start staging-env kind
# API Server: 6445, Ingress: 8081

# 列出所有環境
kde list

# 切換環境
kde use dev-env
kde use test-env
```

## Best Practice（Kind 特有建議）

共用的 Kubernetes 環境命名、工作流程與除錯建議已整理在 `docs/core/environment/kubernetes.md` 的「共通 Best Practice」章節，這裡只補充 Kind 環境特有或差異較大的部分：

- **節點配置**
    - 一般開發：1 個 control-plane 節點即可。
    - 需要模擬多節點/排程行為時：可額外新增 1–2 個 worker 節點，避免過多節點影響啟動速度與資源。
- **自訂 kind-config**
    - 建議將自訂的 `kind-config.template.yaml` 放在專案或環境目錄並納入版本控制，團隊共用同一份模板以確保一致性。
- **儲存與 Volume**
    - Volume 資料實際存放在 `environments/<env_name>/namespaces/<namespace>/<pvc-name>/`，可直接在宿主機上檢查與備份。
    - 在 Kind 環境中預先建立這些資料夾，可以方便預置資料或檢查 PVC 掛載內容。
- **映像與載入**
    - 開發迭代時，優先使用 `kde load-image` 將本地映像載入 Kind，避免頻繁推送到 Registry。
    - 部署到 Kind 時，通常會搭配 `imagePullPolicy: IfNotPresent` 或 `Never`，以優先使用本地已載入映像。
