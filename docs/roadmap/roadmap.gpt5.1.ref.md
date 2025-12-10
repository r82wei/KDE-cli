## KDE-CLI Roadmap（GPT-5.1 版本）

KDE-CLI 的目標是成為「開發者友善、只要有 Docker 就能跑起來」的 Kubernetes 開發與實驗平台。  
下列 roadmap 以「階段 × 軌道」的方式描述整體演進。

```mermaid
flowchart LR
    %% 方向與圖例
    classDef phase fill:#e3f2fd,stroke:#1976d2,stroke-width:2px;
    classDef trackCore fill:#e8f5e9,stroke:#388e3c,stroke-width:1px;
    classDef trackDX fill:#fff3e0,stroke:#f57c00,stroke-width:1px;
    classDef trackAuto fill:#fce4ec,stroke:#c2185b,stroke-width:1px;
    classDef trackCloud fill:#ede7f6,stroke:#5e35b1,stroke-width:1px;

    %% Phase 1 ─ 基礎穩定期
    subgraph P1["Phase 1 － 基礎穩定期（v1.x）"]
        direction TB

        subgraph P1_core["核心能力軌：本地 K8s 與專案管理"]
            direction TB
            P1_c1["環境管理 CLI\nkde start/stop/use/status/list\nkind／k3d／外部 kubeconfig"]
            P1_c2["專案管理 CLI\nproject create/fetch/deploy/undeploy\nnamespaces 目錄結構與 project.env"]
            P1_c3["CI/CD 腳本框架\npre/post-build, deploy, undeploy\n以 Shell 為主的可組合流程"]
        end

        subgraph P1_tools["體驗強化軌：觀測與維運工具"]
            direction TB
            P1_t1["監控與管理\nk9s / Dashboard / Headlamp\n一鍵啟動、共用 kubeconfig"]
            P1_t2["開發工具\nexec 進入節點／專案容器\nload-image 匯入本地映像"]
        end
    end

    class P1 phase;
    class P1_core trackCore;
    class P1_tools trackDX;

    %% Phase 2 ─ 網路與遠端開發
    subgraph P2["Phase 2 － 網路與遠端開發（v1.y）"]
        direction TB

        subgraph P2_net["網路與公開軌"]
            direction TB
            P2_n1["Port Forward\nkde expose\n互動式或參數化的本地轉發"]
            P2_n2["公網代理\nkde ngrok / cloudflare-tunnel\n快速分享與安全公開"]
        end

        subgraph P2_remote["遠端開發軌"]
            direction TB
            P2_r1["Telepresence 整合\nreplace / intercept / wiretap / ingest\n將遠端流量導向本地開發容器"]
            P2_r2["Code Server\n以 Web IDE 連到環境\n支援多專案與多環境切換"]
        end
    end

    class P2 phase;
    class P2_net trackDX;
    class P2_remote trackDX;

    %% Phase 3 ─ 非互動與自動化
    subgraph P3["Phase 3 － 非互動與自動化（v2.0 前後）"]
        direction TB

        subgraph P3_cli["非互動 CLI 軌"]
            direction TB
            P3_c1["指令參數化\n所有互動式問題皆可用 flag 解決\n適合 CI/CD pipeline 直接呼叫"]
            P3_c2["結構化輸出\n機器可解析的輸出格式（JSON/YAML）\n方便其他工具或腳本串接"]
        end

        subgraph P3_auto["開發自動化軌"]
            direction TB
            P3_a1["Watch Dir 自動部署\n監看專案目錄變更後觸發 build/deploy\n支援 ignore 與 debounce"]
            P3_a2["GitHub Actions 模板\n提供官方 workflow\n自動建置映像與發布版本"]
        end
    end

    class P3 phase;
    class P3_cli trackAuto;
    class P3_auto trackAuto;

    %% Phase 4 ─ AI 與智慧輔助
    subgraph P4["Phase 4 － AI 與智慧輔助（v2.x）"]
        direction TB

        subgraph P4_mcp["MCP / AI 整合軌"]
            direction TB
            P4_m1["MCP Server\n以 Model Context Protocol 暴露 KDE 能力\n供多種 AI 客戶端直接呼叫"]
            P4_m2["AI 文件與範本生成\n依專案與環境自動產生\nREADME、部署指引、範例腳本"]
            P4_m3["智慧診斷與建議\n解析 kubectl/k9s 輸出\n提供錯誤原因與修正建議"]
        end
    end

    class P4 phase;
    class P4_mcp trackAuto;

    %% Phase 5 ─ 雲端原生與企業級
    subgraph P5["Phase 5 － 雲端原生與企業級（v3.x）"]
        direction TB

        subgraph P5_cloud["雲端 K8s 與 IaC 軌"]
            direction TB
            P5_c1["Terraform 與雲端 K8s\n一鍵建立 GKE / EKS / AKS / LKE 環境\n與 KDE-CLI 的 environments 目錄對應"]
            P5_c2["GitOps 整合\n與 ArgoCD / Flux 搭配\n讓 KDE 專案成為 GitOps 入口"]
        end

        subgraph P5_enterprise["企業能力軌"]
            direction TB
            P5_e1["RBAC 與多租戶支援\n針對不同團隊／專案\n限制可見與可操作的環境與 namespace"]
            P5_e2["審計與稽核\n紀錄關鍵操作（建立環境、部署、移除）\n輸出審計 log 便於外部系統蒐集"]
        end
    end

    class P5 phase;
    class P5_cloud trackCloud;
    class P5_enterprise trackCloud;

    %% Phase 連接關係
    P1 --> P2 --> P3 --> P4 --> P5

    %% 關鍵演進關係（跨階段）
    P1_c3 -.「提供基礎腳本框架」.-> P3_a1
    P2_r1 -.「遠端流量與本地開發體驗」.-> P3_cli
    P3_c2 -.「標準輸出介面」.-> P4_m1
    P3_a2 -.「CI/CD pipeline 穩定後」.-> P5_c1
```

### 閱讀建議

- **自左向右看階段**：從 P1 到 P5，代表功能與使用情境的逐步擴張。  
- **自上而下看軌道**：每個階段內，再依「核心 CLI／開發體驗／自動化／雲端與企業」區分。  
- **虛線標註關聯**：說明某一階段成果如何成為下一階段的技術或產品基礎。  


