# KDE CLI Roadmap（mermaid）

以下依據現有文件（`principle.md`、`workflow.md`、`environment-variables.md` 等）整理的高層流程圖，涵蓋環境層級、專案生命週期與工具整合。

```mermaid
flowchart TD
    %% 啟動與定位
    A[開始] --> B{找到 kde.env?}
    B -->|否| B1[向上搜尋 kde.env<br/>自動定位 KDE_PATH]
    B -->|是| C[載入全域變數<br/>KDE_PATH/KDE_SCRIPTS_PATH/ENVIROMENTS_PATH]
    B1 --> C

    %% 環境生命週期
    C --> D{環境存在?}
    D -->|否| D1[建置環境目錄<br/>生成 k8s.env]
    D -->|是| E{環境初始化?}
    D1 --> E
    E -->|否| E1[初始化 kubeconfig<br/>寫入 .env<br/>設定 API/Ingress port]
    E -->|是| F{環境運行?}
    E1 --> F
    F -->|否| F1[啟動/連線 K8s<br/>kde start/create<br/>kind / k3d / --k8s]
    F -->|是| G[切換/確認當前環境<br/>current.env]
    F1 --> G

    %% 專案生命週期
    G --> H{專案存在?}
    H -->|否| H1[建立專案 namespace<br/>kde proj create<br/>生成 project.env]
    H -->|是| I[拉取/同步程式碼<br/>kde proj fetch/pull]
    H1 --> I
    I --> J[建置 CI<br/>DEVELOP_IMAGE<br/>pre/post-build.sh + build.sh]
    J --> K[部署 CD<br/>DEPLOY_IMAGE<br/>pre/post-deploy.sh + deploy.sh + PVC/Helm]
    K --> L[服務就緒於 K8s]

    %% 工具與觀測
    L --> M{需要開發/除錯?}
    M -->|是| M1[Port Forward: kde expose<br/>或 Telepresence 攔截流量]
    M -->|否| N[進入監控]
    M1 --> N
    N --> O[觀測/管理<br/>kde k9s 或 headlamp/dashboard]
    O --> P{對外公開?}
    P -->|是| P1[ngrok（快速） / cloudflare-tunnel（安全）]
    P -->|否| Q[持續迭代]
    P1 --> Q

    %% 配置分層提示
    subgraph 配置分層
        C:::conf
        G:::conf
        note1[全域: kde.env]:::conf --> note2[環境: k8s.env + .env]:::conf --> note3[專案: project.env]:::conf
    end
    classDef conf fill:#e1f5fe,stroke:#90caf9,color:#0d47a1;
```

## 說明重點

- **自動尋徑**：從當前目錄向上尋找 `kde.env`，自動設定 `KDE_PATH` 與腳本路徑。
- **環境三階段**：存在 → 初始化（kubeconfig/.env）→ 運行（K8s Ready）。透過 `kde start/use/status` 管理。
- **配置分層覆蓋**：`kde.env`（全域）→ `k8s.env`/`.env`（環境）→ `project.env`（專案），確保共享又可客製。
- **專案 = Namespace**：`proj create/fetch/build/deploy` 以容器化 CI/CD 執行，建置與部署映像可獨立設定。
- **工具整合**：K9s/Headlamp 觀測，Expose/Telepresence 開發除錯，Ngrok/Cloudflare Tunnel 對外公開。
- **安全與一致性**：全部操作在容器內完成，避免汙染本機，確保團隊環境一致。
