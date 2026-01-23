# Workspace

### workspace 是一個用來定義專案、CICD pipeline(專案到環境的發布流程)、環境三者之間關係的地方

一個 workspace 通常包含：

- 環境定義
  - 一個或多個對應的 Kubernetes cluster（本地或遠端）
  - 每個環境的 namespaces 內會有一個或多個專案 repo 定義
  - 在 kde.env 內定義相關工具的 image
- 專案定義
  - 每個專案名稱對應的是一個 Kubernetes 的 namespace
  - 同一專案可以同時存在多個環境，彼此隔離。
  - 在 project.env 內定義 git repo 相關設定
  - 在 project.env 內定義`開發環境`image
  - 在 project.env 內定義`部署環境`image
  - 在 project.env 內定義`CICD 流程`的環境變數
- CICD 流程定義
  - 支援兩種 Pipeline 模式：
    - **標準 DevOps Loops**（預設）- Build → Test → Release → Deploy 階段
    - **自定義 Pipeline** - 透過 `KDE_PIPELINE_STAGES` 靈活定義階段、順序和執行環境
  - 每個階段的腳本都可以指定 Docker image，在指定的 container 內執行
  - 詳細配置請參考 [CI/CD Pipeline 配置指南](./cicd-pipeline.md)

### 自動環境搜尋機制，無需手動設定路徑

- 從當前目錄往上搜尋 kde.env 檔案，自動定位 workspace 根目錄
- 支援在 workspace 的任意子目錄執行 kde 指令，保持操作一致性

### Debug 模式支援

- 透過在 kde.env 設定 KDE_DEBUG 環境變數啟用除錯模式
- 除錯模式會顯示所有執行的 shell 指令 (set -x)

## 資料夾結構

```
environments/
  └─ <k8s-name>/      # K8S 環境
    └─ kubeconfig/                    # k8s kubeconfig 所在資料夾 (建議加入 .gitignore)
    └─ pki/                           # kind cluster cert 所在資料夾 (建議加入 .gitignore)
    └─ kind-config.template.yaml      # kind 的設定檔模板 (可自訂，可版控)
    └─ kind-config.yaml               # kind 的設定檔 (建議加入 .gitignore)
    └─ k3d-config.template.yaml       # k3d 的設定檔模板 (可自訂，可版控)
    └─ k3d-config.yaml                # k3d 的設定檔 (建議加入 .gitignore)
    └─ k9s                            # 此環境的 k9s 設定檔目錄
    └─ .env                           # 此環境的本地的設定檔 (建議加入 .gitignore)
    └─ k8s.env                        # 此環境的公用的設定檔，環境級配置，每個 K8S 環境獨立的設定
    └─ init.sh                        # 本地 K8S 啟動後執行的初始化腳本
    └─ namespaces/
      └─ <project-name>/    # 專案名稱(K8S namespace 名稱)
        ├─ project.env        # 專案級設定檔(包含專案 Git Repository、環境 image 設定、Pipeline 配置)
        ├─ .env               # 專案本地設定檔 (建議加入 .gitignore)
        ├─ {stage}.sh         # Pipeline 階段腳本（如 build.sh、test.sh、deploy.sh 等）
        ├─ [repo]/            # 專案 git repo
        ├─ [pvc dir]/         # PVC 掛載的資料夾 (StroageClass: local-path)
        └─ ...
current.env  # 當前使用的環境名稱，用於快速切換環境 (建議加入 .gitignore)
kde.env      # 全局配置，包含 KDE 路徑、預設映像版本、工具映像等
k9s/         # 全部環境的 k9s 設定檔目錄
```

## 檔案說明

### kde.env

kde-cli 的全域環境變數設定以及各功能使用的 docker image。

### current.env

記錄當前使用的 K8S 環境。

### environments/[k8s-name]/.env

特定 K8S 環境的本地設定檔，包含 kube-apiserver 的 Port、Ingress 的 Port、K8S PV 掛載路徑，主要放置個人化的 K8S 環境設定。

- 不建議加入 git 版控。

### environments/[k8s-name]/k8s.env

特定 K8S 環境的共用設定檔，主要放置不應該進入版控的個人化的 k8s 環境設定，包含此環境的名稱、類型、DOCKER_NETWORK...等等，，主要放置共用的 K8S 環境設定。

- 建議加入 git 版控。

### environments/[k8s-name]/kind-config.template.yaml

Kind 集群的自訂配置模板檔案。

- 支援環境變數替換（使用 `envsubst`）
- 可加入 Git 版控與團隊共享
- 優先級高於預設模板

### environments/[k8s-name]/kind-config.yaml

Kind 集群的實際配置檔案，由模板生成。

- 透過 `envsubst` 處理環境變數替換
- 不建議加入 Git 版控（應加入 .gitignore）
- 每次環境初始化時重新生成

### environments/[k8s-name]/k3d-config.template.yaml

K3d 集群的自訂配置模板檔案。

- 支援環境變數替換（使用 `envsubst`）
- 可加入 Git 版控與團隊共享
- 優先級高於預設模板

### environments/[k8s-name]/k3d-config.yaml

K3d 集群的實際配置檔案，由模板生成。

- 透過 `envsubst` 處理環境變數替換
- 不建議加入 Git 版控（應加入 .gitignore）
- 每次環境初始化時重新生成

### environments/[k8s-name]/namespaces/[project-name]/project.env

專案的設定檔，包含 Git repository 相關設定，以及環境 image 設定。可以自訂執行 `容器開發環境` 和 `CI/CD pipeline` 的時候使用到的環境變數以及掛載的檔案/資料夾路徑。

- 基本環境變數（`kde proj create` 的時候會自動新增）：

  - GIT_REPO_URL: Git repository URL
  - GIT_REPO_BRANCH: Git 分支
  - DEVELOP_IMAGE: 開發環境(CI 環境)的 docker image
  - DEPLOY_IMAGE: 部署環境(CD 環境)的 docker image

  範例：

  ```bash
  GIT_REPO_URL=https://github.com/nodejs/examples.git
  GIT_REPO_BRANCH=main
  DEVELOP_IMAGE=node:20
  DEPLOY_IMAGE=node:20
  ```

- 自訂環境變數：

  範例：設定 DEBUG 環境變數

  ```
  DEBUG=*
  ```

- 自定義 Pipeline 配置：

  可以在 project.env 中定義自定義的 CI/CD Pipeline：

  ```bash
  # 定義要執行的階段（空格或逗號分隔）
  KDE_PIPELINE_STAGES="lint build test deploy"

  # 每個階段的配置
  KDE_STAGE_lint_SCRIPT=lint.sh
  KDE_STAGE_lint_IMAGE=node:20

  KDE_STAGE_build_SCRIPT=build.sh
  KDE_STAGE_build_IMAGE=node:20

  KDE_STAGE_test_SCRIPT=test.sh
  KDE_STAGE_test_IMAGE=node:20

  KDE_STAGE_deploy_SCRIPT=deploy.sh
  KDE_STAGE_deploy_IMAGE=r82wei/deploy-env:1.0.0
  ```

  階段配置變數：

  | 變數模式 | 說明 | 範例 |
  |---------|------|------|
  | `KDE_STAGE_{stage}_SCRIPT` | 腳本路徑 | `KDE_STAGE_build_SCRIPT=build.sh` |
  | `KDE_STAGE_{stage}_IMAGE` | Docker 映像 | `KDE_STAGE_build_IMAGE=node:20` |

  預設行為：

  - **腳本**：如果未指定，使用 `{stage}.sh`
  - **映像**：如果未指定，使用 `DEPLOY_IMAGE`
  - **跳過**：沒有設定 Docker 映像、腳本路徑或是腳本檔案不存在

  錯誤處理：

  ```bash
  KDE_DEVOPS_FAIL_FAST=true       # 任何階段失敗立即停止
  KDE_DEVOPS_AUTO_ROLLBACK=true   # deploy 相關階段失敗時自動回滾
  KDE_STAGE_test_SKIP=true        # 跳過特定階段
  ```

  詳細配置請參考 [CI/CD Pipeline 配置指南](./cicd-pipeline.md)

- `容器開發環境` 和 `CI/CD pipeline` 掛載檔案/資料夾路徑的方式

  設定 `KDE_MOUNT_` 開頭的環境變數，並且指定掛載路徑

  範例：

  ```bash
  # 將本地 HOME 底下的 .netrc 掛載到 container 內的 ~/.netrc
  KDE_MOUNT_NETRC=~/.netrc:~/.netrc
  ```

### environments/[k8s-name]/namespaces/[project-name]/.env

特定專案本地設定檔，主要放置不應該進入版控的個人化的專案環境設定，像是：敏感資訊 (Secrets & Credentials)、本地開發的覆寫、Pipeline 階段的本地覆寫參數

- 不建議加入 git 版控。

### environments/[k8s-name]/namespaces/[project-name]/{stage}.sh

Pipeline 階段腳本，每個階段可以有對應的腳本檔案。

- 腳本命名規則：`{stage}.sh`（如 `build.sh`、`test.sh`、`deploy.sh`）
- 可以透過 `KDE_STAGE_{stage}_SCRIPT` 指定自訂腳本路徑
- 可以透過 `KDE_STAGE_{stage}_IMAGE` 指定執行環境的 Docker 映像

常見的階段腳本範例：

| 腳本 | 用途 | 預設映像 |
|------|------|----------|
| `lint.sh` | 程式碼檢查 | `DEPLOY_IMAGE` |
| `security-scan.sh` | 安全掃描 | `DEPLOY_IMAGE` |
| `build.sh` | 建置專案 | `DEPLOY_IMAGE` |
| `test.sh` | 執行測試 | `DEPLOY_IMAGE` |
| `deploy.sh` | 部署到 K8s | `DEPLOY_IMAGE` |
| `monitor.sh` | 監控設定 | `DEPLOY_IMAGE` |

執行時機：

- 執行 `kde proj [project-name] deploy` 時，會依照 `KDE_PIPELINE_STAGES` 定義的順序執行各階段腳本
- 如果腳本不存在，該階段會被跳過

詳細配置請參考 [CI/CD Pipeline 配置指南](./cicd-pipeline.md)
