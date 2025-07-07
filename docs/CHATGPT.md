# KDE-cli 快速指南

此文件為 Codex 與 ChatGPT 在操作本專案時的參考速查。KDE-cli 提供在本地或遠端 Kubernetes 環境中快速建立、開發並驗證 CI/CD 流程的工具。以下整理常見指令與功能，協助你快速上手。

## 安裝
```bash
# 取得程式碼並安裝
git clone https://github.com/r82wei/KDE-cli.git
cd KDE-cli
sudo ./install.sh
```
安裝後即可於任意資料夾透過 `kde` 指令操作。

## 環境管理
- 列出已建立的環境：`kde list`
- 建立並啟動環境：
  ```bash
  kde create <cluster-name> --kind   # 或 --k3d / --k8s
  ```
- 快速啟動並進入 K9s：
  ```bash
  kde start <cluster-name> [--kind|--k3d|--k8s]
  ```
- 停止或重啟環境：`kde stop <name>`、`kde restart <name>`
- 刪除或重置環境：`kde remove <name>`、`kde reset <name>`
- 切換環境：`kde use <name>`，顯示當前環境：`kde current`
- 查看狀態：`kde status`
- 載入本地映像：`kde load-image <image> [env_name]`
- 進入 node 容器：`kde exec [env_name]`

## 專案管理
- 建立專案（namespace）：
  ```bash
  kde project create <project-name>
  ```
  專案會位於 `environments/<cluster>/namespaces/<project>/`，並生成 `project.env` 供後續設定。
- 從 Git 抓取或更新程式碼：
  ```bash
  kde project fetch <project-name> <git-url> <branch>
  kde project pull <project-name>
  ```
- 列出或連結專案：`kde project list`、`kde project link <name>`
- 進入開發或部署容器：
  ```bash
  kde project exec <project-name> dev [port]   # 使用 DEVELOP_IMAGE
  kde project exec <project-name> dep [port]   # 使用 DEPLOY_IMAGE
  ```
- 部署與解除部署：
  ```bash
  kde project deploy <project-name>
  kde project undeploy <project-name>
  ```
- 建立 Ingress：`kde project ingress <project-name>`
  依序執行 `build.sh`、`pre-deploy.sh`、`deploy.sh`、`post-deploy.sh`（若存在）。

## CI/CD
在專案目錄中撰寫下列腳本即可觸發完整流程：
- `pre-build.sh`、`build.sh`、`post-build.sh` – 編譯流程，於 `DEVELOP_IMAGE` 容器執行。
- `pre-deploy.sh`、`deploy.sh`、`post-deploy.sh` – 部署流程，於 `DEPLOY_IMAGE` 容器執行。

執行 `kde project deploy <project-name>` 會自動依序執行上述腳本；`kde project undeploy <project-name>` 則會呼叫 `undeploy.sh`（若存在）或刪除 namespace。

## 除錯與監控
- **K9s 文字介面**：`kde k9s [--port]`
- **Kubernetes Dashboard**：`kde dashboard [--port] [--insecure]`
- **查看 Pod 日誌**：`kde project tail <project-name> [行數]`

## 服務公開與連線
- 本地 port-forward：`kde expose`
- Ngrok：`kde ngrok <target>`
- Cloudflare Tunnel：`kde cloudflare-tunnel <domain> <target>`
- Telepresence：`kde telepresence <command> [namespace] [workload]`
   - `replace` 停止目標 Pod 並把流量攔截到本地
   - `intercept` 導流到本地但不中斷目標 Pod
   - `wiretap` 僅複製流量到本地，不影響目標 Pod
   - `ingest` 只建立連線，不攔截流量
   - `list` 查看目前連線狀態
   - `uninstall` 移除指定 namespace 的代理程式
   - `clear` 中斷所有 Telepresence 連線

## 目錄結構概念
```
environments/
  └─ <cluster-name>/
      └─ namespaces/
          └─ <project-name>/
              ├─ project.env
              ├─ build.sh / deploy.sh / ...
              └─ [repo]/               # 專案原始碼
current.env  # 目前使用中的 cluster
kde.env      # kde 環境使用的 Docker image
kde.sh       # 主程式入口
```

## 相關文件
若需更詳細的功能說明與範例，可參考專案根目錄的 `README.md`、`developer.md`、`devops.md` 與 `GEMINI.md`。
