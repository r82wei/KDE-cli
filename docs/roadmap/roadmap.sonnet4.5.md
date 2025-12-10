# KDE-CLI Roadmap - 架構與功能全景圖

本文件從多個維度展示 KDE-CLI 的完整架構、功能關係與發展路線。

## 目錄

1. [系統架構層級圖](#系統架構層級圖)
2. [用戶角色與使用場景](#用戶角色與使用場景)
3. [核心功能依賴關係](#核心功能依賴關係)
4. [配置層級與生命週期](#配置層級與生命週期)
5. [開發流程全景圖](#開發流程全景圖)
6. [工具整合生態系](#工具整合生態系)
7. [技術棧演進路線](#技術棧演進路線)

---

## 系統架構層級圖

展示 KDE-CLI 的完整分層架構，從底層容器到上層應用。

```mermaid
graph TB
    subgraph layer_app["🎯 應用層 - 用戶直接交互"]
        direction LR
        cli["KDE CLI<br/>────────<br/>kde.sh<br/>指令入口"]
        
        subgraph commands["核心指令"]
            direction TB
            env_cmd["環境管理<br/>start/stop/restart<br/>use/current/status"]
            proj_cmd["專案管理<br/>create/deploy<br/>fetch/pull/exec"]
            tool_cmd["工具指令<br/>k9s/dashboard<br/>ngrok/telepresence"]
        end
        
        cli --> commands
    end
    
    subgraph layer_orchestration["🔧 編排層 - K8S 環境"]
        direction LR
        
        subgraph k8s_local["本地 K8S"]
            kind["Kind<br/>K8S in Docker"]
            k3d["K3D<br/>K3S in Docker"]
        end
        
        subgraph k8s_remote["遠端 K8S"]
            gke["GKE"]
            eks["EKS"]
            aks["AKS"]
            custom["自建 K8S"]
        end
        
        kubeconfig["Kubeconfig<br/>統一配置"]
    end
    
    subgraph layer_runtime["⚙️ 運行層 - 容器環境"]
        direction LR
        
        subgraph containers["容器類型"]
            dev_container["開發容器<br/>DEVELOP_IMAGE<br/>CI 環境"]
            deploy_container["部署容器<br/>DEPLOY_IMAGE<br/>CD 環境"]
            tool_container["工具容器<br/>K9s/Dashboard<br/>Ngrok/Telepresence"]
        end
        
        subgraph storage["儲存管理"]
            pvc["PVC<br/>local-path"]
            volume["Volume Mount<br/>專案目錄"]
        end
    end
    
    subgraph layer_config["📄 配置層 - 環境變數與腳本"]
        direction LR
        
        subgraph config_hierarchy["配置層級"]
            direction TB
            c1["1️⃣ kde.env<br/>全域配置"]
            c2["2️⃣ current.env<br/>當前環境"]
            c3["3️⃣ k8s.env<br/>環境配置"]
            c4["4️⃣ project.env<br/>專案配置"]
            
            c1 --> c2 --> c3 --> c4
        end
        
        subgraph cicd_scripts["CI/CD 腳本"]
            direction TB
            ci["CI 階段<br/>pre-build.sh<br/>build.sh<br/>post-build.sh"]
            cd["CD 階段<br/>pre-deploy.sh<br/>deploy.sh<br/>post-deploy.sh"]
            cleanup["清理階段<br/>undeploy.sh"]
            
            ci --> cd --> cleanup
        end
    end
    
    subgraph layer_infra["🐳 基礎設施層 - Docker"]
        docker["Docker Engine<br/>────────<br/>容器運行時<br/>網路管理<br/>儲存管理"]
    end
    
    %% 層級之間的關係
    layer_app --> layer_orchestration
    layer_app --> layer_config
    layer_orchestration --> layer_runtime
    layer_config --> layer_runtime
    layer_runtime --> layer_infra
    
    %% 特殊連接
    kubeconfig -.-> k8s_local
    kubeconfig -.-> k8s_remote
    
    style layer_app fill:#e3f2fd,stroke:#1976d2,stroke-width:3px
    style layer_orchestration fill:#f3e5f5,stroke:#7b1fa2,stroke-width:3px
    style layer_runtime fill:#fff3e0,stroke:#f57c00,stroke-width:3px
    style layer_config fill:#e8f5e9,stroke:#388e3c,stroke-width:3px
    style layer_infra fill:#fce4ec,stroke:#c2185b,stroke-width:3px
```

---

## 用戶角色與使用場景

不同角色的用戶如何使用 KDE-CLI 完成各自的任務。

```mermaid
flowchart TB
    subgraph users["👥 用戶角色"]
        direction LR
        developer["🧑‍💻 開發者<br/>Developer"]
        devops["⚙️ DevOps<br/>維運工程師"]
        qa["🧪 測試工程師<br/>QA"]
        sre["🔧 SRE<br/>可靠性工程師"]
    end
    
    subgraph dev_scenario["開發者場景"]
        direction TB
        dev_1["快速本地開發<br/>━━━━━━━━━━"]
        dev_2["本地啟動 kind/k3d"]
        dev_3["建立專案並 clone 程式碼"]
        dev_4["進入開發容器 Hot Reload"]
        dev_5["使用 K9s 監控 Pod 狀態"]
        dev_6["Ngrok 對外展示"]
        
        dev_1 --> dev_2 --> dev_3 --> dev_4 --> dev_5 --> dev_6
    end
    
    subgraph devops_scenario["DevOps 場景"]
        direction TB
        ops_1["CI/CD 流程驗證<br/>━━━━━━━━━━"]
        ops_2["建立模擬環境"]
        ops_3["撰寫 build/deploy 腳本"]
        ops_4["本地測試部署流程"]
        ops_5["驗證 Helm Chart 配置"]
        ops_6["部署到遠端 K8S"]
        
        ops_1 --> ops_2 --> ops_3 --> ops_4 --> ops_5 --> ops_6
    end
    
    subgraph qa_scenario["QA 場景"]
        direction TB
        qa_1["特定版本測試<br/>━━━━━━━━━━"]
        qa_2["切換到測試環境"]
        qa_3["拉取特定 commit 程式碼"]
        qa_4["一鍵部署測試環境"]
        qa_5["Dashboard 檢查服務狀態"]
        qa_6["執行自動化測試"]
        
        qa_1 --> qa_2 --> qa_3 --> qa_4 --> qa_5 --> qa_6
    end
    
    subgraph sre_scenario["SRE 場景"]
        direction TB
        sre_1["遠端環境除錯<br/>━━━━━━━━━━"]
        sre_2["連接生產 K8S"]
        sre_3["Telepresence 攔截流量"]
        sre_4["本地除錯問題"]
        sre_5["Headlamp 監控資源"]
        sre_6["修復並重新部署"]
        
        sre_1 --> sre_2 --> sre_3 --> sre_4 --> sre_5 --> sre_6
    end
    
    developer --> dev_scenario
    devops --> devops_scenario
    qa --> qa_scenario
    sre --> sre_scenario
    
    style users fill:#e1f5fe
    style dev_scenario fill:#f1f8e9,stroke:#689f38
    style devops_scenario fill:#fff3e0,stroke:#f57c00
    style qa_scenario fill:#fce4ec,stroke:#c2185b
    style sre_scenario fill:#e0f2f1,stroke:#00897b
```

---

## 核心功能依賴關係

展示各功能模組之間的依賴關係與協作流程。

```mermaid
graph TB
    subgraph foundation["🏗️ 基礎層"]
        docker["Docker Engine"]
        config_mgmt["配置管理系統<br/>kde.env → current.env<br/>→ k8s.env → project.env"]
        auto_search["自動環境搜尋<br/>從當前目錄往上尋找"]
    end
    
    subgraph env_layer["🌍 環境層"]
        env_create["環境建立<br/>kde start"]
        env_switch["環境切換<br/>kde use"]
        env_status["環境狀態<br/>kde status/list"]
        
        env_kind["Kind 環境"]
        env_k3d["K3D 環境"]
        env_remote["遠端 K8S"]
    end
    
    subgraph project_layer["📦 專案層"]
        proj_create["專案建立<br/>kde proj create"]
        proj_fetch["程式碼管理<br/>fetch/pull"]
        proj_config["專案配置<br/>project.env"]
        
        proj_git["Git 整合"]
        proj_local["本地專案"]
    end
    
    subgraph cicd_layer["🚀 CI/CD 層"]
        cicd_trigger["部署觸發<br/>kde proj deploy"]
        
        subgraph ci_stage["CI 階段"]
            ci_pre["pre-build.sh<br/>前置處理"]
            ci_build["build.sh<br/>建置編譯"]
            ci_post["post-build.sh<br/>後置處理"]
        end
        
        subgraph cd_stage["CD 階段"]
            cd_pre["pre-deploy.sh<br/>部署前準備"]
            cd_deploy["deploy.sh<br/>部署執行"]
            cd_post["post-deploy.sh<br/>部署後處理"]
        end
        
        cicd_trigger --> ci_stage --> cd_stage
    end
    
    subgraph dev_layer["💻 開發層"]
        dev_container["開發容器<br/>DEVELOP_IMAGE"]
        deploy_container["部署容器<br/>DEPLOY_IMAGE"]
        
        hot_reload["Hot Reload<br/>PVC 掛載"]
        telepresence["Telepresence<br/>流量攔截"]
    end
    
    subgraph monitor_layer["📊 監控層"]
        k9s["K9s<br/>TUI 管理"]
        dashboard["Dashboard<br/>Web UI"]
        headlamp["Headlamp<br/>現代化 UI"]
    end
    
    subgraph network_layer["🌐 網路層"]
        expose["Port Forward<br/>本地轉發"]
        ngrok["Ngrok<br/>快速公開"]
        cloudflare["Cloudflare Tunnel<br/>安全公開"]
    end
    
    subgraph tool_layer["🛠️ 工具層"]
        code_server["Code Server<br/>Web IDE"]
        image_loader["映像載入<br/>load-image"]
        exec_tool["容器進入<br/>exec"]
    end
    
    %% 基礎依賴
    foundation --> env_layer
    foundation --> project_layer
    
    %% 環境與專案關係
    env_create --> env_kind
    env_create --> env_k3d
    env_create --> env_remote
    env_layer --> project_layer
    
    %% 專案與開發關係
    proj_create --> proj_config
    proj_fetch --> proj_git
    proj_fetch --> proj_local
    project_layer --> dev_layer
    project_layer --> cicd_layer
    
    %% CI/CD 與容器關係
    ci_stage -.-> dev_container
    cd_stage -.-> deploy_container
    
    %% 開發與監控
    dev_layer --> monitor_layer
    env_layer --> monitor_layer
    
    %% 網路與工具
    env_layer --> network_layer
    project_layer --> network_layer
    dev_layer --> tool_layer
    
    %% 特殊關係
    env_remote -.-> telepresence
    hot_reload -.-> env_kind
    hot_reload -.-> env_k3d
    
    style foundation fill:#e8eaf6,stroke:#3f51b5,stroke-width:3px
    style env_layer fill:#e0f2f1,stroke:#00897b,stroke-width:2px
    style project_layer fill:#fff3e0,stroke:#f57c00,stroke-width:2px
    style cicd_layer fill:#fce4ec,stroke:#c2185b,stroke-width:2px
    style dev_layer fill:#f3e5f5,stroke:#7b1fa2,stroke-width:2px
    style monitor_layer fill:#e8f5e9,stroke:#388e3c,stroke-width:2px
    style network_layer fill:#e3f2fd,stroke:#1976d2,stroke-width:2px
    style tool_layer fill:#fff9c4,stroke:#f9a825,stroke-width:2px
```

---

## 配置層級與生命週期

展示 KDE-CLI 的配置管理機制與資源生命週期。

```mermaid
flowchart TB
    subgraph lifecycle["⏳ 生命週期階段"]
        direction LR
        init["初始化階段<br/>Installation"]
        create["建立階段<br/>Creation"]
        active["運行階段<br/>Active"]
        maintain["維護階段<br/>Maintenance"]
        destroy["銷毀階段<br/>Destruction"]
        
        init --> create --> active --> maintain
        maintain --> active
        maintain --> destroy
    end
    
    subgraph init_phase["🎬 初始化階段"]
        direction TB
        i1["安裝 KDE-CLI<br/>install.sh"]
        i2["建立 kde.env<br/>全域配置"]
        i3["設定工具映像版本<br/>KIND_IMAGE, K9S_IMAGE..."]
        i4["自動環境搜尋機制<br/>向上尋找 kde.env"]
        
        i1 --> i2 --> i3 --> i4
    end
    
    subgraph create_phase["🏗️ 建立階段"]
        direction TB
        c1["建立環境目錄<br/>environments/[name]"]
        c2["生成 k8s.env<br/>環境配置"]
        c3["啟動 K8S<br/>kind/k3d/remote"]
        c4["生成 kubeconfig<br/>連線配置"]
        c5["更新 current.env<br/>設為當前環境"]
        
        c1 --> c2 --> c3 --> c4 --> c5
        
        subgraph k8s_states["K8S 環境狀態"]
            direction LR
            s1["Exist<br/>目錄已建立"]
            s2["Init<br/>kubeconfig 已產生"]
            s3["Running<br/>節點 Ready"]
            
            s1 --> s2 --> s3
        end
        
        c5 --> k8s_states
    end
    
    subgraph active_phase["▶️ 運行階段"]
        direction TB
        a1["建立專案<br/>kde proj create"]
        a2["配置 project.env<br/>Git/Image 設定"]
        a3["抓取程式碼<br/>kde proj fetch/pull"]
        a4["執行 CI/CD<br/>kde proj deploy"]
        
        subgraph config_cascade["配置層級覆蓋"]
            direction LR
            conf1["kde.env<br/>全域"]
            conf2["current.env<br/>當前環境"]
            conf3["k8s.env<br/>環境特定"]
            conf4["project.env<br/>專案特定"]
            
            conf1 -.覆蓋.-> conf2 -.覆蓋.-> conf3 -.覆蓋.-> conf4
        end
        
        a1 --> a2 --> a3 --> a4
        a2 --> config_cascade
    end
    
    subgraph maintain_phase["🔧 維護階段"]
        direction TB
        m1["環境切換<br/>kde use"]
        m2["專案更新<br/>kde proj pull"]
        m3["重新部署<br/>kde proj redeploy"]
        m4["監控除錯<br/>k9s/dashboard"]
        m5["環境重啟<br/>kde restart"]
        
        m1 --> m2 --> m3 --> m4
        m4 --> m5 --> m4
    end
    
    subgraph destroy_phase["🗑️ 銷毀階段"]
        direction TB
        d1["卸載專案<br/>kde proj undeploy"]
        d2["移除專案<br/>kde proj remove"]
        d3["停止環境<br/>kde stop"]
        d4["重置環境<br/>kde reset"]
        d5["移除環境<br/>kde remove"]
        
        d1 --> d2 --> d3
        d3 --> d4
        d3 --> d5
    end
    
    init --> init_phase
    create --> create_phase
    active --> active_phase
    maintain --> maintain_phase
    destroy --> destroy_phase
    
    style lifecycle fill:#fff9c4,stroke:#f9a825,stroke-width:3px
    style init_phase fill:#e8eaf6,stroke:#3f51b5,stroke-width:2px
    style create_phase fill:#e0f2f1,stroke:#00897b,stroke-width:2px
    style active_phase fill:#e8f5e9,stroke:#388e3c,stroke-width:2px
    style maintain_phase fill:#fff3e0,stroke:#f57c00,stroke-width:2px
    style destroy_phase fill:#ffebee,stroke:#c62828,stroke-width:2px
```

---

## 開發流程全景圖

完整的開發到部署流程，包含本地與遠端兩種開發模式。

```mermaid
flowchart TB
    start([開始開發])
    
    subgraph env_choice["🌍 環境選擇"]
        choice{選擇開發模式}
    end
    
    subgraph local_flow["💻 本地開發流程"]
        direction TB
        
        l1["啟動本地 K8S<br/>━━━━━━━━━━<br/>kde start dev-env kind/k3d"]
        l2["建立專案<br/>━━━━━━━━━━<br/>kde proj create myapp"]
        l3["配置專案<br/>━━━━━━━━━━<br/>設定 project.env"]
        
        subgraph local_dev["本地開發環節"]
            direction LR
            ld1["進入開發容器<br/>kde proj exec dev"]
            ld2["程式開發<br/>Hot Reload"]
            ld3["載入映像<br/>kde load-image"]
            
            ld1 --> ld2 --> ld3 --> ld1
        end
        
        l4["執行 CI/CD<br/>━━━━━━━━━━<br/>kde proj deploy"]
        
        subgraph cicd_detail["CI/CD Pipeline"]
            direction TB
            ci1["pre-build.sh"]
            ci2["build.sh"]
            ci3["post-build.sh"]
            cd1["pre-deploy.sh"]
            cd2["deploy.sh<br/>kubectl/helm"]
            cd3["post-deploy.sh"]
            
            ci1 --> ci2 --> ci3 --> cd1 --> cd2 --> cd3
        end
        
        l5["服務監控<br/>━━━━━━━━━━<br/>kde k9s / kde dashboard"]
        
        l1 --> l2 --> l3 --> local_dev --> l4
        l4 --> cicd_detail --> l5
    end
    
    subgraph remote_flow["☁️ 遠端開發流程"]
        direction TB
        
        r1["連接遠端 K8S<br/>━━━━━━━━━━<br/>kde start prod-env k8s"]
        r2["設定 Telepresence<br/>━━━━━━━━━━<br/>kde telepresence intercept"]
        r3["選擇目標 Pod<br/>━━━━━━━━━━<br/>選擇 namespace & workload"]
        
        subgraph remote_dev["遠端開發環節"]
            direction LR
            rd1["進入本地容器<br/>流量攔截到本地"]
            rd2["本地除錯<br/>連接遠端服務"]
            rd3["測試修改<br/>即時生效"]
            
            rd1 --> rd2 --> rd3 --> rd1
        end
        
        r4["驗證完成<br/>━━━━━━━━━━<br/>清理 Telepresence"]
        r5["部署到遠端<br/>━━━━━━━━━━<br/>kde proj deploy"]
        
        r1 --> r2 --> r3 --> remote_dev --> r4 --> r5
    end
    
    subgraph publish_flow["🌐 對外公開"]
        direction TB
        
        p1{需要對外存取?}
        
        subgraph publish_options["公開方式"]
            direction LR
            po1["Port Forward<br/>本地測試"]
            po2["Ngrok<br/>快速展示"]
            po3["Cloudflare Tunnel<br/>安全部署"]
        end
        
        p1 -->|是| publish_options
    end
    
    subgraph monitor_flow["📊 監控與除錯"]
        direction TB
        
        subgraph monitor_tools["監控工具"]
            direction LR
            mt1["K9s<br/>終端管理"]
            mt2["Dashboard<br/>Web UI"]
            mt3["Headlamp<br/>現代化 UI"]
        end
        
        subgraph debug_tools["除錯工具"]
            direction LR
            dt1["exec<br/>進入容器"]
            dt2["tail<br/>查看日誌"]
            dt3["expose<br/>端口轉發"]
        end
        
        monitor_tools --> debug_tools
    end
    
    subgraph version_control["📦 版本控制"]
        direction TB
        vc1["配置版本化<br/>━━━━━━━━━━<br/>environments/ 目錄"]
        vc2["腳本版本化<br/>━━━━━━━━━━<br/>CI/CD 腳本"]
        vc3["推送到 Git<br/>━━━━━━━━━━<br/>團隊共享"]
        
        vc1 --> vc2 --> vc3
    end
    
    complete([完成])
    
    start --> env_choice
    choice -->|本地開發| local_flow
    choice -->|遠端除錯| remote_flow
    
    local_flow --> publish_flow
    remote_flow --> publish_flow
    
    publish_flow --> monitor_flow
    monitor_flow --> version_control
    version_control --> complete
    
    style local_flow fill:#e8f5e9,stroke:#388e3c,stroke-width:3px
    style remote_flow fill:#e3f2fd,stroke:#1976d2,stroke-width:3px
    style publish_flow fill:#fff3e0,stroke:#f57c00,stroke-width:2px
    style monitor_flow fill:#f3e5f5,stroke:#7b1fa2,stroke-width:2px
    style version_control fill:#fce4ec,stroke:#c2185b,stroke-width:2px
```

---

## 工具整合生態系

KDE-CLI 整合的所有工具及其用途。

```mermaid
mindmap
  root((KDE-CLI<br/>工具生態系))
    [環境管理工具]
      kind
        本地 K8S 環境
        Docker 容器模擬
        快速啟動
      k3d
        輕量級 K3S
        資源占用少
        適合 CI/CD
      kubectl
        K8S 操作
        資源管理
        內建於部署映像
      helm
        應用部署
        Chart 管理
        內建於部署映像
    
    [監控與管理]
      K9s
        終端 UI 管理
        即時監控
        快捷鍵操作
      Dashboard
        Kubernetes 官方 UI
        Web 介面
        資源視覺化
      Headlamp
        現代化 Web UI
        使用者友善
        擴充性強
    
    [網路與代理]
      Ngrok
        快速公開服務
        即時 URL
        適合測試展示
      Cloudflare Tunnel
        安全隧道
        自訂域名
        SSL 加密
      Telepresence
        流量攔截
        本地除錯
        環境同步
      Port Forward
        本地端口轉發
        簡單直接
        開發測試
    
    [開發工具]
      Code Server
        Web IDE
        VS Code 介面
        遠端開發
      Docker
        容器運行時
        映像管理
        網路儲存
      Git
        版本控制
        專案管理
        協作開發
    
    [儲存與配置]
      local-path-provisioner
        本地 PV
        動態供應
        Hot Reload
      ConfigMap
        配置管理
        環境變數
        配置注入
      Secret
        敏感資訊
        加密儲存
        安全管理
```

---

## 技術棧演進路線

從當前版本到未來計劃的技術演進。

```mermaid
timeline
    title KDE-CLI 技術棧演進路線
    
    section Phase 1: 核心基礎 (v1.0-v1.2) ✅
        容器化基礎
            : Docker Engine
            : 映像管理機制
            : 容器編排
        
        本地 K8S
            : Kind 整合
            : K3D 整合
            : kubeconfig 管理
        
        配置系統
            : 分層配置 (kde.env → project.env)
            : 自動環境搜尋
            : 環境變數注入
        
        CI/CD Pipeline
            : Shell 腳本驅動
            : 多階段執行 (CI/CD)
            : 自訂執行環境
    
    section Phase 2: 工具生態 (v1.1-v1.2) ✅
        監控工具
            : K9s 整合
            : Dashboard 整合
            : Headlamp 整合
        
        網路代理
            : Ngrok 整合
            : Cloudflare Tunnel
            : Telepresence 流量攔截
        
        開發體驗
            : Code Server Web IDE
            : Hot Reload 支援
            : 專案集合管理
    
    section Phase 3: 自動化增強 (v1.3-v2.0) ⏳
        非互動模式
            : CLI 參數化
            : CI/CD 友善
            : 腳本自動化
        
        監控與反饋
            : Watch Dir 自動部署
            : 檔案變更觸發
            : 即時反饋機制
        
        GitHub Action
            : 自動建置映像
            : 版本發布自動化
            : 測試自動化
    
    section Phase 4: AI 整合 (v2.0) 📋
        MCP Server
            : Model Context Protocol
            : AI Agent 基礎設施
            : 工具標準化介面
        
        智能化輔助
            : AI 文件生成
            : 部署建議系統
            : 錯誤診斷輔助
        
        優化建議
            : 資源使用分析
            : 效能優化建議
            : 配置最佳實踐
    
    section Phase 5: Git 進階 (v2.0) 📋
        Worktree 支援
            : 多分支並行開發
            : 分支環境隔離
            : 快速切換測試
        
        版本管理
            : 環境快照
            : 配置版本追蹤
            : 回滾機制
    
    section Phase 6: 雲端原生 (v3.0) 📋
        Terraform 整合
            : Infrastructure as Code
            : 多雲部署
            : 狀態管理
        
        雲端 K8S
            : GKE (Google)
            : EKS (AWS)
            : AKS (Azure)
            : LKE (Linode)
        
        GitOps
            : 宣告式部署
            : ArgoCD 整合
            : Flux 整合
        
        企業功能
            : RBAC 精細控制
            : Audit Log
            : 合規性支援
```

---

## 功能成熟度矩陣

各功能模組的當前狀態與未來規劃。

```mermaid
quadrantChart
    title 功能成熟度與優先級矩陣
    x-axis 低成熟度 --> 高成熟度
    y-axis 低優先級 --> 高優先級
    quadrant-1 持續優化
    quadrant-2 核心優勢
    quadrant-3 未來探索
    quadrant-4 重點發展
    
    環境管理: [0.9, 0.95]
    專案管理: [0.85, 0.9]
    CI/CD Pipeline: [0.8, 0.85]
    K9s 整合: [0.9, 0.7]
    Dashboard: [0.85, 0.65]
    Ngrok: [0.8, 0.6]
    Cloudflare Tunnel: [0.75, 0.65]
    Telepresence: [0.7, 0.7]
    Code Server: [0.8, 0.6]
    
    非互動模式: [0.3, 0.9]
    MCP Server: [0.1, 0.85]
    Watch Dir: [0.2, 0.8]
    AI Agent: [0.15, 0.75]
    Git Worktree: [0.1, 0.7]
    
    Terraform 整合: [0.05, 0.4]
    雲端 K8S: [0.1, 0.45]
    GitOps: [0.05, 0.35]
    Distroless Image: [0.2, 0.3]
```

---

## 架構設計原則

KDE-CLI 遵循的核心設計理念。

```mermaid
flowchart LR
    subgraph principles["🎯 設計原則"]
        direction TB
        
        subgraph p1["容器優先<br/>Container First"]
            direction TB
            p1a["所有工具容器化"]
            p1b["環境隔離"]
            p1c["一致性保證"]
        end
        
        subgraph p2["約定優於配置<br/>Convention over Configuration"]
            direction TB
            p2a["標準目錄結構"]
            p2b["預設合理值"]
            p2c["減少配置複雜度"]
        end
        
        subgraph p3["漸進式複雜度<br/>Progressive Complexity"]
            direction TB
            p3a["基本操作簡單"]
            p3b["進階功能可選"]
            p3c["不強制使用"]
        end
        
        subgraph p4["模組化設計<br/>Modular Architecture"]
            direction TB
            p4a["獨立功能模組"]
            p4b["清晰職責分離"]
            p4c["易於擴展"]
        end
        
        subgraph p5["配置即代碼<br/>Configuration as Code"]
            direction TB
            p5a["環境可版本化"]
            p5b["Git 友善"]
            p5c["團隊協作"]
        end
        
        subgraph p6["開發者體驗<br/>Developer Experience"]
            direction TB
            p6a["直覺的指令"]
            p6b["清晰的錯誤訊息"]
            p6c["完整的文件"]
        end
    end
    
    subgraph benefits["✨ 帶來的好處"]
        direction TB
        
        b1["快速上手<br/>5分鐘開始"]
        b2["環境一致<br/>消除差異"]
        b3["團隊協作<br/>配置共享"]
        b4["靈活擴展<br/>滿足需求"]
        b5["版本管理<br/>追蹤變更"]
        b6["降低門檻<br/>只需 Docker"]
    end
    
    principles --> benefits
    
    style principles fill:#e8f5e9,stroke:#388e3c,stroke-width:3px
    style benefits fill:#e3f2fd,stroke:#1976d2,stroke-width:3px
    style p1 fill:#fff3e0,stroke:#f57c00
    style p2 fill:#f3e5f5,stroke:#7b1fa2
    style p3 fill:#fce4ec,stroke:#c2185b
    style p4 fill:#e0f2f1,stroke:#00897b
    style p5 fill:#e8eaf6,stroke:#3f51b5
    style p6 fill:#fff9c4,stroke:#f9a825
```

---

## 相關文件

- [核心概念](./principle.md)
- [工作流程](./workflow.md)
- [開發架構](./development-architecture.md)
- [環境變數說明](./environment-variables.md)
- [資料夾結構](./folder.structure.md)
- [Roadmap (Opus 4.5 版本)](./roadmap.Opus4.5.md)

---

## 總結

KDE-CLI 是一個全面的 Kubernetes 開發環境解決方案：

- **🏗️ 完整架構**: 從 Docker 到應用層的完整技術棧
- **👥 多角色支援**: 滿足開發者、DevOps、QA、SRE 的不同需求
- **🔄 成熟工作流**: 涵蓋開發、測試、部署、監控的完整流程
- **🛠️ 豐富生態**: 整合業界主流工具，提供一站式解決方案
- **📈 持續演進**: 從基礎功能到 AI 整合、雲端原生的長期規劃
- **🎯 設計優良**: 遵循現代軟體工程的最佳實踐

KDE-CLI 致力於簡化 Kubernetes 開發體驗，讓團隊專注於業務價值的創造！

