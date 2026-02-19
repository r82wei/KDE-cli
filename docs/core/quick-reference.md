# KDE-CLI 指令快速查詢

## 環境管理

### 基礎指令

```bash
# 初始化 KDE 環境
kde init

# 列出所有環境
kde list
kde ls

# 顯示當前環境
kde current
kde cur

# 顯示 KDE 版本
kde version
kde -v
```

### 環境生命週期

```bash
# 建立/啟動環境
kde start <env_name> [kind|k3d|k8s] [config]
kde create <env_name> [kind|k3d|k8s] [config]

# 停止環境
kde stop [env_name] [-f|--force]

# 重啟環境
kde restart [env_name] [-f|--force]

# 切換環境
kde use [env_name]

# 查看環境狀態
kde status [json]

# 移除環境
kde remove <env_name>
kde rm <env_name>

# 重置環境
kde reset [env_name]
```

### 環境選項說明

**環境類型**:
- `kind` - Kind 本地開發環境（預設）
- `k3d` / `k3s` - K3D 本地開發環境
- `k8s` - 外部 Kubernetes 環境

**範例**:
```bash
# 建立 Kind 環境
kde start dev-env kind
kde start dev-env --kind

# 建立 K3D 環境
kde start test-env k3d
kde start test-env --k3d

# 連接外部 K8s 環境
kde start prod-env k8s
kde start prod-env --k8s

# 使用自訂配置檔案
kde start custom-env kind ./custom-config.yaml
```

## 專案管理

### 基礎指令

```bash
# 列出專案
kde project list
kde project ls
kde proj ls
kde namespace ls
kde ns ls

# 建立專案
kde project create <project_name>
kde proj create <project_name>

# 刪除專案
kde project remove <project_name>
kde project rm <project_name>
kde proj rm <project_name>
```

### Git 整合

```bash
# 從 Git 抓取專案
kde project fetch <project_name> <git_url> <branch>
kde proj fetch <project_name> <git_url> <branch>

# 更新專案（git pull）
kde project pull [project_name]
kde proj pull [project_name]

# 強制重新抓取（刪除後重新 clone）
kde project pull [project_name] --force
kde project pull [project_name] -f
```

### 專案部署

```bash
# 執行 Pipeline（部署）
kde project pipeline [project_name]
kde project deploy [project_name]
kde proj deploy [project_name]

# Pipeline 進階選項
kde project pipeline <project_name> --from <step>    # 從特定步驟開始
kde project pipeline <project_name> --to <step>      # 執行到特定步驟
kde project pipeline <project_name> --only <step>    # 只執行特定步驟
kde project pipeline <project_name> --manual         # 執行手動步驟

# 解除部署
kde project undeploy <project_name>
kde proj undeploy <project_name>

# 重新部署（undeploy + pipeline）
kde project redeploy <project_name>
kde proj redeploy <project_name>
```

### 專案容器

```bash
# 進入開發容器（預設）
kde project exec <project_name>
kde project exec <project_name> develop
kde project exec <project_name> dev
kde proj exec <project_name>

# 進入部署容器
kde project exec <project_name> deploy
kde project exec <project_name> dep

# 指定端口
kde project exec <project_name> develop 3000
kde project exec <project_name> deploy 8080
```

### 專案監控

```bash
# 查看 Pod 日誌（預設 100 行）
kde project tail <project_name>
kde proj tail <project_name>

# 指定 Pod 和行數
kde project tail <project_name> <pod_name> [line_count]
kde proj tail <project_name> <pod_name> 200

# 列出專案的 Pods
kde project pod <project_name>

# 進入 Pod Shell
kde project pod-exec <project_name> [pod_name]
```

## 開發工具

### K9s 終端機管理工具

```bash
# 啟動 K9s
kde k9s

# 指定端口
kde k9s -p <port>
kde k9s --port <port>

# 指定 Namespace
kde k9s -n <namespace>
kde k9s --namespace <namespace>

# 組合使用
kde k9s -p 8080 -n myapp
```

**K9s 快捷鍵**:
- `1-9` - 切換資源視圖
- `d` - 描述資源
- `l` - 查看日誌
- `s` - 進入 Shell
- `e` - 編輯資源
- `Ctrl-K` - 刪除資源
- `q` - 返回上層
- `Ctrl-C` - 退出

### Headlamp K8S Web UI Dashboard

```bash
# 啟動 Headlamp（預設端口 4466）
kde headlamp

# 指定端口
kde headlamp -p <port>
kde headlamp --port <port>

# 背景執行
kde headlamp -d
kde headlamp -p 8080 -d
```

### K8S Dashboard Web UI

```bash
# 啟動 Dashboard（預設 HTTPS，端口 8443）
kde dashboard

# 指定端口
kde dashboard -p <port>
kde dashboard --port <port>

# 使用 HTTP（不安全模式）
kde dashboard --insecure
kde dashboard -p 8080 --insecure
```

### Code Server

```bash
# 啟動 Code Server（預設端口 8080）
kde code-server

# 指定端口
kde code-server -p <port>
kde code-server --port <port>

# 背景執行
kde code-server -d
kde code-server --daemon

# 組合使用
kde code-server -p 9090 -d
```

### 容器環境操作

```bash
# 進入 K8s 節點容器
kde exec [env_name]

# 載入 Docker 映像（Kind/K3D only）
kde load-image <image> [env_name]
```

### Port Forward

```bash
# 互動式選擇
kde expose

# 直接指定參數
kde expose <namespace> service <service_name> <target_port> <local_port>
kde expose <namespace> pod <pod_name> <target_port> <local_port>

# 背景執行
kde expose -d <namespace> service <service_name> <target_port> <local_port>

# 範例
kde expose myapp service myapp-svc 8080 3000
kde expose myapp pod myapp-pod 8080 3000
```

## 雲端代理工具

### Ngrok

```bash
# 連接到 Ingress
kde ngrok ingress

# 連接到 Service
kde ngrok service

# 連接到 Pod
kde ngrok pod

# 連接到自訂 URL
kde ngrok http://localhost:8080
kde ngrok http://192.168.1.100:3000
```

### Cloudflare Tunnel

```bash
# 快速模式（隨機網址，無需登入）
kde cloudflare-tunnel url -q
kde cloudflare-tunnel url --quick

# 自訂域名模式（需要 Cloudflare 帳號）
kde cloudflare-tunnel service -d myapp.example.com
kde cloudflare-tunnel service --domain myapp.example.com

# 連接到 Service
kde cloudflare-tunnel service -d <domain>
kde cloudflare-tunnel service -n <namespace> -s <service> -p <port>

# 連接到 Pod
kde cloudflare-tunnel pod -d <domain>
kde cloudflare-tunnel pod -n <namespace> --pod <pod_name> -p <port>

# 連接到自訂 URL
kde cloudflare-tunnel url -u http://localhost:8080
kde cloudflare-tunnel url -u http://192.168.1.1 -d myapp.example.com

# 指定 Docker 網路
kde cloudflare-tunnel url -u http://localhost:8080 --network host
```

**選項說明**:
- `-q, --quick` - 使用快速模式（隨機網址）
- `-d, --domain` - 指定自訂域名
- `-u, --url` - 指定目標 URL
- `-n, --namespace` - 指定 Namespace
- `-s, --service` - 指定 Service 名稱
- `--pod` - 指定 Pod 名稱
- `-p, --port` - 指定端口
- `--network` - 指定 Docker 網路

### Telepresence

```bash
# 列出連線狀態
kde telepresence list [namespace]

# Replace 模式（攔截流量 + 停止遠端 Pod）
kde telepresence replace [namespace] [workload]

# Intercept 模式（攔截流量 + 不停止遠端 Pod）
kde telepresence intercept [namespace] [workload]

# Wiretap 模式（複製流量 + 不攔截）
kde telepresence wiretap [namespace] [workload]

# Ingest 模式（僅連線 K8s 環境，不攔截流量）
kde telepresence ingest [namespace] [workload]

# 卸載代理程式
kde telepresence uninstall [namespace]

# 停止所有連線
kde telepresence clear
```

**模式說明**:
- **Replace**: 攔截流量並停止遠端 Pod 運行
- **Intercept**: 攔截流量但不停止遠端 Pod
- **Wiretap**: 複製流量但不攔截（觀察模式）
- **Ingest**: 僅連線環境，不攔截流量

## 其他工具

### Alias（Tmux 快捷方式）

```bash
# 建立 alias 到當前目錄
kde alias <name>

# 建立 alias 到指定目錄
kde alias <name> <path>

# 範例
kde alias workspace ~/projects/myworkspace
kde alias myproject
```

**注意**: 需要安裝 tmux 才能使用此功能

## 常用工作流程範例

### 快速開始開發環境

```bash
# 1. 初始化 KDE
kde init

# 2. 建立並啟動開發環境
kde start dev-env kind

# 3. 建立專案
kde project create myapp

# 4. 從 Git 抓取程式碼
kde project fetch myapp https://github.com/user/myapp.git main

# 5. 部署專案
kde project deploy myapp

# 6. 查看日誌
kde project tail myapp
```

### 本地開發與除錯

```bash
# 1. 進入開發容器
kde project exec myapp develop

# 2. 在容器中開發和測試
# （編輯程式碼、執行測試等）

# 3. 重新部署
kde project redeploy myapp

# 4. 查看運行狀態
kde k9s
```

### 多環境管理

```bash
# 建立多個環境
kde create dev-env kind
kde create test-env k3d
kde create staging-env k8s

# 列出所有環境
kde list

# 切換環境
kde use dev-env
kde use test-env

# 查看當前環境
kde current

# 查看所有環境狀態
kde status
```

### 外部存取設定

```bash
# 方式 1: 使用 Ngrok（快速測試）
kde ngrok service

# 方式 2: 使用 Cloudflare Tunnel（安全穩定）
kde cloudflare-tunnel service -d myapp.example.com

# 方式 3: Port Forward（本地存取）
kde expose myapp service myapp-svc 8080 3000

# 方式 4: 建立 Ingress
kde project ingress myapp
```

### Telepresence 本地開發

```bash
# 1. 啟動 Telepresence Intercept
kde telepresence intercept myapp myapp-deployment

# 2. 選擇要開發的專案
# （系統會顯示選單）

# 3. 系統自動進入開發容器
# （可以存取 K8s 環境內的所有服務）

# 4. 完成後停止連線
kde telepresence clear
```

### 專案集合部署

```bash
# 1. 從 Git 抓取專案集合
kde projects fetch https://github.com/user/projects.git main

# 2. 更新所有專案
kde projects pull

# 3. 連結專案
kde projects link

# 4. 進入專案集合環境
kde projects exec
```

## 環境變數

### 主要環境變數

```bash
KDE_PATH              # KDE 工作區根目錄
KDE_CLI_PATH          # KDE CLI 安裝目錄
KDE_SCRIPTS_PATH      # KDE 腳本目錄
ENVIROMENTS_PATH      # 環境目錄路徑
CUR_ENV               # 當前環境名稱
KUBECONFIG            # Kubernetes 配置檔案路徑
```

### 環境配置變數

```bash
ENV_NAME              # 環境名稱
ENV_TYPE              # 環境類型（kind/k3d/k8s）
K8S_CONTAINER_NAME    # K8s 容器名稱
DOCKER_NETWORK        # Docker 網路名稱
STORAGE_CLASS         # 儲存類別
```

### 映像環境變數

```bash
KIND_IMAGE                      # Kind 映像
K3D_IMAGE                       # K3D 映像
KDE_DEPLOY_ENV_IMAGE           # 部署環境映像
NGROK_PROXY_IMAGE              # Ngrok 代理映像
CLOUDFLARE_TUNNEL_PROXY_IMAGE  # Cloudflare Tunnel 映像
K8S_UI_DASHBOARD_IMAGE         # Dashboard 映像
K9S_IMAGE                      # K9s 映像
TELEPRESENCE_IMAGE             # Telepresence 映像
CODE_SERVER_IMAGE              # Code Server 映像
```

## 配置檔案結構

### 工作區根目錄

```
KDE_PATH/
├── kde.env           # 主要環境變數配置
├── current.env       # 當前環境配置
├── ngrok.env         # Ngrok 配置（可選）
├── environments/     # 環境目錄
└── docs/            # 文件目錄（kde init 後建立）
```

### 環境目錄結構

```
environments/<env_name>/
├── k8s.env              # 環境基本配置
├── .env                 # 環境本地配置
├── kubeconfig/          # Kubernetes 配置
│   └── config
├── kind-config.yaml     # Kind 配置（Kind 環境）
├── k3d-config.yaml      # K3D 配置（K3D 環境）
├── pki/                 # PKI 憑證目錄
└── namespaces/          # 專案目錄
    └── <project_name>/
        ├── project.env      # 專案配置
        ├── build.sh         # 建置腳本
        ├── deploy.sh        # 部署腳本
        ├── undeploy.sh      # 卸載腳本
        └── <repo_name>/     # Git 倉庫內容
```

### 專案配置檔案 (project.env)

```bash
GIT_REPO_URL=https://github.com/user/repo.git
GIT_REPO_BRANCH=main
DEVELOP_IMAGE=node:18
DEPLOY_IMAGE=r82wei/deploy-env:1.0.0
```

## 常見選項參數

### 通用選項

```bash
-h, --help          # 顯示說明
-v, --version       # 顯示版本
-f, --force         # 強制執行
-d, --daemon        # 背景執行
```

### 端口選項

```bash
-p, --port <port>   # 指定端口
--insecure          # 使用 HTTP 而非 HTTPS
```

### Namespace 選項

```bash
-n, --namespace <ns>  # 指定 Namespace
```

## 指令別名速查

### 環境管理別名

```bash
kde ls          → kde list
kde cur         → kde current
kde rm          → kde remove
```

### 專案管理別名

```bash
kde proj        → kde project
kde namespace   → kde project
kde ns          → kde project
kde projs       → kde projects
```

### 專案指令別名

```bash
kde proj ls     → kde project list
kde proj rm     → kde project remove
kde proj dep    → kde project deploy
```

## 故障排除

### 檢查環境狀態

```bash
# 查看所有環境狀態
kde status

# 查看當前環境
kde current

# 檢查 K8s 連線
kubectl get nodes
kubectl get pods -A
```

### 重啟環境

```bash
# 重啟當前環境
kde restart

# 重啟指定環境
kde restart <env_name>

# 強制停止後重啟
kde stop <env_name> --force
kde start <env_name>
```

### 環境清理

```bash
# 重置環境（保留 namespaces）
kde reset <env_name>

# 完全移除環境
kde remove <env_name>

# 清理 Docker 資源
docker system prune -a
```

### 查看日誌

```bash
# 查看專案 Pod 日誌
kde project tail <project_name>

# 查看特定 Pod 日誌
kubectl logs <pod_name> -n <namespace>

# 查看事件
kubectl get events -A
```

### 網路除錯

```bash
# 進入 K8s 節點容器
kde exec

# 檢查網路配置
ip addr
ip route

# 檢查 DNS
nslookup kubernetes.default
```

## 最佳實踐

### 命名慣例

- **環境名稱**: `dev-env`, `test-env`, `prod-env`
- **專案名稱**: 使用小寫字母和連字號（如 `my-app`, `api-service`）
- **映像標籤**: `dev`, `test`, `prod`

### 環境選擇

- **本地開發**: 使用 `kind` 或 `k3d`
- **測試環境**: 使用 `k3d`（較輕量）
- **生產環境**: 使用外部 `k8s`

### 開發工作流程

1. 使用 `kde project exec` 進入開發容器
2. 在容器內進行開發和測試
3. 使用 `kde project redeploy` 重新部署
4. 使用 `kde k9s` 或 `kde dashboard` 監控狀態

### 安全性建議

- 生產環境使用 HTTPS (Dashboard)
- 定期更新 Token 和憑證
- 限制 Dashboard 和工具的存取
- 使用 Cloudflare Tunnel 而非 Ngrok（生產環境）
- 妥善管理 `ngrok.env` 等敏感配置

### 效能優化

- 定期清理不需要的映像和容器
- 使用 `kde load-image` 預載常用映像
- 監控資源使用（`kubectl top nodes/pods`）
- 適當配置資源限制

## 快速參考卡片

### 環境管理
```bash
kde init                           # 初始化
kde start <env> [kind|k3d|k8s]    # 建立/啟動
kde use <env>                      # 切換
kde status                         # 查看狀態
kde rm <env>                       # 移除
```

### 專案管理
```bash
kde proj create <name>             # 建立專案
kde proj fetch <name> <url> <br>   # 抓取專案
kde proj deploy <name>             # 部署專案
kde proj exec <name>               # 進入容器
kde proj tail <name>               # 查看日誌
```

### 開發工具
```bash
kde k9s                           # 終端機管理
kde dashboard                     # Web UI
kde exec                          # 進入節點
kde expose                        # Port Forward
```

### 雲端代理
```bash
kde ngrok service                 # Ngrok
kde cloudflare-tunnel service     # Cloudflare
kde telepresence intercept        # Telepresence
```

## 進階主題

更多詳細資訊，請參考：

- [環境管理詳細指南](./environment-management.md)
- [專案管理詳細指南](./project-management.md)
- [開發工具詳細指南](./operations-tools.md)
- [雲端代理工具詳細指南](./cloud-proxy-tools.md)
- [CICD Pipeline 指南](./cicd-pipeline.md)
- [工作區管理](./workspace.md)
