# Container 開發環境(程式開發環境/部署工具環境)
**透過 Docker 容器提供隔離的開發環境/部署工具環境，並支援與 K8s 環境整合**

## 功能說明
- 快速啟動容器開發環境
    - 透過專案建立時設定的 `DEVELOP_IMAGE`，快速啟動一致性的開發環境
    - 透過專案建立時設定的 `DEPLOY_IMAGE`，快速啟動包含 kubectl/helm 等工具的部署環境
- 容器環境特性
    - 自動掛載專案資料夾到容器內的相同路徑，確保檔案路徑一致性
    - 自動進入專案的 Git 倉庫目錄（DEVELOP_IMAGE 模式）
    - 支援 Port 對應到本地，方便開發除錯
    - 與 K8s 環境整合，容器內可直接使用 kubectl 操作集群
- 環境變數
    - 預設環境變數：
        - `KUBECONFIG` - K8s 配置檔案路徑（掛載到容器內 `/.kube/config`）
        - `PROJECT_PATH` - 專案路徑（專案在 KDE 環境中的完整路徑）
    - 預設依序載入環境變數設定檔：
        - `${KDE_PATH}/kde.env` - KDE 系統主配置檔，包含 KDE 相關的全域設定（提交到版本控制）
        - `${ENVIROMENTS_PATH}/${CUR_ENV}/k8s.env` - 環境基本配置，包含環境基本資訊（提交到版本控制）
        - `${ENVIROMENTS_PATH}/${CUR_ENV}/.env` - 環境本地配置，環境特定的本地設定（不提交到版本控制）
        - `${PROJECT_PATH}/project.env` - 專案配置檔，專案的所有配置（提交到版本控制）
        - `${PROJECT_PATH}/.env` - 專案本地配置，專案特定的本地設定（不提交到版本控制）
- 檔案掛載
    - 自動掛載：
        - 專案資料夾（`${PROJECT_PATH}`）- 讀寫模式
        - K8s 配置檔案（`${KUBECONFIG}`）- 讀寫模式，容器內路徑為 `/.kube/config`
        - Docker Socket（`/var/run/docker.sock`）- 只讀模式，支援在容器內使用 Docker（DooD）
        - 系統使用者/群組檔案（`/etc/passwd`, `/etc/group`）- 只讀模式
        - 容器自動加入 docker 群組，可直接使用 Docker 指令
    - 自訂掛載：
        - 可以透過 project.env 定義 `KDE_MOUNT_[自定義名稱]=/host/path:/container/path[:ro]` 掛載特定檔案或資料夾
        - 支援 `:ro` 後綴指定只讀模式（建議用於敏感檔案如 SSH 金鑰）
- 網路整合
    - **Kind/K3D 環境**: 
        - 容器自動連接到與 K8s 環境相同的 Docker 網路（`kde-${ENV_NAME}`）
        - 可以直接透過服務名稱存取 K8s 集群內的服務（如 `http://service-name:port`）
    - **外部 K8s 環境**:
        - 容器使用預設的 `bridge` 網路
        - 透過掛載的 KUBECONFIG 和 kubectl 連接到外部 K8s API
        - 無法直接透過 Docker 網路存取 K8s 內部服務
        - 需要透過 `kubectl port-forward` 或 Ingress/LoadBalancer 存取服務

### 功能總整理
| 環境變數 | 說明 | 範例 |
|---------|------|------|
| `DEVELOP_IMAGE` | 開發環境使用的 Docker 映像檔 | `DEVELOP_IMAGE=node:20` |
| `DEPLOY_IMAGE` | 部署環境使用的 Docker 映像檔（包含 kubectl/helm 等工具） | `DEPLOY_IMAGE=r82wei/deploy-env:1.0.0` |
| `KDE_MOUNT_[自定義名稱]` | 掛載所有模式共用的檔案或資料夾 | `KDE_MOUNT_SSH=${HOME}/.ssh:${HOME}/.ssh:ro` |

## 使用說明
- 透過指令進入開發容器環境
    ```bash
    kde proj exec <project-name> [develop|deploy] [port]
    ```
    - `project-name`: 專案名稱（必填，若未提供則會顯示選單）
    - `[develop|deploy]`: 容器模式（可選，預設為 develop）
        - `develop` 或 `dev`: 進入 `DEVELOP_IMAGE` 啟動的開發容器
        - `deploy` 或 `dep`: 進入 `DEPLOY_IMAGE` 啟動的部署容器
    - `[port]`: Port 對應（可選，將容器內的 Port 對應到本地相同 Port）

## 使用範例

### 範例 1：Node.js 專案開發

建立專案時設定開發環境：
```bash
# 建立專案
kde proj create my-nodejs-app

# 設定 DEVELOP_IMAGE
DEVELOP_IMAGE=node:20

# project.env 中會包含
DEVELOP_IMAGE=node:20
DEPLOY_IMAGE=r82wei/deploy-env:1.0.0
```

進入開發環境：
```bash
# 進入開發容器（會自動進入 Git 倉庫目錄）
kde proj exec my-nodejs-app

# 或明確指定 develop 模式
kde proj exec my-nodejs-app develop

# 在容器內進行開發
npm install
npm run dev
```

### 範例 2：帶 Port 對應的 Web 開發

開發 Web 應用並對應端口到本地：
```bash
# 進入開發容器，並將容器內的 3000 端口對應到本地 3000
kde proj exec my-web-app develop 3000

# 在容器內啟動開發伺服器
npm run dev -- --port 3000

# 在本機瀏覽器存取 http://localhost:3000
```

### 範例 3：Python 專案開發

```bash
# 建立 Python 專案時設定
DEVELOP_IMAGE=python:3.11
DEPLOY_IMAGE=r82wei/deploy-env:1.0.0

# 進入開發容器
kde proj exec my-python-app develop

# 在容器內開發
pip install -r requirements.txt
python app.py
```

### 範例 4：進入部署環境測試部署腳本

方法一：直接進入部署容器
```bash
# 進入部署容器（包含 kubectl、helm 等工具）
kde proj exec my-app deploy

# 在容器內測試部署腳本
kubectl get pods -A
helm list -A
./deploy.sh
```

方法二：使用 Pipeline 的 --manual 參數（推薦）
```bash
# 進入 deploy 階段的執行環境
kde proj pipeline my-app --only deploy --manual

# 同樣在容器內，但會自動載入 Pipeline 相關配置
# 包括 deploy 階段特定的環境變數、掛載點等
kubectl get pods -A
helm list -A
# 可以直接測試部署腳本
./deploy.sh
```

**差異說明**：
- `kde proj exec ... deploy`: 進入基本的 DEPLOY_IMAGE 容器環境
- `kde proj pipeline ... --manual`: 進入 Pipeline deploy 階段的完整執行環境
  - 會載入 deploy 階段的專屬配置（`KDE_PIPELINE_STAGE_deploy_*`）
  - 包含階段特定的掛載（`KDE_PIPELINE_STAGE_deploy_MOUNT_*`）
  - 適合測試實際 Pipeline 執行時的環境

### 範例 5：使用 Pipeline --manual 進入開發環境

使用 Pipeline 的 `--manual` 參數可以進入特定階段的執行環境，適合測試 Pipeline 腳本：

```bash
# 進入 build 階段的執行環境（使用 DEVELOP_IMAGE）
kde proj pipeline my-app --only build --manual

# 在容器內可以測試 build.sh 的內容
npm install
npm run build
npm test

# 也可以直接執行 build.sh 測試完整流程
./build.sh
```

**與 `kde proj exec` 的比較**：
```bash
# 方法 A：使用 proj exec（基本容器環境）
kde proj exec my-app develop

# 方法 B：使用 pipeline --manual（Pipeline 執行環境）
kde proj pipeline my-app --only build --manual
```

**選擇建議**：
- 一般開發：使用 `kde proj exec my-app develop`
- 測試 Pipeline 腳本：使用 `kde proj pipeline my-app --only build --manual`
- 除錯 Pipeline 問題：使用 `--manual` 參數可以重現 Pipeline 執行時的環境

### 範例 6：掛載 SSH 金鑰進行 Git 操作

在 `project.env` 中設定 SSH 金鑰掛載：
```bash
# project.env
DEVELOP_IMAGE=node:20
DEPLOY_IMAGE=r82wei/deploy-env:1.0.0

# 掛載 SSH 金鑰（只讀模式）
KDE_MOUNT_SSH=${HOME}/.ssh:${HOME}/.ssh:ro
```

使用：
```bash
# 進入開發容器
kde proj exec my-app develop

# 在容器內可以使用 SSH 金鑰進行 Git 操作
git pull
git push
```

### 範例 7：掛載本地工具或函式庫

掛載本地共用的工具或函式庫到多個專案：
```bash
# project.env
DEVELOP_IMAGE=node:20

# 掛載本地共用的函式庫
KDE_MOUNT_SHARED_LIBS=${HOME}/shared-libs:/workspace/shared-libs:ro
```

使用：
```bash
# 進入開發容器
kde proj exec my-app develop

# 在容器內可以存取共用函式庫
ls /workspace/shared-libs
```

### 範例 8：在容器內使用 Docker（DooD）

KDE 的開發容器自動掛載了 Docker Socket，讓你可以在容器內直接使用宿主機的 Docker：

```bash
# 進入開發容器（需要使用包含 Docker CLI 的映像檔）
kde proj exec my-app develop

# 在容器內可以直接使用 Docker 指令
docker version
docker ps
docker images

# 建置 Docker 映像檔
docker build -t my-app:latest .

# 執行容器
docker run -d -p 8080:8080 my-app:latest

# 查看容器日誌
docker logs <container-id>

# 推送映像檔到 Registry
docker tag my-app:latest registry.example.com/my-app:latest
docker push registry.example.com/my-app:latest
```

**技術說明**：
- KDE 使用 **DooD（Docker-out-of-Docker）** 而非 DinD（Docker-in-Docker）
- 容器透過掛載宿主機的 Docker Socket（`/var/run/docker.sock`）來使用 Docker
- 容器自動加入 docker 群組，無需額外配置權限
- 在容器內建置的映像檔會直接儲存在宿主機的 Docker 中

**應用場景**：
- 在開發容器內建置應用程式的 Docker 映像檔
- 測試 multi-stage Dockerfile
- 執行需要 Docker 的整合測試
- 在 Pipeline 的 build 階段建置容器映像

**注意事項**：
- Docker Socket 以只讀模式掛載（`:ro`），這是為了安全性考量
- 映像檔建置、容器執行等操作仍然可以正常運作
- 建議使用 `DEVELOP_IMAGE` 時選擇包含 Docker CLI 的映像檔（如：`docker:latest`）

**實際應用：在 Pipeline build 階段建置 Docker 映像**

專案配置（`project.env`）：
```bash
# 使用包含 Docker CLI 的映像檔
DEVELOP_IMAGE=docker:latest
DEPLOY_IMAGE=r82wei/deploy-env:1.0.0

# Pipeline 配置
KDE_PIPELINE_STAGES="build,deploy"
KDE_PIPELINE_STAGE_build_IMAGE=docker:latest
KDE_PIPELINE_STAGE_build_SCRIPT=build.sh

# Docker Registry 配置
DOCKER_REGISTRY=registry.example.com
VERSION=1.0.0
```

建置腳本（`build.sh`）：
```bash
#!/bin/bash
set -e

echo "開始建置應用程式..."

# 安裝依賴（如果需要）
# apk add --no-cache npm
# npm install
# npm run build

# 建置 Docker 映像檔
echo "建置 Docker 映像檔：my-app:${VERSION}"
docker build -t my-app:${VERSION} .

# 標記映像檔
echo "標記映像檔：${DOCKER_REGISTRY}/my-app:${VERSION}"
docker tag my-app:${VERSION} ${DOCKER_REGISTRY}/my-app:${VERSION}

# 推送到 Registry
echo "推送映像檔到 Registry..."
docker push ${DOCKER_REGISTRY}/my-app:${VERSION}

# 將映像檔名稱寫入環境變數供 deploy 階段使用
echo "APP_IMAGE=${DOCKER_REGISTRY}/my-app:${VERSION}" >> .pipeline.env
echo "✅ 建置完成！"
```

執行：
```bash
# 執行 Pipeline（自動執行 build.sh）
kde proj pipeline my-app

# 或使用 --manual 進入容器手動測試
kde proj pipeline my-app --only build --manual
```

## Best Practice
- **環境類型選擇**
    - **本地開發**: 建議使用 Kind 或 K3D 環境
        - 優點：開發容器可以直接透過服務名稱存取 K8s 內部服務
        - 優點：啟動快速、資源佔用少
        - 適用：日常開發、單元測試、整合測試
    - **外部 K8s**: 適用於連接現有的雲端或遠端集群
        - 特點：透過 kubectl API 連接，無法直接透過 Docker 網路存取服務
        - 適用：生產環境驗證、多人協作開發
        - 注意：需要透過 `kubectl port-forward` 或 Ingress 存取服務
- **映像檔選擇**
    - `DEVELOP_IMAGE`: 選擇與專案技術棧匹配的官方映像檔（如：`node:20`, `python:3.11`, `golang:1.21`）
    - `DEPLOY_IMAGE`: 使用包含 kubectl/helm 等 K8s 工具的映像檔（預設為 `r82wei/deploy-env:1.0.0`）
    - 需要在容器內使用 Docker 時，選擇包含 Docker CLI 的映像檔（如：`docker:latest`, `docker:24-cli`）
    - 或使用包含多種工具的映像檔（如：`docker:latest` + 安裝 Node.js）
- **環境變數管理**
    - 將通用配置放在 `project.env` 中（提交到版本控制）
    - 將敏感資訊（如 API Token、密碼）放在 `.env` 中（不提交到版本控制）
    ```bash
    # project.env
    APP_NAME=my-app
    APP_PORT=8080
    
    # .env（不提交到版本控制）
    DATABASE_PASSWORD=secret
    API_TOKEN=xxxxx
    ```
- **Port 對應**
    - 開發 Web 應用時，使用 Port 對應方便在本地瀏覽器測試
    - 建議在 `project.env` 中定義專案使用的 Port，方便團隊成員統一
    ```bash
    # project.env
    APP_PORT=3000
    ```
- **檔案掛載**
    - 掛載 SSH 金鑰時使用只讀模式（`:ro`）提升安全性
    - 掛載共用函式庫或工具時，使用統一的路徑規範
    - 避免掛載過多不必要的檔案，影響容器啟動速度
- **開發工作流程**
    1. 建立專案時選擇適合的 `DEVELOP_IMAGE`
    2. 使用 `kde proj exec <project-name> develop` 進入開發環境
    3. 在容器內進行開發、測試
    4. 使用 `kde proj pipeline <project-name>` 執行 CI/CD Pipeline
    5. 使用 `kde proj exec <project-name> deploy` 測試部署腳本
- **多專案開發**
    - 不同專案可以使用不同的 `DEVELOP_IMAGE`，互不干擾
    - 透過 Docker 網路，多個專案容器之間可以直接通訊
    - 使用專案名稱作為服務名稱進行內部通訊（如：`http://backend-app:8080`）
- **在容器內使用 Docker**
    - KDE 自動掛載 Docker Socket，無需額外配置即可使用 Docker
    - 使用 DooD（Docker-out-of-Docker）架構，容器內建置的映像檔會儲存在宿主機
    - 選擇包含 Docker CLI 的映像檔（如：`docker:latest`）
    - 適用場景：建置 Docker 映像、執行 Docker Compose 測試、容器化應用開發
    - 注意事項：
        - Docker Socket 以只讀模式掛載，這不影響映像建置和容器執行
        - 在容器內建置的映像可透過 `kde load-image` 載入到 Kind/K3D 環境
        - 建議在 Pipeline 的 build 階段使用 Docker 建置映像
- **與 K8s 整合**
    - 開發容器自動掛載 `KUBECONFIG`，可直接使用 kubectl 操作集群
    - **Kind/K3D 環境**: 開發容器與 K8s 環境在同一個 Docker 網路，可以直接透過服務名稱存取 K8s 服務
    - **外部 K8s 環境**: 需要透過 `kubectl port-forward` 或 Ingress/LoadBalancer 存取服務
    - 使用 `deploy` 模式測試部署腳本，確保部署邏輯正確
    - 建議在本地開發時使用 Kind/K3D 環境以獲得更好的開發體驗
- **容器資源管理**
    - 開發容器執行完畢後會自動清理（`docker run --rm`）
    - 避免在容器內安裝過多不必要的套件，保持映像檔輕量
    - 定期更新 `DEVELOP_IMAGE` 到最新的穩定版本

## 除錯容器環境

### 啟用除錯模式

當容器啟動或執行出現問題時：

```bash
# 追蹤容器啟動過程
KDE_DEBUG=true kde proj exec myapp develop
KDE_DEBUG=true kde proj exec myapp deploy

# 追蹤 Pipeline 執行過程
KDE_DEBUG=true kde proj pipeline myapp
```

### 常見問題

**容器無法啟動**：
- 檢查映像是否存在：`docker images | grep <image>`
- 檢查 Docker 服務：`docker ps`
- 檢查專案路徑是否正確
- 使用 `KDE_DEBUG=true` 查看啟動命令

**容器內無法存取 K8s**：
- **Kind/K3D**：確認容器與 K8s 在同一個 Docker 網路
- **外部 K8s**：確認 `KUBECONFIG` 路徑正確
- 在容器內執行 `kubectl get nodes` 測試連線

**檔案掛載問題**：
- 檢查掛載路徑是否正確（使用絕對路徑）
- 檢查檔案權限
- 確認 Docker Socket 已正確掛載（用於 DooD）

更多除錯資訊請參考：
- [概述文檔中的除錯章節](../overview.md#除錯與故障排除)
- [專案管理文檔中的故障排除](../project.md#故障排除)
