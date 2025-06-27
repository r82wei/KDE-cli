# KDE-cli (Kubernetes Development Environment)

KDE-cli 是一套結合 **Kubernetes 開發環境** 與 **CI/CD 部署流程** 的命令列工具，目標是讓開發者可以在本地快速建構、開發與部署多個專案、測試 CI/CD pipeline 以及驗證 yaml 設定。

## 🔑 主要功能

- ⚙️ `多種 K8s 環境支持`
  - [kind](https://kind.sigs.k8s.io/): Docker 中的 Kubernetes 集群 (預設)
  - [k3d](https://k3d.io/stable/): 輕量級 K3s 集群
  - 外部 K8s: 連接現有的 Kubernetes 集群
- 📦 `IaC 化的環境設定`
  - 開發環境設定檔可透過 git 版本化
  - 團隊同步的標準化開發環境
- 🧑🏻‍💻 `即時開發`
  - 快速啟動容器化開發環境 (各專案可自訂開發和部署的 image)
  - 透過 telepresence ，讓開發者可以用本地容器環境取代遠端 K8s 上的服務，加速開發與測試，不需每次變更都需要等待 CI/CD
  - 透過 k8s yaml 部署到本地環境，只需建立 PVC，即可掛載本地專案原始碼資料夾到 Pod 內進行開發，模擬實際執行環境（僅支援 Kind、K3d 環境）
- 🚀 `簡易且彈性的 CI/CD`
  - 提供 `build.sh`/`deploy.sh`/`undeploy.sh` 等自動化部署腳本，可以透過 project.env 自訂 pipeline 環境變數
  - 支援所有 CD 工具(可自訂 Deploy 環境 image)
  - 快速驗證 CI/CD pipeline
- 📊 `監控和管理工具`
  - [k9s](https://k9scli.io/): 終端 Kubernetes 管理界面，方便在 IDE 開發除錯
  - [Kubernetes Dashboard](https://github.com/kubernetes/dashboard): Web UI 管理界面
- 🌐 `公開服務`
  - Ngrok 整合: 將本地服務暴露到外網
  - Cloudflare Tunnel: 通過 Cloudflare 建立安全隧道
  - Port Forward: 將 K8s 服務/Pod 端口轉發到本地
- 🐳 `完全容器化`
  - 所有操作都在 Docker 容器中執行
  - 隔離的開發環境，支持多個專案同時開發
  - 只需安裝 Docker 就可以複製一致的開發環境

## 安裝

1. **準備 Docker**
   - 必須先安裝 [Docker](https://docs.docker.com/engine/install/)。
2. **安裝 KDE-cli**
   ```bash
   git clone https://github.com/r82wei/KDE-cli.git
   cd KDE-cli
   sudo ./install.sh
   ```
   安裝完成後，可在任意目錄透過 `kde` 指令操作。

## 基本用法

1. **建立並啟動 K8s 環境**
   ```bash
   kde create <cluster-name> --kind    # 或 --k3d 或 --k8s
   ```
2. **新增專案（namespace）**
   ```bash
   # 將專案建立在 environment/<cluster-name>/namespaces/<project-name>，並且新增專案相關設定到 project.env
   kde project create <project-name>
   ```
3. **快速啟動開發/部署環境**

   - 可以將**開發**/**部署**需要的環境變數定義在 project.env，啟動環境時會自動注入 container 環境內

   ```bash
   # 透過 project.env 自訂的 Docker image(DEVELOP_IMAGE) 啟動開發執行環境
   kde project exec <project-name> dev [port]

   # 透過 project.env 自訂的 Docker image(DEPLOY_IMAGE) 啟動部署執行環境
   kde project exec <project-name> dep [port]
   ```

4. **執行 CI/CD 部署**

   - 可以將**編譯**/**部署**需要的環境變數定義在 project.env，執行 CI/CD 時會自動注入 container 環境內

   ```bash
   # 依序觸發 build.sh、pre-deploy.sh、deploy.sh、post-deploy.sh（若檔案存在）
   # build.sh 將會在 project.env 定義的 DEVELOP_IMAGE container 內執行
   # pre-deploy.sh、deploy.sh、post-deploy.sh 將會在 project.env 定義的 DEPLOY_IMAGE container 內執行
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

   - 可以將**編譯**/**部署**需要的環境變數定義在 project.env，啟動環境時會自動注入 container 環境內

   ```bash
   # 觸發 undeploy.sh（若檔案存在）
   # undeploy.sh 將會在 project.env 定義的 DEPLOY_IMAGE container 內執行
   # 如果 undeploy.sh 不存在則執行 kubectl delete ns <project-name>
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

- **將遠端環境流量導流到本地容器環境開發/測試 (Telepresence)**

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

## 目錄結構概念

```
environments/
  └─ <cluster-name>/      # K8S 環境
      └─ namespaces/
          └─ <project-name>/      # 專案名稱(K8S namespace 名稱)
              ├─ project.env      # 專案設定檔(包含專案 Repo、開發/部署環境 image 設定，可增加自訂環境變數)
              ├─ build.sh         # CI 執行腳本，會在 DEVELOP_IMAGE 啟動的容器中執行 (optional)
              ├─ pre-deploy.sh    # CD 前置腳本，會在 DEPLOY_IMAGE 啟動的容器中執行 (optional)
              ├─ deploy.sh        # CD 執行腳本，會在 DEPLOY_IMAGE 啟動的容器中執行 (optional)
              ├─ post-deploy.sh   # CD 後置腳本，會在 DEPLOY_IMAGE 啟動的容器中執行 (optional)
              ├─ undeploy.sh      # 解除部署指令，會在 DEPLOY_IMAGE 啟動的容器中執行 (optional，如果不存在，預設動作為刪除 K8S 環境內與專案名稱同名的 namespace)
              ├─ [repo]/          # 專案 git repo
              ├─ [pvc dir]/       # PVC 掛載的資料夾 (StroageClass: local-path)
              └─ ...

current.env  # 當前使用的 K8s 環境
kde.env      # kde 開發環境使用的 docker image
kde.sh       # 主腳本，連動 scripts/* 內的子指令 (安裝到 /usr/local/lib)
scripts/     # 各項指令的實作 (安裝到 /usr/local/lib)
```

## 相關連結

- [k3d](https://k3d.io/stable/)
- [kind](https://kind.sigs.k8s.io/)
- [k9s](https://k9scli.io/)
- [Kubernetes Dashboard](https://github.com/kubernetes/dashboard)
- [Cloudflare Tunnel](https://developers.cloudflare.com/cloudflare-one/connections/connect-apps/)
- [Ngrok](https://ngrok.com/)
- [Telepresence](https://telepresence.io/docs/quick-start)
