# KDE-cli (Kubernetes Development Environment)

一個以開發者為核心的基礎架構自動化框架，協助快速打造本地 Kubernetes 開發流程，同時支援 CI/CD 環境的模擬與驗證，並可將開發環境設定保存、同步到各個地方。

## 🔑 主要功能

- ⚙️ `快速啟動本地 K8s 或連接遠端 K8s`
  - [kind](https://kind.sigs.k8s.io/): Docker 中的 Kubernetes 集群 (預設)
  - [k3d](https://k3d.io/stable/): 輕量級 K3s 集群
  - 遠端 K8s: 連接現有的 Kubernetes 集群
- 🚀 `簡易且彈性的 CI/CD`
  - 提供 `build.sh`/`deploy.sh`/`undeploy.sh` 等自動化部署腳本，並且可以透過 project.env 自訂 pipeline 環境變數
  - 支援所有 CD 工具(可自訂 Deploy 環境 image)
  - 一鍵部署，快速驗證部署腳本及設定
- 🧑🏻‍💻 `即時開發`
  - 快速啟動容器化開發環境 (各專案可自訂開發和部署的 image，可選擇使用任意語言開發、任意工具部署)
  - 透過 [Telepresence](https://telepresence.io/docs/quick-start) 流量攔截與代理，讓開發者可以用本地容器環境取代遠端 K8s 上的服務，加速開發與測試，不需每次變更都需要等待 CI/CD
  - 透過 k8s yaml 部署到本地環境，只需建立 PVC，即可掛載本地專案原始碼資料夾到 Pod 內進行 Live Reload 開發（目前只支援本地 K8s 環境）
- 🖥️ `監控和管理工具`
  - [k9s](https://k9scli.io/): 終端 Kubernetes 管理界面，方便在 IDE 開發除錯
  - [Kubernetes Dashboard](https://github.com/kubernetes/dashboard): Web UI 管理界面
- 📦 `IaC 化的環境設定`
  - 開發環境設定檔可透過 git 版本化
  - 團隊同步的標準化開發環境
- 🌐 `快速公開服務`
  - [Ngrok](https://ngrok.com/): 將本地服務快速開放到外網進行測試
  - [Cloudflare Tunnel](https://developers.cloudflare.com/cloudflare-one/connections/connect-apps/): 通過 Cloudflare 建立安全隧道，快速對外開放服務進行測試
  - Port Forward: 將 K8s Service/Pod 的 Port 轉發到本地
- 🐳 `完全容器化`
  - 所有操作都在 Docker 容器中執行
  - 隔離的開發環境，支持多個專案同時開發
  - 只需安裝 Docker 就可以建立一致的開發環境

## 為什麼選 KDE-cli？

- 你是 Developer，想快速啟動本地測試環境？✅
- 你是 QA，要驗證某個特定 Commit 的行為？✅
- 你是 Ops/Infra/DevOps，要在撰寫 CI/CD 前先模擬部署？✅
- 你想要減少開發環境與正式環境的差異？✅
- 你希望用一個 Shell 工具就搞定？✅

👉 KDE-cli 希望做到「簡化並整合這些工作流程」，讓使用者能夠在本地的命令列環境裡完成大部分開發、測試與部署驗證流程，並且能把環境版本化。

## Workflow

```mermaid
flowchart TD
    subgraph Ops["Ops/DevOps/Infra"]
        Ops_create_workspace[建立 Workspace 環境]
        Ops_create_local_k8s[建立本地K8s環境]
        Ops_add_remote_k8s[連接現有K8s]
        Ops_create_project[設定專案]
        Ops_pull_repo[從 Git 抓取現有專案]
        Ops_create_local_repo[建立新的本地專案]
        Ops_k8s_yaml[撰寫部署 K8s yaml]
        Ops_shell_script[撰寫 CI/CD shell build.sh/deploy.sh/undeploy.sh]
        Ops_deploy[一鍵部署服務到 K8S]
        Ops_cicd[CI/CD 開發與除錯]
        Ops_Monitor[K9s / K8S Dashboard]
        Ops_expose[公開服務]
        Ops_port_forwarding[port-forwarding]
        Ops_cloudflare_tunnel[Cloudflare Tunnel]
        Ops_ngrok[ngrok]
        Ops_git_push[將 Workspace 環境儲存至Git]
    end

    subgraph Developer["Developer"]
        Dev_git_pull[從 Git 抓取 Workspace 環境]
        Dev_start_k8s[啟動K8S / 設定 kubeconfig]
        Dev_deploy[一鍵部署服務到 K8S]
        Dev_remote_debug[遠端除錯]
        Dev_local_env[本地容器開發環境]
        Dev_debug_1[程式開發/除錯]
        Dev_debug_2[程式開發/除錯]
        Dev_debug_3[程式開發/除錯]
        Dev_monitor[K9s / K8S Dashboard]
        Dev_expose[公開服務]
        Dev_cloudflare_tunnel[Cloudflare Tunnel]
        Dev_ngrok[ngrok]
        Dev_port_forwarding[port-forwarding]
        Dev_telepresence[Telepresence]
        Dev_connect_remote_k8s[連線到遠端的 K8s]
        Dev_telepresence_remote_pod[擷取流量到本地容器開發環境]

    end

    subgraph QA["QA"]
        QA_git_pull[從 Git 抓取 Workspace 環境]
        QA_start_k8s[啟動K8S / 設定 kubeconfig]
        QA_deploy[一鍵部署服務到 K8S]
        QA_monitor[K9s / K8S Dashboard]
        QA_test[測試]
        QA_expose[公開服務]
        QA_port_forwarding[port-forwarding]
        QA_cloudflare_tunnel[Cloudflare Tunnel]
        QA_ngrok[ngrok]

    end

    %% DevOps/Infra
    Ops_create_workspace--> Ops_create_local_k8s
    Ops_create_workspace--> Ops_add_remote_k8s
    Ops_create_local_k8s --> Ops_create_project
    Ops_add_remote_k8s --> Ops_create_project
    Ops_create_project --> Ops_pull_repo
    Ops_create_project --> Ops_create_local_repo
    Ops_pull_repo --> Ops_k8s_yaml
    Ops_create_local_repo --> Ops_k8s_yaml
    Ops_k8s_yaml --> Ops_shell_script
    Ops_shell_script --> Ops_deploy
    Ops_deploy --> Ops_Monitor
    Ops_Monitor --> Ops_cicd
    Ops_cicd --> Ops_git_push
    %% 公開服務
    Ops_deploy -.-> Ops_expose
    Ops_expose -.-> Ops_port_forwarding
    Ops_expose -.-> Ops_cloudflare_tunnel
    Ops_expose -.-> Ops_ngrok

    %% Developer
    Ops_git_push --> Dev_git_pull
    Dev_git_pull --> Dev_start_k8s
    %% K8S 開發環境
    Dev_start_k8s --> Dev_deploy
    Dev_deploy --> Dev_monitor
    Dev_deploy -.-> Dev_expose
    Dev_monitor --> Dev_debug_1
    %% 遠端除錯
    Dev_git_pull --> Dev_remote_debug
    Dev_remote_debug -->  Dev_telepresence
    Dev_telepresence --> Dev_connect_remote_k8s
    Dev_connect_remote_k8s --> Dev_telepresence_remote_pod
    Dev_telepresence_remote_pod --> Dev_debug_3
    %% 本地容器開發環境
    Dev_git_pull --> Dev_local_env
    Dev_local_env --> Dev_debug_2
    Dev_local_env -.-> Dev_expose
    %% 公開服務
    Dev_expose -.-> Dev_cloudflare_tunnel
    Dev_expose -.-> Dev_ngrok
    Dev_expose -.-> Dev_port_forwarding

    %% QA
    Ops_git_push --> QA_git_pull
    QA_git_pull --> QA_start_k8s
    QA_start_k8s --> QA_deploy
    QA_deploy --> QA_monitor
    QA_monitor --> QA_test
    QA_deploy -.-> QA_expose
    QA_expose -.-> QA_port_forwarding
    QA_expose -.-> QA_cloudflare_tunnel
    QA_expose -.-> QA_ngrok



```

## 安裝

1. **準備 Docker**
   - 必須先安裝 [Docker](https://docs.docker.com/engine/install/)。
2. **安裝 KDE-cli**
   ```bash
   git clone https://github.com/r82wei/KDE-cli.git
   cd KDE-cli
   sudo ./install.sh
   ```

## 快速開始

1. **啟動或加入 K8s 環境**
   - 在本地啟動 kind/k3d
     ```bash
     kde create <cluster-name> --kind    # 或 --k3d
     ```
   - 加入現有的 K8s 叢集
     ```bash
     kde create <cluster-name> --k8s
     ```
2. **新增專案（namespace）**
   ```bash
   # 將專案建立在 environment/<cluster-name>/namespaces/<project-name>，並且新增專案相關設定到 project.env
   kde project create <project-name>
   ```
3. **進入本地容器開發環境**

   - 可以將需要的環境變數定義在 project.env，啟動環境時會自動注入 container 環境內

   ```bash
   # 透過 project.env 自訂的 Docker image(DEVELOP_IMAGE) 啟動開發執行環境
   kde project exec <project-name> dev [port]

   # 透過 project.env 自訂的 Docker image(DEPLOY_IMAGE) 啟動部署執行環境
   kde project exec <project-name> dep [port]
   ```

4. **執行 CI/CD 部署**

   - 可以將**編譯**/**部署**需要的環境變數定義在 project.env，執行 CI/CD 時會自動注入 container 環境內
   - (如果檔案存在) 依序觸發 `pre-build.sh -> build.sh -> post-build.sh -> pre-deploy.sh -> deploy.sh -> post-deploy.sh`，每個 shell 可以在 project.env 自訂執行環境的 docker image
     - `pre-build.sh`: PRE_BUILD_IMAGE (預設: DEVELOP_IMAGE)
     - `build.sh`: BUILD_IMAGE (預設: DEVELOP_IMAGE)
     - `post-build.sh`: POST_BUILD_IMAGE (預設: DEVELOP_IMAGE)
     - `pre-deploy.sh`: PRE_DEPLOY_IMAGE (預設: DEPLOY_IMAGE)
     - `deploy.sh`: DEPLOY_IMAGE (預設: DEPLOY_IMAGE)
     - `post-deploy.sh`: POST_DEPLOY_IMAGE (預設: DEPLOY_IMAGE)

   ```bash
   kde project deploy <project-name>

   ```

5. **開啟 Dashboard 開發/除錯**

   ```bash
   # 文字介面，可在 IDE 的終端機使用
   # 如果指定 --port 30000-30020，就可以使用 K9S 的 Port forwarding 功能將 port 30000-30020 對應到本地
   kde k9s [--port]

   # Web UI，可加上 `--insecure` 跳過登入
   kde dashboard [--port] [--insecure]
   ```

6. **解除部署**

   - 可以將**解除部署**需要的環境變數定義在 project.env，啟動環境時會自動注入 container 環境內
   - (如果檔案存在) 觸發 `undeploy.sh`，可以在 project.env 自訂執行環境的 docker image
     - `undeploy.sh`: UNDEPLOY_IMAGE (預設: DEPLOY_IMAGE)
   - ⚠️ 如果檔案不存在，預設動作為刪除 K8S 環境內與專案名稱同名的 namespace

   ```bash
   kde project undeploy <project-name>
   ```

7. **查看或切換當前環境**

   ```bash
   # 取得目前使用的 cluster
   kde current

   # 切換當前使用的 K8s cluster
   kde use <cluster-name>
   ```

8. **查看全部 K8s 環境狀態**
   ```bash
   kde status
   ```

## 進階功能

- **遠端除錯 ([Telepresence](https://telepresence.io/docs/quick-start))**

  ```bash
  kde telepresence <command>
  ```

  - command
    - `replace` 攔截遠端 Pod 的流量到本地環境，並且停止 Pod 的運行
    - `intercept` 攔截遠端 Pod 的流量到本地環境，但不干擾遠端 Pod 的運行
    - `wiretap` 複製遠端 Pod 的流量副本到本地環境，但不干擾遠端 Pod 的運行
    - `ingest` 不攔截流量，也不干擾遠端 Pod 的運行，僅讓本地環境可以連線 k8s 環境內的服務

- **公開服務**

  ```bash
  # 本地 port forwarding
  kde expose

  # Ngrok
  kde ngrok <target>

  # Cloudflare Tunnel
  kde cloudflare-tunnel <domain> <target>
  ```

## 檔案結構

### kde-cli

```
kde.sh                    # 主腳本，連動 scripts/* 內的子指令 (安裝到 /usr/local/lib)
install.sh                # 安裝腳本
uninstall.sh              # 解除安裝腳本
dockerfiles/
  └─ <docker images>/       # kde-cli 使用的 docker image 相關檔案
scripts/                  # 各項指令的實作 (安裝到 /usr/local/lib)
  └─ <commands>/            # kde cli 指令邏輯
  └─ utils/                 # kde cli 功能函式
```

### kde-cli Artifacts (可版本化的環境設定)

```
environments/
  └─ <cluster-name>/      # K8S 環境
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

## 免責聲明

KDE-cli 整合了多個第三方工具與服務，其中部分服務（如 Ngrok, Cloudflare Tunnel, Telepresence）為商業公司所維護，並提供免費增值（Freemium）方案。

本工具僅作為自動化操作的框架，協助使用者更方便地啟用這些服務。所有使用者應自行了解並遵守這些第三方服務各自的服務條款與授權模式。

## 相關連結

- [k3d](https://k3d.io/stable/)
- [kind](https://kind.sigs.k8s.io/)
- [k9s](https://k9scli.io/)
- [Kubernetes Dashboard](https://github.com/kubernetes/dashboard)
- [Cloudflare Tunnel](https://developers.cloudflare.com/cloudflare-one/connections/connect-apps/)
- [Ngrok](https://ngrok.com/)
- [Telepresence](https://telepresence.io/docs/quick-start)
