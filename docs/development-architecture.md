# KDE 開發架構說明

kde-cli 主要功能：

- 建立開發環境 (容器開發環境 / 容器部署環境 / 本地 K8S / 遠端 K8S 連接)
- 模擬部署服務 (CI/CD Pipeline)
- 整合開發工具 (code-server / telepresence / k9s / headlamp)
- 對外公開服務 (Ngrok / Cloudflare tunnel)

## 開發環境

### 容器開發環境 （CI 環境）

使用 project.env 定義的 `DEVELOP_IMAGE` 啟動的容器，會掛載專案的 Repository (GIT_REPO_URL)資料夾作為 workdir，並且把 project.env 設定的變數注入到容器的環境變數。

#### 範例：

- 以 Node.JS 24 開發的專案，DEVELOP_IMAGE 可以設定為 node:24
- 也可以使用自訂的 Docker image，整合需要的套件及習慣的開發工具

#### 使用時機：

- 只需要開發單一專案，不想啟動 K8S 也不需要部署多個服務
- 專案只需要服務本身啟動，不需要同時啟動關聯服務，例如：
  - 前端專案
  - 連接到現有的資料庫的後端專案
    - `tips` 可以在 project.env 設定現有的資料庫連線相關環境變數
- 測試 CI 腳本
- 專案部署時

#### 設定環境變數

- 在 `project.env` 設定環境變數

#### 啟動方式

- 如果有指定 Port，會將容器內啟動的服務 Port 掛載到本地的 Port

```
kde proj exec [project-name] dev [服務使用的 Port]
```

### 容器部署環境 （CD 環境）

使用 project.env 定義的 `DEPLOY_IMAGE` 啟動的容器，會掛載專案的 Repository (GIT_REPO_URL)資料夾作為 workdir，並且把 project.env 設定的變數注入到容器的環境變數。

#### 範例：

- 以 k8s 部署的專案，DEVELOP_IMAGE 可以設定為包含 kubectl、helm、argocd cli 等工具的 image
- 以 k8s 以外環境部署的專案，也可以使用自訂的 Docker image，整合需要的套件及習慣的部署工具，例如：aws-cli、gcloud cli ...等等

#### 使用時機：

- 測試 CD 腳本
- 專案部署時

#### 設定環境變數

- 在 `project.env` 設定環境變數

#### 啟動方式

```
kde proj exec [project-name] dep
```

#### 開發流程

- 進入容器部署環境 -> 執行部署腳本 or 執行部署 cli 指令

### 本地 K8S (kind / k3d)

透過 docker 啟動 kind (K8S in docker) / k3d (K3S in docker)

#### 使用時機：

- 專案需要一次部署多個服務才可以開發/測試
- 專案需要模擬接近正式環境的開發環境
- 測試多個開環境的測試環境

#### 設定環境

- 在 `environments/[k8s-name]/kind-config.yaml` 設定 kind 環境
- 在 `environments/[k8s-name]/k3d-config.yaml` 設定 k3d 環境

#### 啟動方式

- kind (default)

  ```
  kde start [k8s-name]
  ```

- k3d

  ```
  kde start [k8s-name] --k3d
  ```

#### 開發流程

啟動本地 K8S 環境 -> 部署專案 (執行 CI/CD Pipeline) -> 進入 Pod 開發 -> 透過 Ngrok / Cloudflare tunnel 啟動對外測試網址

### 遠端 K8S

#### 使用時機：

- 本地機器規格不足以啟動服務
- 希望使用現有的 K8S 環境

#### 設定連接方式

- 會提示請使用者輸入現有 k8s 的 kube config 路徑，並且複製到 environments/[k8s-name]/kubeconfig/config

```
kde start [k8s-name] --k8s
```

#### 開發流程

連接遠端 K8S 環境 -> [透過 Telepresence 擷取遠端 K8S Pod 流量到容器開發環境進行開發](./docs/telepresence.usage.md) -> 透過 Ngrok / Cloudflare tunnel 啟動對外測試網址

## CI/CD Pipeline

透過 `專案資料夾` 底下特定檔名的 `.sh` 腳本，模擬 CI/CD 執行，可參考 [Workspace 資料夾結構及檔案說明](./docs/folder.structure.md)

- 可以將**編譯**/**編譯**/**部署**需要的環境變數定義在 project.env，執行時會自動注入 container 環境內
- 如果檔案存在，將會依序執行專案下的 shell 腳本，每個 shell 可以在 project.env 自訂執行環境的 docker image

  | 執行順序 | 腳本           | 說明            | 預設執行環境 Image (project.env) | 自訂執行環境 Image (project.env) |
  | -------- | -------------- | --------------- | -------------------------------- | -------------------------------- |
  | 1        | pre-build.sh   | CI 前置作業腳本 | DEVELOP_IMAGE                    | PRE_BUILD_IMAGE                  |
  | 2        | build.sh       | CI 執行腳本     | DEVELOP_IMAGE                    | BUILD_IMAGE                      |
  | 3        | post-build.sh  | CI 後置作業腳本 | DEVELOP_IMAGE                    | POST_BUILD_IMAGE                 |
  | 4        | pre-deploy.sh  | CD 前置作業腳本 | DEPLOY_IMAGE                     | PRE_DEPLOY_IMAGE                 |
  | 5        | deploy.sh      | CD 執行腳本     | DEPLOY_IMAGE                     |                                  |
  | 6        | post-deploy.sh | CD 後置作業腳本 | DEPLOY_IMAGE                     | POST_DEPLOY_IMAGE                |
  | 7        | undeploy.sh    | 解除部署腳本    | DEPLOY_IMAGE                     | UNDEPLOY_IMAGE                   |

### 觸發 CI & CD

```bash
kde project deploy <project-name>
```

### 只觸發 CI

```bash
kde project build <project-name>
```

### 只觸發 CD

```bash
kde project deploy-only <project-name>
```

## 整合開發工具

#### [使用 code-server(VS Code) Web IDE](./docs/code-server.usage.md)

#### [透過 Telepresence 擷取遠端 K8S Pod 流量到容器開發環境進行開發](./docs/telepresence.usage.md)

#### [K9S](https://k9scli.io/)

#### [Headlamp](https://headlamp.dev/)

## 對外公開服務

#### [使用 Ngrok 建立對外網址](./docs/ngrok.usage.md)

#### [使用 Cloudflare Tunnel 建立對外網址](./docs/cloudflare-tunnel.usage.md)
