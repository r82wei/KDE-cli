# DevOps 操作指引

本文件整理常用 DevOps 命令與操作方式，協助快速管理與部署專案。

## 環境管理

- `kde start <name>`：啟動或建立指定的 Kubernetes 環境，可搭配 `--k3d` 或 `--k8s`。
- `kde stop <name>`：停止環境。
- `kde restart <name>`：重新啟動環境。
- `kde status`：查看所有環境的狀態。
- `kde remove <name>`：刪除環境。
- `kde reset <name>`：重置環境資料夾，並詢問是否保留 namespaces。

### 載入 Docker Image

- `kde load-image <image> [env_name]`：將本地映像載入指定 K8s 環境。(Kind、K3d 適用)

### 自訂 Docker Image

- **dockerfiles/** 可自行建置 kde 環境所使用的 docker image
- **kde.env** 可指定 kde 環境使用的 docker image
- **environments/\<cluster-name\>/namespaces/\<project-name\>/project.env** 可指定 **開發(編譯)**/**部署** 所使用的 docker image

## 專案部署

### 腳本測試

- 可以將**編譯**/**部署**需要的環境變數定義在 project.env，啟動環境時會自動注入 container 環境內

- 透過下列指令啟動環境，測試編譯、部署腳本：

  ```bash
  # 透過 project.env 自訂的 Docker image(DEVELOP_IMAGE) 啟動編譯執行環境
  kde project exec <project-name> dev [port]

  # 透過 project.env 自訂的 Docker image(DEPLOY_IMAGE) 啟動部署執行環境
  kde project exec <project-name> dep [port]
  ```

### 專案部署

專案可在目錄內撰寫 `build.sh`、`pre-deploy.sh`、`deploy.sh`、`post-deploy.sh` 等腳本，透過下列指令自動執行編譯與部署流程：

```
kde project deploy <project_name>
```

依序執行 `build.sh`、`pre-deploy.sh`、`deploy.sh` 及 `post-deploy.sh`（若存在）。

## 服務公開

- `kde expose`：使用 port-forward 對外暴露服務。
- `kde ngrok <target>`：透過 Ngrok 公開服務。
- `kde cloudflare-tunnel <domain> <target>`：使用 Cloudflare Tunnel 建立公開網址。

## 監控工具

- `kde k9s [--port]`：開啟終端機版 K9s Dashboard。
- `kde dashboard [--port] [--insecure]`：啟動 Web UI Dashboard，可加上 `--insecure` 跳過登入。

## 其他常用指令

- `kde exec [env_name]`：進入 k8s node container。
- `kde project tail <project_name> [行數]`：追蹤專案 Pod 的 log。
