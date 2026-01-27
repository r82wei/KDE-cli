# Pipeline 機制遷移指南

## 概述

KDE CLI 已升級為支援更靈活的 Pipeline 機制，包括：

1. **標準 CICD 流程**（預設）- Build → Test → Release → Deploy
2. **自定義 Pipeline** - 靈活定義階段、順序和執行環境
3. **向後相容** - 舊的 build/deploy 流程仍然完全支援

## 新舊機制對照

### 舊機制（仍然支援）

```bash
# project.env
GIT_REPO_URL=https://github.com/user/repo.git
GIT_REPO_BRANCH=main
DEVELOP_IMAGE=node:20
DEPLOY_IMAGE=r82wei/deploy-env:1.0.0

# 可選的自訂腳本配置
KDE_PROJECT_PRE_BUILD_SCRIPT=custom-pre-build.sh
KDE_PROJECT_BUILD_SCRIPT=custom-build.sh
KDE_PROJECT_POST_BUILD_SCRIPT=custom-post-build.sh
KDE_PROJECT_PRE_DEPLOY_SCRIPT=custom-pre-deploy.sh
KDE_PROJECT_DEPLOY_SCRIPT=custom-deploy.sh
KDE_PROJECT_POST_DEPLOY_SCRIPT=custom-post-deploy.sh
```

執行流程：
- `kde project build myapp` → 執行 pre-build.sh, build.sh, post-build.sh
- `kde project deploy myapp` → 執行 pre-deploy.sh, deploy.sh, post-deploy.sh

### 新機制（標準 CICD 流程）

```bash
# project.env
GIT_REPO_URL=https://github.com/user/repo.git
GIT_REPO_BRANCH=main
DEVELOP_IMAGE=node:20
DEPLOY_IMAGE=r82wei/deploy-env:1.0.0

# 不需要設定 KDE_CICD_STAGES（使用預設）
```

目錄結構：
```
namespaces/myapp/
├── project.env
├── build.sh      # CICD 階段
├── test.sh       # CICD 階段
├── release.sh    # CICD 階段
└── deploy.sh     # CICD 階段
```

執行流程：
- `kde project deploy myapp` → 執行 build.sh, test.sh, release.sh, deploy.sh（存在的話）

### 新機制（自定義 Pipeline）

```bash
# project.env
GIT_REPO_URL=https://github.com/user/repo.git
GIT_REPO_BRANCH=main
DEVELOP_IMAGE=node:20
DEPLOY_IMAGE=r82wei/deploy-env:1.0.0

# 定義自定義 Pipeline
KDE_CICD_STAGES="lint build test deploy monitor"

# 每個階段的配置（可選）
KDE_CICD_STAGE_lint_SCRIPT=lint.sh
KDE_CICD_STAGE_lint_IMAGE=node:20

KDE_CICD_STAGE_build_SCRIPT=build.sh
KDE_CICD_STAGE_build_IMAGE=node:20

KDE_CICD_STAGE_test_SCRIPT=test.sh
KDE_CICD_STAGE_test_IMAGE=node:20

KDE_CICD_STAGE_deploy_SCRIPT=deploy.sh
KDE_CICD_STAGE_deploy_IMAGE=r82wei/deploy-env:1.0.0

KDE_CICD_STAGE_monitor_SCRIPT=monitor.sh
KDE_CICD_STAGE_monitor_IMAGE=r82wei/deploy-env:1.0.0

# 錯誤處理
KDE_DEVOPS_FAIL_FAST=true
KDE_DEVOPS_AUTO_ROLLBACK=true
```

執行流程：
- `kde project deploy myapp` → 執行所有定義的階段（lint → build → test → deploy → monitor）

## 遷移步驟

### 選項 1：保持不變（推薦）

如果目前的 build/deploy 流程運作正常，無需做任何修改，系統會自動使用舊的流程。

### 選項 2：遷移到標準 CICD 流程

**步驟 1：確認腳本檔案**

```bash
cd environments/your-env/namespaces/myapp

# 確保有以下檔案（如果沒有則創建）
# build.sh, test.sh, release.sh, deploy.sh
```

**步驟 2：移除舊的配置（可選）**

```bash
# 編輯 project.env，移除以下配置（如果存在）
# KDE_PROJECT_PRE_BUILD_SCRIPT=...
# KDE_PROJECT_BUILD_SCRIPT=...
# KDE_PROJECT_POST_BUILD_SCRIPT=...
# KDE_PROJECT_PRE_DEPLOY_SCRIPT=...
# KDE_PROJECT_DEPLOY_SCRIPT=...
# KDE_PROJECT_POST_DEPLOY_SCRIPT=...
```

**步驟 3：測試**

```bash
kde project deploy myapp
```

### 選項 3：遷移到自定義 Pipeline

**步驟 1：定義 Pipeline 階段**

```bash
# 編輯 project.env
KDE_CICD_STAGES="lint security build test deploy monitor"
```

**步驟 2：建立階段腳本**

```bash
cd environments/your-env/namespaces/myapp

# 建立各階段的腳本檔案
touch lint.sh security.sh build.sh test.sh deploy.sh monitor.sh
chmod +x *.sh
```

**步驟 3：配置每個階段（可選）**

```bash
# 編輯 project.env，為每個階段設定自訂配置
KDE_CICD_STAGE_lint_IMAGE=node:20
KDE_CICD_STAGE_security_IMAGE=aquasec/trivy:latest
KDE_CICD_STAGE_build_IMAGE=node:20
# ...
```

**步驟 4：測試**

```bash
kde project deploy myapp
```

## 自動偵測機制

系統會根據以下規則自動決定使用哪種機制：

1. **如果定義了 `KDE_CICD_STAGES`** → 使用自定義 Pipeline
2. **否則** → 使用舊的 build/deploy 流程（向後相容）

## 階段命名建議

### 標準階段
- `build`: 建置階段，編譯程式碼
- `test`: 測試階段，單元測試、整合測試
- `release`: 發布階段，版本標記、打包
- `deploy`: 部署階段，部署到 K8s

### 自定義階段範例
- `lint`: 程式碼風格檢查
- `security`: 安全掃描
- `unit-test`: 單元測試
- `integration-test`: 整合測試
- `e2e-test`: 端到端測試
- `build-image`: 建置 Docker 映像
- `push-image`: 推送映像到 Registry
- `deploy-staging`: 部署到測試環境
- `smoke-test`: 冒煙測試
- `deploy-production`: 部署到生產環境
- `healthcheck`: 健康檢查

## 進階功能

### Fail Fast 模式

```bash
# project.env
KDE_DEVOPS_FAIL_FAST=true
```

任何階段失敗立即停止整個 Pipeline。

### 自動回滾

```bash
# project.env
KDE_DEVOPS_AUTO_ROLLBACK=true
```

當 deploy 相關階段失敗時，自動執行回滾操作。

### 跳過特定階段

```bash
# project.env
KDE_CICD_STAGE_test_SKIP=true
```

跳過 test 階段（適用於快速開發模式）。

### 環境特定配置

```bash
# project.env（共用配置）
KDE_CICD_STAGES="lint build test deploy"
DEPLOY_ENV=development

# .env（環境特定配置，覆寫共用配置）
DEPLOY_ENV=production
KDE_CICD_STAGE_deploy_SCRIPT=deploy-production.sh
```

## 常見問題

### Q: 我需要立即遷移嗎？

A: 不需要。舊的機制完全向後相容，可以繼續使用。

### Q: 可以混用舊機制和新機制嗎？

A: 不建議。系統會自動偵測並選擇一種機制。如果混用，可能會導致混淆。

### Q: 如何知道目前使用的是哪種機制？

A: 執行 `kde project deploy` 時，系統會顯示訊息：
- "📋 執行標準 CICD Pipeline"
- "📋 執行自定義 Pipeline"
- 或者沒有特別訊息（使用舊機制）

### Q: 可以在不同專案使用不同機制嗎？

A: 可以。每個專案可以獨立選擇機制。

### Q: 新機制有效能影響嗎？

A: 沒有。新機制只是更靈活的執行方式，不影響效能。

## 範例

完整範例請參考：
- [自定義 Pipeline 範例](./examples/custom-pipeline-example.md)

## 技術細節

### Pipeline 執行流程

```
kde project deploy myapp
  ↓
偵測 Pipeline 類型
  ↓
┌─────────────────┬──────────────────┬─────────────────┐
│ 自定義 Pipeline │ 標準 CICD 流程   │ 舊機制（相容）  │
├─────────────────┼──────────────────┼─────────────────┤
│ KDE_PIPELINE_   │ plan.sh 等檔案   │ build.sh,       │
│ STAGES 已定義   │ 存在             │ deploy.sh 等    │
└─────────────────┴──────────────────┴─────────────────┘
  ↓                 ↓                  ↓
執行對應的 Pipeline
```

### 腳本查找順序

1. 檢查 `KDE_CICD_STAGE_{stage}_SCRIPT` 環境變數
2. 如果存在，使用該腳本
3. 否則，使用預設腳本 `{stage}.sh`
4. 如果腳本不存在，跳過該階段

### 映像選擇順序

1. 檢查 `KDE_CICD_STAGE_{stage}_IMAGE` 環境變數
2. 如果存在，使用該映像
3. 否則，使用 `DEPLOY_IMAGE`

## 總結

新的 Pipeline 機制提供：
- ✅ 更靈活的階段定義
- ✅ 標準 CICD 流程支援
- ✅ 自定義階段和順序
- ✅ 每階段獨立配置
- ✅ 向後相容
- ✅ 簡單易用

選擇適合你的專案的方式，從簡單開始，按需擴展！
