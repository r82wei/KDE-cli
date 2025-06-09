# KDE-cli 開發者指南

KDE-cli 是一套針對 **Kubernetes 本地開發** 與 **部署** 流程優化的命令列工具。它利用 `Kind` 與 `K3d` 來快速建立多個 K8s 環境，並整合 CI/CD、Dashboard、以及服務對外公開等常用功能，目標是讓開發者輕鬆複製近似「雲端」的環境於本機。

## 功能總覽

- **環境管理**
  - 建立、啟動、停止、刪除及切換多個 K8s 叢集（可選擇 Kind 或 K3d）。
  - 連結或新增外部 K8s 叢集，統一管理不同環境。
- **專案管理**
  - 在 K8s 叢集下建立專案（對應 namespace），可從 Git 倉庫取得程式碼並自訂 Build/Deploy Image。
  - 提供 `build.sh`/`deploy.sh` 等腳本，使專案能用 CI/CD 流程快速建置與部署。
- **即時開發**
  - 將本機資料夾掛載至 K8s 的 Pod，支援 hot reload 或其他即時開發需求。
- **除錯與監控**
  - 內建 k9s 與 kubernetesui Dashboard，方便檢視 Pod 狀態、日誌和資源。
- **服務公開**
  - 除了本地 port forwarding，亦提供 Ngrok 與 Cloudflare Tunnel，能快速讓外部存取服務。

## 安裝

1. **準備 Docker**
   - 必須先安裝 Docker 與 Docker Compose。
2. **安裝 KDE-cli**
   ```bash
   git clone https://github.com/r82wei/KDE-cli.git
   cd KDE-cli
   sudo ./install.sh      # 需要 sudo 權限
   ```
   安裝完成後，可在任意目錄透過 `kde` 指令操作。

## 基本用法

1. **建立並啟動 K8s 環境**
   ```bash
   kde start <cluster-name> --kind    # 或 --k3d 或 --k8s
   ```
2. **新增專案（namespace）**
   ```bash
   kde project create <project-name>
   # 將自訂 Docker image 設定在 environment/<cluster-name>/namespaces/<project-name>/
   ```
3. **執行 CI/CD 部署**
   ```bash
   kde project deploy <project-name>
   # 依序觸發 build.sh、pre-deploy.sh、deploy.sh、post-deploy.sh（若檔案存在）
   ```
4. **查看或切換當前環境**
   ```bash
   kde current     # 取得目前使用的 cluster
   kde use <cluster-name>
   ```

## 進階功能

- **開啟 Dashboard**
  ```bash
  kde k9s                         # 文字介面
  kde dashboard [--insecure]      # Web UI
  ```
- **公開服務**
  ```bash
  kde expose <pod-name> <port>           # 本地 port forwarding
  kde ngrok <target>                     # Ngrok
  kde cloudflare-tunnel <domain> <target>  # Cloudflare Tunnel
  ```
- **管理多個專案**
  ```bash
  kde projects download      # 批次下載多個專案
  kde projects link          # 批次建立 symlink
  ```

## 目錄結構概念

```
environment/
  └─ <cluster-name>/
      └─ namespaces/
          └─ <project-name>/
              ├─ build.sh
              ├─ deploy.sh
              ├─ pre-deploy.sh
              ├─ post-deploy.sh
              └─ ...
kde.sh       # 主腳本，連動 scripts/* 內的子指令
scripts/      # 各項指令的實作
```

## 相關連結

- [k3d](https://k3d.io/stable/)
- [kind](https://kind.sigs.k8s.io/)
- [k9s](https://k9scli.io/)
- [Cloudflare Tunnel](https://developers.cloudflare.com/cloudflare-one/connections/connect-apps/)
- [Ngrok](https://ngrok.com/)
