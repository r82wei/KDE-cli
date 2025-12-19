# KDE Workspace 工作流程圖

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

    CICD --> CI[CI 階段<br/>使用 DEVELOP_IMAGE]
    CI --> PreBuild{pre-build.sh<br/>存在?}
    PreBuild -->|是| PreBuildExec[執行 pre-build.sh]
    PreBuild -->|否| Build
    PreBuildExec --> Build[執行 build.sh<br/>編譯/建置專案]
    Build --> PostBuild{post-build.sh<br/>存在?}
    PostBuild -->|是| PostBuildExec[執行 post-build.sh]
    PostBuild -->|否| CD
    PostBuildExec --> CD

    CD[CD 階段<br/>使用 DEPLOY_IMAGE]
    CD --> PreDeploy{pre-deploy.sh<br/>存在?}
    PreDeploy -->|是| PreDeployExec[執行 pre-deploy.sh]
    PreDeploy -->|否| DeployScript
    PreDeployExec --> DeployScript[執行 deploy.sh<br/>建立 Namespace<br/>建立 PVC<br/>Helm 部署服務]
    DeployScript --> PostDeploy{post-deploy.sh<br/>存在?}
    PostDeploy -->|是| PostDeployExec[執行 post-deploy.sh]
    PostDeploy -->|否| Services
    PostDeployExec --> Services

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
    style CI fill:#ffeaa7
    style CD fill:#ffeaa7
    style Services fill:#d1ecf1
    style RemoteEnv fill:#e7f3ff
    style Telepresence fill:#e7f3ff
    style DevContainer fill:#e7f3ff
    style LocalDev fill:#e7f3ff
    style Manage fill:#f8d7da
    style Optional fill:#e2e3e5
```

## 開發流程說明

### 本地 Container 開發流程（DEVELOP_IMAGE）

1. **啟動環境**：使用 `kde project exec <專案名稱> dev <使用的 Port>` 啟動本地 Container 環境（DEVELOP_IMAGE）
2. **本地開發**：進入本地開發容器，支援 Hot Reload 即時測試
3. **對外公開**（可選）：使用 Ngrok 或 Cloudflare Tunnel 對外公開服務

### 本地 K8S 開發流程（kind/k3d）

1. **啟動環境**：使用 `kde start` 啟動本地 K8S 環境（kind 或 k3d）
2. **部署專案**：執行 `kde proj deploy` 部署專案到 K8S
3. **CI/CD Pipeline**：
   - **CI 階段**（使用 `DEVELOP_IMAGE` 或自訂的 `PRE_BUILD_IMAGE`/`BUILD_IMAGE`/`POST_BUILD_IMAGE`）：
     - `pre-build.sh`：CI 前置作業腳本（預設：`DEVELOP_IMAGE`，可自訂：`PRE_BUILD_IMAGE`）
     - `build.sh`：CI 執行腳本，進行編譯/建置（預設：`DEVELOP_IMAGE`，可自訂：`BUILD_IMAGE`）
     - `post-build.sh`：CI 後置作業腳本（預設：`DEVELOP_IMAGE`，可自訂：`POST_BUILD_IMAGE`）
   - **CD 階段**（使用 `DEPLOY_IMAGE` 或自訂的 `PRE_DEPLOY_IMAGE`/`POST_DEPLOY_IMAGE`）：
     - `pre-deploy.sh`：CD 前置作業腳本（預設：`DEPLOY_IMAGE`，可自訂：`PRE_DEPLOY_IMAGE`）
     - `deploy.sh`：CD 執行腳本，進行部署（建立 Namespace、PVC、Helm 部署等）（預設：`DEPLOY_IMAGE`）
     - `post-deploy.sh`：CD 後置作業腳本（預設：`DEPLOY_IMAGE`，可自訂：`POST_DEPLOY_IMAGE`）
4. **服務管理**：使用 K9s、Headlamp 或 Port Forward 管理服務
5. **對外公開**（可選）：使用 Ngrok 或 Cloudflare Tunnel 對外公開服務

### 遠端 K8S 開發流程

1. **連接遠端環境**：使用 `kde start [環境名稱] --k8s` 連接遠端 K8S（需提供 kubeconfig）
2. **使用 Telepresence**：執行 `kde telepresence replace/intercept` 攔截遠端 Pod 流量
3. **本地開發**：進入本地開發容器，流量會攔截到本地開發容器，支援 Hot Reload 即時測試
4. **服務管理與對外公開**：與本地 K8S 流程相同

### 本地 CICD 開發流程（DEPLOY_IMAGE）

1. **啟動環境**：使用 `kde project exec <專案名稱> dep <使用的 Port>` 啟動本地 Container 環境（DEPLOY_IMAGE）
2. **本地開發**：進入本地開發容器，直接執行 CICD script (pre-build.sh、build.sh、post-build.sh、pre-deploy.sh、deploy.sh、post-deploy.sh)

## 相關文件

- [KDE 開發架構說明](./development-architecture.md)
- [透過 Telepresence 擷取遠端 K8S Pod 流量到容器開發環境進行開發](./telepresence.usage.md)
- [使用 Ngrok 建立對外網址](./ngrok.usage.md)
- [使用 Cloudflare Tunnel 建立對外網址](./cloudflare-tunnel.usage.md)
