# 專案設定說明

本文件說明如何設定 KDE 專案的環境變數及 CI/CD 腳本。

## 目錄

- [專案目錄結構](#專案目錄結構)
- [專案設定檔 (project.env)](#專案設定檔-projectenv)
- [CI/CD 腳本說明](#cicd-腳本說明)
- [環境變數設定](#環境變數設定)
- [掛載檔案與資料夾](#掛載檔案與資料夾)
- [最佳實踐](#最佳實踐)
- [常見問題](#常見問題)

## 專案目錄結構

當使用 `kde project create` 建立專案後，會在當前環境的 `namespaces` 目錄下建立專案資料夾：

```
environments/
└── <env_name>/
    └── namespaces/
        └── <project_name>/
            ├── project.env          # 專案設定檔（必要）
            ├── pre-build.sh         # CI 前置腳本（選擇性）
            ├── build.sh             # CI 執行腳本（選擇性）
            ├── post-build.sh        # CI 後置腳本（選擇性）
            ├── pre-deploy.sh        # CD 前置腳本（選擇性）
            ├── deploy.sh            # CD 執行腳本（必要）
            ├── post-deploy.sh       # CD 後置腳本（選擇性）
            ├── undeploy.sh          # 解除部署腳本（選擇性）
            ├── <repo_name>/         # Git repository 內容
            └── <pvc_dir>/           # PVC 掛載的資料夾
```

## 專案設定檔 (project.env)

### 基本結構

`project.env` 是專案的核心設定檔，定義了專案的 Git repository、開發環境、部署環境等資訊。

#### 必要環境變數

執行 `kde project create` 時會自動建立以下基本環境變數：

```bash
# Git Repository 設定
GIT_REPO_URL=https://github.com/username/repo.git  # Git repository URL
GIT_REPO_BRANCH=main                                # Git 分支名稱

# 開發環境 Image（CI 環境）
DEVELOP_IMAGE=node:20                               # 用於執行 build.sh 的環境

# 部署環境 Image（CD 環境）
DEPLOY_IMAGE=r82wei/deploy-env:1.0.0               # 用於執行 deploy.sh 的環境
```

### Git Repository 設定

#### 使用遠端 Git Repository

如果專案來自 Git repository：

```bash
GIT_REPO_URL=https://github.com/nodejs/examples.git
GIT_REPO_BRANCH=main
```

專案目錄結構：

```
<project_name>/
├── project.env
├── build.sh
├── deploy.sh
└── examples/           # Git repo 內容會下載到這裡
```

#### 使用本地專案

如果是本地專案（不使用 Git）：

```bash
GIT_REPO_URL=./<project_name>
GIT_REPO_BRANCH=main
```

專案目錄結構：

```
<project_name>/
├── project.env
├── build.sh
├── deploy.sh
└── <project_name>/     # 本地專案內容放在這裡
```

### 開發與部署環境 Image

#### DEVELOP_IMAGE (CI 環境)

用於執行建置相關腳本的環境：

- `pre-build.sh`（預設）
- `build.sh`（預設）
- `post-build.sh`（預設）

**範例：**

```bash
# Node.js 專案
DEVELOP_IMAGE=node:20

# Python 專案
DEVELOP_IMAGE=python:3.11

# Go 專案
DEVELOP_IMAGE=golang:1.21

# 自訂 Image（包含多種工具）
DEVELOP_IMAGE=myregistry/my-build-env:latest
```

#### DEPLOY_IMAGE (CD 環境)

用於執行部署相關腳本的環境：

- `pre-deploy.sh`（預設）
- `deploy.sh`（必須）
- `post-deploy.sh`（預設）
- `undeploy.sh`（預設）

**範例：**

```bash
# 使用 KDE 提供的部署環境（包含 kubectl、helm 等工具）
DEPLOY_IMAGE=r82wei/deploy-env:1.0.0

# 自訂部署環境
DEPLOY_IMAGE=myregistry/my-deploy-env:latest
```

## CI/CD 腳本說明

### 腳本執行順序

執行 `kde project deploy <project_name>` 時，會依照以下順序執行腳本：

| 順序 | 腳本檔案       | 說明        | 預設執行環境    | 自訂執行環境        |
| ---- | -------------- | ----------- | --------------- | ------------------- |
| 1    | pre-build.sh   | CI 前置作業 | `DEVELOP_IMAGE` | `PRE_BUILD_IMAGE`   |
| 2    | build.sh       | CI 建置作業 | `DEVELOP_IMAGE` | `BUILD_IMAGE`       |
| 3    | post-build.sh  | CI 後置作業 | `DEVELOP_IMAGE` | `POST_BUILD_IMAGE`  |
| 4    | pre-deploy.sh  | CD 前置作業 | `DEPLOY_IMAGE`  | `PRE_DEPLOY_IMAGE`  |
| 5    | deploy.sh      | CD 部署作業 | `DEPLOY_IMAGE`  | -                   |
| 6    | post-deploy.sh | CD 後置作業 | `DEPLOY_IMAGE`  | `POST_DEPLOY_IMAGE` |
| 7    | undeploy.sh    | 解除部署    | `DEPLOY_IMAGE`  | `UNDEPLOY_IMAGE`    |

### 腳本說明

#### 1. pre-build.sh（選擇性）

**用途：** CI 前置作業，例如：安裝相依套件、設定環境

**執行時機：**

- `kde project build <project_name>`
- `kde project deploy <project_name>`

**執行環境：** `PRE_BUILD_IMAGE`（未設定則使用 `DEVELOP_IMAGE`）

**範例：**

```bash
#!/bin/bash
set -e

echo "=== Pre-build: Installing dependencies ==="

# 安裝 npm 套件
npm install

# 設定環境變數
export NODE_ENV=production
```

#### 2. build.sh（選擇性）

**用途：** CI 執行腳本，用於編譯、建置、測試

**執行時機：**

- `kde project build <project_name>`
- `kde project deploy <project_name>`

**執行環境：** `BUILD_IMAGE`（未設定則使用 `DEVELOP_IMAGE`）

**範例：**

```bash
#!/bin/bash
set -e

echo "=== Building application ==="

# 進入 Git repo 目錄
cd $(basename -s .git ${GIT_REPO_URL})

# 編譯應用程式
npm run build

# 執行測試
npm test

# 建置 Docker Image（如果需要）
docker build -t myapp:${GIT_REPO_BRANCH} .
```

#### 3. post-build.sh（選擇性）

**用途：** CI 後置作業，例如：上傳建置產物、通知

**執行時機：**

- `kde project build <project_name>`
- `kde project deploy <project_name>`

**執行環境：** `POST_BUILD_IMAGE`（未設定則使用 `DEVELOP_IMAGE`）

**範例：**

```bash
#!/bin/bash
set -e

echo "=== Post-build: Uploading artifacts ==="

# 上傳建置產物到 S3
# aws s3 cp ./dist s3://my-bucket/artifacts/ --recursive
```

#### 4. pre-deploy.sh（選擇性）

**用途：** CD 前置作業，例如：建立 Namespace、Secret

**執行時機：**

- `kde project deploy <project_name>`
- `kde project deploy-only <project_name>`

**執行環境：** `PRE_DEPLOY_IMAGE`（未設定則使用 `DEPLOY_IMAGE`）

**範例：**

```bash
#!/bin/bash
set -e

echo "=== Pre-deploy: Creating namespace and secrets ==="

# 建立 Namespace
kubectl create namespace ${PROJECT_NAME} --dry-run=client -o yaml | kubectl apply -f -

# 建立 Secret
kubectl create secret generic app-secret \
  --from-literal=DB_PASSWORD=${DB_PASSWORD} \
  -n ${PROJECT_NAME} \
  --dry-run=client -o yaml | kubectl apply -f -
```

#### 5. deploy.sh（必要）

**用途：** CD 執行腳本，部署應用到 Kubernetes

**執行時機：**

- `kde project deploy <project_name>`
- `kde project deploy-only <project_name>`

**執行環境：** `DEPLOY_IMAGE`

**範例：**

```bash
#!/bin/bash
set -e

echo "=== Deploying application ==="

# 進入 Git repo 目錄
cd $(basename -s .git ${GIT_REPO_URL})

# 使用 Helm 部署
helm upgrade --install myapp ./helm-chart \
  --namespace ${PROJECT_NAME} \
  --create-namespace \
  --set image.tag=${GIT_REPO_BRANCH} \
  --wait

# 或使用 kubectl apply
# kubectl apply -f k8s/ -n ${PROJECT_NAME}
```

#### 6. post-deploy.sh（選擇性）

**用途：** CD 後置作業，例如：驗證部署、發送通知

**執行時機：**

- `kde project deploy <project_name>`
- `kde project deploy-only <project_name>`

**執行環境：** `POST_DEPLOY_IMAGE`（未設定則使用 `DEPLOY_IMAGE`）

**範例：**

```bash
#!/bin/bash
set -e

echo "=== Post-deploy: Verifying deployment ==="

# 等待 Pod 就緒
kubectl wait --for=condition=ready pod \
  -l app=myapp \
  -n ${PROJECT_NAME} \
  --timeout=300s

# 執行健康檢查
kubectl exec -n ${PROJECT_NAME} deployment/myapp -- curl -f http://localhost:8080/health
```

#### 7. undeploy.sh（選擇性）

**用途：** 解除部署，清理 Kubernetes 資源

**執行時機：**

- `kde project undeploy <project_name>`
- `kde project remove <project_name>`

**執行環境：** `UNDEPLOY_IMAGE`（未設定則使用 `DEPLOY_IMAGE`）

**預設行為：** 如果 `undeploy.sh` 不存在，預設會刪除與專案同名的 namespace

**範例：**

```bash
#!/bin/bash
set -e

echo "=== Undeploying application ==="

# 使用 Helm 卸載
helm uninstall myapp -n ${PROJECT_NAME}

# 或使用 kubectl delete
# kubectl delete -f k8s/ -n ${PROJECT_NAME}

# 刪除 Namespace
kubectl delete namespace ${PROJECT_NAME}
```

## 環境變數設定

### 自訂環境變數

在 `project.env` 中可以定義任何自訂環境變數，這些環境變數會在執行 CI/CD 腳本和進入容器開發環境時自動注入。

#### 範例：資料庫連線設定

```bash
# 資料庫設定
DB_HOST=mysql.default.svc.cluster.local
DB_PORT=3306
DB_NAME=myapp
DB_USER=root
DB_PASSWORD=secret123

# 應用程式設定
APP_ENV=development
APP_DEBUG=true
APP_PORT=3000

# API 金鑰
API_KEY=your-api-key-here
STRIPE_SECRET_KEY=sk_test_xxxxx
```

#### 範例：不同環境的專案設定

KDE 的設計理念：**一個 Project = 一個 Kubernetes Namespace**

如果需要在不同環境（開發、測試、生產）部署相同的專案，有兩種方式：

**方式一：建立不同的 K8s 環境（推薦）**

每個環境使用獨立的 K8s 集群，專案名稱可以相同：

```
# 開發環境
environments/dev/namespaces/myapp/
  └── project.env    # 開發環境設定

# 測試環境
environments/staging/namespaces/myapp/
  └── project.env    # 測試環境設定

# 生產環境
environments/prod/namespaces/myapp/
  └── project.env    # 生產環境設定
```

**方式二：在同一個 K8s 內使用不同的 Namespace**

如果在同一個 K8s 集群內部署多個版本，需要使用不同的專案名稱（Namespace）：

```
# 同一個 K8s 環境
environments/dev/namespaces/
├── myapp-test/
│   └── project.env      # 測試版本設定
├── myapp-staging/
│   └── project.env      # 預發布版本設定
└── myapp-prod/
    └── project.env      # 生產版本設定
```

**開發環境的 project.env：**

```bash
GIT_REPO_URL=https://github.com/username/myapp.git
GIT_REPO_BRANCH=develop
DEVELOP_IMAGE=node:20
DEPLOY_IMAGE=r82wei/deploy-env:1.0.0

# 開發環境設定
DB_HOST=mysql.dev.svc.cluster.local
REPLICA_COUNT=1
DEBUG=true
```

**生產環境的 project.env：**

```bash
GIT_REPO_URL=https://github.com/username/myapp.git
GIT_REPO_BRANCH=main
DEVELOP_IMAGE=node:20
DEPLOY_IMAGE=r82wei/deploy-env:1.0.0

# 生產環境設定
DB_HOST=mysql.prod.svc.cluster.local
REPLICA_COUNT=3
DEBUG=false
```

### 內建環境變數

KDE 會自動提供以下環境變數供腳本使用：

| 環境變數          | 說明                            | 範例值                             |
| ----------------- | ------------------------------- | ---------------------------------- |
| `PROJECT_NAME`    | 專案名稱（也是 namespace 名稱） | `myapp`                            |
| `PROJECT_PATH`    | 專案在容器內的路徑              | `/workspace/myapp`                 |
| `GIT_REPO_URL`    | Git repository URL              | `https://github.com/user/repo.git` |
| `GIT_REPO_BRANCH` | Git 分支                        | `main`                             |
| `KUBECONFIG`      | Kubernetes 配置檔案路徑         | `/workspace/.kube/config`          |

## 掛載檔案與資料夾

### 使用 KDE*MOUNT* 前綴掛載檔案

在 `project.env` 中設定 `KDE_MOUNT_` 開頭的環境變數來掛載檔案或資料夾到容器內。

#### 語法格式

```bash
KDE_MOUNT_<NAME>=<host_path>:<container_path>[:<options>]
```

- `<NAME>`: 自訂名稱（任意命名）
- `<host_path>`: 主機端路徑
- `<container_path>`: 容器內路徑
- `<options>`: 掛載選項（選擇性，例如：`ro` 表示唯讀）

#### 範例：掛載 .netrc 檔案

```bash
# 掛載 .netrc 用於 Git 認證
KDE_MOUNT_NETRC=~/.netrc:~/.netrc:ro
```

#### 範例：掛載 SSH 金鑰

```bash
# 掛載 SSH 金鑰
KDE_MOUNT_SSH_KEY=~/.ssh/id_rsa:~/.ssh/id_rsa:ro
KDE_MOUNT_SSH_KNOWN_HOSTS=~/.ssh/known_hosts:~/.ssh/known_hosts:ro
```

#### 範例：掛載 Docker Socket

```bash
# 掛載 Docker socket（用於在容器內建置 Docker Image）
KDE_MOUNT_DOCKER_SOCK=/var/run/docker.sock:/var/run/docker.sock
```

#### 範例：掛載設定檔

```bash
# 掛載 npm 設定
KDE_MOUNT_NPM_CONFIG=~/.npmrc:~/.npmrc:ro

# 掛載 git 設定
KDE_MOUNT_GIT_CONFIG=~/.gitconfig:~/.gitconfig:ro

# 掛載 AWS 憑證
KDE_MOUNT_AWS_CREDENTIALS=~/.aws/credentials:~/.aws/credentials:ro
KDE_MOUNT_AWS_CONFIG=~/.aws/config:~/.aws/config:ro
```

#### 範例：掛載資料夾

```bash
# 掛載本地 node_modules 加速開發
KDE_MOUNT_NODE_MODULES=./node_modules:/workspace/myapp/node_modules

# 掛載暫存目錄
KDE_MOUNT_CACHE=./cache:/tmp/cache
```

### 注意事項

1. **路徑展開規則**：

   ```bash
   # 正確：主機端和容器端都支援 ~ 展開
   KDE_MOUNT_NETRC=~/.netrc:~/.netrc:ro
   KDE_MOUNT_SSH_KEY=~/.ssh/id_rsa:~/.ssh/id_rsa:ro

   # 正確：主機端支援相對路徑 ./，容器端使用絕對路徑
   KDE_MOUNT_CONFIG=./config.json:/app/config.json:ro

   # 正確：都使用絕對路徑
   KDE_MOUNT_DATA=/path/to/data:/data:ro

   # 錯誤：容器端不支援相對路徑 ./
   # KDE_MOUNT_NETRC=~/.netrc:./netrc:ro
   ```

2. **主機端路徑規則**：

   - 支援 `~` 展開為使用者家目錄
   - 支援 `./` 相對於專案目錄的相對路徑
   - 支援 `/` 開頭的絕對路徑

3. **容器端路徑規則**：

   - 支援 `~` 展開（通常是 `/root`）
   - 支援 `/` 開頭的絕對路徑
   - **不支援** `./` 相對路徑

4. **唯讀掛載**：使用 `:ro` 選項防止容器修改主機檔案

5. **權限問題**：確保容器內的使用者有權限存取掛載的檔案

## 最佳實踐

### 1. 專案設定檔管理

#### 版本控制建議

```bash
# 建議納入版本控制
- project.env（移除敏感資訊）
- .env.template（環境變數範本）
- build.sh
- deploy.sh
- pre-deploy.sh
- post-deploy.sh
- undeploy.sh
- .gitignore

# 不要納入版本控制
- .env（本地環境變數）
- secrets/（敏感資訊）
- *.key（金鑰檔案）
```

#### 管理敏感資訊

**方法一：使用本地 .env 檔案**

在專案資料夾下建立 `.env` 檔案存放本地環境變數，並加入 `.gitignore`。

建議同時建立 `.env.template` 作為範本納入版控，讓團隊成員知道需要設定哪些環境變數：

```bash
# 專案目錄結構
environments/<env_name>/namespaces/<project_name>/
├── project.env          # 專案設定檔（納入版控）
├── .env.template        # 環境變數範本（納入版控）
├── .env                 # 本地環境變數（不納入版控）
├── .gitignore           # 忽略 .env
├── build.sh
├── deploy.sh
└── ...
```

在 `.gitignore` 中加入：

```bash
# .gitignore
.env
```

建立 `.env.template` 作為範本（納入版控）：

```bash
# .env.template（納入版控，作為範例）
# 複製此檔案為 .env 並填入實際值
# cp .env.template .env

# 資料庫設定
DB_PASSWORD=<your-db-password>

# API 金鑰
API_KEY=<your-api-key>

# AWS 憑證
AWS_ACCESS_KEY_ID=<your-aws-access-key-id>
AWS_SECRET_ACCESS_KEY=<your-aws-secret-access-key>
```

使用方式：

```bash
# 1. 從範本複製建立 .env
cp .env.template .env

# 2. 編輯 .env 填入實際的敏感資訊
vim .env
```

在 `.env` 中設定實際的敏感資訊（不納入版控）：

```bash
# .env（不納入版控）
# 從 .env.template 複製後填入實際值

DB_PASSWORD=secret123
API_KEY=your-api-key-here
AWS_ACCESS_KEY_ID=AKIAIOSFODNN7EXAMPLE
AWS_SECRET_ACCESS_KEY=wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY
```

在 CI/CD 腳本中載入：

```bash
#!/bin/bash
# build.sh 或 deploy.sh

# 載入本地環境變數（如果存在）
if [ -f .env ]; then
    source .env
fi

# 現在可以使用環境變數
echo "Connecting to database..."
kubectl create secret generic app-secret \
  --from-literal=DB_PASSWORD=${DB_PASSWORD} \
  -n ${PROJECT_NAME} \
  --dry-run=client -o yaml | kubectl apply -f -
```

**方法二：直接從系統環境變數讀取**

在執行前設定環境變數：

```bash
# 在執行前設定環境變數
export DB_PASSWORD=secret123
kde project deploy myapp
```

在 `project.env` 中引用環境變數：

```bash
# project.env
DB_HOST=mysql.default.svc.cluster.local
DB_USER=root
DB_PASSWORD=${DB_PASSWORD}  # 從環境變數讀取
```

### 2. CI/CD 腳本最佳實踐

#### 使用 set -e 確保錯誤中斷

```bash
#!/bin/bash
set -e  # 任何命令失敗時立即退出

# 腳本內容...
```

#### 加入詳細日誌

```bash
#!/bin/bash
set -e

echo "=== Starting deployment ==="
echo "Project: ${PROJECT_NAME}"
echo "Branch: ${GIT_REPO_BRANCH}"
echo "Environment: ${ENV}"

# 部署邏輯...

echo "=== Deployment completed successfully ==="
```

#### 使用函數提高可讀性

```bash
#!/bin/bash
set -e

deploy_database() {
    echo "Deploying database..."
    helm upgrade --install mysql ./charts/mysql -n ${PROJECT_NAME}
}

deploy_backend() {
    echo "Deploying backend..."
    helm upgrade --install backend ./charts/backend -n ${PROJECT_NAME}
}

deploy_frontend() {
    echo "Deploying frontend..."
    helm upgrade --install frontend ./charts/frontend -n ${PROJECT_NAME}
}

# 主流程
echo "=== Starting deployment ==="
deploy_database
deploy_backend
deploy_frontend
echo "=== Deployment completed ==="
```

#### 加入錯誤處理

```bash
#!/bin/bash
set -e

# 錯誤處理函數
handle_error() {
    echo "Error occurred in line $1"
    exit 1
}

trap 'handle_error $LINENO' ERR

# 腳本邏輯...
```

### 3. 環境變數管理

#### 使用有意義的變數名稱

```bash
# 好的命名
DB_HOST=mysql.default.svc.cluster.local
REDIS_CACHE_URL=redis://redis:6379
STRIPE_PUBLISHABLE_KEY=pk_test_xxxxx

# 不好的命名
HOST=mysql
URL=redis://redis:6379
KEY=pk_test_xxxxx
```

#### 分組相關變數

```bash
# 資料庫設定
DB_HOST=mysql.default.svc.cluster.local
DB_PORT=3306
DB_NAME=myapp
DB_USER=root
DB_PASSWORD=secret123

# Redis 設定
REDIS_HOST=redis.default.svc.cluster.local
REDIS_PORT=6379
REDIS_DB=0

# 應用程式設定
APP_ENV=production
APP_DEBUG=false
APP_PORT=3000
```

#### 避免硬編碼敏感資訊

```bash
# 不好：敏感資訊寫死在 project.env
DB_PASSWORD=my_secret_password_123

# 好：使用 Kubernetes Secret
# 在 pre-deploy.sh 建立 Secret
kubectl create secret generic db-credentials \
  --from-literal=password=${DB_PASSWORD} \
  -n ${PROJECT_NAME}

# 在 Pod 中使用 Secret
# deployment.yaml:
# env:
#   - name: DB_PASSWORD
#     valueFrom:
#       secretKeyRef:
#         name: db-credentials
#         key: password
```

### 4. Docker Image 選擇

#### 使用特定版本而非 latest

```bash
# 好：使用特定版本
DEVELOP_IMAGE=node:20.10.0
DEPLOY_IMAGE=r82wei/deploy-env:1.0.0

# 不好：使用 latest
DEVELOP_IMAGE=node:latest
DEPLOY_IMAGE=r82wei/deploy-env:latest
```

#### 選擇適合的 Image 大小

```bash
# 開發環境：功能完整
DEVELOP_IMAGE=node:20

# 生產建置：使用 alpine 減小體積
BUILD_IMAGE=node:20-alpine

# 部署環境：只包含必要工具
DEPLOY_IMAGE=r82wei/deploy-env:1.0.0
```

### 5. 測試腳本

#### 在部署前測試腳本

```bash
# 只執行建置（測試 CI）
kde project build myapp

# 只執行部署（測試 CD）
kde project deploy-only myapp

# 完整 CI/CD
kde project deploy myapp
```

#### 使用 dry-run 模式

```bash
#!/bin/bash
# deploy.sh

# 使用 --dry-run 檢查資源
kubectl apply -f deployment.yaml --dry-run=client -o yaml

# 使用 helm --debug --dry-run 檢查部署
helm upgrade --install myapp ./chart \
  --namespace ${PROJECT_NAME} \
  --debug \
  --dry-run
```

## 常見問題

### Q1: 如何在腳本中使用專案內的檔案？

**A:** 腳本執行時的工作目錄是專案根目錄，Git repository 內容在子目錄中。

```bash
#!/bin/bash
set -e

# 取得 Git repo 名稱
REPO_NAME=$(basename -s .git ${GIT_REPO_URL})

# 進入 Git repo 目錄
cd ${REPO_NAME}

# 現在可以使用 repo 內的檔案
npm install
npm run build
```

### Q2: 如何在不同環境使用不同的設定？

**A:** 建立不同的 K8s 環境，每個環境有獨立的專案設定。

KDE 的設計理念是 **Project = K8s Namespace**，如果要在不同環境部署，應該建立多個 K8s 環境：

```bash
# 1. 建立開發環境
kde start dev k3d

# 2. 在開發環境建立專案
kde use dev
kde project create myapp
# 設定開發環境的 project.env

# 3. 建立生產環境
kde start prod k8s

# 4. 在生產環境建立相同的專案
kde use prod
kde project create myapp
# 設定生產環境的 project.env

# 5. 分別部署到不同環境
kde use dev
kde project deploy myapp  # 部署到開發環境

kde use prod
kde project deploy myapp  # 部署到生產環境
```

目錄結構：

```
environments/
├── dev/
│   └── namespaces/
│       └── myapp/
│           └── project.env    # DB_HOST=mysql.dev.svc.cluster.local
└── prod/
    └── namespaces/
        └── myapp/
            └── project.env    # DB_HOST=mysql.prod.example.com
```

### Q3: 如何在容器內建置 Docker Image？

**A:** 掛載 Docker socket 到容器內。

```bash
# project.env
KDE_MOUNT_DOCKER_SOCK=/var/run/docker.sock:/var/run/docker.sock
```

```bash
# build.sh
#!/bin/bash
set -e

REPO_NAME=$(basename -s .git ${GIT_REPO_URL})
cd ${REPO_NAME}

# 在容器內建置 Docker Image
docker build -t myapp:${GIT_REPO_BRANCH} .

# 推送到 Registry
docker push myapp:${GIT_REPO_BRANCH}
```

### Q4: 如何處理建置失敗後的清理？

**A:** 使用 trap 捕捉錯誤並執行清理。

```bash
#!/bin/bash
set -e

# 清理函數
cleanup() {
    echo "Cleaning up..."
    # 清理暫存檔案
    rm -rf /tmp/build-*
}

# 註冊清理函數
trap cleanup EXIT

# 建置邏輯
npm install
npm run build
```

### Q5: 如何在腳本中使用 kubectl？

**A:** DEPLOY_IMAGE 已包含 kubectl，並自動設定 KUBECONFIG。

```bash
#!/bin/bash
# deploy.sh
set -e

# 直接使用 kubectl
kubectl get nodes

# 建立資源
kubectl apply -f k8s/ -n ${PROJECT_NAME}

# 檢查部署狀態
kubectl rollout status deployment/myapp -n ${PROJECT_NAME}
```

### Q6: 如何實現多專案相依部署？

**A:** 可以在腳本中檢查相依服務是否就緒。

```bash
#!/bin/bash
# pre-deploy.sh
set -e

echo "Checking dependencies..."

# 檢查資料庫是否就緒
if ! kubectl get deployment mysql -n database &> /dev/null; then
    echo "Error: Database service not found"
    echo "Please deploy database first: kde project deploy database"
    exit 1
fi

# 等待資料庫就緒
kubectl wait --for=condition=available deployment/mysql \
    -n database \
    --timeout=300s

echo "All dependencies are ready"
```

### Q7: 如何在開發容器中使用專案的環境變數？

**A:** 進入開發容器時會自動載入 project.env 的環境變數。

```bash
# 進入開發容器
kde project exec myapp dev 3000

# 在容器內可以直接使用環境變數
$ echo $DB_HOST
mysql.default.svc.cluster.local

$ echo $APP_PORT
3000
```

### Q8: 如何為腳本加入條件執行？

**A:** 使用環境變數控制執行流程。

```bash
# project.env
SKIP_TESTS=false
SKIP_BUILD=false
```

```bash
#!/bin/bash
# build.sh
set -e

if [ "${SKIP_BUILD}" = "true" ]; then
    echo "Skipping build..."
    exit 0
fi

echo "Building application..."
npm run build

if [ "${SKIP_TESTS}" = "true" ]; then
    echo "Skipping tests..."
else
    echo "Running tests..."
    npm test
fi
```

### Q9: 如何處理大型檔案或資料？

**A:** 使用 PVC 儲存大型檔案，並在腳本中掛載使用。

```bash
# pre-deploy.sh
#!/bin/bash
set -e

# 建立 PVC
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: data-pvc
  namespace: ${PROJECT_NAME}
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 10Gi
  storageClassName: local-path
EOF

# 在 deployment 中掛載 PVC
# volumes:
#   - name: data
#     persistentVolumeClaim:
#       claimName: data-pvc
# volumeMounts:
#   - name: data
#     mountPath: /data
```

### Q10: 如何實現滾動更新？

**A:** 使用 Helm 或 kubectl 的滾動更新功能。

```bash
#!/bin/bash
# deploy.sh
set -e

REPO_NAME=$(basename -s .git ${GIT_REPO_URL})
cd ${REPO_NAME}

# 使用 Helm 滾動更新
helm upgrade --install myapp ./helm-chart \
  --namespace ${PROJECT_NAME} \
  --set image.tag=${GIT_REPO_BRANCH} \
  --set replicaCount=${REPLICA_COUNT:-3} \
  --wait \
  --timeout 10m

# 或使用 kubectl
# kubectl set image deployment/myapp \
#   app=myapp:${GIT_REPO_BRANCH} \
#   -n ${PROJECT_NAME}
# kubectl rollout status deployment/myapp -n ${PROJECT_NAME}
```

## 相關文件

- [Workspace 資料夾結構及檔案說明](./folder.structure.md)
- [KDE 開發架構說明](./development-architecture.md)
- [KDE Workspace 工作流程圖](./workflow.md)
- [使用 Telepresence](./telepresence.usage.md)
- [使用 Ngrok](./ngrok.usage.md)
- [使用 Cloudflare Tunnel](./cloudflare-tunnel.usage.md)
