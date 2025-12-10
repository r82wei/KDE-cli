# KDE-CLI Roadmap (Gemini Pro 3 Analysis)

本文件基於現有程式碼結構 (`scripts/`)、待辦事項 (`TODO.md`) 以及專案文件 (`docs/`) 進行綜合分析，構建出 KDE-CLI 的技術演進藍圖。

## 核心演進策略

KDE-CLI 的發展路徑正從「本地開發工具」向「AI 原生與自動化平台」演進。

```mermaid
graph TD
    subgraph Phase1["Phase 1: 堅實基礎 (v1.x)"]
        direction TB
        Base["多環境支援 (Kind/K3d)"]
        Proj["專案生命週期管理"]
        Tools["運維工具整合 (K9s/Dashboard)"]
    end

    subgraph Phase2["Phase 2: 連結與體驗 (v1.x - Current)"]
        direction TB
        Proxy["網路穿透 (Ngrok/Cloudflare)"]
        Dev["遠端開發 (Telepresence/Code-server)"]
        UI["現代化介面 (Headlamp)"]
    end

    subgraph Phase3["Phase 3: 自動化與標準化 (Next)"]
        direction TB
        CLI["非互動式 CLI (CI/CD Ready)"]
        Auto["GitHub Actions 整合"]
        Sec["Distroless Image 優化"]
    end

    subgraph Phase4["Phase 4: 智慧化與雲端 (Future)"]
        direction TB
        AI["AI Agent 整合 (Docs/MCP)"]
        Watch["即時監控 (Watch Dir)"]
        Cloud["多雲支援 (Terraform)"]
    end

    Phase1 --> Phase2
    Phase2 --> Phase3
    Phase3 --> Phase4

    style Phase1 fill:#e3f2fd,stroke:#1565c0,stroke-width:2px
    style Phase2 fill:#e8f5e9,stroke:#2e7d32,stroke-width:2px
    style Phase3 fill:#fff3e0,stroke:#ef6c00,stroke-width:2px
    style Phase4 fill:#f3e5f5,stroke:#7b1fa2,stroke-width:2px
```

## 詳細功能路線圖

```mermaid
timeline
    title KDE-CLI 技術演進時間軸
    section v1.0 - 基礎核心
        環境管理 : Kind / K3d / K8s (External)
        專案管理 : Create / Deploy / Undeploy
        運維工具 : K9s / Dashboard / Load-image
    section v1.1 - 網路擴充
        穿透服務 : Ngrok / Cloudflare Tunnel
        本地整合 : Port Forward (Expose)
        遠端除錯 : Telepresence
    section v1.2 - 開發體驗
        IDE 整合 : Code Server
        集合管理 : Projects Collection
        監控升級 : Headlamp UI
    section v1.3 - 自動化 (開發中)
        CI/CD 整合 : 非互動式指令 (Flags) : GitHub Actions Release
        映像優化 : Distroless Base Image
        環境重構 : 完整參數化支援
    section v2.0 - 智慧化 (計劃中)
        AI 賦能 : MCP Server : AI Agent Docs Generator
        即時開發 : Watch Dir Auto-deploy
        Git 進階 : Git Worktree Support
    section v3.0 - 雲端整合 (展望)
        IaC : Terraform (GKE/AKS/EKS/LKE)
        GitOps : ArgoCD / Flux 整合
```

## 架構依賴分析

此圖展示了功能模組之間的技術依賴關係，以及未來的發展重點。

```mermaid
classDiagram
    class Core_CLI {
        +kde start/stop
        +kde project
        +kde tools
    }

    class Automation {
        <<In Progress>>
        +Non-interactive Flags
        +GitHub Actions
        +Distroless Images
    }

    class AI_Integration {
        <<Future>>
        +MCP Server
        +Agent Docs
        +Watch Mode
    }

    class Cloud_Infra {
        <<Planned>>
        +Terraform
        +Multi-cloud
    }

    Core_CLI <|-- Automation : 增強
    Automation <|-- AI_Integration : 基礎
    Core_CLI <|-- Cloud_Infra : 擴展
    AI_Integration ..> Cloud_Infra : 智慧管理

    note for Automation "目前開發重點：\n讓指令更適合腳本呼叫"
    note for AI_Integration "核心亮點：\nMCP Server 與 AI 文件生成"
```

## 待辦事項狀態矩陣 (基於 TODO.md)

```mermaid
gantt
    title 功能開發進度追蹤
    dateFormat X
    axisFormat %s

    section 已完成 (v1.x)
    環境管理 (Kind/K3d/K8s)    :done, a1, 0, 10
    專案基礎操作 (CRUD)        :done, a2, 0, 10
    監控工具 (K9s/Dashboard)   :done, a3, 0, 10
    網路代理 (Ngrok/CF)        :done, a4, 0, 10
    專案集合 (Projects)        :done, a5, 0, 10

    section 開發中 (v1.3)
    非互動式指令支援           :active, b1, 10, 20
    GitHub Action Release     :active, b2, 10, 20
    Distroless Image 遷移     :active, b3, 10, 20

    section 計劃中 (v2.0+)
    AI Agent 文件生成          :crit, c1, 20, 30
    Watch Dir 自動部署         :c2, 20, 30
    Git Worktree 支援          :c3, 20, 30
    MCP Server 實作            :c4, 20, 30

    section 遠期規劃 (v3.0)
    Terraform (GKE/AKS/EKS)   :d1, 30, 40
```

## 觀察與建議

根據現有的程式碼結構與 `TODO.md`，Gemini Pro 3 提出以下觀察：

1.  **自動化的關鍵性**：目前的 CLI 高度依賴互動式問答 (`read -p`)，這限制了 CI/CD 的整合能力。`TODO.md` 中提到的「非互動式指令」是邁向自動化的關鍵一步，應列為最高優先級。
2.  **AI 整合的潛力**：專案明確列出了 `MCP Server` 與 `AI Agent Docs`，顯示開發者有意將 KDE-CLI 轉型為 AI 友善的工具。這需要標準化的輸出格式 (JSON/YAML) 來支援。
3.  **基礎設施即代碼 (IaC)**：雖然 Terraform 在規劃中，但目前的重心仍在本地開發體驗。建議先完善本地的自動化 (Watch Mode)，再擴展至雲端管理。
