# Kubernetes 環境
**透過 Kind、K3D 或外部 K8s 集群提供完整的 Kubernetes 開發與部署環境**

KDE 支援三種 Kubernetes 環境類型，每種環境都有其特定的使用場景和優勢。請根據您的需求選擇合適的環境類型：

## 環境類型

### 1. [Kind 環境 (Kubernetes in Docker)](./kubernetes/kind.md)
**本地開發環境，使用 Docker 容器模擬完整的 K8s 節點**

- **適用場景**：本地開發、完整功能測試、複雜應用
- **啟動速度**：快速（15-30 秒）
- **資源佔用**：中等（~500MB）
- **特色功能**：
    - 更接近真實 K8s 環境
    - 支援多節點配置（control-plane + worker）
    - 完整的 K8s 組件
    - Docker 網路整合，開發容器可直接存取 K8s 服務
    - PVC 自動掛載專案資料夾
    - 支援 `kde load-image` 載入本地映像

📖 [查看 Kind 環境詳細文檔](./kubernetes/kind.md)

### 2. [K3D 環境 (K3s in Docker)](./kubernetes/k3d.md)
**輕量級本地開發環境，基於 K3s 的 Docker 容器**

- **適用場景**：快速開發、CI/CD、資源受限環境
- **啟動速度**：極快（5-10 秒）
- **資源佔用**：極低（~200MB）
- **特色功能**：
    - 啟動和清理極快速
    - 適合快速迭代開發
    - 適合 CI/CD 整合測試
    - Docker 網路整合
    - PVC 自動掛載專案資料夾
    - 支援 `kde load-image` 載入本地映像

📖 [查看 K3D 環境詳細文檔](./kubernetes/k3d.md)

### 3. [外部 Kubernetes 環境](./kubernetes/external-kubernetes.md)
**連接到現有的 Kubernetes 集群（雲端或遠端集群）**

- **適用場景**：生產環境、團隊協作、雲端部署
- **啟動速度**：N/A（集群已存在）
- **資源佔用**：取決於雲端集群
- **特色功能**：
    - 連接到 AWS EKS、Google GKE、Azure AKS 等
    - 連接到自建 on-premises K8s 集群
    - 支援多雲端環境管理
    - 完整的生產級功能
    - 透過 kubectl API 連接

📖 [查看外部 Kubernetes 環境詳細文檔](./kubernetes/external-kubernetes.md)

## 環境類型快速比較

| 特性 | Kind | K3D | 外部 K8s |
|------|------|-----|----------|
| 啟動速度 | 快速（15-30s） | 極快（5-10s） | N/A（已存在） |
| 資源佔用 | 中等（~500MB） | 極低（~200MB） | 取決於集群 |
| K8s 完整性 | 完整 | 精簡 | 完整 |
| 適用場景 | 本地開發、測試 | 快速開發、CI/CD | 生產、團隊協作 |
| 網路整合 | Docker 網路 | Docker 網路 | kubectl API |
| 映像載入 | 支援 | 支援 | 不支援（需 Registry） |
| PVC 掛載 | 自動掛載專案資料夾 | 自動掛載專案資料夾 | 標準 PVC |
| 配置靈活性 | 高 | 高 | 取決於集群 |
| 成本 | 免費 | 免費 | 可能需要雲端費用 |

## 快速開始

### 建立 Kind 環境
```bash
kde start dev-env kind
```

### 建立 K3D 環境
```bash
kde start test-env k3d
```

### 連接外部 K8s 環境
- 建議使用只包含單一 K8s 環境設定的 kubeconfig
```bash
kde start prod-env k8s ~/.kube/config
```

## 通用環境管理指令

以下指令適用於所有環境類型（部分指令僅適用於 Kind/K3D）：

### 環境管理
```bash
# 列出所有環境
kde list

# 查看環境狀態
kde status

# 切換環境
kde use <env_name>

# 停止環境（僅 Kind/K3D）
kde stop <env_name>

# 重啟環境（僅 Kind/K3D）
kde restart <env_name>

# 刪除環境
kde remove <env_name>

# 重置環境（僅 Kind/K3D）
kde reset <env_name>
```

### Kubernetes 操作
```bash
# 進入節點容器（僅 Kind/K3D）
kde exec <env_name>

# 載入映像（僅 Kind/K3D）
kde load-image <image> <env_name>

# Port Forward（所有環境）
kde expose [namespace] [pod|service] [resource_name] [target_port] [local_port]

# K9s 終端機 TUI 監控（所有環境）
kde k9s

# Headlamp Web GUI 監控（所有環境）
kde headlamp -p 8088

# Dashboard Web GUI 管理（所有環境）
kde dashboard -p 8088 --insecure
```

## 選擇建議

### 何時使用 Kind？
- ✅ 需要完整的 K8s 功能測試
- ✅ 開發複雜的 K8s 應用
- ✅ 需要多節點配置
- ✅ 學習完整的 Kubernetes
- ✅ 本地開發環境

### 何時使用 K3D？
- ✅ 快速開發與迭代
- ✅ CI/CD 整合測試
- ✅ 資源受限的開發環境
- ✅ 需要頻繁建立/刪除環境
- ✅ 學習 Kubernetes 基礎

### 何時使用外部 K8s？
- ✅ 生產環境部署
- ✅ 團隊協作開發
- ✅ 需要雲端 K8s 完整功能
- ✅ 高可用和擴展性需求
- ✅ 多區域部署
- ✅ 連接現有企業 K8s

## 詳細文檔

- **[Kind 環境詳細文檔](./kubernetes/kind.md)** - 完整的 Kind 環境使用指南
- **[K3D 環境詳細文檔](./kubernetes/k3d.md)** - 完整的 K3D 環境使用指南
- **[外部 Kubernetes 環境詳細文檔](./kubernetes/external-kubernetes.md)** - 外部 K8s 環境連接與使用指南

## 共通功能說明
### 共通環境變數
- 環境變數設定位置：
    - environments/[k8s name]/k8s.env（可納入版控）
    - environments/[k8s name]/.env（不納入版控）

| 環境變數 | 說明 | 範例 | 設定位置 |
|---------|------|------|------|
| `ENV_NAME` | 環境名稱 | `ENV_NAME=dev-env` | k8s.env |
| `ENV_TYPE` | 環境類型（kind/k3d/k8s） | `ENV_TYPE=kind` | k8s.env |
| `K8S_CONTAINER_NAME` | K8s 容器名稱（Kind/K3D）或 API Server IP（外部 K8s） | `K8S_CONTAINER_NAME=dev-env-control-plane` | k8s.env |
| `DOCKER_NETWORK` | Docker 網路名稱 | `DOCKER_NETWORK=kde-dev-env` | k8s.env |
| `STORAGE_CLASS` | 預設儲存類別（Kind/K3D） | `STORAGE_CLASS=local-path` | k8s.env |
| `K8S_API_SERVER_PORT` | K8s API Server 端口（Kind/K3D） | `K8S_API_SERVER_PORT=6443` | .env |
| `K8S_INGRESS_NGINX_PORT` | Ingress Nginx 端口（Kind/K3D） | `K8S_INGRESS_NGINX_PORT=80` | .env |
| `VOLUMES_PATH` | Volume 資料夾路徑（Kind/K3D） | `VOLUMES_PATH=/opt/kde/environments/dev-env/volumes` |.env |

### 權限
- K8S 環境權限基於 K8S RBAC (kubeconfig)

### 狀態
- 環境狀態有三個階段：存在 -> 初始化 -> 運行

  - **存在 (Exist)**: 環境目錄已建立，k8s.env 檔案存在
  - **初始化 (Init)**: kubeconfig 已產生，環境可被使用
  - **運行 (Running)**: 全部 K8S 節點處於 Ready 狀態，可正常使用

### 共通 Best Practice

#### 環境類型選擇
- **本地開發**: 優先使用 Kind 或 K3D
- **CI/CD**: 建議使用 K3D（啟動速度快、資源佔用少）
- **生產驗證**: 使用外部 K8s 環境連接到實際集群
- **團隊協作**: 為不同成員建立獨立的環境，避免衝突

#### 環境命名規範
- 使用有意義的名稱：`dev-env`, `test-env`, `staging-env`
- 避免特殊字元，使用小寫字母和連字號
- 團隊成員可以加上個人前綴：`john-dev-env`, `mary-test-env`

#### 多環境管理
- 為不同用途建立獨立環境（開發、測試、驗證、生產）
- 使用 `kde use` 快速切換環境
- 避免在生產環境中進行實驗性操作
- 保持環境配置的文檔化

#### 環境維護
- 定期清理不使用的環境（`kde remove`）
- 監控 Docker 容器和映像佔用的磁碟空間
- 定期更新 Kind、K3D 映像版本
- 記錄環境配置和變更

#### 與其他 KDE 功能整合
- 使用 K9s 監控環境狀態（`kde k9s`）
- 使用 Dashboard 進行圖形化管理（`kde dashboard`）
- 配合專案管理進行應用部署（`kde proj deploy`）
- 使用 Telepresence 進行本地開發與 K8s 整合（`kde telepresence`）
- 使用 Ngrok/Cloudflare Tunnel 提供外部存取

#### 開發工作流程建議
1. 建立開發環境（Kind 或 K3D）
2. 建立專案
3. 載入映像（Kind/K3D）或推送到 Registry（外部 K8s）
4. 部署專案
5. 使用 K9s 或 Dashboard 監控
6. 進行開發與測試
7. 完成後清理環境

#### 除錯技巧
- 使用 `kubectl get events -A` 查看集群事件
- 使用 `kubectl describe` 查看資源詳細資訊
- 使用 `kubectl logs` 查看 Pod 日誌
- 進入節點容器檢查：`kde exec`（Kind/K3D）
- 使用 K9s 進行即時監控和操作
- 檢查環境配置檔案：`cat environments/<env_name>/k8s.env`

---

**更多詳細資訊和最佳實踐，請參考各環境類型的詳細文檔：**

- **[Kind 環境詳細文檔](./kubernetes/kind.md)**
- **[K3D 環境詳細文檔](./kubernetes/k3d.md)**
- **[外部 Kubernetes 環境詳細文檔](./kubernetes/external-kubernetes.md)**
