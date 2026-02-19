# KDE-cli

[English](./README.md) | [繁體中文](./README.zh-TW.md)

> **Kubernetes Development Environment CLI** - 以 Kubernetes 為目標的開發環境與交付流程管理工具

KDE-cli 是一個 Kubernetes 開發環境的統一管理工具，整合完整的開發工具鏈，實現從環境建立到部署的全生命週期管理。它將分散的 Kubernetes 開發工具整合為統一的指令介面，讓開發者用**一套工具、一個指令介面**完成從環境建立、開發、測試到部署的完整 Kubernetes 開發流程。

## 💡 獨特價值
- All-in-One 整合：整合環境管理 + 開發工具 + 運維工具 + 外部連線的方案
- 零配置啟動：kde start dev kind 即可使用本地 K8s 環境，無需複雜配置檔案
- 環境隔離：輕鬆管理多個獨立環境，避免衝突
- 即時開發：本地檔案與 Pod 內檔案的即時同步
- 團隊共享：環境設定、專案設定、CICD 交付流程皆可透過 git 共享
- 學習曲線平緩：命令直觀，文檔完整（繁體中文）
- 完整工作流程：涵蓋從環境建立到部署監控的整個生命週期
#### 如果你需要一個「開箱即用、功能完整、簡單易用」的本地 K8s 開發環境，KDE-CLI 是最佳選擇。


## ✨ 核心特性

### 🔄 環境一致性
- 透過 Kind/K3D 模擬正式環境的開發環境
- 透過 kubeconfig 連接現有的 Kubernetes 環境
- 使用與正式環境相同的部署方式及 yaml 啟動開發環境，確保環境一致性
- 所有工具都在容器內執行，確保環境一致性

**💡 核心價值**：消除「在我機器上可以跑」的問題，開發環境與生產環境完全對齊，提早發現環境相關問題。

### 🧑‍💻 Kubernetes 環境內即時開發
- 開發環境(Kind/K3D)透過 PVC 掛載本地程式碼，實現即時同步與 Hot Reload
- 透過 Telepresence 將遠端 Kubernetes 流量攔截到本地開發容器，並且透過 volume 掛載本地程式碼，實現即時同步與 Hot Reload

**💡 核心價值**：在真實的 Kubernetes 環境中開發，無需重新建置映像即可立即看到程式碼變更效果，大幅加快開發迭代速度。

### 🔒 專案隔離性
- 每個專案對應獨立的 Kubernetes Namespace，資源完全隔離，可同時開發多個專案而不互相干擾
- 開發容器之間相互隔離，可同時開發多個專案而不互相干擾
- 環境變數隔離：每個專案的配置和環境變數互不影響

**💡 核心價值**：多專案並行開發不衝突，資源和配置完全隔離，團隊協作更安全高效。

### 📦 可版控、可共享、可攜帶
- 設定檔可納入版本控制
  - 環境配置（`k8s.env`）
  - 專案配置（`project.env`）
  - CI/CD Pipeline 腳本 & 執行環境映像檔設定 (`*.sh` & `project.env`)
  - 開發工具版本配置（`kde.env`）
- 專案資料夾可平移或複製到其他環境：將專案資料夾（包含 `project.env` 和所有腳本）複製到不同環境的 `namespaces/` 底下，即可用相同的配置和流程在新環境中快速啟動服務，無需重新配置
- 可以透過 GitHub/Gitlab 在不同電腦間快速同步、搬移開發工作區(Workspace)
- 團隊成員可快速複製相同的開發工作區
- 新成員快速 onboarding

**💡 核心價值**：開發環境即程式碼（Environment as Code），團隊成員一鍵啟動相同環境，新人 onboarding 從數天縮短到數分鐘。

### 🚀 Script 驅動的 CI/CD Pipeline
- 使用 Shell Script 定義 CI/CD 流程
- 自訂 Pipeline 階段和執行環境
- 支援手動模式進行開發與除錯
- 彈性的錯誤處理機制

**💡 核心價值**：本地開發與測試 CI/CD 流程，確保流程正確性後再部署到遠端 CI/CD 系統，大幅降低試錯成本。

### 🐳 容器優先
- 只需要安裝 Docker 就可以執行所有功能
- 所有工具都在容器中執行
- 避免污染本機環境
- 確保環境一致性

**💡 核心價值**：零環境配置，只需 Docker 即可執行所有功能，團隊成員使用相同的工具版本，避免版本衝突。

### 🎯 統一的工具入口
將 9+ 種 Kubernetes 開發工具整合為統一的 CLI 介面，並且自動處理工具與 K8s 環境的連接，降低學習曲線：

```bash
kde start               # 建立/啟動/連接環境 (Kind/K3D/K8s)
kde k9s                 # 啟動 K9s 終端管理工具
kde headlamp            # 啟動 Headlamp Web UI
kde telepresence        # 啟動 Telepresence 流量攔截
kde code-server         # 啟動 VSCode Web IDE
kde cloudflare-tunnel   # 啟動 Cloudflare Tunnel
kde ngrok               # 啟動 Ngrok 外部連線
kde expose              # Port Forward 端口轉發
```

**💡 核心價值**：一套指令完成所有操作，工具自動連接到當前環境，開發者只需專注於開發，無需學習多種工具的安裝和配置。

## 🎯 適用對象

### 組織 (Organization)
- 希望開發環境與正式環境對齊
- 需要管理多環境、多專案
- 需要標準化開發流程和環境配置版本化
- 團隊希望保持環境的一致性
- 需要快速 onboarding（一鍵啟動環境）
- 希望可以在開發環境測試 CI/CD 流程和驗證 K8s 配置

### 專案 (Project)
- 正式環境部署於 Kubernetes 的專案
- 微服務架構
- 需要部署到多個 K8s 環境

### 使用者 (Developer/DevOps/SRE/QA)
- 快速建立模擬環境
- 方便程式開發/除錯
- 方便 K8s 環境、CI/CD Pipeline 模擬/開發/除錯
- 環境配置版本化管理
- 本地模擬完整的 K8s 環境

## 🚀 快速開始

### 系統需求

- **Docker**：已安裝並運行
- **作業系統**：Linux / macOS / Windows (WSL)
- **Shell**：Bash
- **權限**：需要 sudo 權限進行安裝

### 安裝

#### 方式 1：一鍵安裝（推薦）

```bash
# 使用 curl（需要 sudo 權限）
curl -fsSL https://raw.githubusercontent.com/r82wei/KDE-cli/refs/heads/main/install.sh | sudo bash

# 或使用 wget（需要 sudo 權限）
wget -qO- https://raw.githubusercontent.com/r82wei/KDE-cli/refs/heads/main/install.sh | sudo bash

# 驗證安裝
kde --version
```

#### 方式 2：手動安裝

```bash
# 1. Clone 專案
git clone https://github.com/r82wei/KDE-cli.git
cd KDE-cli

# 2. 執行安裝（需要 sudo 權限）
sudo ./local-install.sh

# 3. 驗證安裝
kde --version
```

### 5 分鐘快速體驗

```bash
# 1. 初始化 Workspace
mkdir my-workspace && cd my-workspace
kde init

# 2. 啟動 Kind 開發環境
kde start dev-env kind

# 3. 建立專案
kde proj create myapp
# 選擇從 Git 倉庫抓取或建立本地專案
# 設定開發映像（例如：node:20）

# 4. 執行 CI/CD Pipeline 部署
kde proj pipeline myapp

# 5. 啟動 K9s 監控
kde k9s
```

恭喜！你已經成功建立了第一個 Kubernetes 開發環境並部署了專案。

## 📚 核心概念

### Workspace（工作空間）
Workspace 是 KDE-cli 的核心組織單位，用來統一管理：
- **環境定義**：一個或多個 Kubernetes 集群（本地或遠端）
- **專案定義**：每個專案對應一個 K8s Namespace
- **CI/CD 流程定義**：每個專案可定義獨立的 Pipeline 流程

### Environment（環境）
支援三種環境類型：
- **Kind**：Kubernetes in Docker，適合本地開發
- **K3D**：K3s in Docker，輕量級本地開發環境
- **外部 K8s**：連接到雲端或地端 K8s 集群

### Project（專案）
- 每個專案對應一個 Kubernetes Namespace
- 包含應用程式原始碼、建置腳本、部署腳本
- 支援從 Git 倉庫抓取或本地開發

### CI/CD Pipeline
- Script 驅動的 CI/CD 流程
- 預設流程：`build` → `deploy`
- 可自訂階段：`test` → `lint` → `build` → `security-scan` → `release` → `deploy`
- 每個階段可指定執行環境（Docker 映像）

## 🛠️ 整合的工具生態系統

| 分類 | 工具 | 功能 |
|------|------|------|
| **本地 K8s** | Kind, K3D | 快速啟動本地 Kubernetes 環境 |
| **K8s 管理** | K9s | TUI 終端機圖形化操作介面 |
| | Headlamp | Web UI 圖形化管理介面 |
| **開發整合** | 開發容器 | DEVELOP_IMAGE 容器環境 |
| | Kind/K3D + PVC 掛載 | 透過 local-path-provisioner 實現程式碼即時同步 |
| | Telepresence | 遠端 Pod 流量轉接與環境模擬 |
| | code-server | Web UI 的 VSCode 開發環境 |
| | Port Forward | Service/Pod 端口轉發到本地 |
| **對外連線** | Cloudflare Tunnel | 安全的外部連線（自訂域名） |
| | Ngrok | 快速的臨時外部連線 |

## 📖 基本使用

### 環境管理

```bash
# 列出所有環境
kde list
kde ls

# 啟動/建立環境
kde start dev-env kind        # Kind 環境
kde start test-env k3d        # K3D 環境
kde start prod-env k8s        # 外部 K8s 環境

# 切換環境
kde use dev-env

# 查看環境狀態
kde status

# 停止環境
kde stop dev-env

# 重啟環境
kde restart dev-env

# 移除環境
kde remove dev-env
kde rm dev-env
```

### 專案管理

```bash
# 列出專案
kde proj list
kde proj ls

# 建立專案
kde proj create myapp

# 執行 CI/CD Pipeline 部署
kde proj pipeline myapp
kde proj deploy myapp

# 更新專案程式碼
kde proj pull myapp

# 重新部署
kde proj redeploy myapp

# 卸載專案
kde proj undeploy myapp

# 移除專案
kde proj remove myapp
kde proj rm myapp
```

### 開發模式

```bash
# 進入開發容器（DEVELOP_IMAGE）
kde proj exec myapp develop
kde proj exec myapp dev

# 進入開發容器並對應端口
kde proj exec myapp develop 3000

# 進入部署容器（DEPLOY_IMAGE，包含 kubectl/helm）
kde proj exec myapp deploy
kde proj exec myapp dep
```

### 監控與除錯

```bash
# 啟動 K9s（終端機 UI）
kde k9s

# 啟動 Headlamp（Web UI）
kde headlamp

# 查看專案 Pod 日誌
kde proj tail myapp
```

### 外部連線

```bash
# Port Forward（本地存取）
kde expose myapp service myapp-service 3000 3000

# Cloudflare Tunnel（安全外部存取）
kde cloudflare-tunnel myapp.example.com service

# Ngrok（快速外部存取）
kde ngrok service
```

### CI/CD Pipeline 進階操作

```bash
# 執行完整 Pipeline
kde proj pipeline myapp

# 從特定階段開始
kde proj pipeline myapp --from build

# 執行到特定階段
kde proj pipeline myapp --to test

# 只執行特定階段
kde proj pipeline myapp --only build

# 手動模式（除錯）
kde proj pipeline myapp --manual
kde proj pipeline myapp --only build --manual
```

## 🏗️ 開發模式

KDE-cli 支援三種開發模式，適應不同的開發場景：

### 模式 1：開發容器模式
進入 `DEVELOP_IMAGE` 容器，掛載專案資料夾進行開發。

```bash
kde proj exec myapp develop [port]
```

**適用場景**：快速開發、單元測試、不需要 K8s 功能

### 模式 2：K8s + PVC 掛載模式（Hot Reload）
透過 K8s YAML 或 Helm 部署應用到 K8s，使用 `local-path-provisioner` 將 source code 掛載到 Pod 內。

```
本地程式碼 → PVC → Pod 內即時同步 → Hot Reload
```

**適用場景**：整合測試、接近生產環境的開發、需要 K8s 網路功能

### 模式 3：Telepresence 模式
攔截遠端 K8s Pod 的流量到本地開發容器。

```bash
kde telepresence replace myapp myapp-deployment
```

**適用場景**：連接遠端 K8s 開發、需要存取遠端服務

## 📖 文檔

完整的文檔請參考 `docs/` 目錄：

### 核心文檔
- **[KDE-cli 概述](./docs/core/overview.md)** - 核心價值與開發生命週期
- **[Workspace（工作空間）](./docs/core/workspace.md)** - Workspace 完整說明
- **[設計原則](./docs/principle.md)** - 設計理念與工作流程

### 環境管理
- **[環境概述](./docs/core/environment/environment-overview.md)** - 環境類型與開發模式
- **[Kubernetes 環境](./docs/core/environment/kubernetes/overview.md)** - K8s 環境詳細說明
  - [Kind 環境](./docs/core/environment/kubernetes/kind.md)
  - [K3D 環境](./docs/core/environment/kubernetes/k3d.md)
  - [外部 K8s 環境](./docs/core/environment/kubernetes/external-kubernetes.md)
- **[開發容器](./docs/core/environment/dev-container.md)** - 開發容器詳細說明

### 專案與 CI/CD
- **[專案管理](./docs/core/project.md)** - 專案配置與管理
- **[CI/CD Pipeline](./docs/core/cicd-pipeline.md)** - Script 驅動的 CI/CD 流程

### 開發工具
- **[開發工具概述](./docs/dev-tools.md)** - 整合工具總覽
- **[K9s](./docs/core/dev-tools/k9s.md)** - 終端機 K8s 管理工具
- **[Headlamp](./docs/core/dev-tools/headlamp.md)** - Web UI Dashboard
- **[Telepresence](./docs/core/dev-tools/telepresence.md)** - 遠端流量攔截
- **[code-server](./docs/core/dev-tools/code-server.md)** - Web VSCode
- **[Port Forward](./docs/core/dev-tools/port-forward.md)** - 端口轉發
- **[Cloudflare Tunnel](./docs/core/dev-tools/cloudflare-tunnel.md)** - 安全外部連線
- **[Ngrok](./docs/core/dev-tools/ngrok.md)** - 快速外部連線

### 快速參考
- **[快速參考指南](./.cursor/rules/quick-reference.mdc)** - 常用指令速查

## 🎓 使用範例

### 範例 1：團隊協作開發工作區

```bash
# 管理員：建立並配置 Workspace
mkdir team-workspace && cd team-workspace
kde init
kde start dev-env kind
kde proj create service-a
kde proj create service-b
# 配置專案...
git add . && git commit -m "Add dev environment" && git push

# 團隊成員：一鍵啟動環境
git clone <team-workspace-repo-url>
cd team-workspace
kde start dev-env kind
kde proj pipeline service-a
kde proj pipeline service-b
kde k9s  # 開始開發
```

### 範例 2：多環境部署

```bash
# 開發環境
kde use dev-env
kde proj pipeline myapp

# 測試環境
kde use test-env
kde proj pipeline myapp

# 生產環境
kde use prod-env
kde proj pipeline myapp
```

### 範例 3：使用 Telepresence 連接遠端 K8s

```bash
# 連接到遠端環境
kde start remote-env k8s

# 啟動 Telepresence 攔截流量
kde telepresence replace myapp myapp-deployment

# 選擇專案並進入容器開發環境
# 容器內開發，遠端流量導向容器
npm run dev
```

### 範例 4：將專案平移到其他環境快速部署

```bash
# 情境：將開發環境的專案快速複製到測試環境

# 1. 在開發環境中已配置好的專案
kde use dev-env
kde proj list
# 輸出：myapp (已配置好 project.env 和所有腳本)

# 2. 複製專案資料夾到測試環境
cp -r environments/dev-env/namespaces/myapp environments/test-env/namespaces/myapp

# 3. 修改成測試環境的環境變數
vi environments/test-env/namespaces/myapp/project.env

# 4. 切換到測試環境並部署
kde use test-env
kde proj pipeline myapp
# 使用相同的配置和流程，快速在測試環境啟動服務

# 5. 也可以直接用 Git 版控來同步
git add . && git commit -m "Add myapp configuration"
git push
```

**核心優勢**：
- ✅ 專案資料夾包含所有 CI/CD 設定
- ✅ 所有腳本（build.sh, deploy.sh 等）一起遷移
- ✅ 不需要重新配置，確保多環境一致性
- ✅ 適合快速擴展到多個環境（dev → test → staging → prod）

## 🔧 除錯

啟用除錯模式來追蹤 KDE-cli 的執行流程：

```bash
# 方式 1：臨時啟用
KDE_DEBUG=true kde start dev-env kind
KDE_DEBUG=true kde proj pipeline myapp

# 方式 2：在 kde.env 中永久啟用
echo "KDE_DEBUG=true" >> kde.env
kde proj pipeline myapp
```

除錯模式會顯示：
- KDE-cli 內部執行的每個 shell 命令
- 變數值和函數調用
- 幫助追蹤問題發生在哪個步驟

## 📝 授權

本專案採用 Apache 2.0 授權條款 - 詳見 [LICENSE](./LICENSE) 檔案

## 🔗 相關資源

- **GitHub**：[r82wei/KDE-cli](https://github.com/r82wei/KDE-cli)
- **文檔**：[docs/](./docs/)
- **Issues**：[GitHub Issues](https://github.com/r82wei/KDE-cli/issues)
- **Discussions**：[GitHub Discussions](https://github.com/r82wei/KDE-cli/discussions)

## 💡 專案名稱說明

**KDE** = **Kubernetes Development Environment** = **Workspace**

這三個名詞指的是同一個概念：
- **KDE** 是縮寫，代表整個開發工作區
- **Kubernetes Development Environment** 是完整名稱
- **Workspace（開發工作區）** 是實際的組織單位和目錄結構
