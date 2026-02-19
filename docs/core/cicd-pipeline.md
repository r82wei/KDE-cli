# Script 驅動的 CI/CD 交付流程
**透過 shell script 與 docker image，定義專案到環境的交付流程**

## 功能說明
-  快速 CICD pipeline（預設）
    - 流程： build → deploy
    - 可以透過 project.env 定義 `KDE_PIPELINE_STAGE_[階段名稱]_IMAGE=node:24` CICD pipeline 特定階段容器映像檔
    - 可以透過 project.env 定義 `KDE_PIPELINE_STAGE_[階段名稱]_SCRIPT=build.sh` CICD pipeline 特定階段腳本
- 自定義 CICD pipeline
    - 可以透過 project.env 定義 `KDE_PIPELINE_STAGES=build,test,release,deploy` CICD pipeline 流程
    - 可以透過 project.env 定義 `KDE_PIPELINE_STAGE_[階段名稱]_IMAGE=node:24` CICD pipeline 特定階段容器映像檔
    - 可以透過 project.env 定義 `KDE_PIPELINE_STAGE_[階段名稱]_SCRIPT=build.sh` CICD pipeline 特定階段腳本
- 開發模式
    - 透過執行 pipeline 的時候加入 `--manual` 參數，進入 stage 執行環境
- 環境變數
    - 預設環境變數：
        - `KDE_PATH` - workspace 目錄路徑
        - `ENVIROMENTS_PATH` - 環境目錄路徑
        - `CUR_ENV` - 當前環境名稱
        - `KUBECONFIG` - K8s 配置檔案路徑
        - `PROJECT_PATH` - 專案路徑
    - 預設依序載入環境變數設定檔：
        - `${KDE_PATH}/kde.env` - KDE 系統主配置檔包含 KDE 相關的全域設定，如各種 Image 版本 (提交到版本控制)
        - `${ENVIROMENTS_PATH}/${CUR_ENV}/k8s.env` - 環境基本配置，包含環境基本資訊: ENV_NAME、ENV_TYPE、K8S_CONTAINER_NAME 等 (提交到版本控制)
        - `${ENVIROMENTS_PATH}/${CUR_ENV}/.env` - 環境本地配置，環境特定的本地設定（不提交到版本控制）
        - `${PROJECT_PATH}/project.env` - 專案配置檔，專案的所有配置，包括 Pipeline 設定 (提交到版本控制)
        - `${PROJECT_PATH}/.env` - 專案本地配置，專案特定的本地設定（不提交到版本控制）
        - `${PROJECT_PATH}/.pipeline.env` - Pipeline 階段間傳遞的環境變數上一階段輸出的環境變數（如果存在）
- 檔案掛載
    - CICD pipeline 各階段執行環境會自動掛載 `專案資料夾` 作為 workdir
    - 各階段的 Artifact 可以直接輸出在 `專案資料夾` 底下
    - 可以透過 project.env 定義 `KDE_PIPELINE_STAGE_[階段名稱]_MOUNT_[自定義名稱]=${PROJECT_PATH}/libs:${PROJECT_PATH}/libs` 掛載 CICD pipeline 特定階段的特定檔案或資料夾
    - 可以透過 project.env 定義 `KDE_MOUNT_[自定義名稱]=${}/.ssh:${PROJECT_PATH}/.ssh` CICD pipeline 全部階段掛載特定檔案或資料夾
- 錯誤處理選項：
    - 預設啟用 Fail Fast 模式（任何階段失敗立即停止），可以透過 project.env 定義 `KDE_PIPELINE_FAIL_FAST=false` 停用
- 階段控制選項：
    - 可以透過 project.env 定義 `KDE_PIPELINE_STAGE_[階段名稱]_SKIP=true` 跳過特定階段（預設：false）
    - 可以透過 project.env 定義 `KDE_PIPELINE_STAGE_[階段名稱]_MANUAL_ONLY=true` 設定特定階段只能透過 `--manual` 參數手動觸發（預設：false）
    - 可以透過 project.env 定義 `KDE_PIPELINE_STAGE_[階段名稱]_ALLOW_FAILURE=true` 設定特定階段允許失敗但不影響後續階段執行（預設：false）
    - 可以透過 project.env 定義 `KDE_PIPELINE_STAGE_[階段名稱]_PAUSE=true` 設定特定階段執行完畢後暫停，等待使用者確認是否繼續後續階段（預設：false）

### 功能總整理
| 環境變數 | 說明 | 預設值 | 範例 |
|---------|------|--------|------|
| `KDE_PIPELINE_STAGES` | 自定義 CICD pipeline 流程階段 | `build,deploy`（建立專案時自動產生） | `KDE_PIPELINE_STAGES=build,test,release,deploy` |
| `KDE_PIPELINE_STAGE_[階段名稱]_IMAGE` | 指定特定階段使用的容器映像檔 | `DEPLOY_IMAGE`（未指定時使用） | `KDE_PIPELINE_STAGE_build_IMAGE=node:24` |
| `KDE_PIPELINE_STAGE_[階段名稱]_SCRIPT` | 指定特定階段執行的腳本檔案 | `[階段名稱].sh`（檔案存在時使用） | `KDE_PIPELINE_STAGE_build_SCRIPT=build.sh` |
| `KDE_PIPELINE_STAGE_[階段名稱]_MOUNT_[自定義名稱]` | 掛載特定階段的檔案或資料夾 | 無 | `KDE_PIPELINE_STAGE_build_MOUNT_LIBS=${PROJECT_PATH}/libs:${PROJECT_PATH}/libs` |
| `KDE_PIPELINE_STAGE_[階段名稱]_SKIP` | 跳過特定階段 | `false` | `KDE_PIPELINE_STAGE_lint_SKIP=true` |
| `KDE_PIPELINE_STAGE_[階段名稱]_MANUAL_ONLY` | 只能透過 --manual 參數手動觸發 | `false` | `KDE_PIPELINE_STAGE_lint_MANUAL_ONLY=true` |
| `KDE_PIPELINE_STAGE_[階段名稱]_ALLOW_FAILURE` | 允許該階段失敗但不影響後續階段 | `false` | `KDE_PIPELINE_STAGE_lint_ALLOW_FAILURE=true` |
| `KDE_PIPELINE_STAGE_[階段名稱]_PAUSE` | 階段執行完畢後暫停，等待使用者確認是否繼續 | `false` | `KDE_PIPELINE_STAGE_preview_PAUSE=true` |
| `KDE_PIPELINE_FAIL_FAST` | 任何階段失敗時立即停止整個 pipeline | `true` | `KDE_PIPELINE_FAIL_FAST=false` |
| `KDE_MOUNT_[自定義名稱]` | 掛載所有階段共用的檔案或資料夾 | 無 | `KDE_MOUNT_SSH=${}/.ssh:${PROJECT_PATH}/.ssh` |



## Pipeline 指令使用說明

### 基本語法

```bash
kde proj pipeline <project_name> [options]
# 或使用別名
kde proj deploy <project_name> [options]
```

### 執行選項

#### 執行完整 Pipeline
```bash
# 執行所有階段
kde proj pipeline myapp
```

#### 從特定階段開始執行（--from）
```bash
# 從 test 階段開始執行（跳過前面的階段）
kde proj pipeline myapp --from test

# 等號語法
kde proj pipeline myapp --from=test
```

#### 執行到特定階段（--to）
```bash
# 只執行到 build 階段（不執行後續階段）
kde proj pipeline myapp --to build

# 等號語法
kde proj pipeline myapp --to=build
```

#### 組合使用 --from 和 --to
```bash
# 只執行 test 到 build 之間的階段
kde proj pipeline myapp --from test --to build
kde proj pipeline myapp --from=test --to=build
```

#### 只執行單一階段（--only）
```bash
# 只執行 build 階段
kde proj pipeline myapp --only build

# 等號語法
kde proj pipeline myapp --only=build
```

**注意**：`--only` 不可與 `--from`、`--to` 一起使用

#### 手動模式（--manual）
```bash
# 進入每個階段的執行環境（用於除錯和測試）
kde proj pipeline myapp --manual

# 只進入 build 階段的環境
kde proj pipeline myapp --only build --manual

# 從 test 到 deploy，逐個進入環境
kde proj pipeline myapp --from test --to deploy --manual
```

在手動模式下，退出單一階段環境後會自動進入下一階段環境。

### 使用場景說明

**完整執行（適合 CI/CD）**：
```bash
kde proj pipeline myapp
```

**快速測試特定階段**：
```bash
# 只測試建置階段
kde proj pipeline myapp --only build

# 只測試部署階段
kde proj pipeline myapp --only deploy
```

**跳過前期階段**：
```bash
# 已經完成 test 和 lint，只想重新執行 build 和 deploy
kde proj pipeline myapp --from build
```

**除錯特定階段**：
```bash
# 進入 build 階段環境手動測試
kde proj pipeline myapp --only build --manual
```

**部分流程測試**：
```bash
# 只測試從 test 到 build 的流程
kde proj pipeline myapp --from test --to build
```

## 配置範例

### 範例 1：快速開發模式

只執行 build 和 deploy：

```bash
# project.env
KDE_PIPELINE_STAGES="build,deploy"

KDE_PIPELINE_STAGE_build_SCRIPT=build.sh
KDE_PIPELINE_STAGE_build_IMAGE=node:24

KDE_PIPELINE_STAGE_deploy_SCRIPT=deploy-quick.sh
KDE_PIPELINE_STAGE_deploy_IMAGE=r82wei/deploy-env:1.0.0
```

### 範例 2：安全優先模式

加入安全掃描：

```bash
# project.env
KDE_PIPELINE_STAGES="test,lint,code-analytics,build,security-scan,release,deploy"

KDE_PIPELINE_STAGE_test_SCRIPT=test.sh
KDE_PIPELINE_STAGE_test_IMAGE=node:24

KDE_PIPELINE_STAGE_lint_SCRIPT=lint.sh
KDE_PIPELINE_STAGE_lint_IMAGE=node:24

KDE_PIPELINE_STAGE_code-analytics_SCRIPT=code-analytics.sh
KDE_PIPELINE_STAGE_code-analytics_IMAGE=sonarqube:latest

KDE_PIPELINE_STAGE_build_SCRIPT=build.sh
KDE_PIPELINE_STAGE_build_IMAGE=node:24

KDE_PIPELINE_STAGE_security-scan_SCRIPT=security-scan.sh
KDE_PIPELINE_STAGE_security-scan_IMAGE=aquasec/trivy:latest

KDE_PIPELINE_STAGE_release_SCRIPT=release.sh
KDE_PIPELINE_STAGE_release_IMAGE=r82wei/deploy-env:1.0.0

KDE_PIPELINE_STAGE_deploy_SCRIPT=deploy.sh
KDE_PIPELINE_STAGE_deploy_IMAGE=r82wei/deploy-env:1.0.0
```

### 範例 3：僅作為 CICD pipeline stage 觸發器，執行專案內原有的 CICD script

執行專案內原本的 build.sh 和 deploy.sh：

```bash
# project.env
KDE_PIPELINE_STAGES="build,deploy"

KDE_PIPELINE_STAGE_build_SCRIPT=${PROJECT_PATH}/my-app/build.sh
KDE_PIPELINE_STAGE_build_IMAGE=node:24

KDE_PIPELINE_STAGE_deploy_SCRIPT=${PROJECT_PATH}/my-app/deploy.sh
KDE_PIPELINE_STAGE_deploy_IMAGE=r82wei/deploy-env:1.0.0
```

### 範例 4：階段控制 - 手動觸發與跳過

設定部分階段只能手動觸發，跳過某些階段：

```bash
# project.env
KDE_PIPELINE_STAGES="build,lint,test,security-scan,deploy"

# 一般階段
KDE_PIPELINE_STAGE_build_SCRIPT=build.sh
KDE_PIPELINE_STAGE_build_IMAGE=node:24

# lint 階段只能手動觸發
KDE_PIPELINE_STAGE_lint_SCRIPT=lint.sh
KDE_PIPELINE_STAGE_lint_IMAGE=node:24
KDE_PIPELINE_STAGE_lint_MANUAL_ONLY=true

KDE_PIPELINE_STAGE_test_SCRIPT=test.sh
KDE_PIPELINE_STAGE_test_IMAGE=node:24

# security-scan 階段預設跳過
KDE_PIPELINE_STAGE_security-scan_SCRIPT=security-scan.sh
KDE_PIPELINE_STAGE_security-scan_IMAGE=aquasec/trivy:latest
KDE_PIPELINE_STAGE_security-scan_SKIP=true

KDE_PIPELINE_STAGE_deploy_SCRIPT=deploy.sh
KDE_PIPELINE_STAGE_deploy_IMAGE=r82wei/deploy-env:1.0.0
```

執行方式：
```bash
# 一般執行：會跳過 lint（MANUAL_ONLY）和 security-scan（SKIP）
kde proj pipeline myapp

# 手動模式：會執行 lint，但仍跳過 security-scan（SKIP）
kde proj pipeline myapp --manual

# 只執行 lint 階段（手動模式）
kde proj pipeline myapp --only lint --manual
```

### 範例 5：暫停確認 - Pause

在部署前執行 diff 預覽，讓使用者確認變更後再決定是否繼續部署：

```bash
# project.env
KDE_PIPELINE_STAGES="build,preview,deploy"

KDE_PIPELINE_STAGE_build_SCRIPT=build.sh
KDE_PIPELINE_STAGE_build_IMAGE=node:24

# preview 階段執行完畢後暫停，等待使用者確認
KDE_PIPELINE_STAGE_preview_SCRIPT=preview.sh
KDE_PIPELINE_STAGE_preview_IMAGE=r82wei/deploy-env:1.0.0
KDE_PIPELINE_STAGE_preview_PAUSE=true

KDE_PIPELINE_STAGE_deploy_SCRIPT=deploy.sh
KDE_PIPELINE_STAGE_deploy_IMAGE=r82wei/deploy-env:1.0.0
```

`preview.sh` 範例（執行 helm diff 或 kubectl diff）：

```bash
#!/bin/bash
helm diff upgrade myapp ./charts/myapp -f values.yaml
# 或
kubectl diff -f manifests/
```

執行結果：
```bash
kde proj pipeline myapp

# 執行情況：
# 1. build 階段正常執行
# 2. preview 階段執行完畢後顯示：
#    ⏸️  階段 preview 執行完成，Pipeline 已暫停
#       請確認上方輸出後決定是否繼續執行後續階段
#       繼續執行？(y/N):
# 3. 輸入 y → 繼續執行 deploy 階段
#    輸入 N 或 Enter → Pipeline 停止，不執行 deploy
```

### 範例 6：錯誤處理 - Allow Failure

允許某些階段失敗但不影響整體流程：

```bash
# project.env
KDE_PIPELINE_STAGES="lint,test,build,security-scan,deploy"

# lint 階段允許失敗（代碼風格問題不應阻止部署）
KDE_PIPELINE_STAGE_lint_SCRIPT=lint.sh
KDE_PIPELINE_STAGE_lint_IMAGE=node:24
KDE_PIPELINE_STAGE_lint_ALLOW_FAILURE=true

KDE_PIPELINE_STAGE_test_SCRIPT=test.sh
KDE_PIPELINE_STAGE_test_IMAGE=node:24

KDE_PIPELINE_STAGE_build_SCRIPT=build.sh
KDE_PIPELINE_STAGE_build_IMAGE=node:24

# security-scan 階段允許失敗（安全掃描發現問題時可繼續部署到測試環境）
KDE_PIPELINE_STAGE_security-scan_SCRIPT=security-scan.sh
KDE_PIPELINE_STAGE_security-scan_IMAGE=aquasec/trivy:latest
KDE_PIPELINE_STAGE_security-scan_ALLOW_FAILURE=true

KDE_PIPELINE_STAGE_deploy_SCRIPT=deploy.sh
KDE_PIPELINE_STAGE_deploy_IMAGE=r82wei/deploy-env:1.0.0
```

執行結果：
```bash
# 一般執行
kde proj pipeline myapp

# 執行情況：
# - lint 失敗 → 顯示警告，繼續執行 test
# - security-scan 失敗 → 顯示警告，繼續執行 deploy
# - build 失敗 → Pipeline 立即停止（預設 Fail Fast 行為）
```

## Best Practice
- 使用專案名稱作為 K8S 部署目標 namespace
- 依據環境變數是否適合納入版本控制，選擇在 project.env（可納入版控）或 .env（不納入版控）中定義 CICD pipeline 相關的環境變數，例如：
    ```bash
    # project.env
    
    NAMESPACE=my-app
    REPO_DIR=my-app
    PORT=8088
    BUILD_SCRIPT_PATH=${PROJECT_PATH}/build.sh
    ```
    ```bash
    # .env
    
    JWT_SECRET_KEY=xxxxxxx
    API_TOKEN=xxxxx
    ```
- 各階段環境變數傳遞方式
    - 環境變數可以透過下列範例使用的方式傳遞 (`release` -> `deploy`) :
        - `release` 階段 
            ```
            # 將 APP_IMAGE 作為環境變數輸出到 .pipeline.env
            echo "APP_IMAGE=my-app:1.0.0" >> .pipeline.env
            ```
        - `deploy` 階段 
            ```
            # 載入 .pipeline.env 內的環境變數
            source .pipeline.env

            # 印出 APP_IMAGE
            echo $APP_IMAGE
            ```

## 進階主題

### 自訂 Pipeline 階段掛載

可以為特定 Pipeline 階段設定額外的檔案掛載：

```bash
# project.env

# 掛載共用函式庫到 build 階段
KDE_PIPELINE_STAGE_build_MOUNT_LIBS=${HOME}/shared-libs:/workspace/libs:ro

# 掛載測試資料到 test 階段
KDE_PIPELINE_STAGE_test_MOUNT_DATA=${PROJECT_PATH}/test-data:/test-data:ro

# 掛載 Docker config 到 release 階段
KDE_PIPELINE_STAGE_release_MOUNT_DOCKER_CONFIG=${HOME}/.docker:/root/.docker:ro
```

**使用場景**：
- 掛載共用的函式庫或工具
- 掛載測試資料檔案
- 掛載 Docker Registry 認證
- 掛載 SSH 金鑰進行 Git 操作

### Pipeline 階段間環境變數傳遞

在 Pipeline 中，可以透過 `.pipeline.env` 在階段間傳遞環境變數：

**build.sh**（建置並輸出變數）：
```bash
#!/bin/bash
set -e

echo "開始建置應用..."

# 建置應用
npm run build

# 建置 Docker 映像
VERSION=$(cat package.json | jq -r .version)
docker build -t myapp:${VERSION} .

# 推送到 Registry
docker tag myapp:${VERSION} registry.example.com/myapp:${VERSION}
docker push registry.example.com/myapp:${VERSION}

# 將映像名稱輸出到 .pipeline.env 供後續階段使用
echo "APP_IMAGE=registry.example.com/myapp:${VERSION}" >> .pipeline.env
echo "APP_VERSION=${VERSION}" >> .pipeline.env

echo "✅ 建置完成！映像: registry.example.com/myapp:${VERSION}"
```

**deploy.sh**（載入並使用變數）：
```bash
#!/bin/bash
set -e

# 載入上一階段的環境變數
source .pipeline.env

echo "開始部署應用..."
echo "部署映像: ${APP_IMAGE}"
echo "版本: ${APP_VERSION}"

# 使用 APP_IMAGE 進行部署
kubectl set image deployment/myapp myapp=${APP_IMAGE} -n myapp

# 或使用 Helm
helm upgrade --install myapp ./helm/myapp \
    --set image.repository=${APP_IMAGE%:*} \
    --set image.tag=${APP_VERSION} \
    --namespace myapp

echo "✅ 部署完成！"
```

**使用場景**：
- 在 build 階段產生映像名稱，在 deploy 階段使用
- 在 test 階段產生測試報告路徑，在後續階段上傳
- 在 release 階段產生版本號，在 deploy 階段使用
- 傳遞任何需要在階段間共享的資訊

### 複雜 Pipeline 範例

完整的 build → test → release → deploy 流程：

**project.env**：
```bash
# Pipeline 配置
KDE_PIPELINE_STAGES="build,test,release,deploy"

# Build 階段
KDE_PIPELINE_STAGE_build_SCRIPT=build.sh
KDE_PIPELINE_STAGE_build_IMAGE=node:20

# Test 階段
KDE_PIPELINE_STAGE_test_SCRIPT=test.sh
KDE_PIPELINE_STAGE_test_IMAGE=node:20

# Release 階段（建置 Docker 映像）
KDE_PIPELINE_STAGE_release_SCRIPT=release.sh
KDE_PIPELINE_STAGE_release_IMAGE=docker:latest
KDE_PIPELINE_STAGE_release_MOUNT_DOCKER_CONFIG=${HOME}/.docker:/root/.docker:ro

# Deploy 階段
KDE_PIPELINE_STAGE_deploy_SCRIPT=deploy.sh
KDE_PIPELINE_STAGE_deploy_IMAGE=r82wei/deploy-env:1.0.0

# Registry 配置
DOCKER_REGISTRY=registry.example.com
```

**build.sh**：
```bash
#!/bin/bash
set -e

echo "安裝依賴..."
npm install

echo "建置應用..."
npm run build

echo "✅ 建置完成"
```

**test.sh**：
```bash
#!/bin/bash
set -e

echo "執行測試..."
npm test

echo "執行 Lint..."
npm run lint

echo "✅ 測試通過"
```

**release.sh**：
```bash
#!/bin/bash
set -e

# 取得版本號
VERSION=$(cat package.json | jq -r .version)
IMAGE_NAME="${DOCKER_REGISTRY}/myapp:${VERSION}"

echo "建置 Docker 映像: ${IMAGE_NAME}"
docker build -t ${IMAGE_NAME} .

echo "推送映像到 Registry..."
docker push ${IMAGE_NAME}

# 輸出映像資訊供 deploy 階段使用
echo "APP_IMAGE=${IMAGE_NAME}" >> .pipeline.env
echo "APP_VERSION=${VERSION}" >> .pipeline.env

echo "✅ Release 完成: ${IMAGE_NAME}"
```

**deploy.sh**：
```bash
#!/bin/bash
set -e

# 載入環境變數
source .pipeline.env

NAMESPACE=myapp

echo "部署應用到 Kubernetes..."
echo "映像: ${APP_IMAGE}"
echo "版本: ${APP_VERSION}"

# 建立或更新 Namespace
kubectl create namespace ${NAMESPACE} --dry-run=client -o yaml | kubectl apply -f -

# 部署應用
kubectl set image deployment/myapp myapp=${APP_IMAGE} -n ${NAMESPACE} || \
    kubectl create deployment myapp --image=${APP_IMAGE} -n ${NAMESPACE}

# 等待部署完成
kubectl rollout status deployment/myapp -n ${NAMESPACE}

echo "✅ 部署完成！"
```

**執行**：
```bash
# 執行完整流程
kde proj pipeline myapp

# 或分別測試各階段
kde proj pipeline myapp --only build --manual
kde proj pipeline myapp --only test --manual
kde proj pipeline myapp --only release --manual
kde proj pipeline myapp --only deploy --manual
```

## 除錯 Pipeline

### 啟用除錯模式

當 Pipeline 執行失敗或需要追蹤執行流程時：

```bash
# 顯示 KDE CLI 層級的執行命令
KDE_DEBUG=true kde proj pipeline myapp

# 使用 --manual 進入每個階段手動測試
kde proj pipeline myapp --only build --manual

# 在腳本內加上 set -x 追蹤腳本執行
# 在 build.sh 或 deploy.sh 開頭加入：
set -x  # 啟用腳本除錯模式
```

### 常見問題

**Pipeline 執行失敗**：
- 檢查腳本檔案是否存在且有執行權限（`chmod +x *.sh`）
- 使用 `--manual` 進入環境手動測試
- 檢查映像是否存在：`docker pull <image>`
- 查看退出碼和錯誤訊息

**環境變數問題**：
- 確認 `project.env` 中的變數是否正確定義
- 使用 `--manual` 進入環境後執行 `env` 查看所有環境變數
- 檢查 `.pipeline.env` 是否正確生成（階段間傳遞）

**階段跳過問題**：
- 檢查是否設定了 `KDE_PIPELINE_STAGE_<stage>_SKIP=true`
- 檢查是否設定了 `MANUAL_ONLY` 但未使用 `--manual` 參數