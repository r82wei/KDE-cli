# KDE-CLI 完整指令速查

## 環境管理

```bash
# 初始化
kde init

# 建立/啟動環境
kde start <env_name> [kind|k3d|k8s] [config_file]
kde create <env_name> [kind|k3d|k8s]

# 切換環境
kde use [env_name]            # 不指定則互動式選擇

# 查看環境
kde current / kde cur         # 當前環境
kde list / kde ls             # 所有環境
kde status [json]             # 環境狀態

# 環境生命週期
kde stop [env_name] [-f]      # 停止
kde restart [env_name] [-f]   # 重啟（執行 init.sh）
kde reset [env_name]          # 重置（保留 namespaces，重建集群）
kde remove <env_name>         # 移除
kde rm <env_name>             # 移除（別名）

# 進入 K8s 節點容器
kde exec [env_name]

# 載入映像（kind/k3d only）
kde load-image <image> [env_name]

# 版本
kde version / kde -v
```

## 專案管理

```bash
# 別名：kde project = kde proj = kde namespace = kde ns

# 列出專案
kde proj list / kde proj ls

# 建立專案（互動式，會詢問 Git URL / 映像 / Pipeline 配置）
kde proj create <project_name>

# Git 操作
kde proj fetch <name> <git_url> <branch>    # Clone
kde proj pull [name] [--force|-f]            # git pull 或強制重新 clone

# 部署
kde proj pipeline <name> [options]           # 執行 Pipeline
kde proj deploy <name> [options]             # 同上（別名）
kde proj undeploy <name>                     # 卸載（執行 undeploy.sh）
kde proj redeploy <name>                     # undeploy + pipeline

# Pipeline 選項
#   --from <stage>     從指定階段開始
#   --to <stage>       執行到指定階段
#   --only <stage>     只執行單一階段
#   --manual           進入容器手動模式

# 進入容器
kde proj exec <name>                         # 進入開發容器（使用 DEVELOP_IMAGE）
kde proj exec <name> develop [port]          # 同上
kde proj exec <name> dev [port]              # 同上
kde proj exec <name> deploy [port]           # 進入部署容器（使用 DEPLOY_IMAGE，含 kubectl/helm）
kde proj exec <name> dep [port]              # 同上

# 日誌
kde proj tail [name]                         # 查看 Pod 日誌（預設 100 行）
kde proj tail <name> <pod_name> [lines]      # 指定 Pod 和行數

# Pod 管理
kde proj pod <name>                          # 列出 Pod
kde proj pod-exec <name> [pod_name]          # 進入 Pod Shell

# 網路
kde proj ingress <name>                      # 互動式建立 Ingress
kde proj link <name>                         # 建立軟連結到專案目錄

# 刪除
kde proj remove <name> / kde proj rm <name>
```

## K9s

```bash
kde k9s                                # 啟動（使用當前 KUBECONFIG）
kde k9s -n <namespace>                 # 指定 Namespace
kde k9s -p <port>                      # 指定端口

# K9s 快捷鍵
# :namespace  → 切換 Namespace 視圖
# 1-9         → 切換資源視圖（1=Pods, 2=Deployments...）
# d           → describe 資源
# l           → 查看日誌
# s           → 進入 Pod Shell
# e           → 編輯資源
# Ctrl-K      → 刪除資源
# q           → 返回上層
# Ctrl-C      → 退出
# ?           → 顯示所有快捷鍵
```

## Headlamp（Web UI）

```bash
kde headlamp                           # 啟動（預設端口 4466）
kde headlamp -p <port>                 # 指定端口
kde headlamp -d                        # 背景執行
# 存取：http://localhost:4466
```

## K8s Dashboard

```bash
kde dashboard                          # 啟動（HTTPS，預設 8443）
kde dashboard -p <port>
kde dashboard --insecure               # HTTP 模式
```

## Code Server（Web VSCode）

```bash
kde code-server                        # 啟動（預設端口 8080）
kde code-server -p <port>
kde code-server -d / --daemon          # 背景執行
```

## Port Forward

```bash
kde expose                             # 互動式選擇
kde expose <namespace> service <service_name> <target_port> <local_port>
kde expose <namespace> pod <pod_name> <target_port> <local_port>
kde expose -d <namespace> service <svc> <target> <local>  # 背景執行

# 範例
kde expose myapp service myapp-svc 8080 3000
kde expose myapp pod myapp-pod-xxx 8080 3000
```

## Telepresence

```bash
# 模式說明：
# replace   - 攔截流量 + 停止遠端 Pod（完全本地開發）
# intercept - 攔截流量（遠端 Pod 仍運行）
# wiretap   - 複製流量（觀察模式，不攔截）
# ingest    - 僅連線 K8s 環境（不攔截流量）

kde telepresence replace [namespace] [workload]
kde telepresence intercept [namespace] [workload]
kde telepresence wiretap [namespace] [workload]
kde telepresence ingest [namespace] [workload]

kde telepresence list [namespace]          # 查看連線狀態
kde telepresence uninstall [namespace]     # 卸載代理程式
kde telepresence clear                     # 停止所有連線
```

## Ngrok

```bash
kde ngrok ingress          # 連接到 Ingress（互動式選擇）
kde ngrok service          # 連接到 Service（互動式選擇）
kde ngrok pod              # 連接到 Pod（互動式選擇）
kde ngrok http://localhost:8080   # 直接指定 URL
```

## Cloudflare Tunnel

```bash
# 選項說明：
# -q, --quick       快速模式（隨機網址，無需帳號）
# -d, --domain      指定自訂域名（需要 Cloudflare 帳號）
# -u, --url         指定目標 URL
# -n, --namespace   指定 Namespace
# -s, --service     指定 Service 名稱
# --pod             指定 Pod 名稱
# -p, --port        指定端口

kde cloudflare-tunnel service -d myapp.example.com     # 自訂域名
kde cloudflare-tunnel service -q                        # 快速隨機網址
kde cloudflare-tunnel service -n myapp -s myapp-svc -p 8080
kde cloudflare-tunnel pod -d myapp.example.com
kde cloudflare-tunnel url -u http://localhost:8080
kde cloudflare-tunnel url -u http://localhost:8080 -d myapp.example.com
kde cloudflare-tunnel url -u http://localhost:8080 --network host
```

## Tmux Alias（需安裝 tmux）

```bash
kde alias <name>           # 建立 alias 到當前目錄
kde alias <name> <path>    # 建立 alias 到指定目錄
```

## 通用選項

```bash
-h, --help          # 顯示說明
-v, --version       # 顯示版本
-f, --force         # 強制執行
-d, --daemon        # 背景執行
-p, --port <port>   # 指定端口
-n, --namespace <ns># 指定 Namespace
--insecure          # 使用 HTTP
```

## 指令別名速查

```bash
kde ls          = kde list
kde cur         = kde current
kde rm          = kde remove
kde proj        = kde project = kde namespace = kde ns
kde proj ls     = kde project list
kde proj rm     = kde project remove
kde proj dep    = kde project deploy
kde proj deploy = kde project pipeline
```

## 重要環境變數

```bash
# KDE 系統變數（在容器和腳本中可用）
KDE_PATH              # workspace 根目錄
KDE_CLI_PATH          # KDE CLI 安裝目錄
ENVIROMENTS_PATH      # environments/ 目錄路徑
CUR_ENV               # 當前環境名稱
KUBECONFIG            # K8s 配置路徑
PROJECT_PATH          # 當前專案路徑

# 環境配置（k8s.env）
ENV_NAME              # 環境名稱
ENV_TYPE              # kind / k3d / k8s
K8S_CONTAINER_NAME    # K8s 容器名稱
DOCKER_NETWORK        # Docker 網路名稱
STORAGE_CLASS         # 儲存類別（local-path）

# 全域工具映像（kde.env）
KIND_IMAGE                      # Kind 映像
K3D_IMAGE                       # K3D 映像
KDE_DEPLOY_ENV_IMAGE            # 部署環境映像（預設 DEPLOY_IMAGE）
K9S_IMAGE                       # K9s 映像
HEADLAMP_IMAGE                  # Headlamp 映像
K8S_UI_DASHBOARD_IMAGE          # Dashboard 映像
TELEPRESENCE_IMAGE              # Telepresence 映像
CODE_SERVER_IMAGE               # Code Server 映像
NGROK_PROXY_IMAGE               # Ngrok 映像
CLOUDFLARE_TUNNEL_PROXY_IMAGE   # Cloudflare Tunnel 映像
KDE_DEBUG                       # true = 啟用除錯模式
```
