# 核心概念

## 全局

### 只需要安裝 docker 就可以執行所有東西 (All in container)

### 環境一致、可攜、共享，並且模擬接近正式的環境、CICD pipeline

- 產生的環境、專案設定可以透過 git 版本化，並且讓所有人共同協作或是分工維護 SDLC。
- 透過容器化執行環境，確保所有人的環境一致
- pv 掛載本地資料夾可以直接打包、複製、移轉到所有人的電腦，保持資料一致性

### 配置分層管理，從全局到專案逐層覆蓋

- **第一層 kde.env**: 全局配置，包含 KDE 路徑、預設映像版本、工具映像等
- **第二層 current.env**: 當前使用的環境名稱，用於快速切換環境
- **第三層 k8s.env**: 環境級配置，每個 K8S 環境獨立的設定
- **第四層 project.env**: 專案級配置，包含 Git 倉庫、映像、建置/部署腳本等

### 自動環境搜尋機制，無需手動設定路徑

- 從當前目錄往上搜尋 kde.env 檔案，自動定位 KDE 根目錄
- 支援在任意子目錄執行 kde 指令，保持操作一致性

### Debug 模式支援

- 透過 KDE_DEBUG 環境變數啟用除錯模式
- 除錯模式會顯示所有執行的 shell 指令 (set -x)

## 環境 (K8S)

### 環境指的是 K8S 環境，包含 本地(kind、k3d)、雲端 K8S(EKS、GKE、LKE、AKS)、地端自建 (On-premises)

### 可以建立 k8s 環境(kind、k3d、terraform、ansible)，也可以連結現有 k8s 環境(透過 kubeconfig)

### 環境權限基於 K8S RBAC (kubeconfig)

### 環境狀態有三個階段：存在 -> 初始化 -> 運行

- **存在 (Exist)**: 環境目錄已建立，k8s.env 檔案存在
- **初始化 (Init)**: kubeconfig 已產生，環境可被使用
- **運行 (Running)**: K8S 節點處於 Ready 狀態，可正常使用

### 環境切換機制，透過 current.env 記錄當前環境

- 使用 `kde use` 切換環境，自動更新 current.env
- 所有指令預設操作當前環境，也可透過參數指定特定環境

### 標準化映像管理，統一工具版本

- KIND_IMAGE: Kind 環境映像
- K3D_IMAGE: K3D 環境映像
- KDE_DEPLOY_ENV_IMAGE: 預設部署環境映像 (包含 kubectl、helm 等工具)
- NGROK_PROXY_IMAGE: Ngrok 代理映像
- CLOUDFLARE_TUNNEL_PROXY_IMAGE: Cloudflare Tunnel 映像
- K8S_UI_DASHBOARD_IMAGE: Kubernetes Dashboard 映像
- K9S_IMAGE: K9s 終端管理工具映像
- TELEPRESENCE_IMAGE: Telepresence 映像
- CODE_SERVER_IMAGE: Code Server 映像

## 專案 (Project)

### 專案指的是遠端的 git repository 或一個位於 environments/[k8s name]/namespaces/ 底下的本地資料夾

### 每個專案都是一個 k8s namespace (Project = k8s namespace)

### 專案權限基於 git repository 對於權限的控管 (Github、Gitlab repository 的權限)

### local k8s(kind、k3d) 內每個 pvc 名稱都會對應到 project 資料夾底下的一個與 pvc 同名的資料夾 or 檔案

### CICD pipeline 是專案資料夾底下的 pre-build.sh、build.sh、post-build.sh、pre-deploy.sh、deploy.sh、post-deploy.sh，可以自訂每個步驟的 container 執行環境 image

### 專案支援兩種類型：Git Remote 和 Local

- **Git Remote**: 從遠端 Git 倉庫拉取，支援版本控制和協作
- **Local**: 純本地專案，適合快速測試和原型開發

### 專案建置與部署使用不同的容器環境

- **DEVELOP_IMAGE**: 開發/建置環境，執行 build.sh，可自訂為任何開發環境映像 (node、python、golang 等)
- **DEPLOY_IMAGE**: 部署環境，執行 deploy.sh、pre-deploy.sh、post-deploy.sh，預設包含 kubectl、helm 等部署工具

### 專案標準化 CICD 腳本

- pre-build.sh: 建置前處理
- build.sh: 建置腳本
- post-build.sh: 建置後處理
- pre-deploy.sh: 部署前處理
- deploy.sh: 部署腳本
- post-deploy.sh: 部署後處理
- undeploy.sh: 卸載腳本

### 專案內建 Helm 支援

- 自動設定 HELM_CONFIG_HOME、HELM_CACHE_HOME、HELM_DATA_HOME、HELM_PLUGINS
- Helm 配置、快取、資料都儲存在專案目錄內，保持專案獨立性

### 專案集合 (Projects) 概念

- 支援從 Git 倉庫拉取多個專案的集合
- 適合微服務架構，一次管理多個相關專案

## 工具整合 (Tools Integration)

### 監控工具整合

- **K9s**: 終端機 K8S 管理工具，即時監控和操作
- **Dashboard**: Kubernetes 官方 Web UI
- **Headlamp**: 現代化的 K8S Web UI

### 代理工具整合

- **Ngrok**: 快速外部存取，適合測試和展示
- **Cloudflare Tunnel**: 安全的外部存取，適合生產環境
- **Telepresence**: 本地開發環境與 K8S 整合，支援流量攔截和代理

### 開發工具整合

- **Code Server**: 基於瀏覽器的 VS Code，支援遠端開發
- **Exec**: 直接進入 K8S 節點容器或專案容器環境
- **Expose**: Port Forward，將 Service/Pod 端口轉發到本地

### 別名系統 (Alias)

- 透過 tmux 快速啟動 session 到指定路徑
- 簡化重複性操作，提升效率

## 工作流程 (Workflow)

### 本地環境開發流程

- 建立環境(本地啟動/雲端建立) -> 建立專案(git clone) -> 部署專案 (shell CICD pipeline) -> 服務監控 (k9s/headlamp) -> 對外服務 (cloudflare tunnel/ngrok) -> 開發/除錯

### 遠端環境開發流程

- 建立環境(連結現有 k8s) -> 建立專案(git clone) -> 建立連結遠端服務(Pod)的本地容器開發環境 (telepresence) -> 服務監控 (k9s/headlamp) -> 開發/除錯

### 環境建立流程：啟動/連結 -> 監控

1. **kde start/create**:
   - 產生 config yaml 後，啟動 kind/k3d
   - 設定現有 K8S kubeconfig 路徑
2. **kde k9s/headlamp**: 啟動 TUI / Web UI K8S Dashboard

### 環境切換流程：查詢 -> 切換

1. **kde list**: 列出所有可用環境
2. **kde use**: 切換到指定環境，更新 current.env
3. 後續所有指令自動操作新的當前環境

### 專案部署流程：建立 -> 拉取 -> 建置 -> 部署

1. **kde proj create**: 建立專案目錄和 project.env
2. **kde proj fetch/pull**: 從 Git 拉取程式碼 (如果是 Git Remote 專案)
3. **kde proj build**: 在 DEVELOP_IMAGE 容器中執行 build.sh
4. **kde proj deploy**: 在 DEPLOY_IMAGE 容器中執行 pre-deploy.sh、deploy.sh、post-deploy.sh

## 錯誤處理與狀態檢查

### 超時機制

- K8S 節點就緒檢查有超時設定 (預設 2 秒)
- 避免指令長時間等待無回應
- 可用 `K8S_NODE_READY_TIMEOUT` 自訂超時限制

## 設計理念

### 約定優於配置 (Convention over Configuration)

- 預設使用標準化的目錄結構和檔案名稱
- 減少配置檔案的複雜度
- 提供合理的預設值

### 漸進式複雜度 (Progressive Complexity)

- 基本操作簡單易用 (如 `kde start dev`)
- 進階需求可透過參數和配置檔案客製化
- 不強制使用所有功能

### 模組化與可擴展性

- 每個功能有獨立的 操作邏輯(command.sh) 和 功能邏輯(utils/\*.sh)
- 工具映像可獨立更新和替換
- 容易新增新的工具整合

### 容器優先 (Container First)

- 所有工具都在容器中執行
- 避免污染本機環境
- 確保環境一致性

### 自動化與互動式混合

- 提供自動化腳本執行
- 缺少參數時提供互動式選擇
- 兼顧效率與易用性

## 目標受眾

### 開發人員

- 快速建立開發環境
- 方便程式開發/除錯
- 本地模擬完整的 K8S 環境

### DevOps/SRE/維運

- 快速建立模擬環境
- 方便 k8s 環境、CICD pipeline 模擬/開發/除錯
- 環境配置版本化管理

### 測試人員

- 快速建立測試環境
- 方便測試
- 可重複性高的測試環境
