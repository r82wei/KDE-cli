---
name: kde-cli
description: Assists with KDE-CLI (Kubernetes Development Environment CLI) - a unified Kubernetes dev workspace management tool. Use when users ask about kde commands, environment setup (kind/k3d/external k8s), project lifecycle, CI/CD pipeline configuration, writing build/deploy shell scripts, project.env configuration, debugging pipelines, or using integrated tools like K9s, Telepresence, Cloudflare Tunnel, Ngrok, and Headlamp. Also use when discussing KDE-CLI architecture, design principles, or best practices.
---

# KDE-CLI

KDE-CLI 是以 Kubernetes 為一級目標平台的開發環境與交付流程管理工具。核心理念：**Container First**（只需 Docker）、**Environment as Code**（環境可重現、可版控）、**一個 CLI 統管從建立環境到部署的完整生命週期**。

> **KDE ≠ KDE Desktop/Plasma**。kde-cli 是 DevOps / Platform Engineering 工具。

## 核心架構

```
workspace/                          ← KDE_PATH（由 kde.env 定位）
├── kde.env                         # 全域工具映像版本（✅ 版控）
├── current.env                     # 當前環境（❌ 不版控）
└── environments/<env_name>/
    ├── k8s.env                     # 環境基本配置（✅ 版控）
    ├── .env                        # 環境本地配置（❌ 不版控）
    ├── kubeconfig/config           # K8s 連線（❌ 不版控）
    ├── init.sh                     # 環境初始化腳本（✅ 版控）
    ├── kind-config.template.yaml   # Kind 配置模板（✅ 版控）
    └── namespaces/<project_name>/
        ├── project.env             # 專案配置（✅ 版控）
        ├── .env                    # 專案本地/敏感配置（❌ 不版控）
        ├── build.sh / deploy.sh    # CI/CD 腳本（✅ 版控）
        ├── .pipeline.env           # 階段間傳遞變數（自動生成，❌ 不版控）
        └── <repo>/                 # Git 倉庫內容（❌ 不版控）
```

**Project = K8s Namespace**：每個專案對應一個獨立的 K8s Namespace。

## 環境類型

| 類型 | 指令 | 適用場景 |
|------|------|----------|
| Kind | `kde start dev-env kind` | 本地開發、功能測試 |
| K3D | `kde start test-env k3d` | 輕量快速、CI/CD |
| 外部 K8s | `kde start prod-env k8s` | 雲端/自建集群 |

## 常用指令

### 環境管理
```bash
kde init                                  # 初始化 workspace
kde start <env> [kind|k3d|k8s]           # 建立/啟動環境
kde use [env]                             # 切換環境
kde current / kde cur                     # 查看當前環境
kde list / kde ls                         # 列出所有環境
kde status                                # 環境狀態
kde stop / kde restart / kde reset <env>
kde remove / kde rm <env>
```

### 專案管理
```bash
kde proj create <name>                    # 建立專案（互動式）
kde proj fetch <name> <url> <branch>      # 從 Git 抓取
kde proj pull [name] [-f]                 # 更新程式碼（-f 強制重新 clone）
kde proj list / kde proj ls               # 列出專案
kde proj pipeline <name> [options]        # 執行 Pipeline（= 部署）
kde proj exec <name> [develop|deploy] [port]  # 進入容器
kde proj tail [name]                      # 查看 Pod 日誌
kde proj undeploy / redeploy <name>       # 卸載/重新部署
kde proj ingress <name>                   # 建立 Ingress
```

### Pipeline 執行選項
```bash
kde proj pipeline myapp                   # 執行完整 Pipeline
kde proj pipeline myapp --only build      # 只執行單一階段
kde proj pipeline myapp --from test       # 從指定階段開始
kde proj pipeline myapp --to build        # 執行到指定階段
kde proj pipeline myapp --from test --to deploy
kde proj pipeline myapp --manual          # 進入容器手動模式（除錯用）
kde proj pipeline myapp --only build --manual  # 進入特定階段容器
```

### 開發工具
```bash
kde k9s [-n namespace] [-p port]          # TUI K8s 管理工具
kde headlamp [-p port] [-d]               # Web UI Dashboard（預設 4466）
kde expose [ns] service <svc> <target> <local>  # Port Forward
kde load-image <image> [env]              # 載入映像到 kind/k3d
kde code-server [-p port] [-d]            # Web VSCode（預設 8080）
```

### Telepresence
```bash
kde telepresence replace <ns> <workload>    # 攔截流量 + 停止遠端 Pod
kde telepresence intercept <ns> <workload>  # 攔截流量（不停止遠端 Pod）
kde telepresence wiretap <ns> <workload>    # 複製流量（觀察模式）
kde telepresence list [ns]
kde telepresence uninstall [ns]
kde telepresence clear                      # 停止所有連線
```

### 對外代理
```bash
kde ngrok service/pod/ingress
kde cloudflare-tunnel service -d myapp.example.com
kde cloudflare-tunnel service -q                    # 快速模式（隨機域名）
kde cloudflare-tunnel url -u http://localhost:8080
```

## project.env 配置

```bash
# Git
GIT_REPO_URL=https://github.com/user/repo.git
GIT_REPO_BRANCH=main

# 容器映像
DEVELOP_IMAGE=node:20                      # 開發容器（kde proj exec develop）
DEPLOY_IMAGE=r82wei/deploy-env:1.0.0       # 部署容器（包含 kubectl/helm/docker/aws/az）

# Pipeline 階段定義
KDE_PIPELINE_STAGES="build,test,deploy"

# 各階段配置（IMAGE 未設定時使用 DEPLOY_IMAGE）
KDE_PIPELINE_STAGE_build_IMAGE=node:20
KDE_PIPELINE_STAGE_build_SCRIPT=build.sh

KDE_PIPELINE_STAGE_test_IMAGE=node:20
KDE_PIPELINE_STAGE_test_SCRIPT=test.sh

KDE_PIPELINE_STAGE_deploy_IMAGE=r82wei/deploy-env:1.0.0
KDE_PIPELINE_STAGE_deploy_SCRIPT=deploy.sh

# 階段控制旗標
KDE_PIPELINE_STAGE_lint_SKIP=true           # 跳過此階段
KDE_PIPELINE_STAGE_lint_MANUAL_ONLY=true    # 只能 --manual 觸發
KDE_PIPELINE_STAGE_lint_ALLOW_FAILURE=true  # 失敗不中斷 Pipeline
KDE_PIPELINE_STAGE_preview_PAUSE=true       # 執行後暫停等確認

# 錯誤處理
KDE_PIPELINE_FAIL_FAST=false               # 預設 true（任何失敗立即停止）

# 掛載（所有階段共用）
KDE_MOUNT_SSH=${HOME}/.ssh:${HOME}/.ssh:ro

# 掛載（特定階段）
KDE_PIPELINE_STAGE_release_MOUNT_DOCKER=${HOME}/.docker:/root/.docker:ro

# Helm 配置（可選）
HELM_CONFIG_HOME=${PROJECT_PATH}/.helm/config
HELM_CACHE_HOME=${PROJECT_PATH}/.helm/cache
HELM_DATA_HOME=${PROJECT_PATH}/.helm/data
HELM_PLUGINS=${PROJECT_PATH}/.helm/plugins
```

**重要**：`KDE_PATH`、`PROJECT_PATH`、`CUR_ENV`、`KUBECONFIG`、`ENVIROMENTS_PATH` 在 `project.env` 中可用，但 **不能直接在 shell 腳本內使用**。必須在 `project.env` 中先定義為新變數（如 `HELM_CONFIG_HOME=${PROJECT_PATH}/.helm/config`），才能在腳本中使用。

## 環境變數載入順序

```
kde.env → k8s.env → env .env → project.env → project .env → .pipeline.env
```

後載入的同名變數會覆蓋先前的。

## 階段間環境變數傳遞

```bash
# build.sh 或 release.sh 輸出
echo "APP_IMAGE=registry.example.com/myapp:1.0.0" >> .pipeline.env
echo "APP_VERSION=1.0.0" >> .pipeline.env

# deploy.sh 讀取
source .pipeline.env
kubectl set image deployment/myapp myapp=${APP_IMAGE} -n myapp
```

## 開發模式

| 模式 | 指令 | K8s 功能 | Hot Reload | 適用情境 |
|------|------|---------|-----------|---------|
| 開發容器 | `kde proj exec myapp develop` | ❌ | ✅ | 快速開發、單元測試 |
| K8s + PVC | 部署含 PVC 的 Deployment | ✅ | ✅ | 整合測試、接近生產環境 |
| Telepresence | `kde telepresence replace myapp <workload>` | ✅ | ✅ | 遠端 K8s 開發 |

### PVC Hot Reload 原理

PVC 名稱直接對應到 `namespaces/<project>/<pvc-name>/` 資料夾，local-path-provisioner 自動掛載，本地修改即時同步到 Pod。

## 除錯

```bash
# KDE CLI 層級除錯（顯示每個 shell 指令）
KDE_DEBUG=true kde proj pipeline myapp

# 進入 Pipeline 階段容器手動測試
kde proj pipeline myapp --only build --manual
# 容器內可執行 env 查看環境變數、手動執行 ./build.sh

# 腳本內加 set -x 追蹤執行
set -x  # 加在 build.sh 或 deploy.sh 開頭
```

## 常見工作流程

### 快速開始

```bash
kde init
kde start dev-env kind
kde proj create myapp
kde proj fetch myapp https://github.com/user/myapp.git main
# 編寫 project.env、build.sh、deploy.sh
kde proj pipeline myapp
kde k9s
```

### 多環境部署

```bash
kde use dev-env && kde proj pipeline myapp    # 開發環境
kde use test-env && kde proj pipeline myapp   # 測試環境
kde use prod-env && kde proj pipeline myapp   # 生產環境
```

### 新成員 Onboarding

```bash
git clone <workspace-repo>
cd workspace
kde start dev-env kind
kde proj pipeline myapp   # 一鍵部署
```

## Best Practices

- 生產環境 **必須** 建立 `undeploy.sh`（否則拒絕執行）；本地環境無則預設刪除 namespace
- 敏感資訊（密碼、Token）放 `.env`，不提交版本控制
- `DEVELOP_IMAGE` 選用對應技術棧映像（`node:20`、`python:3.11`、`golang:1.21`）
- `DEPLOY_IMAGE` 預設使用 `r82wei/deploy-env:1.0.0`（含 kubectl/helm/docker/aws-cli/az-cli）
- 可選階段設 `MANUAL_ONLY` 或 `ALLOW_FAILURE`，不要讓 lint 阻斷部署流程
- 使用 `PAUSE` 在 deploy 前執行 `helm diff` / `kubectl diff` 預覽變更

## 附加參考

- 完整 Pipeline 配置範例 → [pipeline-patterns.md](pipeline-patterns.md)
- 完整指令速查表 → [commands.md](commands.md)
