# KDE K8s 環境變數詳細說明

本文檔說明 KDE CLI 中所有與 Kubernetes 環境相關的環境變數，包括其用途、設定位置及使用方式。

## 目錄

- [全域環境變數](#全域環境變數)
- [環境配置變數](#環境配置變數)
- [本地環境變數](#本地環境變數)
- [專案環境變數](#專案環境變數)
- [雲端代理環境變數](#雲端代理環境變數)
- [內部使用變數](#內部使用變數)

---

## 全域環境變數

這些變數定義在 `kde.env` 檔案中，用於設定 KDE CLI 的全域配置。

### KDE 基本配置

#### `KDE_VERSION`

- **說明**: KDE CLI 的版本號
- **預設值**: `v1.0.0-rc.4`
- **用途**: 標識當前使用的 KDE CLI 版本
- **設定位置**: `kde.sh` 自動設定

#### `KDE_PATH`

- **說明**: KDE CLI 的根目錄路徑
- **預設值**: 自動偵測包含 `kde.env` 的目錄
- **用途**: 定位 KDE CLI 安裝位置
- **設定位置**: `kde.sh` 自動設定

#### `KDE_SCRIPTS_PATH`

- **說明**: KDE CLI 腳本目錄路徑
- **預設值**: `${KDE_PATH}/scripts`
- **用途**: 定位所有 KDE CLI 腳本位置
- **設定位置**: `kde.sh` 自動設定

#### `ENVIROMENTS_PATH`

- **說明**: K8s 環境目錄路徑
- **預設值**: `${KDE_PATH}/environments`
- **用途**: 存放所有 K8s 環境配置
- **設定位置**: `kde.sh` 自動設定

#### `KUBE_CONFIG_DIR`

- **說明**: kubeconfig 目錄名稱
- **預設值**: `kubeconfig`
- **用途**: 定義每個環境中 kubeconfig 檔案的目錄名稱
- **設定位置**: `kde.sh` 自動設定

#### `VOLUMES_DIR`

- **說明**: 專案(namespaces)目錄名稱
- **預設值**: `namespaces`
- **用途**: 定義每個環境中專案的目錄名稱
- **設定位置**: `kde.sh` 自動設定

#### `KDE_ENV_FILE`

- **說明**: kde.env 檔案路徑
- **預設值**: `${KDE_PATH}/kde.env`
- **用途**: 全域環境變數配置檔案路徑
- **設定位置**: `kde.sh` 自動設定

#### `CUR_ENV`

- **說明**: 當前使用中的 K8s 環境名稱
- **預設值**: 無（由使用者切換）
- **用途**: 標識當前操作的 K8s 環境
- **設定位置**: `current.env`

#### `KDE_DEBUG`

- **說明**: KDE CLI 調試模式開關
- **預設值**: `false`
- **用途**: 啟用後會顯示詳細的執行命令（set -x）
- **設定位置**: `kde.env`
- **設定方式**:
  ```bash
  echo "KDE_DEBUG=true" >> kde.env
  ```

### Docker 映像配置

#### `KIND_IMAGE`

- **說明**: Kind 環境使用的 Docker 映像
- **預設值**: `r82wei/kind:v0.27.0`
- **用途**: 建立 Kind K8s 環境
- **設定位置**: `kde.env`

#### `K3D_IMAGE`

- **說明**: K3D 環境使用的 Docker 映像
- **預設值**: `r82wei/k3d:v5.8.3`
- **用途**: 建立 K3D K8s 環境
- **設定位置**: `kde.env`

#### `KDE_DEPLOY_ENV_IMAGE`

- **說明**: 部署環境使用的 Docker 映像
- **預設值**: `r82wei/deploy-env:1.0.0`
- **用途**: 執行 kubectl、helm 等 K8s 管理工具
- **設定位置**: `kde.env`

#### `NGROK_PROXY_IMAGE`

- **說明**: Ngrok 代理使用的 Docker 映像
- **預設值**: `r82wei/ngrok-proxy:1.0.0`
- **用途**: 提供 Ngrok 外部連線功能
- **設定位置**: `kde.env`

#### `CLOUDFLARE_TUNNEL_PROXY_IMAGE`

- **說明**: Cloudflare Tunnel 代理使用的 Docker 映像
- **預設值**: `r82wei/cloudflare-tunnel-proxy:1.0.0`
- **用途**: 提供 Cloudflare Tunnel 外部連線功能
- **設定位置**: `kde.env`

#### `K8S_UI_DASHBOARD_IMAGE`

- **說明**: K8s Dashboard UI 使用的 Docker 映像
- **預設值**: `kubernetesui/dashboard:v2.7.0`
- **用途**: 提供 K8s Web UI 管理介面
- **設定位置**: `kde.env`

#### `K9S_IMAGE`

- **說明**: K9s 使用的 Docker 映像
- **預設值**: `quay.io/derailed/k9s`
- **用途**: 提供終端機 K8s 管理介面
- **設定位置**: `kde.env`

#### `TELEPRESENCE_IMAGE`

- **說明**: Telepresence 使用的 Docker 映像
- **預設值**: `r82wei/telepresence:1.0.6`
- **用途**: 提供本地開發環境與 K8s 整合
- **設定位置**: `kde.env`

#### `CODE_SERVER_IMAGE`

- **說明**: Code Server 使用的 Docker 映像
- **預設值**: `docker.io/r82wei/kde-code-server:latest`
- **用途**: 提供 Web 版 VS Code 開發環境
- **設定位置**: `kde.env`

---

## 環境配置變數

這些變數定義在 `environments/<env_name>/k8s.env` 檔案中，用於設定特定 K8s 環境的配置。

### 基本環境配置

#### `ENV_NAME`

- **說明**: 環境名稱
- **範例**: `local-k8s`, `dev-env`, `test-env`
- **用途**: 標識環境的唯一名稱
- **設定位置**: `environments/<env_name>/k8s.env`
- **設定時機**: 執行 `kde start <env_name>` 時自動建立

#### `ENV_TYPE`

- **說明**: 環境類型
- **可選值**:
  - `kind` - Kind 本地環境
  - `k3d` - K3D 本地環境
  - `k8s` - 外部 K8s 環境
- **用途**: 決定環境的建立和管理方式
- **設定位置**: `environments/<env_name>/k8s.env`
- **設定時機**: 執行 `kde start <env_name> [kind|k3d|k8s]` 時設定

#### `K8S_CONTAINER_NAME`

- **說明**: K8s 控制平面容器名稱
- **範例**:
  - Kind: `<env_name>-control-plane`
  - K3D: `k3d-<env_name>-serverlb`
  - 外部 K8s: 伺服器 IP
- **用途**: 用於識別和連接 K8s 控制平面
- **設定位置**: `environments/<env_name>/k8s.env`
- **設定時機**: 建立環境時自動設定

#### `DOCKER_NETWORK`

- **說明**: Docker 網路名稱
- **範例**:
  - Kind/K3D: `kde-<env_name>`
  - 外部 K8s: `bridge`
- **用途**: 定義 K8s 容器使用的 Docker 網路
- **設定位置**: `environments/<env_name>/k8s.env`
- **設定時機**: 建立環境時自動設定

#### `STORAGE_CLASS`

- **說明**: K8s 預設儲存類別
- **預設值**: `local-path`
- **用途**: 定義 PVC 使用的儲存類別
- **設定位置**: `environments/<env_name>/k8s.env`
- **設定時機**: 建立環境時自動設定

#### `CUSTOM_CONFIG`

- **說明**: 是否使用自訂配置檔案
- **可選值**: `true`, 未設定（表示使用預設配置）
- **用途**: 標識是否使用使用者提供的 kind-config.yaml 或 k3d-config.yaml
- **設定位置**: `environments/<env_name>/k8s.env`
- **設定時機**: 使用自訂配置建立環境時設定

---

## 本地環境變數

這些變數定義在 `environments/<env_name>/.env` 檔案中，用於設定特定環境的本地配置（不建議加入版本控制）。

### 路徑配置

#### `VOLUMES_PATH`

- **說明**: 專案目錄完整路徑
- **範例**: `${ENV_PATH}/namespaces`
- **用途**: 定義專案(namespaces)的完整路徑
- **設定位置**: `environments/<env_name>/.env`
- **設定時機**: 環境初始化時自動設定

#### `KUBECONFIG`

- **說明**: kubeconfig 檔案完整路徑
- **範例**: `${ENV_PATH}/kubeconfig/config`
- **用途**: kubectl 等工具使用的配置檔案路徑
- **設定位置**: `environments/<env_name>/.env`（由腳本自動設定）
- **設定時機**: 環境初始化時自動設定

### 網路配置

#### `K8S_API_SERVER_PORT`

- **說明**: K8s API Server 端口
- **預設值**: `6443`
- **用途**: 定義 K8s API Server 對外開放的端口
- **設定位置**: `environments/<env_name>/.env`
- **設定時機**: Kind/K3D 環境初始化時詢問設定
- **設定方式**:
  ```bash
  # 環境初始化時會詢問
  請輸入 K8S api server port (預設: 6443):
  ```

#### `K8S_INGRESS_NGINX_PORT`

- **說明**: K8s Ingress Nginx 端口
- **預設值**: `80`
- **用途**: 定義 Ingress Nginx 對外開放的端口
- **設定位置**: `environments/<env_name>/.env`
- **設定時機**: Kind/K3D 環境初始化時詢問設定
- **設定方式**:
  ```bash
  # 環境初始化時會詢問
  請輸入 K8S ingress nginx port (預設: 80):
  ```

---

## 專案環境變數

這些變數定義在 `environments/<env_name>/namespaces/<project_name>/project.env` 檔案中，用於設定專案的配置。

### Git 倉庫配置

#### `GIT_REPO_URL`

- **說明**: Git 倉庫 URL
- **範例**:
  - 遠端倉庫: `https://github.com/user/repo.git`
  - 本地專案: `./<project_name>`
- **用途**: 定義專案的 Git 倉庫來源
- **設定位置**: `environments/<env_name>/namespaces/<project_name>/project.env`
- **設定時機**: 執行 `kde project create <project_name>` 時設定

#### `GIT_REPO_BRANCH`

- **說明**: Git 分支名稱
- **預設值**: `main`
- **用途**: 定義要使用的 Git 分支
- **設定位置**: `environments/<env_name>/namespaces/<project_name>/project.env`
- **設定時機**: 執行 `kde project create <project_name>` 時設定

### 容器映像配置

#### `DEVELOP_IMAGE`

- **說明**: 開發環境（建置）使用的 Docker 映像
- **範例**: `node:20`, `python:3.9`, `golang:1.21`
- **用途**: 執行 build.sh 的容器環境
- **設定位置**: `environments/<env_name>/namespaces/<project_name>/project.env`
- **設定時機**: 執行 `kde project create <project_name>` 時設定
- **使用場景**:
  - `kde project exec <project_name> develop`
  - `kde project build <project_name>`

#### `DEPLOY_IMAGE`

- **說明**: 部署環境使用的 Docker 映像
- **預設值**: `${KDE_DEPLOY_ENV_IMAGE}`
- **用途**: 執行 deploy.sh 等部署相關腳本的容器環境
- **設定位置**: `environments/<env_name>/namespaces/<project_name>/project.env`
- **設定時機**: 執行 `kde project create <project_name>` 時設定
- **使用場景**:
  - `kde project exec <project_name> deploy`
  - `kde project deploy <project_name>`
  - `kde project undeploy <project_name>`

### CI/CD 階段映像配置（可選）

#### `PRE_BUILD_IMAGE`

- **說明**: 建置前階段使用的 Docker 映像
- **預設值**: `${DEVELOP_IMAGE}`（未設定時使用）
- **用途**: 執行 pre-build.sh 的容器環境
- **設定位置**: `environments/<env_name>/namespaces/<project_name>/project.env`
- **設定時機**: 手動設定（可選）

#### `BUILD_IMAGE`

- **說明**: 建置階段使用的 Docker 映像
- **預設值**: `${DEVELOP_IMAGE}`（未設定時使用）
- **用途**: 執行 build.sh 的容器環境
- **設定位置**: `environments/<env_name>/namespaces/<project_name>/project.env`
- **設定時機**: 手動設定（可選）

#### `POST_BUILD_IMAGE`

- **說明**: 建置後階段使用的 Docker 映像
- **預設值**: `${DEVELOP_IMAGE}`（未設定時使用）
- **用途**: 執行 post-build.sh 的容器環境
- **設定位置**: `environments/<env_name>/namespaces/<project_name>/project.env`
- **設定時機**: 手動設定（可選）

#### `PRE_DEPLOY_IMAGE`

- **說明**: 部署前階段使用的 Docker 映像
- **預設值**: `${DEPLOY_IMAGE}`（未設定時使用）
- **用途**: 執行 pre-deploy.sh 的容器環境
- **設定位置**: `environments/<env_name>/namespaces/<project_name>/project.env`
- **設定時機**: 手動設定（可選）

#### `POST_DEPLOY_IMAGE`

- **說明**: 部署後階段使用的 Docker 映像
- **預設值**: `${DEPLOY_IMAGE}`（未設定時使用）
- **用途**: 執行 post-deploy.sh 的容器環境
- **設定位置**: `environments/<env_name>/namespaces/<project_name>/project.env`
- **設定時機**: 手動設定（可選）

#### `UNDEPLOY_IMAGE`

- **說明**: 解除部署階段使用的 Docker 映像
- **預設值**: `${DEPLOY_IMAGE}`（未設定時使用）
- **用途**: 執行 undeploy.sh 的容器環境
- **設定位置**: `environments/<env_name>/namespaces/<project_name>/project.env`
- **設定時機**: 手動設定（可選）

### Helm 配置（自動設定）

#### `HELM_CONFIG_HOME`

- **說明**: Helm 配置目錄
- **預設值**: `${PROJECT_PATH}/.helm/config`
- **用途**: 儲存 Helm 配置
- **設定位置**: `environments/<env_name>/namespaces/<project_name>/project.env`
- **設定時機**: 建立專案時自動設定

#### `HELM_CACHE_HOME`

- **說明**: Helm 快取目錄
- **預設值**: `${PROJECT_PATH}/.helm/cache`
- **用途**: 儲存 Helm 快取
- **設定位置**: `environments/<env_name>/namespaces/<project_name>/project.env`
- **設定時機**: 建立專案時自動設定

#### `HELM_DATA_HOME`

- **說明**: Helm 資料目錄
- **預設值**: `${PROJECT_PATH}/.helm/data`
- **用途**: 儲存 Helm 資料
- **設定位置**: `environments/<env_name>/namespaces/<project_name>/project.env`
- **設定時機**: 建立專案時自動設定

#### `HELM_PLUGINS`

- **說明**: Helm 插件目錄
- **預設值**: `${PROJECT_PATH}/.helm/plugins`
- **用途**: 儲存 Helm 插件
- **設定位置**: `environments/<env_name>/namespaces/<project_name>/project.env`
- **設定時機**: 建立專案時自動設定

### 自訂掛載配置

#### `KDE_MOUNT_*`

- **說明**: 自訂 Docker Volume 掛載
- **格式**: `KDE_MOUNT_<名稱>=<來源路徑>:<目標路徑>`
- **範例**:

  ```bash
  # 掛載 .netrc 檔案
  KDE_MOUNT_NETRC=~/.netrc:~/.netrc

  # 掛載 .docker 目錄
  KDE_MOUNT_DOCKER=~/.docker:~/.docker

  # 掛載自訂資料夾
  KDE_MOUNT_DATA=/path/to/data:/data
  ```

- **用途**: 在專案容器中掛載額外的檔案或目錄
- **設定位置**: `environments/<env_name>/namespaces/<project_name>/project.env`
- **設定時機**: 手動設定
- **注意事項**:
  - 支援 `~` 符號表示 HOME 目錄
  - 所有 `KDE_MOUNT_` 開頭的環境變數都會被自動轉換為 Docker -v 參數

### 專案本地配置（.env）

專案也可以在 `environments/<env_name>/namespaces/<project_name>/.env` 中設定本地環境變數（不建議加入版本控制）。

- **用途**: 儲存敏感資訊或本地特定的配置
- **優先級**: 會覆蓋 `project.env` 中的同名變數
- **範例**:

  ```bash
  # API 金鑰
  API_KEY=your_secret_key

  # 資料庫連線
  DB_HOST=localhost
  DB_PORT=5432
  ```

---

## 雲端代理環境變數

### Ngrok 配置

#### `NGROK_TOKEN`

- **說明**: Ngrok 認證令牌
- **用途**: 用於 Ngrok 服務認證
- **設定位置**: `ngrok.env`
- **設定時機**: 首次使用 `kde ngrok` 時詢問設定
- **設定方式**:

  ```bash
  # 首次使用時會詢問
  請輸入 NGROK_TOKEN:

  # 或手動編輯 ngrok.env
  echo "NGROK_TOKEN=your_token_here" >> ngrok.env
  ```

### Telepresence 配置

#### `TELEPRESENCE_MANAGER_NAMESPACE`

- **說明**: Telepresence Traffic Manager 的命名空間
- **預設值**: `ambassador`
- **用途**: 指定 Telepresence Traffic Manager 安裝的命名空間
- **設定位置**: 執行時環境變數
- **設定方式**:
  ```bash
  export TELEPRESENCE_MANAGER_NAMESPACE=custom-namespace
  kde telepresence intercept ...
  ```

#### `TELEPRESENCE_CONNECT_NAMESPACE`

- **說明**: Telepresence 連線的命名空間
- **用途**: 指定要連線的 K8s 命名空間
- **設定位置**: 執行時自動設定
- **設定時機**: 執行 Telepresence 命令時自動設定

#### `TELEPRESENCE_ALSO_PROXY_CIDR`

- **說明**: Telepresence 額外代理的 CIDR 網段
- **範例**: `10.0.0.0/8,172.16.0.0/12`
- **用途**: 指定額外需要透過 Telepresence 代理的內網網段
- **設定位置**: 執行時環境變數
- **設定方式**:
  ```bash
  export TELEPRESENCE_ALSO_PROXY_CIDR=10.0.0.0/8
  kde telepresence intercept ...
  ```

---

## 內部使用變數

這些變數主要供 KDE CLI 內部使用，一般使用者不需要手動設定。

### 環境管理變數

#### `ENV_PATH`

- **說明**: 當前環境的完整路徑
- **計算方式**: `${ENVIROMENTS_PATH}/${ENV_NAME}`
- **用途**: 內部腳本使用，定位環境目錄

#### `K8S_ENV_FILE_PATH`

- **說明**: k8s.env 檔案完整路徑
- **計算方式**: `${ENV_PATH}/k8s.env`
- **用途**: 內部腳本使用，讀取環境配置

#### `LOCAL_ENV_FILE_PATH`

- **說明**: .env 檔案完整路徑
- **計算方式**: `${ENV_PATH}/.env`
- **用途**: 內部腳本使用，讀取本地配置

#### `PROJECT_PATH`

- **說明**: 當前專案的完整路徑
- **計算方式**: `${ENVIROMENTS_PATH}/${CUR_ENV}/${VOLUMES_DIR}/${PROJECT_NAME}`
- **用途**: 內部腳本使用，定位專案目錄

### 運行時變數

#### `INITIALIZING`

- **說明**: 環境初始化中標誌
- **可選值**: `true`, 未設定
- **用途**: 內部腳本使用，標識環境正在初始化

#### `K8S_NODE_READY_TIMEOUT`

- **說明**: K8s 節點就緒檢查超時時間
- **預設值**: `2s`
- **用途**: 控制檢查 K8s 節點是否就緒的超時時間
- **設定方式**:
  ```bash
  export K8S_NODE_READY_TIMEOUT=5s
  ```

### Telepresence 內部變數

#### `NAMESPACE`

- **說明**: Telepresence 操作的命名空間
- **用途**: 內部腳本使用，傳遞命名空間資訊

#### `WORKLOAD`

- **說明**: Telepresence 操作的工作負載
- **用途**: 內部腳本使用，傳遞工作負載資訊

---

## 環境變數優先級

當同一個變數在多個檔案中定義時，優先級如下（由高到低）：

1. **執行時環境變數**: 在命令列中 `export` 設定的變數
2. **專案本地配置**: `environments/<env_name>/namespaces/<project_name>/.env`
3. **專案配置**: `environments/<env_name>/namespaces/<project_name>/project.env`
4. **環境本地配置**: `environments/<env_name>/.env`
5. **環境配置**: `environments/<env_name>/k8s.env`
6. **當前環境配置**: `current.env`
7. **全域配置**: `kde.env`
8. **預設值**: KDE CLI 程式碼中定義的預設值

---

## 環境變數載入順序

KDE CLI 在執行時會按以下順序載入環境變數：

```bash
# 1. 載入全域配置
source ${KDE_ENV_FILE}                                    # kde.env

# 2. 載入 Ngrok 配置（如果存在）
source ${KDE_PATH}/ngrok.env                              # ngrok.env

# 3. 載入當前環境配置
source ${KDE_PATH}/current.env                            # current.env

# 4. 載入環境配置
source ${ENV_PATH}/k8s.env                                # k8s.env

# 5. 載入環境本地配置
source ${ENV_PATH}/.env                                   # .env

# 6. 專案執行時載入專案配置
source ${PROJECT_PATH}/project.env                        # project.env
source ${PROJECT_PATH}/.env                               # project .env
```

---

## 常見使用場景

### 場景 1: 設定開發環境

```bash
# 1. 建立開發環境
kde start dev-env kind

# 2. 設定 API Server 端口
# 系統會詢問: 請輸入 K8S api server port (預設: 6443):
# 輸入: 6443

# 3. 設定 Ingress 端口
# 系統會詢問: 請輸入 K8S ingress nginx port (預設: 80):
# 輸入: 8080

# 4. 檢查環境變數
cat environments/dev-env/k8s.env
# ENV_NAME=dev-env
# ENV_TYPE=kind
# K8S_CONTAINER_NAME=dev-env-control-plane
# DOCKER_NETWORK=kde-dev-env
# STORAGE_CLASS=local-path

cat environments/dev-env/.env
# VOLUMES_PATH=/path/to/kde/environments/dev-env/namespaces
# K8S_API_SERVER_PORT=6443
# K8S_INGRESS_NGINX_PORT=8080
```

### 場景 2: 建立專案並設定環境

```bash
# 1. 建立專案
kde project create myapp

# 2. 設定 Git 倉庫
# 系統會詢問: Is this project a git remote repo? (y/n):
# 輸入: y
# 系統會詢問: 請輸入 git repo HTTPS URL:
# 輸入: https://github.com/user/myapp.git
# 系統會詢問: 請輸入分支名稱(default: main):
# 輸入: main

# 3. 設定開發環境
# 系統會詢問: 請輸入專案開發(建置)環境 Image:
# 輸入: node:20

# 4. 設定部署環境
# 系統會詢問: 請輸入專案部署環境 Image:
# 輸入: r82wei/deploy-env:1.0.0

# 5. 自訂環境變數
cat >> environments/dev-env/namespaces/myapp/project.env << EOF
# API 配置
API_URL=https://api.example.com

# 掛載 Docker 配置
KDE_MOUNT_DOCKER=~/.docker:~/.docker

# 掛載 NPM 快取
KDE_MOUNT_NPM=~/.npm:~/.npm
EOF

# 6. 設定敏感資訊（本地配置）
cat >> environments/dev-env/namespaces/myapp/.env << EOF
API_KEY=your_secret_key
DB_PASSWORD=your_db_password
EOF
```

### 場景 3: 使用 Telepresence 連線

```bash
# 1. 設定代理網段（如果需要）
export TELEPRESENCE_ALSO_PROXY_CIDR=10.0.0.0/8,172.16.0.0/12

# 2. 設定 Traffic Manager 命名空間（如果不是預設的 ambassador）
export TELEPRESENCE_MANAGER_NAMESPACE=custom-namespace

# 3. 執行 Telepresence 連線
kde telepresence intercept myapp myapp-deployment

# 4. 進入開發環境
kde project exec myapp develop
```

### 場景 4: 調試 KDE CLI

```bash
# 1. 啟用調試模式
echo "KDE_DEBUG=true" >> kde.env

# 2. 重新執行命令
kde status
# 會顯示詳細的執行命令

# 3. 關閉調試模式
# 編輯 kde.env，將 KDE_DEBUG 設為 false 或刪除該行
```

---

## 最佳實踐

### 1. 版本控制建議

**應加入版本控制的檔案：**

- `kde.env`（Docker 映像版本）
- `environments/<env_name>/k8s.env`（環境公用配置）
- `environments/<env_name>/namespaces/<project_name>/project.env`（專案配置）

**不應加入版本控制的檔案：**

- `current.env`（當前環境，個人偏好）
- `ngrok.env`（包含 Token）
- `environments/<env_name>/.env`（本地配置）
- `environments/<env_name>/namespaces/<project_name>/.env`（敏感資訊）
- `environments/<env_name>/kubeconfig/`（K8s 配置）
- `environments/<env_name>/pki/`（PKI 憑證）

### 2. 敏感資訊處理

```bash
# 將敏感資訊放在 .env 檔案中
cat >> environments/dev-env/namespaces/myapp/.env << EOF
API_KEY=secret_key
DB_PASSWORD=secret_password
PRIVATE_TOKEN=secret_token
EOF

# 確保 .env 檔案不被加入版本控制
echo "**/.env" >> .gitignore
```

### 3. 團隊協作

```bash
# 在 project.env 中使用預設值和註解
cat >> environments/dev-env/namespaces/myapp/project.env << EOF
# Git 倉庫配置
GIT_REPO_URL=https://github.com/team/myapp.git
GIT_REPO_BRANCH=main

# 容器映像配置
DEVELOP_IMAGE=node:20
DEPLOY_IMAGE=r82wei/deploy-env:1.0.0

# API 配置（可在 .env 中覆蓋）
API_URL=https://api.staging.example.com

# 掛載配置範例
# KDE_MOUNT_DOCKER=~/.docker:~/.docker
# KDE_MOUNT_NPM=~/.npm:~/.npm
EOF

# 提供 .env.example 作為範本
cat >> environments/dev-env/namespaces/myapp/.env.example << EOF
# API 金鑰（請填入您的金鑰）
API_KEY=

# 資料庫密碼（請填入您的密碼）
DB_PASSWORD=

# 可選：覆蓋 API URL
# API_URL=https://api.dev.example.com
EOF
```

### 4. 環境隔離

```bash
# 為不同環境建立不同的配置
# 開發環境
kde start dev-env kind
cat >> environments/dev-env/.env << EOF
K8S_API_SERVER_PORT=6443
K8S_INGRESS_NGINX_PORT=8080
EOF

# 測試環境
kde start test-env k3d
cat >> environments/test-env/.env << EOF
K8S_API_SERVER_PORT=6444
K8S_INGRESS_NGINX_PORT=8081
EOF
```

---

## 故障排除

### 問題 1: 環境變數未生效

**症狀**: 修改了環境變數但未生效

**解決方案**:

```bash
# 1. 確認環境變數檔案位置正確
ls -la environments/${CUR_ENV}/

# 2. 確認環境變數語法正確（等號兩邊不要有空格）
cat environments/${CUR_ENV}/k8s.env

# 3. 重新載入環境
kde use ${CUR_ENV}

# 4. 檢查環境變數是否載入
env | grep ENV_NAME
```

### 問題 2: Docker 映像無法下載

**症狀**: 啟動環境時 Docker 映像下載失敗

**解決方案**:

```bash
# 1. 檢查映像設定
cat kde.env | grep IMAGE

# 2. 手動拉取映像測試
docker pull r82wei/kind:v0.27.0

# 3. 如果需要，修改為其他映像
echo "KIND_IMAGE=kindest/node:v1.27.0" >> kde.env
```

### 問題 3: 專案容器無法掛載檔案

**症狀**: 使用 `KDE_MOUNT_*` 掛載檔案失敗

**解決方案**:

```bash
# 1. 確認檔案路徑存在
ls -la ~/.docker

# 2. 確認路徑格式正確
cat environments/${CUR_ENV}/namespaces/myapp/project.env | grep KDE_MOUNT

# 3. 確認使用絕對路徑或 ~ 符號
# 正確: KDE_MOUNT_DOCKER=~/.docker:~/.docker
# 錯誤: KDE_MOUNT_DOCKER=.docker:.docker
```

---

## 參考資料

- [KDE 環境管理指南](../k8s/k8s-env.md)
- [KDE 專案管理指南](../projects/setting.md)
- [KDE 資料夾結構說明](../folder.structure.md)
- [Telepresence 使用說明](../telepresence.usage.md)
- [Ngrok 使用說明](../ngrok.usage.md)
