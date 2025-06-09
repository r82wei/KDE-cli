# KDE-cli 開發者指南

KDE-cli 是一套針對 **Kubernetes 本地開發** 與 **部署** 流程優化的命令列工具。它利用 `Kind` 與 `K3d` 來快速建立多個 K8s 環境，並整合 CI/CD、Dashboard、以及服務對外公開等常用功能，目標是讓開發者輕鬆複製近似「正式」的環境於本機。

## 功能總覽

- **環境管理**
  - 建立、啟動、停止、刪除及切換多個 K8s 叢集（可選擇 Kind 或 K3d）。
  - 連結或新增外部 K8s 叢集，統一管理不同環境。
- **專案管理**
  - 在 K8s 叢集下建立專案（對應 namespace），可從 Git 倉庫取得程式碼並自訂 Devlop/Deploy 環境的 Image。
- **Container 即時開發**
  - 快速啟動 Devlop Image container 開發環境，支援 hot reload 或其他即時開發需求。
  - 快速啟動 Deploy Image container 部署測試環境。
- **K8s Pod 即時開發**
  - 建立與本機資料夾同名的 pv，即可將本機資料夾掛載至 K8s 的 Pod，支援 hot reload 或其他即時開發需求。
- **簡易且彈性的 CI/CD**
  - 提供 `build.sh`/`deploy.sh`/`undeploy.sh` 等腳本，使專案能用 CI/CD 流程快速建置與部署。
- **除錯與監控**
  - 內建 k9s 與 kubernetesui Dashboard，方便檢視 Pod 狀態、日誌和資源。
- **服務公開**
  - 除了本地 port forwarding，亦提供 Ngrok 與 Cloudflare Tunnel，能快速讓外部存取服務。

## 安裝

1. **準備 Docker**
   - 必須先安裝 Docker。
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
   kde start <cluster-name> --kind    # 或 --k3d 或 --k8s
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

5. **執行 CI/CD 解除部署**

   - 可以將**編譯**/**部署**需要的環境變數定義在 project.env，啟動環境時會自動注入 container 環境內

   ```bash
   # 觸發 undeploy.sh（若檔案存在）
   # undeploy.sh 將會在 project.env 定義的 DEPLOY_IMAGE container 內執行
   # 如果 undeploy.sh 不存在則執行 kubectl delete ns <project-name>
   kde project undeploy <project-name>
   ```

6. **查看或切換當前環境**

   ```bash
   kde current              # 取得目前使用的 cluster
   kde use <cluster-name>   # 切換當前使用的 K8s cluster
   ```

7. **查看全部 K8s 環境狀態**
   ```bash
   kde status
   ```

## 進階功能

- **開啟 Dashboard**
  ```bash
  kde k9s [--port]                          # 文字介面，可在 IDE 的終端機使用
  kde dashboard [--port] [--insecure]       # Web UI，可加上 `--insecure` 跳過登入
  ```
- **公開服務**
  ```bash
  kde expose                                # 本地 port forwarding
  kde ngrok <target>                        # Ngrok
  kde cloudflare-tunnel <domain> <target>   # Cloudflare Tunnel
  ```

## 目錄結構概念

```
environment/
  └─ <cluster-name>/
      └─ namespaces/
          └─ <project-name>/
              ├─ build.sh
              ├─ pre-deploy.sh
              ├─ deploy.sh
              ├─ post-deploy.sh
              ├─ undeploy.sh
              ├─ [repo]/
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
- [Cloudflare Tunnel](https://developers.cloudflare.com/cloudflare-one/connections/connect-apps/)
- [Ngrok](https://ngrok.com/)
