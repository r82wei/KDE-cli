# Script 驅動的 CI/CD 部署流程

## 舊版本
- 透過 pre-build.sh、build.sh、post-build.sh、pre-deploy.sh、deploy.sh、post-deploy.sh、undeploy.sh 模擬 CI/CD 觸發或執行
- 可以僅作為觸發事件執行專案內原有的 CI/CD 腳本，也可以直接在流程腳本內實作實際執行的步驟
- 每個 CICD 腳本可以在 project.env 自訂 Docker image ，啟動各自自定義的執行環境
- 透過 project.env 設定 CICD 執行需要的環境變數
- 本地與 CI 執行的流程應盡可能一致。


## 新版本
### 功能說明
- 可以透過 project.env 定義 `KDE_PIPELINE_STAGES=build,test,release,deploy` CICD pipeline 流程
- 可以透過 project.env 定義 `KDE_PIPELINE_STAGE_[階段名稱]_IMAGE=node:24` CICD pipeline 特定階段容器映像檔
- 可以透過 project.env 定義 `KDE_PIPELINE_STAGE_[階段名稱]_SCRIPT=build.sh` CICD pipeline 特定階段腳本
- 檔案掛載
    - 各階段會自動掛載 `專案資料夾` 作為 CICD pipeline 各階段的 workdir
    - 可以透過 project.env 定義 `KDE_PIPELINE_STAGE_[階段名稱]_MOUNT_[自定義名稱]=${PROJECT_PATH}/libs:${PROJECT_PATH}/libs` CICD pipeline 特定階段掛載特定檔案或資料夾
    - 可以透過 project.env 定義 `KDE_MOUNT_[自定義名稱]=${}/.ssh:${PROJECT_PATH}/.ssh` CICD pipeline 全部階段掛載特定檔案或資料夾
- 透過 project.env 定義 CICD pipeline 的環境變數(每個階段都會載入 project.env 作為環境變數定義檔)，例如:
    ```
    PROJECT_NAME=my-app
    NAMESPACE=my-app
    REPO_DIR=my-app
    ```
- 透過指令執行 CICD pipeline 
    ```
    kde proj pipeline [project-name] [options]
    ```
    - options：
        - `--from`: 階段過濾，允許使用者跳過部分流程，從某階段開始執行（例如：只跑 test 之後的流程），可與 `--to` 搭配使用。
        - `--to`: 階段過濾，允許使用者跳過部分流程，只執行到某階段（例如：只跑 test 之前的流程），可與 `--from` 搭配使用。
        - `--only`: 單獨執行某一階段，（例如：只跑 test），不可與 `--to`、`--from` 一起使用。
        - `--manual`: 進入某一階段的執行環境手動測試，與 `--to`、`--from` 搭配使用時，在退出單一階段環境後會進入下一階段環境。
            
### Best Practice
- 各階段 Artifacts 及環境變數傳遞
    - Artifact 可以直接輸出在 `專案資料夾` 內，CICD pipeline 各階段執行環境會自動掛載 `專案資料夾` 作為 workdir
    - 環境變數可以透過下列方式傳遞:
        - release 階段 
            ```
            # 將 APP_IMAGE 作為環境變數輸出到 .pipeline.env
            echo "APP_IMAGE=my-app:1.0.0" >> .pipeline.env
            ```
        - deploy 階段 
            ```
            # 載入 .pipeline.env 內的環境變數
            source .pipeline.env

            # 印出 APP_IMAGE
            echo $APP_IMAGE

### 使用範例

#### 範例 1：快速開發模式

只執行 build 和 deploy：

```bash
# project.env
KDE_PIPELINE_STAGES="build,deploy"

KDE_PIPELINE_STAGE_build_SCRIPT=build.sh
KDE_PIPELINE_STAGE_build_IMAGE=node:20

KDE_PIPELINE_STAGE_deploy_SCRIPT=deploy-quick.sh
KDE_PIPELINE_STAGE_deploy_IMAGE=r82wei/deploy-env:1.0.0
```

#### 範例 2：安全優先模式

加入安全掃描：

```bash
# project.env
KDE_PIPELINE_STAGES="code,build,security-scan,test,deploy,monitor"

KDE_PIPELINE_STAGE_code_SCRIPT=lint.sh
KDE_PIPELINE_STAGE_code_IMAGE=node:20

KDE_PIPELINE_STAGE_build_SCRIPT=build.sh
KDE_PIPELINE_STAGE_build_IMAGE=node:20

KDE_PIPELINE_STAGE_security_scan_SCRIPT=security-scan.sh
KDE_PIPELINE_STAGE_security_scan_IMAGE=aquasec/trivy:latest

KDE_PIPELINE_STAGE_test_SCRIPT=test.sh
KDE_PIPELINE_STAGE_test_IMAGE=node:20

KDE_PIPELINE_STAGE_deploy_SCRIPT=deploy.sh
KDE_PIPELINE_STAGE_deploy_IMAGE=r82wei/deploy-env:1.0.0

KDE_PIPELINE_STAGE_monitor_SCRIPT=monitor.sh
KDE_PIPELINE_STAGE_monitor_IMAGE=r82wei/deploy-env:1.0.0
```