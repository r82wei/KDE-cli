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
  - 專案的 CI/CD 包含 pre-build / build / post-build / pre-deploy / deploy / post-deploy / undeploy 等等的 scripts
  - 每個 CI/CD 的 script 都可以指定 docker image，在指定的 container 內執行

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
        ├─ project.env        # 專案級設定檔(包含專案 Git Repository、環境 image 設定、CICD 環境變數)
        ├─ .env               # 專案本地設定檔 (建議加入 .gitignore)
        ├─ pre-build.sh       # CI 前置腳本
        ├─ build.sh           # CI 執行腳本
        ├─ post-build.sh      # CI 後置腳本
        ├─ pre-deploy.sh      # CD 前置腳本
        ├─ deploy.sh          # CD 執行腳本
        ├─ post-deploy.sh     # CD 後置腳本
        ├─ undeploy.sh        # 解除部署腳本
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

- 自訂 CI/CD 腳本路徑：

  可以在 project.env 中指定自訂的 CI/CD 腳本，支援以下環境變數：

  - `KDE_PROJECT_PRE_BUILD_SCRIPT`: 自訂 pre-build 腳本路徑
  - `KDE_PROJECT_BUILD_SCRIPT`: 自訂 build 腳本路徑
  - `KDE_PROJECT_POST_BUILD_SCRIPT`: 自訂 post-build 腳本路徑
  - `KDE_PROJECT_PRE_DEPLOY_SCRIPT`: 自訂 pre-deploy 腳本路徑
  - `KDE_PROJECT_DEPLOY_SCRIPT`: 自訂 deploy 腳本路徑
  - `KDE_PROJECT_POST_DEPLOY_SCRIPT`: 自訂 post-deploy 腳本路徑
  - `KDE_PROJECT_UNDEPLOY_SCRIPT`: 自訂 undeploy 腳本路徑

  範例：

  ```bash
  # 使用自訂的 build 腳本
  KDE_PROJECT_BUILD_SCRIPT=build-production.sh

  # 使用自訂的 deploy 腳本
  KDE_PROJECT_DEPLOY_SCRIPT=deploy-k8s-staging.sh
  ```

  優先級規則：

  - 如果設定了自訂腳本環境變數，優先使用自訂腳本
  - 如果自訂腳本不存在，會顯示錯誤訊息並且停止繼續執行 CI/CD
  - 如果同時存在自訂腳本和標準腳本，會顯示警告訊息
  - 未設定環境變數時，使用標準腳本

- `容器開發環境` 和 `CI/CD pipeline` 掛載檔案/資料夾路徑的方式

  設定 `KDE_MOUNT_` 開頭的環境變數，並且指定掛載路徑

  範例：

  ```bash
  # 將本地 HOME 底下的 .netrc 掛載到 container 內的 ~/.netrc
  KDE_MOUNT_NETRC=~/.netrc:~/.netrc
  ```

### environments/[k8s-name]/namespaces/[project-name]/.env

特定專案本地設定檔，主要放置不應該進入版控的個人化的專案環境設定，像是：敏感資訊 (Secrets & Credentials)、本地開發的覆寫、CICD 腳本的本地驅動參數

- 不建議加入 git 版控。

### environments/[k8s-name]/namespaces/[project-name]/pre-build.sh

CI 前置腳本，可以透過在 project.env 設定 `PRE_BUILD_IMAGE` 自訂執行環境(預設使用：`DEVELOP_IMAGE`)。

- 執行時機：

  - 執行 `kde proj [project-name] build` 時，在執行 `build.sh` 前會執行此腳本

- 如果 pre-build.sh 不存在，不做任何動作

- 可以透過在 project.env 設定 `KDE_PROJECT_PRE_BUILD_SCRIPT` 來指定使用其他腳本（如 `pre-build-production.sh`）

### environments/[k8s-name]/namespaces/[project-name]/build.sh

CI 腳本，可以透過在 project.env 設定 `BUILD_IMAGE` 自訂執行環境(預設使用：`DEVELOP_IMAGE`)。

- 執行時機：

  - 執行 `kde proj [project-name] build` 時
  - 執行 `kde proj [project-name] deploy` 時

- 如果 build.sh 不存在，不做任何動作

- 可以透過在 project.env 設定 `KDE_PROJECT_BUILD_SCRIPT` 來指定使用其他腳本（如 `build-production.sh`）

### environments/[k8s-name]/namespaces/[project-name]/post-build.sh

CI 後置腳本，可以透過在 project.env 設定 `POST_BUILD_IMAGE` 自訂執行環境(預設使用：`DEVELOP_IMAGE`)。

- 執行時機：

  - 執行 `kde proj [project-name] build` 時，在執行 `build.sh` 後會執行此腳本

- 如果 post-build.sh 不存在，不做任何動作

- 可以透過在 project.env 設定 `KDE_PROJECT_POST_BUILD_SCRIPT` 來指定使用其他腳本（如 `post-build-production.sh`）

### environments/[k8s-name]/namespaces/[project-name]/pre-deploy.sh

CD 前置腳本，可以透過在 project.env 設定 `PRE_DEPLOY_IMAGE` 自訂執行環境(預設使用：`DEPLOY_IMAGE`)。

- 執行時機：

  - 執行 `kde proj [project-name] deploy-only` 時，在執行 `deploy.sh` 前會執行此腳本
  - 執行 `kde proj [project-name] deploy` 時，在執行 `deploy.sh` 前會執行此腳本

- 如果 pre-deploy.sh 不存在，不做任何動作

- 可以透過在 project.env 設定 `KDE_PROJECT_PRE_DEPLOY_SCRIPT` 來指定使用其他腳本（如 `pre-deploy-staging.sh`）

### environments/[k8s-name]/namespaces/[project-name]/deploy.sh

CD 腳本，可以透過在 project.env 設定 `DEPLOY_IMAGE` 自訂執行環境。

- 執行時機：

  - 執行 `kde proj [project-name] deploy` 時
  - 執行 `kde proj [project-name] deploy-only` 時

- 如果 deploy.sh 不存在，不做任何動作

- 可以透過在 project.env 設定 `KDE_PROJECT_DEPLOY_SCRIPT` 來指定使用其他腳本（如 `deploy-k8s.sh`）

### environments/[k8s-name]/namespaces/[project-name]/post-deploy.sh

CD 後置腳本，可以透過在 project.env 設定 `POST_DEPLOY_IMAGE` 自訂執行環境(預設使用：`DEPLOY_IMAGE`)。

- 執行時機：

  - 執行 `kde proj [project-name] deploy` 時，在執行 `deploy.sh` 後會執行此腳本
  - 執行 `kde proj [project-name] deploy-only` 時，在執行 `deploy.sh` 後會執行此腳本

- 如果 post-deploy.sh 不存在，不做任何動作

- 可以透過在 project.env 設定 `KDE_PROJECT_POST_DEPLOY_SCRIPT` 來指定使用其他腳本（如 `post-deploy-notification.sh`）

### environments/[k8s-name]/namespaces/[project-name]/undeploy.sh

解除部署腳本，如果存在（如果不存在 undeploy.sh，預設動作為刪除與專案同名的 namespace ）。可以透過在 project.env 設定 `UNDEPLOY_IMAGE` 自訂執行環境(預設使用：`DEPLOY_IMAGE`)。

- 執行時機：

  - 執行 `kde proj [project-name] undeploy` 時

- 如果 undeploy.sh 不存在，預設動作為刪除與專案同名的 namespace

- 可以透過在 project.env 設定 `KDE_PROJECT_UNDEPLOY_SCRIPT` 來指定使用其他腳本（如 `undeploy-cleanup.sh`）
