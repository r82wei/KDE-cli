# KDE CLI Documentation

This document provides a comprehensive guide to the KDE CLI tool, designed for quick understanding and integration into other projects, including `gemini-cli`.

## 1. Project Overview

KDE 是一個強大的 Kubernetes 環境建置與管理 CLI 工具，提供多種 K8s 環境（kind/k3d/外部）的自動化建置、專案管理、雲端代理等功能。

### 主要功能模組

- **環境管理**: 支援 Kind、K3d、外部 K8s 環境的建立、啟動、停止、重啟、刪除、切換和狀態監控。
- **專案管理**: 提供專案/命名空間的建立、部署、卸載，支援 Git 整合，以及專案集合的批量管理。
- **雲端代理與連線**: 整合 Cloudflare Tunnel、Ngrok、Telepresence 和 Port Forward，實現本地服務與 Kubernetes 環境的無縫對接。
- **運維工具**: 內建 K9s 終端機管理工具、Kubernetes Dashboard Web UI，並支援 Docker 映像載入到 K8s 環境。

### 核心指令架構

```bash
kde <command> [subcommand] [options] [arguments]
```

## 2. Installation and Setup

### 安裝

執行以下指令進行安裝：

```bash
./install.sh
```

### 環境變數

Kde 會在當前目錄���建立 `kde.env` 檔案來儲存預設的 Docker 映像檔設定。您也可以建立 `ngrok.env` 來設定 ngrok 的認證權杖。

- `KIND_IMAGE`: Kind 環境使用的映像檔。
- `K3D_IMAGE`: K3d 環境使用的映像檔。
- `KDE_DEPLOY_ENV_IMAGE`: 用於部署的環境映像檔。
- `NGROK_PROXY_IMAGE`: ngrok 代理使用的映像檔。
- `CLOUDFLARE_TUNNEL_PROXY_IMAGE`: Cloudflare Tunnel 代理使用的映像檔。
- `K8S_UI_DASHBOARD_IMAGE`: Kubernetes Dashboard 使用的映像檔。
- `K9S_IMAGE`: k9s 使用的映像檔。
- `TELEPRESENCE_IMAGE`: Telepresence 使用的映像檔。
- `NGROK_TOKEN`: (在 `ngrok.env` 中設定) 您的 ngrok 認證權杖。

## 3. Environment Management

### 環境類型

- **Kind 環境**: 用於本地開發和測試，輕量級、快速啟動，使用 Docker 容器模擬 K8s 節點。
  - 指令: `kde start <env_name> kind` 或 `kde start <env_name> --kind`
- **K3D 環境**: 用於本地開發和測試，基於 K3s、輕量級、快速啟動，使用 Docker 容器運行 K3s。
  - 指令: `kde start <env_name> k3d` 或 `kde start <env_name> --k3d`
- **外部 K8s 環境**: 連接到現有的 K8s 集群，需要提供 kubeconfig 檔案。
  - 指令: `kde start <env_name> k8s` 或 `kde start <env_name> --k8s`

### 環境管理指令詳解

- **建立與啟動環境**:
  ```bash
  kde start <env_name> [kind|k3d|k8s] [config_path]
  # 範例: kde start my-dev kind
  ```
- **環境狀態管理**:
  ```bash
  kde list # 或 kde ls
  kde status
  kde use <env_name> # 或 kde use (互動式選擇)
  kde current # 或 kde cur
  ```
- **環境生命週期管理**:
  ```bash
  kde stop [env_name] [-f|--force]
  kde restart [env_name]
  kde remove <env_name> # 或 kde rm <env_name>
  kde reset [env_name]
  ```
- **映像管理**:
  ```bash
  kde load-image <image> [env_name]
  # 範例: kde load-image myapp:latest my-dev
  ```

### 環境配置檔案

環境配置位於 `environments/<env_name>/` 目錄下，包含 `k8s.env` (基本配置)、`.env` (本地配置)、`kubeconfig/config` (K8s 配置檔案) 等。

## 4. Project Management

### 專案結構

專案位於 `environments/<env_name>/namespaces/<project_name>/`，包含 `project.env` (專案配置)、`build.sh`、`deploy.sh` 等腳本，以及 Git 倉庫內容。

### 專案管理指令

- **基本專案操作**:
  ```bash
  kde project list # 或 kde project ls, kde proj ls, kde namespace ls, kde ns ls
  kde project create <project_name>
  kde project remove <project_name> # 或 kde project rm <project_name>
  ```
- **Git 整合操作**:
  ```bash
  kde project fetch <project_name> <git_url> <branch>
  kde project pull <project_name>
  # 範例: kde project fetch myapp https://github.com/user/myapp.git main
  ```
- **專案部署操作**:
  ```bash
  kde project deploy <project_name>
  kde project undeploy <project_name>
  kde project redeploy <project_name>
  ```
- **專案容器操作**:
  ```bash
  kde project exec <project_name> [develop|dev] [port]
  kde project exec <project_name> [deploy|dep] [port]
  # 範例: kde project exec myapp develop 3000
  ```
- **專案監控操作**:
  ```bash
  kde project tail <project_name> [pod_name] [line_count]
  # 範例: kde project tail myapp myapp-pod 100
  ```
- **專案網路操作**:
  ```bash
  kde project ingress <project_name>
  kde project link <project_name>
  ```

### 專案集合管理

- **專案集合操作**:
  ```bash
  kde projects fetch <git_url> <branch>
  kde projects pull
  kde projects link
  kde projects exec
  ```

## 5. Cloud Proxy and Connection Tools

- **Ngrok**:
  ```bash
  kde ngrok <target> # target 可以是 ingress, service, pod, 或 URL
  # 範例: kde ngrok http://localhost:8080
  ```
- **Cloudflare Tunnel**:
  ```bash
  kde cloudflare-tunnel <domain> <target>
  ```
- **Telepresence**:
  ```bash
  kde telepresence <command> [namespace] [workload]
  # command 可以是 list, replace, intercept, wiretap, ingest, uninstall, clear
  # 範例: kde telepresence intercept my-namespace my-service
  ```
- **Port Forward**:
  ```bash
  kde expose
  ```

## 6. Operations Tools

- **K9s**:
  ```bash
  kde k9s [-p port]
  ```
- **Kubernetes Dashboard**:
  ```bash
  kde dashboard [-p port] [--insecure]
  ```
- **Exec**: 進入 Kubernetes 節點的容器環境。
  ```bash
  kde exec [name]
  ```
- **Load Image**: 將 Docker 映像檔載入到指定的 Kubernetes 環境。
  ```bash
  kde load-image <image> [env_name]
  ```

## 7. Quick Reference

### 環境管理

- `kde list` 或 `kde ls`: 列出所有可用的 Kubernetes 環境。
- `kde start <env_name> [kind|k3d|k8s]`: 建立並啟動一個新的 Kubernetes 環境。預設使用 Kind。
- `kde stop [env_name]`: 停止指定的 Kubernetes 環境。
- `kde restart [env_name]`: 重新啟動指定的 Kubernetes 環境。
- `kde remove <env_name>` 或 `kde rm <env_name>`: 移除指定的 Kubernetes 環境。
- `kde status`: 顯示所有環境的狀態。
- `kde current` 或 `kde cur`: 顯示當前正在使用的環境。
- `kde use [env_name]`: 切換到指定的環境。
- `kde reset`: 重置當前環境，清除所有資料。

### 專案管理

- `kde project <command>`: 管理單一專案 (namespace)。
    - `list`, `ls`: 列出專案。
    - `create`: 建立新專案。
    - `link`: 連結現有專案。
    - `fetch`: 從 Git URL 抓取專案。
    - `pull`: 從 `project.env` 中的 Git repo 設定重新抓取專案。
    - `deploy`: 部署專案。
    - `undeploy`: 卸載專案。
    - `redeploy`: 重新部署專案。
    - `tail`: 查看 Pod 的日誌。
    - `remove`, `rm`: 刪除專案。
    - `exec`: 進入專案的容器環境。
    - `ingress`: 建立 ingress。
- `kde projects <command>`: 管理專案集合。
    - `fetch`: 從 Git URL 抓取專案集合。
    - `pull`: 拉取專案集合中的所有專案。
    - `link`: 連結專案集合。

### 工具整合

- `kde k9s [-p port]`: 啟動 k9s 儀表板。
- `kde dashboard [-p port] [--insecure]`: 啟動 Kubernetes Web UI 儀表板。
- `kde ngrok <target>`: 使用 ngrok 建立通道。
    - `ingress`: 連接到 ingress。
    - `service`: 連接到 service。
    - `pod`: 連接到 pod。
    - `[url]`: 連接到指定的 URL。
- `kde cloudflare-tunnel <domain> <target>`: 使用 Cloudflare Tunnel 建立通道。
- `kde telepresence <command>`: 使用 Telepresence 連接到 Kubernetes 環境。
    - `list`: 列出連線狀態。
    - `replace`: 攔截流量並取代遠端 Pod。
    - `intercept`: 攔截流量但不影響遠端 Pod。
    - `wiretap`: 複製流量到本地。
    - `ingest`: 僅連接到 Kubernetes 環境。
    - `uninstall`: 卸載 Telepresence 代理。
    - `clear`: 停止所有 Telepresence 連線。

### 其他輔助指令

- `kde load-image <image> [env_name]`: 將 Docker 映像檔載入到指定的 Kubernetes 環境。
- `kde exec [name]`: 進入 Kubernetes 節點的容器環境。
- `kde expose`: 將 Pod 或 Service 的連接埠轉發到本機。

## 8. Troubleshooting

### 常見問題

1.  **環境啟動失敗**
    *   檢查 Docker 是否運行
    *   檢查端口是否被佔用
    *   檢查磁碟空間是否充足
2.  **環境切換失敗**
    *   檢查環境是否存在
    *   檢查環境配置檔案是否完整
    *   檢查 kubeconfig 是否有效
3.  **映像載入失敗**
    *   檢查映像是否存在
    *   檢查環境是否正在運行
    *   檢查網路連線
4.  **專案建立失敗**
    *   檢查專案名稱是否有效
    *   檢查 Git 倉庫 URL 是否正確
    *   檢查網路連線
5.  **部署失敗**
    *   檢查 K8s 環境是否正常
    *   檢查部署腳本是否正確
    *   查看部署日誌
6.  **容器執行失敗**
    *   檢查映像是否存在
    *   檢查容器配置是否正確
    *   查看容器日誌

### 除錯指令

- **環境相關**:
  ```bash
  kde status
  cat environments/<env_name>/k8s.env
  kubectl config view
  docker ps -a | grep <env_name>
  ```
- **專案相關**:
  ```bash
  kde project list
  cat environments/<env_name>/namespaces/<project_name>/project.env
  kubectl get pods -n <project_name>
  kubectl logs -n <project_name> <pod_name>
  ```
