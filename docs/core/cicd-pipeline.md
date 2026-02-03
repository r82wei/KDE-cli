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
| `KDE_PIPELINE_FAIL_FAST` | 任何階段失敗時立即停止整個 pipeline | `true` | `KDE_PIPELINE_FAIL_FAST=false` |
| `KDE_MOUNT_[自定義名稱]` | 掛載所有階段共用的檔案或資料夾 | 無 | `KDE_MOUNT_SSH=${}/.ssh:${PROJECT_PATH}/.ssh` |



## 使用說明
- 透過指令執行 CICD pipeline 
    ```
    kde proj pipeline [project-name] [options]
    ```
    - options：
        - `--from`: 階段過濾，允許使用者跳過部分流程，從某階段開始執行（例如：只跑 test 之後的流程），可與 `--to` 搭配使用。
        - `--to`: 階段過濾，允許使用者跳過部分流程，只執行到某階段（例如：只跑 test 之前的流程），可與 `--from` 搭配使用。
        - `--only`: 單獨執行某一階段，（例如：只跑 test），不可與 `--to`、`--from` 一起使用。
        - `--manual`: 進入某一階段的執行環境手動測試，與 `--to`、`--from` 搭配使用時，在退出單一階段環境後會進入下一階段環境。
    - 防呆：
        - 應該要先判斷 kde proj pipeline 後面接的是不是存在於當前環境底下的 namespaces 內的資料夾，如果是直接接參數（例如: --only build），應該跳出錯誤警告並且停止動作。
            
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
            echo $APP_IMAGE也可以直接在流程腳本內實作實際執行的步驟

## 使用範例

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

KDE_PIPELINE_STAGE_build_SCRIPT=[path to project ]/build.sh
KDE_PIPELINE_STAGE_build_IMAGE=node:24

KDE_PIPELINE_STAGE_deploy_SCRIPT=deploy.sh
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

### 範例 5：錯誤處理 - Allow Failure

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