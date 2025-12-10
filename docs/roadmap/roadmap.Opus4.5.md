# KDE-CLI Roadmap

本文件展示 KDE-CLI 的發展藍圖，包含已完成功能、開發中功能以及未來規劃。

## 版本路線圖

```mermaid
timeline
    title KDE-CLI 發展路線
    section v1.0 基礎版本
        已完成 : 環境管理 (kind/k3d/k8s)
               : 專案管理 (create/deploy/undeploy)
               : CI/CD Pipeline
               : 監控工具 (k9s/dashboard/headlamp)
    section v1.1 網路擴充
        已完成 : Ngrok 整合
               : Cloudflare Tunnel
               : Port Forward
               : Telepresence
    section v1.2 開發體驗
        已完成 : Code Server 整合
               : 專案集合管理
               : 版本機制
        開發中 : 非互動式指令支援
    section v2.0 進階功能
        計劃中 : MCP Server
               : Watch Dir 自動部署
               : AI Agent 文件生成
               : Git Worktree 分支環境
    section v3.0 雲端整合
        計劃中 : GKE by Terraform
               : AKS by Terraform
               : EKS by Terraform
               : LKE by Terraform
```

## 功能發展流程圖

```mermaid
flowchart TB
    subgraph v1_core["🎯 v1.0 核心功能 (已完成)"]
        direction TB
        env_mgmt["環境管理<br/>━━━━━━━━<br/>✅ kde start/stop/restart<br/>✅ kde use/current<br/>✅ kde status/list<br/>✅ kde remove/reset"]
        
        k8s_type["K8S 類型支援<br/>━━━━━━━━<br/>✅ kind 本地環境<br/>✅ k3d 輕量環境<br/>✅ 外部 K8S 連接"]
        
        proj_mgmt["專案管理<br/>━━━━━━━━<br/>✅ project create/remove<br/>✅ project fetch/pull<br/>✅ project deploy/undeploy<br/>✅ project exec/tail"]
        
        cicd["CI/CD Pipeline<br/>━━━━━━━━<br/>✅ pre-build.sh<br/>✅ build.sh<br/>✅ post-build.sh<br/>✅ pre-deploy.sh<br/>✅ deploy.sh<br/>✅ post-deploy.sh"]
    end

    subgraph v1_tools["🛠️ v1.x 工具整合 (已完成)"]
        direction TB
        monitor["監控工具<br/>━━━━━━━━<br/>✅ K9s TUI<br/>✅ Kubernetes Dashboard<br/>✅ Headlamp Web UI"]
        
        proxy["代理工具<br/>━━━━━━━━<br/>✅ Ngrok<br/>✅ Cloudflare Tunnel<br/>✅ Port Forward<br/>✅ Telepresence"]
        
        dev_tools["開發工具<br/>━━━━━━━━<br/>✅ Code Server<br/>✅ load-image<br/>✅ exec 進入容器"]
    end

    subgraph v2_features["🚀 v2.0 進階功能 (計劃中)"]
        direction TB
        auto["自動化<br/>━━━━━━━━<br/>⏳ Watch Dir 自動部署<br/>⏳ GitHub Action 自動建置"]
        
        ai["AI 整合<br/>━━━━━━━━<br/>⏳ MCP Server<br/>⏳ AI Agent 文件生成<br/>⏳ 智能部署建議"]
        
        git["Git 進階<br/>━━━━━━━━<br/>⏳ Git Worktree 分支環境<br/>⏳ 多分支並行開發"]
        
        optimize["優化<br/>━━━━━━━━<br/>⏳ Distroless Image<br/>⏳ 非互動式指令"]
    end

    subgraph v3_cloud["☁️ v3.0 雲端整合 (計劃中)"]
        direction TB
        cloud_k8s["雲端 K8S<br/>━━━━━━━━<br/>📋 GKE by Terraform<br/>📋 AKS by Terraform<br/>📋 EKS by Terraform<br/>📋 LKE by Terraform"]
    end

    v1_core --> v1_tools
    v1_tools --> v2_features
    v2_features --> v3_cloud

    style v1_core fill:#d4edda,stroke:#28a745
    style v1_tools fill:#d1ecf1,stroke:#17a2b8
    style v2_features fill:#fff3cd,stroke:#ffc107
    style v3_cloud fill:#e7f3ff,stroke:#007bff
```

## 詳細功能狀態

```mermaid
flowchart LR
    subgraph legend["圖例"]
        done["✅ 已完成"]
        progress["⏳ 開發中"]
        planned["📋 計劃中"]
    end

    subgraph core["核心指令"]
        direction TB
        c1["✅ kde list/ls"]
        c2["✅ kde start/create"]
        c3["✅ kde stop"]
        c4["✅ kde restart"]
        c5["✅ kde status"]
        c6["✅ kde remove/rm"]
        c7["✅ kde current/cur"]
        c8["✅ kde use"]
        c9["✅ kde reset"]
        c10["✅ kde exec"]
        c11["✅ kde load-image"]
    end

    subgraph project["專案指令"]
        direction TB
        p1["✅ project list/ls"]
        p2["✅ project create"]
        p3["✅ project fetch"]
        p4["✅ project pull"]
        p5["✅ project link"]
        p6["✅ project deploy"]
        p7["✅ project undeploy"]
        p8["✅ project redeploy"]
        p9["✅ project tail"]
        p10["✅ project remove"]
        p11["✅ project exec"]
        p12["✅ project ingress"]
    end

    subgraph tools["工具指令"]
        direction TB
        t1["✅ kde k9s"]
        t2["✅ kde dashboard"]
        t3["✅ kde headlamp"]
        t4["✅ kde expose"]
        t5["✅ kde ngrok"]
        t6["✅ kde cloudflare-tunnel"]
        t7["✅ kde telepresence"]
        t8["✅ kde code-server"]
    end

    subgraph future["未來功能"]
        direction TB
        f1["📋 Terraform 整合"]
        f2["⏳ MCP Server"]
        f3["⏳ Watch Dir 自動部署"]
        f4["⏳ AI Agent 文件"]
        f5["⏳ Git Worktree"]
        f6["📋 GKE/AKS/EKS/LKE"]
    end

    style done fill:#28a745,color:#fff
    style progress fill:#ffc107,color:#000
    style planned fill:#007bff,color:#fff
    style core fill:#d4edda
    style project fill:#d1ecf1
    style tools fill:#fff3cd
    style future fill:#e7f3ff
```

## 開發優先順序

```mermaid
flowchart TD
    subgraph priority_high["🔴 高優先級"]
        h1["非互動式指令支援<br/>讓 CI/CD 自動化更容易"]
        h2["GitHub Action<br/>自動建置 Docker Image"]
        h3["MCP Server<br/>AI 整合基礎"]
    end

    subgraph priority_medium["🟡 中優先級"]
        m1["Watch Dir 自動部署<br/>提升開發效率"]
        m2["AI Agent 文件生成<br/>智能化開發輔助"]
        m3["Git Worktree 分支<br/>多版本並行開發"]
    end

    subgraph priority_low["🟢 低優先級"]
        l1["Distroless Image<br/>安全性優化"]
        l2["Terraform 雲端整合<br/>GKE/AKS/EKS/LKE"]
    end

    h1 --> m1
    h2 --> m2
    h3 --> m2
    m1 --> l1
    m2 --> l2
    m3 --> l2

    style priority_high fill:#ffcccc
    style priority_medium fill:#fff3cd
    style priority_low fill:#d4edda
```

## 架構演進

```mermaid
flowchart TB
    subgraph current["現在: 本地優先"]
        local_k8s["本地 K8S<br/>(kind/k3d)"]
        remote_connect["遠端連接<br/>(kubeconfig)"]
        shell_cicd["Shell CI/CD<br/>(腳本驅動)"]
    end

    subgraph mid_term["中期: 自動化增強"]
        watch["檔案監控<br/>自動部署"]
        ai_assist["AI 輔助<br/>智能建議"]
        mcp["MCP Server<br/>工具整合"]
    end

    subgraph long_term["長期: 雲端原生"]
        terraform["Terraform<br/>基礎設施即代碼"]
        multi_cloud["多雲支援<br/>GKE/AKS/EKS/LKE"]
        gitops["GitOps<br/>宣告式部署"]
    end

    current --> mid_term
    mid_term --> long_term

    style current fill:#d4edda,stroke:#28a745
    style mid_term fill:#fff3cd,stroke:#ffc107
    style long_term fill:#e7f3ff,stroke:#007bff
```

## 版本里程碑

| 版本 | 狀態 | 主要功能 | 預計時程 |
|------|------|----------|----------|
| v1.0 | ✅ 已發布 | 核心環境管理、專案管理、CI/CD Pipeline | - |
| v1.1 | ✅ 已發布 | Ngrok、Cloudflare Tunnel、Telepresence | - |
| v1.2 | ✅ 已發布 | Code Server、專案集合、版本機制 | - |
| v1.3 | ⏳ 開發中 | 非互動式指令、GitHub Action | Q1 2025 |
| v2.0 | 📋 計劃中 | MCP Server、AI 整合、Watch Dir | Q2 2025 |
| v3.0 | 📋 計劃中 | Terraform 雲端整合 | Q3-Q4 2025 |

## 貢獻指南

歡迎貢獻！請參考以下優先順序：

1. **Bug 修復** - 最高優先
2. **文件改進** - 高優先
3. **高優先級功能** - 中優先
4. **其他功能** - 視情況

## 相關文件

- [核心概念](./principle.md)
- [工作流程](./workflow.md)
- [開發架構](./development-architecture.md)
- [環境變數說明](./environment-variables.md)

