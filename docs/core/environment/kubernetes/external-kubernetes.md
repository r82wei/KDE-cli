# 外部 Kubernetes 環境
**連接到現有的 Kubernetes 集群（雲端或遠端集群）**

## 功能說明
- **連接現有 K8s 集群**
    - 支援連接到任何現有的 Kubernetes 集群
    - 雲端 K8s：AWS EKS、Google GKE、Azure AKS、Alibaba ACK 等
    - 自建 K8s：on-premises 集群、裸機 K8s 等
    - 遠端 K8s：其他團隊或環境的 K8s 集群
- **環境管理功能**
    - 連接、驗證 Kubernetes 集群
    - 支援多環境管理，可同時連接多個外部集群
    - 環境狀態檢查與監控
    - 環境切換與配置管理
- **網路管理**
    - 使用 bridge 網路，透過 kubectl API 連接
    - 透過 `kubectl port-forward` 將服務端口轉發到本地
    - 支援 Ingress、LoadBalancer 進行外部存取
    - 開發容器無法直接透過 Docker 網路存取 K8s 服務
- **Kubernetes 整合**
    - 自動讀取並配置 kubeconfig 檔案
    - 支援 kubectl 指令直接操作遠端集群
    - 與 KDE 所有工具深度整合（K9s、Dashboard、Telepresence 等）
- **容器執行環境**
    - 在 DEPLOY_IMAGE 容器中執行 kubectl 指令
    - 自動掛載 kubeconfig
    - 與專案環境整合，支援遠端部署
- **安全性**
    - 支援多種認證方式（Token、Certificate、AWS IAM 等）
    - 自動處理 kubeconfig 的複雜配置
    - 保護 kubeconfig 檔案安全

### 與 Kind/K3D 的比較
| 特性 | 外部 K8s | Kind/K3D |
|------|---------|----------|
| 環境位置 | 遠端/雲端 | 本地 Docker |
| 啟動時間 | N/A（已存在） | 5-30 秒 |
| 網路存取 | kubectl API | Docker 網路 |
| 映像載入 | 不支援（需推送 Registry） | 支援（`kde load-image`） |
| 資源隔離 | 完全隔離 | 共用宿主機資源 |
| 適用場景 | 生產、團隊協作 | 本地開發、測試 |
| 成本 | 可能需要雲端費用 | 免費 |

### 環境變數
| 環境變數 | 說明 | 範例 |
|---------|------|------|
| `ENV_NAME` | 環境名稱 | `ENV_NAME=prod-env` |
| `ENV_TYPE` | 環境類型（固定為 k8s） | `ENV_TYPE=k8s` |
| `K8S_CONTAINER_NAME` | K8s API Server IP 或域名 | `K8S_CONTAINER_NAME=api.k8s.example.com` |
| `DOCKER_NETWORK` | Docker 網路名稱（固定為 bridge） | `DOCKER_NETWORK=bridge` |
| `KUBECONFIG` | Kubeconfig 檔案路徑 | `KUBECONFIG=/opt/kde/environments/prod-env/kubeconfig/config` |

## 使用說明

### 連接外部 K8s 環境
```bash
kde start <env_name> k8s [kubeconfig_path]
```
- `env_name`: 環境名稱（必填）
- `k8s`: 指定連接到外部 K8s 環境
- `[kubeconfig_path]`: kubeconfig 檔案路徑（可選，系統會詢問）

連接流程：
1. 建立環境目錄結構
2. 生成環境配置檔案（`k8s.env`、`.env`）
3. 詢問或使用提供的 kubeconfig 路徑
4. 複製 kubeconfig 到環境目錄
5. 從 kubeconfig 讀取集群資訊
6. 自動設定 K8S_CONTAINER_NAME（API Server IP）
7. 驗證集群連線
8. 設定為當前環境

### 其他管理指令
```bash
# 檢查環境狀態（驗證連線）
kde status

# 切換到外部 K8s 環境
kde use <env_name>

# 列出所有環境
kde list

# 刪除環境配置（不影響遠端集群）
kde remove <env_name>
```

**注意**：
- 外部 K8s 環境不支援 `kde stop`、`kde restart`、`kde reset`
- `kde remove` 只會刪除本地配置，不會影響遠端集群

### Kubernetes 資源操作

#### Port Forward
```bash
kde expose [namespace] [pod|service] [resource_name] [target_port] [local_port]
```
將遠端 K8s 中的 Service 或 Pod 端口轉發到本地，實現本地存取。

#### 部署應用
```bash
# 部署專案到遠端集群
kde proj deploy <project_name>

# 使用 Pipeline 進行 CI/CD
kde proj pipeline <project_name>
```

## 使用範例

### 範例 1：連接到 AWS EKS 集群

連接到 Amazon EKS 集群：
```bash
# 1. 使用 AWS CLI 生成 kubeconfig
aws eks update-kubeconfig --name my-cluster --region us-west-2

# 2. 連接到 EKS 集群
kde start prod-eks k8s ~/.kube/config

# 系統會自動：
# - 複製 kubeconfig 到環境目錄
# - 讀取 API Server 位址
# - 驗證集群連線

# 3. 驗證連線
kubectl get nodes
```

輸出範例：
```
開始初始化 prod-eks 環境...
請輸入 kubeconfig 路徑: ~/.kube/config
K8S_CONTAINER_NAME=A1B2C3D4E5F6.gr7.us-west-2.eks.amazonaws.com
K8S 環境設定初始化已完成
當前 k8s 環境已變更為: prod-eks
[STATUS]   [Environment]
[RUNNING]  prod-eks
```

### 範例 2：連接到 Google GKE 集群

連接到 Google Kubernetes Engine 集群：
```bash
# 1. 使用 gcloud 生成 kubeconfig
gcloud container clusters get-credentials my-cluster --zone us-central1-a --project my-project

# 2. 連接到 GKE 集群
kde start prod-gke k8s ~/.kube/config

# 3. 切換到 GKE 環境
kde use prod-gke

# 4. 操作集群
kubectl get pods -A
```

### 範例 3：連接到 Azure AKS 集群

連接到 Azure Kubernetes Service 集群：
```bash
# 1. 使用 Azure CLI 生成 kubeconfig
az aks get-credentials --resource-group myResourceGroup --name myAKSCluster

# 2. 連接到 AKS 集群
kde start prod-aks k8s ~/.kube/config

# 3. 驗證連線
kde status
```

### 範例 4：連接到自建 K8s 集群

連接到 on-premises 或自建集群：
```bash
# 假設已有 kubeconfig 檔案
# 可能是從 K8s 管理員取得的

# 連接到自建集群
kde start onprem-cluster k8s /path/to/kubeconfig

# 驗證連線
kubectl get nodes
kubectl get namespaces
```

### 範例 5：多雲端環境管理

管理多個雲端環境：
```bash
# 連接到不同的雲端環境
kde start prod-aws k8s ~/.kube/config-aws
kde start prod-gcp k8s ~/.kube/config-gcp
kde start prod-azure k8s ~/.kube/config-azure

# 列出所有環境
kde list
# 輸出：
# dev-env (kind) [RUNNING]
# prod-aws (k8s) [RUNNING]
# prod-gcp (k8s) [RUNNING]
# prod-azure (k8s) [RUNNING]

# 切換環境
kde use prod-aws
kubectl get pods -A

kde use prod-gcp
kubectl get pods -A

kde use prod-azure
kubectl get pods -A
```

### 範例 6：使用 Port Forward 存取遠端服務

由於開發容器無法直接存取遠端 K8s 服務，需要使用 Port Forward：
```bash
# 連接到生產環境
kde use prod-env

# 將遠端服務轉發到本地
kde expose myapp service myapp-service 8080 3000

# 在本地瀏覽器存取遠端服務
# http://localhost:3000

# 或在開發容器中存取
kde proj exec myapp develop
curl http://localhost:3000
```

### 範例 7：部署應用到遠端集群

部署應用到生產環境：
```bash
# 1. 切換到生產環境
kde use prod-env

# 2. 準備部署
# 注意：映像需要推送到 Registry
docker build -t registry.example.com/myapp:v1.0.0 .
docker push registry.example.com/myapp:v1.0.0

# 3. 建立專案（會在 namespaces 目錄下建立 myapp 專案）
kde proj create myapp

# 4. 配置專案
# 在 project.env 中設定映像（專案配置檔放在 namespaces/<project_name> 目錄）
echo "APP_IMAGE=registry.example.com/myapp:v1.0.0" >> environments/prod-env/namespaces/myapp/project.env

# 5. 部署
kde proj deploy myapp

# 6. 驗證部署
kubectl get pods -n myapp
kubectl get svc -n myapp
```

### 範例 8：使用 Pipeline 進行 CI/CD（簡略流程）

執行 CI/CD Pipeline 的典型步驟為：

1. 在 `project.env` 中配置 Pipeline 相關變數與階段。
2. 執行 `kde proj pipeline <project_name>`。

詳細的 Pipeline 設定與完整範例請參考 `docs/core/cicd-pipeline.md`，以避免在此文件重複大量 CI/CD 細節。

### 範例 9：團隊協作開發

多個團隊成員連接到共用集群：
```bash
# 團隊成員 A
kde start shared-dev k8s ~/kubeconfig-shared
kde use shared-dev
kde proj create myapp-feature-a
kde proj deploy myapp-feature-a

# 團隊成員 B
kde start shared-dev k8s ~/kubeconfig-shared
kde use shared-dev
kde proj create myapp-feature-b
kde proj deploy myapp-feature-b

# 兩個成員可以在相同集群的不同 namespace 中工作
# 使用 K9s 查看所有資源
kde k9s
```

### 範例 10：環境配置備份與共用

備份和共用環境配置：
```bash
# 備份環境配置（不包含 kubeconfig）
tar -czf prod-env-config.tar.gz \
  --exclude='kubeconfig' \
  environments/prod-env/

# 共用給團隊成員
# 團隊成員需要自行取得 kubeconfig

# 還原配置
tar -xzf prod-env-config.tar.gz -C /opt/kde/environments/

# 設定 kubeconfig
cp ~/my-kubeconfig environments/prod-env/kubeconfig/config

# 切換到環境
kde use prod-env
```

## Best Practice

- **認證管理**
    - 妥善保管 kubeconfig 檔案，不要提交到版本控制
    - 定期更新 Token 和憑證
    - 生產環境使用專用的 kubeconfig，避免與開發環境混用
    - 考慮使用雲端 IAM 認證（AWS IAM、GCP Service Account 等）
- **環境命名規範**
    - 使用有意義的名稱：`prod-aws`, `staging-gcp`, `prod-onprem`
    - 包含環境用途和位置資訊
    - 避免使用模糊的名稱如 `k8s-1`, `cluster-2`
- **網路存取**
    - 外部 K8s 環境無法直接透過 Docker 網路存取服務
    - 使用 `kubectl port-forward` 轉發服務到本地
    - 使用 Ingress 或 LoadBalancer 進行外部存取
    - 考慮使用 Telepresence 進行本地開發與遠端整合
- **映像管理**
    - 外部 K8s 環境不支援 `kde load-image`
    - 映像必須推送到可存取的 Container Registry
    - 使用私有 Registry 時，需要配置 imagePullSecrets
    - 建議使用雲端 Registry（ECR、GCR、ACR 等）
- **部署流程**
    - 建立完善的 CI/CD Pipeline
    - 使用 `kde proj pipeline` 進行自動化部署
    - 在 build 階段建置並推送映像到 Registry
    - 在 deploy 階段部署到遠端 K8s
    - 實施適當的部署策略（Rolling Update、Blue-Green 等）
- **安全性考量**
    - 限制環境目錄的存取權限（`chmod 700 environments/prod-env/`）
    - 不要在日誌中輸出敏感資訊
    - 使用 RBAC 限制權限
    - 定期審計存取記錄
    - 在 CI/CD 中使用 Secret 管理工具
- **環境隔離**
    - 為不同用途建立不同的環境配置（開發、測試、生產）
    - 避免在生產環境中進行實驗性操作
    - 使用不同的 kubeconfig 檔案管理不同環境
    - 保持環境配置的文檔化
- **多環境管理**
    - 使用 `kde use` 快速切換環境
    - 列出所有環境前先確認當前環境（`kde status`）
    - 執行敏感操作前雙重確認當前環境
    - 考慮在 Shell prompt 中顯示當前環境名稱
- **成本控制**
    - 雲端 K8s 可能產生費用，注意資源使用
    - 定期清理不使用的資源
    - 監控集群資源使用情況
    - 使用 Autoscaling 優化資源利用率
- **故障處理**
    - 連線失敗：檢查 kubeconfig 是否正確
    - 認證失敗：檢查 Token 或憑證是否過期
    - 權限不足：檢查 RBAC 設定
    - 網路問題：檢查防火牆和網路策略
    - API Server 不可達：檢查 VPN 或網路連線
- **監控與維護**
    - 使用 K9s 監控集群狀態（`kde k9s`）
    - 使用 Dashboard 進行圖形化管理（`kde dashboard`）
    - 定期檢查集群健康狀態
    - 監控應用日誌和指標
    - 設定告警機制
- **開發工作流程**
    1. 連接到遠端集群：`kde start prod-env k8s ~/.kube/config`
    2. 驗證連線：`kde status`
    3. 建立專案：`kde proj create myapp`
    4. 本地開發與測試（在 Kind/K3D 環境）
    5. 建置並推送映像到 Registry
    6. 切換到生產環境：`kde use prod-env`
    7. 部署到生產：`kde proj deploy myapp`
    8. 監控部署狀態：`kde k9s`
- **與其他 KDE 功能整合**
    - 使用 K9s 監控遠端集群（`kde k9s`）
    - 使用 Dashboard 進行圖形化管理（`kde dashboard`）
    - 使用 Telepresence 進行本地開發與遠端整合（`kde telepresence`）
    - 使用 Port Forward 存取遠端服務（`kde expose`）
    - 配合專案 Pipeline 進行 CI/CD（`kde proj pipeline`）
- **除錯技巧**
    - 使用 `kubectl get events -A` 查看集群事件
    - 使用 `kubectl describe` 查看資源詳細資訊
    - 使用 `kubectl logs` 查看 Pod 日誌
    - 使用 K9s 進行即時監控和操作
    - 檢查環境配置檔案：`cat environments/<env_name>/k8s.env`
    - 驗證 kubeconfig：`kubectl config view`
- **何時選擇外部 K8s**
    - 生產環境部署
    - 團隊協作開發
    - 需要雲端 K8s 的完整功能
    - 需要高可用和擴展性
    - 連接到現有的企業 K8s 環境
    - 多區域部署

## 常見問題

### Q: 如何更新 kubeconfig？
```bash
# 1. 取得新的 kubeconfig
# 2. 替換環境中的 kubeconfig
cp ~/new-kubeconfig environments/prod-env/kubeconfig/config
# 3. 驗證連線
kde use prod-env
kubectl get nodes
```

### Q: 如何在開發容器中存取遠端服務？
```bash
# 方法 1: 使用 Port Forward
kde expose myapp service myapp-service 8080 3000
# 然後在開發容器中存取 localhost:3000

# 方法 2: 使用 Telepresence
kde telepresence intercept myapp myapp-deployment
# 流量會導向本地開發環境
```

### Q: 如何部署需要私有 Registry 認證的映像？
```bash
# 建立 Docker Registry Secret
kubectl create secret docker-registry regcred \
  --docker-server=registry.example.com \
  --docker-username=myuser \
  --docker-password=mypass \
  -n myapp

# 在 Deployment 中使用
# imagePullSecrets:
# - name: regcred
```

### Q: 如何處理 Token 過期？
```bash
# 1. 重新生成 kubeconfig
# AWS EKS
aws eks update-kubeconfig --name my-cluster

# GKE
gcloud container clusters get-credentials my-cluster

# 2. 更新環境配置
cp ~/.kube/config environments/prod-env/kubeconfig/config

# 3. 驗證連線
kde use prod-env
kubectl get nodes
```

## TODO 待新增功能

> 注意：本節為未來功能構想，**目前尚未在 KDE CLI 中實作**。以下內容僅供 roadmap 參考，請不要依賴其中提到的參數或指令。

### 1. 支援 IaC 工具建立 K8s 叢集

**功能描述**：
- 支援透過 Infrastructure as Code (IaC) 工具在 Docker 容器中建立 Kubernetes 叢集
- 支援的 IaC 工具：
    - **Terraform**: 用於宣告式建立雲端 K8s 叢集（EKS、GKE、AKS 等）
    - **Ansible**: 用於自動化配置和部署 K8s 叢集
- 建立完成後自動以外部 K8s 的方式連結到 KDE 環境

**使用情境**：
```bash
# 使用 Terraform 建立 AWS EKS 叢集
kde start prod-env k8s --terraform ./terraform/

# 使用 Ansible 建立自訂 K8s 叢集
kde start prod-env k8s --ansible ./ansible/playbook.yml

# 執行流程：
# 1. 在 Docker 容器中執行 Terraform/Ansible
# 2. 建立雲端 K8s 叢集
# 3. 取得 kubeconfig
# 4. 自動配置為外部 K8s 環境
# 5. 驗證連線並完成設定
```

**環境配置範例**：
```bash
# k8s.env 或環境配置
KDE_K8S_IAC_TOOL=terraform  # 或 ansible
KDE_K8S_IAC_PATH=./terraform/
KDE_K8S_IAC_VARS="region=us-west-2,cluster_name=my-cluster"
KDE_K8S_IAC_IMAGE=hashicorp/terraform:latest  # 或 ansible/ansible:latest
```

**預期功能**：
- 在隔離的 Docker 容器中執行 IaC 工具，避免污染本地環境
- 自動處理認證（AWS credentials、GCP service account 等）
- 支援變數傳遞和環境配置
- 執行後自動取得並配置 kubeconfig
- 提供建立進度和日誌輸出
- 支援叢集刪除（`kde remove <env_name>` 時自動執行 destroy）

**技術實現考量**：
- 掛載 IaC 配置目錄到容器
- 掛載雲端認證檔案（`~/.aws/`, `~/.gcp/` 等）
- 使用 DEPLOY_IMAGE 或專用的 IaC 映像
- 儲存 Terraform state 或 Ansible inventory
- 錯誤處理和回滾機制

### 2. K8s Init Hook 機制

**功能描述**：
- 在 K8s 環境啟動完成後（或外部 K8s 連線驗證後），自動執行初始化安裝步驟
- 類似 Pipeline 的機制，透過 script 和 image 執行自訂安裝任務
- 支援多個 Hook 階段，按順序執行

**使用情境**：
```bash
# 外部 K8s 環境連線後自動執行 Init Hooks
kde start prod-env k8s ~/.kube/config

# 執行流程：
# 1. 連接外部 K8s 集群
# 2. 驗證連線
# 3. 執行 init hook 1: 安裝 Ingress Nginx
# 4. 執行 init hook 2: 安裝 Cert-Manager
# 5. 執行 init hook 3: 安裝自訂 CRD
# 6. 完成環境初始化
```

**配置範例**：

在 `k8s.env` 或環境配置中：
```bash
# 定義 Init Hook 階段
KDE_K8S_INIT_HOOKS="ingress,cert-manager,monitoring"

# Hook 1: 安裝 Ingress Nginx
KDE_K8S_INIT_HOOK_ingress_IMAGE=bitnami/kubectl:latest
KDE_K8S_INIT_HOOK_ingress_SCRIPT=./hooks/install-ingress.sh

# Hook 2: 安裝 Cert-Manager
KDE_K8S_INIT_HOOK_cert_manager_IMAGE=bitnami/kubectl:latest
KDE_K8S_INIT_HOOK_cert_manager_SCRIPT=./hooks/install-cert-manager.sh

# Hook 3: 安裝監控工具
KDE_K8S_INIT_HOOK_monitoring_IMAGE=r82wei/deploy-env:1.0.0
KDE_K8S_INIT_HOOK_monitoring_SCRIPT=./hooks/install-monitoring.sh
KDE_K8S_INIT_HOOK_monitoring_ALLOW_FAILURE=true
```

**預期功能**：
- 支援多個 Hook 階段，按順序執行
- 每個 Hook 可以指定：
    - `IMAGE`: 執行環境的 Docker 映像
    - `SCRIPT`: 要執行的腳本路徑
    - `ALLOW_FAILURE`: 是否允許失敗（預設 false）
    - `TIMEOUT`: 執行超時時間（預設無限制）
    - `MOUNT_*`: 自訂掛載點
- 自動掛載 kubeconfig 到 Hook 容器
- 提供執行日誌和錯誤處理
- 支援跳過特定 Hook（`--skip-hooks ingress,monitoring`）
- 支援僅執行特定 Hook（`--only-hooks ingress`）
- 支援手動重新執行 Hook（`kde init-hooks <env_name>`）

**使用指令**：
```bash
# 連接環境並執行 Init Hooks
kde start prod-env k8s ~/.kube/config

# 跳過特定 Hooks
kde start prod-env k8s ~/.kube/config --skip-hooks monitoring

# 僅執行特定 Hooks
kde start prod-env k8s ~/.kube/config --only-hooks ingress

# 手動重新執行所有 Hooks
kde init-hooks prod-env

# 手動執行特定 Hook
kde init-hooks prod-env --only ingress
```

**技術實現考量**：
- 外部 K8s 環境在連線驗證後執行 Hooks
- 使用類似 Pipeline 的執行邏輯
- Hook 執行狀態記錄（`.env` 或狀態檔案）
- 冪等性考量（可重複執行）
