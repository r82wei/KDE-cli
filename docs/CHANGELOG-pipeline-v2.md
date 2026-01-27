# Pipeline 機制更新 - v2

## 更新日期

**日期**: 2026-01-24
**版本**: v2.0
**類型**: 重大更新（向後相容）

## 概述

根據 `docs/custom-pipeline.md` 的最新設計，更新 Pipeline 機制，簡化配置並統一命名規範。

## 主要變更

### 1. 環境變數命名更新

**舊名稱** → **新名稱**

- `KDE_PIPELINE_STAGES` → `KDE_CICD_STAGES`
- `KDE_STAGE_{stage}_SCRIPT` → `KDE_CICD_STAGE_{stage}_SCRIPT`
- `KDE_STAGE_{stage}_IMAGE` → `KDE_CICD_STAGE_{stage}_IMAGE`
- `KDE_STAGE_{stage}_SKIP` → `KDE_CICD_STAGE_{stage}_SKIP`

### 2. 標準流程簡化

**舊設計**：8 階段 DevOps Loops
- Plan → Code → Build → Test → Release → Deploy → Operate → Monitor

**新設計**：4 階段標準 CICD 流程
- Build → Test → Release → Deploy

### 3. 映像使用簡化

**舊設計**：根據階段類型決定預設映像
- CI 階段（plan, code, build, test）使用 `DEVELOP_IMAGE`
- CD 階段（release, deploy, operate, monitor）使用 `DEPLOY_IMAGE`

**新設計**：統一使用 `DEPLOY_IMAGE`
- 所有階段預設使用 `DEPLOY_IMAGE`
- 可透過 `KDE_CICD_STAGE_{stage}_IMAGE` 自訂

### 4. 自動偵測邏輯優化

**舊邏輯**：
1. 檢查 `KDE_PIPELINE_STAGES` 是否定義
2. 檢查標準階段檔案是否存在（多個條件）
3. 使用舊流程

**新邏輯**：
1. 檢查 `KDE_CICD_STAGES` 是否定義
2. 使用舊流程（簡化）

## 配置範例

### 標準 CICD 流程

```bash
# project.env
GIT_REPO_URL=https://github.com/user/repo.git
GIT_REPO_BRANCH=main
DEVELOP_IMAGE=node:20
DEPLOY_IMAGE=r82wei/deploy-env:1.0.0

# 不需要設定 KDE_CICD_STAGES
# 系統會執行存在的標準階段腳本：build.sh, test.sh, release.sh, deploy.sh
```

### 自定義 Pipeline

```bash
# project.env
GIT_REPO_URL=https://github.com/user/repo.git
GIT_REPO_BRANCH=main
DEVELOP_IMAGE=node:20
DEPLOY_IMAGE=r82wei/deploy-env:1.0.0

# 定義自定義 Pipeline
KDE_CICD_STAGES="lint,security,build,test,deploy,monitor"

# 每個階段的配置
KDE_CICD_STAGE_lint_SCRIPT=lint.sh
KDE_CICD_STAGE_lint_IMAGE=node:20

KDE_CICD_STAGE_security_SCRIPT=security-scan.sh
KDE_CICD_STAGE_security_IMAGE=aquasec/trivy:latest

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

## 遷移指南

### 如果你使用舊的環境變數

```bash
# 舊配置
KDE_PIPELINE_STAGES="lint build test deploy"
KDE_STAGE_lint_IMAGE=node:20

# 新配置（批量替換）
KDE_CICD_STAGES="lint build test deploy"
KDE_CICD_STAGE_lint_IMAGE=node:20
```

**批量替換指令**：
```bash
# 在專案目錄執行
sed -i 's/KDE_PIPELINE_STAGES/KDE_CICD_STAGES/g' project.env
sed -i 's/KDE_STAGE_/KDE_CICD_STAGE_/g' project.env
```

### 如果你使用標準流程

無需修改，系統會繼續正常運作。

## 向後相容性

✅ **完全向後相容**

- 舊的 `build.sh`、`deploy.sh` 等腳本繼續正常運作
- 舊的 `pre-build.sh`、`post-build.sh` 等腳本繼續支援
- 舊的環境變數配置（`KDE_PROJECT_BUILD_SCRIPT` 等）繼續支援

## 檔案變更清單

### 程式碼檔案
- ✅ `scripts/utils/pipeline.sh` - 更新環境變數名稱和邏輯
- ✅ `scripts/utils/project.sh` - 更新偵測邏輯

### 文件檔案
- ✅ `docs/custom-pipeline.md` - 主要設計文件（已存在）
- ✅ `docs/pipeline-migration-guide.md` - 更新所有環境變數名稱
- ✅ `docs/examples/custom-pipeline-example.md` - 更新範例
- ✅ `docs/CHANGELOG-pipeline.md` - 更新變更日誌
- ❌ `docs/examples/standard-devops-loops-example.md` - 已刪除（不再需要）
- ✅ `README.md` - 更新說明
- ✅ `README.zh-TW.md` - 更新說明

## 測試驗證

### 語法檢查
```bash
✅ scripts/utils/pipeline.sh - 語法正確
✅ scripts/utils/project.sh - 語法正確
```

### 功能測試建議

1. **測試舊流程（向後相容）**
   ```bash
   kde project deploy old-project
   # 應該執行 pre-build.sh, build.sh, post-build.sh, pre-deploy.sh, deploy.sh, post-deploy.sh
   ```

2. **測試標準 CICD 流程**
   ```bash
   # 建立標準階段腳本
   touch build.sh test.sh release.sh deploy.sh
   kde project deploy standard-project
   # 應該執行 build.sh, test.sh, release.sh, deploy.sh
   ```

3. **測試自定義 Pipeline**
   ```bash
   # 在 project.env 設定
   KDE_CICD_STAGES="lint build test deploy"
   kde project deploy custom-project
   # 應該執行 lint.sh, build.sh, test.sh, deploy.sh
   ```

## 優點

相較於 v1 版本，v2 提供：

1. **更簡潔的命名**：`KDE_CICD_*` 比 `KDE_PIPELINE_*` 更直觀
2. **更簡單的設計**：4 階段標準流程比 8 階段更易理解
3. **更統一的映像使用**：所有階段預設使用 `DEPLOY_IMAGE`，減少混淆
4. **更簡化的偵測邏輯**：減少判斷條件，提升可維護性
5. **完全向後相容**：現有專案無需修改

## 已知限制

與 v1 相同：

1. **並行執行**：目前所有階段都是順序執行
2. **回滾機制**：自動回滾功能為占位符
3. **階段依賴**：沒有顯式的依賴關係定義

## 未來計劃

- [ ] 支援階段並行執行
- [ ] 實作完整的自動回滾機制
- [ ] 支援階段條件執行
- [ ] 支援階段重試機制
- [ ] 提供 Pipeline 視覺化工具

## 相關文件

- [自定義 Pipeline 配置指南](./custom-pipeline.md) - 主要設計文件
- [Pipeline 遷移指南](./pipeline-migration-guide.md) - 詳細遷移說明
- [自定義 Pipeline 範例](./examples/custom-pipeline-example.md) - 完整範例
- [設計原則](./principle.md) - 整體設計原則

## 總結

v2 版本的 Pipeline 機制：

- ✅ 更簡潔的命名規範
- ✅ 更簡化的標準流程
- ✅ 更統一的映像使用
- ✅ 完全向後相容
- ✅ 更易於理解和使用

使用者可以根據需求選擇最適合的方式，從簡單開始，按需擴展！
