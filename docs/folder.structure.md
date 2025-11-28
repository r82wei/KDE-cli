# Workspace 資料夾結構及檔案說明

## 資料夾結構

```
environments/
  └─ <k8s-name>/      # K8S 環境
    └─ kubeconfig/          # k8s kubeconfig 所在資料夾 (建議加入 .gitignore)
    └─ pki/                 # kind cluster cert 所在資料夾 (建議加入 .gitignore)
    └─ kind-config.yaml     # kind 的設定檔 (建議加入 .gitignore)
    └─ k3d-config.yaml      # k3d 的設定檔 (建議加入 .gitignore)
    └─ .env                 # 此環境的本地的設定檔 (建議加入 .gitignore)
    └─ k8s.env              # 此環境的公用的設定檔
    └─ namespaces/
      └─ <project-name>/    # 專案名稱(K8S namespace 名稱)
        ├─ project.env        # 專案設定檔(包含專案 Repo、開發/部署環境 image 設定，可增加自訂環境變數)
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
current.env  # 當前使用的 K8s 環境 (建議加入 .gitignore)
kde.env      # kde-cli 使用的 docker image (建議加入 .gitignore)
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

特定 K8S 環境的共用設定檔，包含此環境的名稱、類型、DOCKER_NETWORK...等等，，主要放置共用的 K8S 環境設定。

- 建議加入 git 版控。

### environments/[k8s-name]/kind-config.env

kind 的[設定檔](https://kind.sigs.k8s.io/docs/user/configuration/)。

### environments/[k8s-name]/k3d-config.env

k3d 的[設定檔](https://k3d.io/stable/usage/configfile/#config-options)。

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

- `容器開發環境` 和 `CI/CD pipeline` 掛載檔案/資料夾路徑的方式

  設定 `KDE_MOUNT_` 開頭的環境變數，並且指定掛載路徑

  範例：

  ```bash
  # 將本地 HOME 底下的 .netrc 掛載到 container 內的 ~/.netrc
  KDE_MOUNT_NETRC=~/.netrc:~/.netrc
  ```

### environments/[k8s-name]/namespaces/[project-name]/pre-build.sh

CI 前置腳本，可以透過在 project.env 設定 `PRE_BUILD_IMAGE` 自訂執行環境(預設使用：`DEVELOP_IMAGE`)。

- 執行時機：

  - 執行 `kde proj [project-name] build` 時，在執行 `build.sh` 前會執行此腳本

- 如果 pre-build.sh 不存在，不做任何動作

### environments/[k8s-name]/namespaces/[project-name]/build.sh

CI 腳本，可以透過在 project.env 設定 `BUILD_IMAGE` 自訂執行環境(預設使用：`DEVELOP_IMAGE`)。

- 執行時機：

  - 執行 `kde proj [project-name] build` 時
  - 執行 `kde proj [project-name] deploy` 時

- 如果 build.sh 不存在，不做任何動作

### environments/[k8s-name]/namespaces/[project-name]/post-build.sh

CI 後置腳本，可以透過在 project.env 設定 `POST_BUILD_IMAGE` 自訂執行環境(預設使用：`DEVELOP_IMAGE`)。

- 執行時機：

  - 執行 `kde proj [project-name] build` 時，在執行 `build.sh` 後會執行此腳本

- 如果 post-build.sh 不存在，不做任何動作

### environments/[k8s-name]/namespaces/[project-name]/pre-deploy.sh

CD 前置腳本，可以透過在 project.env 設定 `PRE_DEPLOY_IMAGE` 自訂執行環境(預設使用：`DEPLOY_IMAGE`)。

- 執行時機：

  - 執行 `kde proj [project-name] deploy-only` 時，在執行 `deploy.sh` 前會執行此腳本
  - 執行 `kde proj [project-name] deploy` 時，在執行 `deploy.sh` 前會執行此腳本

- 如果 pre-deploy.sh 不存在，不做任何動作

### environments/[k8s-name]/namespaces/[project-name]/deploy.sh

CD 腳本，可以透過在 project.env 設定 `DEPLOY_IMAGE` 自訂執行環境。

- 執行時機：

  - 執行 `kde proj [project-name] deploy` 時
  - 執行 `kde proj [project-name] deploy-only` 時

- 如果 deploy.sh 不存在，不做任何動作

### environments/[k8s-name]/namespaces/[project-name]/post-deploy.sh

CD 後置腳本，可以透過在 project.env 設定 `POST_DEPLOY_IMAGE` 自訂執行環境(預設使用：`DEPLOY_IMAGE`)。

- 執行時機：

  - 執行 `kde proj [project-name] deploy` 時，在執行 `deploy.sh` 後會執行此腳本
  - 執行 `kde proj [project-name] deploy-only` 時，在執行 `deploy.sh` 後會執行此腳本

- 如果 post-deploy.sh 不存在，不做任何動作

### environments/[k8s-name]/namespaces/[project-name]/undeploy.sh

解除部署腳本，如果存在（如果不存在 undeploy.sh，預設動作為刪除與專案同名的 namespace ）。可以透過在 project.env 設定 `UNDEPLOY_IMAGE` 自訂執行環境(預設使用：`DEPLOY_IMAGE`)。

- 執行時機：

  - 執行 `kde proj [project-name] undeploy` 時

- 如果 undeploy.sh 不存在，預設動作為刪除與專案同名的 namespace
