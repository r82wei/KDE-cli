# CI/CD 交付流程
**透過 shell script 及 docker image，定義專案到環境的交付流程**

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
    - 預設環境變數
        - `KDE_PATH`
    - 自訂環境變數
        - 可以透過 project.env 定義 CICD pipeline 的環境變數(每個階段都會載入 project.env 作為環境變數定義檔)，例如:
            ```bash
            # project.env
            
            NAMESPACE=my-app
            REPO_DIR=my-app
            ```
- 檔案掛載
    - CICD pipeline 各階段執行環境會自動掛載 `專案資料夾` 作為 workdir
    - 各階段的 Artifact 可以直接輸出在 `專案資料夾` 底下
    - 可以透過 project.env 定義 `KDE_PIPELINE_STAGE_[階段名稱]_MOUNT_[自定義名稱]=${PROJECT_PATH}/libs:${PROJECT_PATH}/libs` 掛載 CICD pipeline 特定階段的特定檔案或資料夾
    - 可以透過 project.env 定義 `KDE_MOUNT_[自定義名稱]=${}/.ssh:${PROJECT_PATH}/.ssh` CICD pipeline 全部階段掛載特定檔案或資料夾
- 錯誤處理選項：
    - 預設啟用 Fail Fast 模式（任何階段失敗立即停止），可以透過 project.env 定義 `KDE_PIPELINE_FAIL_FAST=false` 停用
    - 可以透過 project.env 定義 `KDE_PIPELINE_AUTO_ROLLBACK=true` 部署失敗時自動回滾

### 功能總整理
| 環境變數 | 說明 | 範例 |
|---------|------|------|
| `KDE_PIPELINE_STAGES` | 自定義 CICD pipeline 流程階段 | `KDE_PIPELINE_STAGES=build,test,release,deploy` |
| `KDE_PIPELINE_STAGE_[階段名稱]_IMAGE` | 指定特定階段使用的容器映像檔 | `KDE_PIPELINE_STAGE_BUILD_IMAGE=node:24` |
| `KDE_PIPELINE_STAGE_[階段名稱]_SCRIPT` | 指定特定階段執行的腳本檔案 | `KDE_PIPELINE_STAGE_BUILD_SCRIPT=build.sh` |
| `KDE_PIPELINE_STAGE_[階段名稱]_MOUNT_[自定義名稱]` | 掛載特定階段的檔案或資料夾 | `KDE_PIPELINE_STAGE_BUILD_MOUNT_LIBS=${PROJECT_PATH}/libs:${PROJECT_PATH}/libs` |
| `KDE_PIPELINE_FAIL_FAST` | 任何階段失敗時立即停止整個 pipeline（預設：true） | `KDE_PIPELINE_FAIL_FAST=false` 停用 |
| `KDE_PIPELINE_AUTO_ROLLBACK` | 部署失敗時自動回滾到前一版本 | `KDE_PIPELINE_AUTO_ROLLBACK=true` |
| `KDE_MOUNT_[自定義名稱]` | 掛載所有階段共用的檔案或資料夾 | `KDE_MOUNT_SSH=${}/.ssh:${PROJECT_PATH}/.ssh` |
| `KDE_PATH` | 預設環境變數，KDE 系統路徑 | 系統自動設定 |



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

```bash
# build.sh

```

```bash
# deploy.sh

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