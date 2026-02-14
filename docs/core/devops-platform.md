# DevOps 工作流程平台定義與說明

## 核心概念

**DevOps 工作流程平台**是一個整合工具和流程的系統，用於支援軟體從開發（Development）到運維（Operations）的完整生命週期，實現持續交付和環境一致性。

在 KDE-CLI 的脈絡下，DevOps 工作流程平台是指能夠整合環境管理、CI/CD Pipeline、開發工具，並實現自動化和標準化的統一系統。

---

## 📋 關鍵組成要素

### 1. 環境管理（Environment Management）

環境管理是 DevOps 平台的基礎，確保不同階段使用一致的環境配置。

#### 環境類型
- **本地開發環境**：Kind、K3D
- **測試環境**：連接到測試用 K8s 集群
- **生產環境**：連接到生產用 K8s 集群(建議只給 read-only 權限)
- **環境一致性**：確保 Dev/Test/Prod 使用相同的配置和容器

#### KDE-CLI 實現
```bash
kde start dev-env kind      # 開發環境
kde start test-env k8s      # 測試環境
kde start prod-env k8s      # 生產環境
```

#### 核心價值
- 消除「在我機器上可以跑」的問題
- 環境配置可版控（k8s.env）
- 快速複製和遷移環境

### 2. 交付流程（Delivery Pipeline）

自動化的軟體交付流程，從程式碼到部署的完整路徑。

#### 流程特點
- **CI/CD Pipeline**：自動化的建置、測試、部署流程
- **階段化執行**：build → test → deploy（可自定義）
- **腳本驅動**：使用 Shell Script 定義每個階段的操作
- **容器化執行**：每個階段在指定的容器映像中執行

#### KDE-CLI 實現
```bash
# 定義自定義交付流程
KDE_PIPELINE_STAGES=build,test,release,deploy

# 執行完整 Pipeline
kde proj pipeline myapp

# 階段控制
kde proj pipeline myapp --from test --to deploy
kde proj pipeline myapp --only build
kde proj pipeline myapp --manual  # 開發模式
```

#### 核心價值
- 可重現的建置和部署流程
- 階段化控制和錯誤處理
- 本地開發 CI/CD 流程
- 與生產環境 CI/CD 保持一致
- CI/CD 流程可版控(project.env & *.sh)

### 3. 專案管理（Project Management）

多專案的組織和隔離機制。

#### 管理特點
- **專案隔離**：每個專案對應獨立的 Kubernetes Namespace
- **配置版控**：專案配置可納入版本控制
- **多專案支援**：同時管理多個專案

#### KDE-CLI 實現
```bash
kde proj create myapp           # 建立專案
kde proj deploy myapp           # 部署專案
kde proj tail myapp             # 查看日誌
kde proj pod-exec myapp         # 進入 pod
```

#### 核心價值
- 專案之間完全隔離，互不干擾
- 統一的專案管理介面
- 專案配置可版控(project.env)

### 4. 開發工具整合（Toolchain Integration）

整合多種開發工具，涵蓋開發各階段的需求。

#### 工具生態系統

| 階段 | 工具 | 功能 | KDE 指令 |
|------|------|------|----------|
| **開發** | 開發容器 | 即時開發、Hot Reload | `kde proj exec myapp dev` |
| | Telepresence | 流量攔截到本地 | `kde telepresence intercept` |
| | code-server | Web IDE | `kde code-server` |
| **建置** | CI/CD Pipeline | 自動化建置和測試 | `kde proj pipeline myapp` |
| **部署** | kubectl、Helm | 部署到 K8s | `kde proj deploy myapp` |
| **監控** | K9s | 終端管理介面 | `kde k9s` |
| | Headlamp | Web 管理介面 | `kde headlamp` |
| **對外** | Ngrok | 快速外部存取 | `kde ngrok service` |
| | Cloudflare Tunnel | 安全外部存取 | `kde cloudflare-tunnel` |
| **除錯** | Port Forward | 本地端口轉發 | `kde expose` |

#### 核心價值
- 統一的工具入口（Single Entry Point）
- 工具之間自動連接和配置
- 降低學習曲線

### 5. 自動化與標準化（Automation & Standardization）

確保流程可重現和團隊一致性。

#### 自動化特點
- **容器優先**：所有工具在容器中執行，避免環境污染
- **版本管理**：環境、專案、CI/CD 設定皆可版控及共享
- **一鍵啟動**：快速複製和啟動完整環境
- **互動式選擇**：缺少參數時自動提供選項

#### KDE-CLI 實現
```bash
# 所有工具版本統一管理
# kde.env
KIND_IMAGE=kindest/node:v1.27.3
K3D_IMAGE=rancher/k3s:v1.27.4-k3s1
KDE_DEPLOY_ENV_IMAGE=r82wei/deploy-env:1.0.0
K9S_IMAGE=r82wei/k9s:0.32.5-1.0.0
```

#### 核心價值
- 團隊成員使用相同的工具版本
- 快速 onboarding 新成員
- 配置可版控和共享

---

## 🎯 DevOps 工作流程平台的必要特徵

### ✅ 1. 環境一致性（Environment Parity）

**定義**：開發、測試、生產環境使用相同的容器和配置。

**KDE-CLI 實現**：
- 所有環境都基於 Kubernetes
- 使用相同的容器映像
- 配置可版控（k8s.env, project.env）
- 開發環境透過 PVC 掛載實現即時同步

**價值**：減少「在我機器上可以跑」的問題

### ✅ 2. 自動化流程（Automation）

**定義**：CI/CD Pipeline 自動執行建置、測試、部署，減少人工操作。

**KDE-CLI 實現**：
- 自定義 Pipeline 系統
- 腳本驅動的自動化流程
- 階段化控制和錯誤處理

**價值**：提高效率，減少人為錯誤

### ✅ 3. 可重現性（Reproducibility）

**定義**：配置可版控，團隊成員可快速複製相同環境。

**KDE-CLI 實現**：
- 所有配置檔案可納入 Git
- 一鍵啟動完整環境
- 跨機器遷移環境

**價值**：快速 onboarding，環境一致性

### ✅ 4. 工具整合（Tool Integration）

**定義**：統一的指令介面，工具之間自動連接和配置。

**KDE-CLI 實現**：
- 9+ 種工具的統一入口
- 工具自動連接到當前環境
- 減少手動配置

**價值**：降低學習曲線，提高開發效率

### ✅ 5. 快速迭代（Rapid Iteration）

**定義**：支援 Hot Reload，即時查看變更效果。

**KDE-CLI 實現**：
- 開發容器支援 Hot Reload
- PVC 掛載實現即時同步
- Telepresence 流量攔截到本地

**價值**：加快開發速度，提升開發體驗

---

## 🔄 完整的 DevOps Loop

DevOps 工作流程平台需要支援完整的 DevOps 循環：

```
計畫 → 開發 → 建置 → 測試 → 發布 → 部署 → 運維 → 監控
  ↑                                           ↓
  └───────────────────────────────────────────┘
                  在同一個平台完成
```

### KDE-CLI 的 DevOps Loop 實現

| 階段 | 活動 | KDE-CLI 實現 |
|------|------|-------------|
| **計畫** | 定義專案配置和流程 | 編輯 `project.env`, `KDE_PIPELINE_STAGES` |
| **開發** | 撰寫程式碼 | 使用開發容器 `kde proj exec myapp dev`<br/>或 PVC 掛載開發<br/>或 Telepresence 攔截 |
| **建置** | 編譯、打包 | CI Pipeline: `build.sh` |
| **測試** | 執行測試 | 自定義測試階段: `test.sh` |
| **發布** | 建立 Release | 自定義發布階段: `release.sh` |
| **部署** | 部署到 K8s | CD Pipeline: `deploy.sh` |
| **運維** | 管理服務 | K9s `kde k9s`<br/>Headlamp `kde headlamp` |
| **監控** | 查看狀態和日誌 | `kde proj tail myapp`<br/>K9s `kde k9s`<br/>Headlamp `kde headlamp` |
| **回饋** | 根據結果調整 | 調整配置，重新執行 Pipeline |

---

## 🌟 為什麼 KDE-CLI 是 DevOps 工作流程平台

### 1. 完整的生命週期管理

KDE-CLI 涵蓋軟體開發的完整生命週期：

- ✅ **環境建立**：Kind/K3D/K8s 環境管理
- ✅ **開發階段**：開發容器、PVC 掛載、Telepresence、code-server (VS Code)
- ✅ **CI/CD**：自定義 Pipeline 系統
- ✅ **部署階段**：kubectl/kustomize/Helm 自動部署
- ✅ **監控階段**：K9s、Headlamp、日誌查看

### 2. 高度自動化

- ✅ **自定義 Pipeline 系統**：定義任意階段流程
- ✅ **階段化控制**：`--from`, `--to`, `--only` 控制執行範圍
- ✅ **錯誤處理機制**：Fail Fast、Allow Failure、Manual Only
- ✅ **開發模式**：`--manual` 進入階段環境除錯

### 3. 開發者體驗優化

- ✅ **統一指令介面**：一套指令完成所有操作
- ✅ **互動式選擇**：缺少參數時自動提供選項
- ✅ **開發模式**：支援 Hot Reload 和即時除錯
- ✅ **文件完整**：18+ 個詳細的使用文件

### 4. 企業級功能

- ✅ **多環境管理**：Dev/Test/Prod 環境切換
- ✅ **多專案隔離**：每個專案獨立 Namespace
- ✅ **配置版控**：所有配置可納入 Git
- ✅ **團隊協作**：快速複製和共享環境

---

## 📚 總結

### DevOps 工作流程平台的定義

**DevOps 工作流程平台** = **環境管理** + **CI/CD Pipeline** + **工具整合** + **自動化** + **標準化**

這是一個整合型系統，能夠：
1. 管理多個環境（Dev/Test/Prod）
2. 定義和執行自動化交付流程
3. 整合開發工具鏈
4. 實現環境一致性和可重現性
5. 支援完整的 DevOps 循環


### 核心價值

1. **統一平台**：一個工具完成所有 DevOps 任務
2. **環境一致**：Dev/Test/Prod 使用相同配置
3. **可重現性**：配置可版控，快速複製環境
4. **自動化**：減少人工操作，提高效率
5. **開發體驗**：Hot Reload、即時除錯、統一介面

### 適用場景

- ✅ Kubernetes 原生應用開發
- ✅ 微服務架構
- ✅ 需要多環境管理的團隊
- ✅ 需要同時開發多個專案的團隊
- ✅ 需要標準化開發流程的組織
- ✅ 追求一致開發環境的團隊
- ✅ 需要快速 onboarding 的團隊

---

## 🔗 相關文件

- [設計原則](./principle.md)
- [核心概述](./core/overview.md)
- [CI/CD Pipeline](./core/cicd-pipeline.md)
- [快速參考指南](./core/quick-reference.md)
- [專案管理](./core/project.md)
- [工作區管理](./core/workspace.md)
