# 設計原則

以 DevOps Loop 為核心的 Kubernetes 平台工程框架。定義專案到不同 K8S 環境的交付流程，實現從本地開發到各環境 K8s 部署的全生命週期一致性，並且整合開發工具優化 DevOps Loop 各階段的開發體驗。

## 設計重點

- 以 Kubernetes 為最終部署目標環境，並且維持開發環境、測試環境、正式環境的一致性
- 定義專案、交付流程(CICD pipeline)、環境(K8S)三者之間的關係，提供可重現、可版控、團隊一致且可攜、共享的開發環境與各階段(開發、測試、正式) K8S 環境的交付流程
- 使用者可自訂交付流程(CICD pipeline)各階段的 shell script 與執行環境容器映像檔
- 整合各式開發工具，提升 DevOps Loop 各階段開發體驗(DX)
- 可以快速啟動並連結本地 K8S 開發環境(kind、k3d)，也可以透過 kubeconfig 連結雲端/地端 K8S 作為專案部署的目的地
- 本地 K8S 環境(kind、k3d)可以透過 local-path-provisioner 建立 PVC，將專案程式碼掛載到 Pod 內
- 容器優先 (Container First)，只需要安裝 docker 就可以執行所有東西
  - 所有工具都在容器中執行
  - 避免污染本機環境
  - 確保環境一致性
- 自動化與互動式混合
  - 提供自動化腳本執行
  - 缺少參數時提供互動式選擇
- 標準化映像管理，統一工具版本 (kde.env)
  - KIND_IMAGE: Kind 環境映像
  - K3D_IMAGE: K3D 環境映像
  - KDE_DEPLOY_ENV_IMAGE: 預設部署環境映像 (包含 kubectl、helm 等工具)
  - NGROK_PROXY_IMAGE: Ngrok 代理映像
  - CLOUDFLARE_TUNNEL_PROXY_IMAGE: Cloudflare Tunnel 映像
  - K8S_UI_DASHBOARD_IMAGE: Kubernetes Dashboard 映像
  - K9S_IMAGE: K9s 終端管理工具映像
  - TELEPRESENCE_IMAGE: Telepresence 映像
  - CODE_SERVER_IMAGE: Code Server 映像
- 目標受眾
  - Organization
    - 希望開發環境與正式環境對齊
    - 需要管理多環境、多專案
    - 需要標準化開發流程
    - 需要環境配置版本化
    - 團隊希望保持環境的一致性
    - 需要快速 onboarding (一鍵啟動環境)
    - 希望可以在開發環境測試 CI/CD 流程
    - 希望可以在開發環境驗證 K8S 配置
  - Project
    - 正式環境部署於 K8S 的專案
    - 微服務架構
    - 需要部署到多個 K8S 環境
  - Developer
    - 快速建立開發環境
    - 方便程式開發/除錯
    - 本地模擬完整的 K8S 環境
  - DevOps/SRE
    - 快速建立模擬環境
    - 方便 k8s 環境、CICD pipeline 模擬/開發/除錯
    - 環境配置版本化管理
  - QA
    - 快速建立測試環境

## 工作流程

### 流程圖

以下流程圖展示了從啟動環境到部署服務的完整流程：

```mermaid
flowchart TD
    Start([開始]) --> Init{是否已初始化?}
    Init -->|否| InitStep[執行 ./init.sh<br/>初始化 KDE CLI]
    InitStep --> StartEnv
    Init -->|是| StartEnv["啟動/連接 K8S 環境<br/>kde start 或 kde start (環境名稱)"]

    StartEnv --> EnvType{選擇環境類型}
    EnvType -->|本地 container 開發| ContainerEnv["DEVELOP_IMAGE 容器環境 <br/><br/> kde project exec (專案名稱) dev (使用的Port)"]
    EnvType -->|本地 K8S 開發| KindEnv[kind 環境<br/>預設]
    EnvType -->|本地輕量級 K8S 開發| K3dEnv[k3d 環境<br/>--k3d]
    EnvType -->|遠端連接| RemoteEnv["連接遠端 K8s<br/>kde start (環境名稱) --k8s<br/>提供 kubeconfig"]

    %% 本地容器開發流程
    ContainerEnv --> LocalDev[本地開發<br/>Hot Reload<br/>即時測試]

    %% 本地 K8S 流程
    KindEnv --> LocalDeploy
    K3dEnv --> LocalDeploy
    LocalDeploy["部署專案<br/>kde proj deploy (專案名稱)"]

    LocalDeploy --> CICD[觸發 CI/CD Pipeline]

    CICD --> PipelineStages[依序執行 Pipeline 階段<br/>KDE_PIPELINE_STAGES]
    PipelineStages --> Stage1[階段 1<br/>使用對應的 _IMAGE<br/>執行對應的 _SCRIPT]
    Stage1 --> Stage2[階段 2<br/>...]
    Stage2 --> StageN[階段 N<br/>...]
    StageN --> PipelineEnv[階段間環境變數<br/>透過 .pipeline.env 傳遞]
    PipelineEnv --> Services

    %% 常見 Pipeline 階段範例
    note1[範例階段:<br/>build → test → deploy<br/>或<br/>lint → test → build → security-scan → deploy]
    Stage1 -.-> note1

    Services[服務已部署到 K8s]

    %% 遠端 K8S 流程
    RemoteEnv --> Telepresence["使用 Telepresence<br/>kde telepresence replace/intercept<br/>(namespace) (workload)"]
    Telepresence --> DevContainer["進入本地開發容器<br/>流量攔截到本地<br/>環境變數同步"]
    DevContainer --> LocalDev[本地開發<br/>Hot Reload<br/>即時測試]

    %% 共同的管理與監控
    Services --> Manage{管理與監控}
    LocalDev --> Manage
    Manage -->|CLI 工具| K9s[使用 K9s<br/>kde k9s]
    Manage -->|Web UI| Headlamp[使用 Headlamp<br/>kde headlamp]
    Manage -->|Port Forward| Expose[Port Forward<br/>kde expose]

    %% 對外公開服務
    Services --> Optional{對外公開服務?}
    LocalDev --> Optional
    Optional -->|是| Public{選擇方式}
    Optional -->|否| End
    Public -->|快速測試| Ngrok[使用 Ngrok<br/>kde ngrok]
    Public -->|生產環境| Cloudflare[使用 Cloudflare Tunnel<br/>kde cloudflare-tunnel]

    K9s --> End
    Headlamp --> End
    Expose --> End
    Ngrok --> End
    Cloudflare --> End

    End([完成])

    style Start fill:#e1f5ff
    style End fill:#d4edda
    style CICD fill:#fff3cd
    style PipelineStages fill:#ffeaa7
    style Stage1 fill:#ffeaa7
    style Stage2 fill:#ffeaa7
    style StageN fill:#ffeaa7
    style PipelineEnv fill:#d4edda
    style Services fill:#d1ecf1
    style RemoteEnv fill:#e7f3ff
    style Telepresence fill:#e7f3ff
    style DevContainer fill:#e7f3ff
    style LocalDev fill:#e7f3ff
    style Manage fill:#f8d7da
    style Optional fill:#e2e3e5
```

### 流程說明

### 本地 Container 開發流程（DEVELOP_IMAGE）

1. **啟動環境**：使用 `kde project exec <專案名稱> dev <使用的 Port>` 啟動本地 Container 環境（DEVELOP_IMAGE）
2. **本地開發**：進入本地開發容器，支援 Hot Reload 即時測試
3. **對外公開**（可選）：使用 Ngrok 或 Cloudflare Tunnel 對外公開服務

#### 本地 K8S 流程（kind/k3d）

1. **啟動環境**：使用 `kde start` 啟動本地 K8S 環境（kind 或 k3d）
2. **部署專案**：執行 `kde proj deploy` 或 `kde proj pipeline` 部署專案到 K8S
3. **CI/CD Pipeline**（腳本驅動的工作流程）：
   - **Pipeline 階段定義**：透過 `project.env` 定義 `KDE_PIPELINE_STAGES`
     ```bash
     # 預設階段
     KDE_PIPELINE_STAGES="build,deploy"
     
     # 或自訂階段
     KDE_PIPELINE_STAGES="lint,test,build,security-scan,deploy"
     ```
   - **階段配置**：每個階段可指定專屬的容器映像和腳本
     ```bash
     # 階段映像配置
     KDE_PIPELINE_STAGE_build_IMAGE=node:20
     KDE_PIPELINE_STAGE_build_SCRIPT=build.sh
     
     KDE_PIPELINE_STAGE_deploy_IMAGE=r82wei/deploy-env:1.0.0
     KDE_PIPELINE_STAGE_deploy_SCRIPT=deploy.sh
     ```
   - **階段控制**：
     - `_SKIP=true`：跳過階段
     - `_MANUAL_ONLY=true`：只能手動觸發
     - `_ALLOW_FAILURE=true`：允許失敗
   - **階段間資料傳遞**：透過 `.pipeline.env` 在階段間傳遞環境變數
   - **執行選項**：
     - `kde proj pipeline <name>`：執行完整 Pipeline
     - `kde proj pipeline <name> --only build`：只執行特定階段
     - `kde proj pipeline <name> --from test`：從特定階段開始
     - `kde proj pipeline <name> --manual`：手動模式（進入容器環境）
4. **服務管理**：使用 K9s、Headlamp 或 Port Forward 管理服務
5. **對外公開**（可選）：使用 Ngrok 或 Cloudflare Tunnel 對外公開服務

#### 遠端 K8S 流程

1. **連接遠端環境**：使用 `kde start [環境名稱] --k8s` 連接遠端 K8S（需提供 kubeconfig）
2. **使用 Telepresence**：執行 `kde telepresence replace/intercept` 攔截遠端 Pod 流量
3. **本地開發**：進入本地開發容器，流量會攔截到本地，支援 Hot Reload 即時測試
4. **服務管理與對外公開**：與本地 K8S 流程相同

#### 本地 Pipeline 開發流程

1. **測試 Pipeline 腳本**：
   - 方法 A：使用 `kde proj exec <專案名稱> [dev|dep]` 進入開發/部署容器，手動執行腳本
   - 方法 B（推薦）：使用 `kde proj pipeline <專案名稱> --only <stage> --manual` 進入 Pipeline 階段環境
     ```bash
     # 進入 build 階段環境測試
     kde proj pipeline myapp --only build --manual
     
     # 進入 deploy 階段環境測試
     kde proj pipeline myapp --only deploy --manual
     ```
2. **除錯 Pipeline**：
   - 啟用除錯模式：`KDE_DEBUG=true kde proj pipeline <專案名稱>`
   - 手動模式逐階段測試：`kde proj pipeline <專案名稱> --manual`
   - 在腳本中加入 `set -x` 追蹤執行過程

## Best practice

- 當系統複雜度足夠時，開發環境應接近正式環境
- 程式執行期的設定應定義於 Kubernetes ConfigMap / Secret，而不是 .env 檔案

## 注意：

- kde-cli 與 KDE Desktop / Plasma 無關，它是一個 Dev / Platform Engineering 工具。
