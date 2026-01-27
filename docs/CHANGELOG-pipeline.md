# Pipeline 機制重構 - 變更日誌

## 版本資訊

**日期**: 2026-01-24
**類型**: 功能增強
**影響**: 向後相容

## 概述

根據 `docs/principle.md` 的設計原則，將 KDE CLI 的 CICD Pipeline 機制重構為支援更靈活的 Pipeline 配置，同時保持向後相容性。

## 主要變更

### 1. 新增 Pipeline 工具 (`scripts/utils/pipeline.sh`)

新增了完整的 Pipeline 執行框架，支援：

- **標準 CICD 流程**：8 階段完整循環
  - CI 階段：Plan → Code → Build → Test
  - CD 階段：Release → Deploy → Operate → Monitor

- **自定義 Pipeline**：靈活定義階段
  - 透過 `KDE_CICD_STAGES` 定義階段列表
  - 每個階段可獨立配置腳本和映像
  - 支援跳過特定階段

- **錯誤處理機制**：
  - Fail Fast 模式（`KDE_DEVOPS_FAIL_FAST`）
  - 自動回滾（`KDE_DEVOPS_AUTO_ROLLBACK`）

### 2. 重構專案管理函數 (`scripts/utils/project.sh`)

更新了 `build_project()` 和 `deploy_project()` 函數：

- 自動偵測 Pipeline 類型
- 優先使用新的 Pipeline 機制
- 向後相容舊的 build/deploy 流程

**偵測邏輯**：
1. 如果定義了 `KDE_CICD_STAGES` → 使用自定義 Pipeline
2. 如果存在標準 CICD 流程 階段檔案 → 使用標準 CICD 流程
3. 否則 → 使用舊的 build/deploy 流程（完全向後相容）

### 3. 文件更新

新增/更新了以下文件：

- **`docs/pipeline-migration-guide.md`**：完整的遷移指南
  - 新舊機制對照
  - 遷移步驟詳解
  - 常見問題解答

- **`docs/examples/standard-devops-loops-example.md`**：標準 CICD 流程 範例
  - 完整的專案結構
  - 每個階段的腳本範例
  - 使用方式和最佳實踐

- **`docs/examples/custom-pipeline-example.md`**：自定義 Pipeline 範例
  - 安全優先的 Pipeline 配置
  - 多環境配置範例
  - 進階場景展示

- **`README.md`** 和 **`README.zh-TW.md`**：更新了 CI/CD 部分
  - 說明三種 Pipeline 模式
  - 提供快速開始指南
  - 連結到詳細文件

## 向後相容性

✅ **完全向後相容**

- 現有專案無需修改即可繼續使用
- 舊的 `build.sh`、`deploy.sh` 等腳本繼續正常運作
- 舊的環境變數配置（`KDE_PROJECT_BUILD_SCRIPT` 等）繼續支援
- 自動偵測機制確保平滑過渡

## 新功能

### 標準 CICD 流程

```bash
# 建立階段腳本
touch plan.sh code.sh build.sh test.sh release.sh deploy.sh operate.sh monitor.sh

# 系統自動執行對應階段
kde project build myapp    # 執行 CI 階段
kde project deploy myapp   # 執行 CD 階段
```

### 自定義 Pipeline

```bash
# project.env
KDE_CICD_STAGES="lint,security,build,test,deploy,monitor"

# 每個階段的配置
KDE_CICD_STAGE_lint_SCRIPT=lint.sh
KDE_CICD_STAGE_lint_IMAGE=node:20

KDE_CICD_STAGE_security_SCRIPT=security-scan.sh
KDE_CICD_STAGE_security_IMAGE=aquasec/trivy:latest
# ...

# 錯誤處理
KDE_DEVOPS_FAIL_FAST=true
KDE_DEVOPS_AUTO_ROLLBACK=true
```

### 階段配置變數

每個階段支援以下配置：

- `KDE_CICD_STAGE_{stage}_SCRIPT`：腳本路徑
- `KDE_CICD_STAGE_{stage}_IMAGE`：Docker 映像
- `KDE_CICD_STAGE_{stage}_SKIP`：跳過此階段

## 使用場景

### 場景 1：保持現狀（無需改動）

```bash
# 繼續使用現有的 build.sh、deploy.sh
kde project deploy myapp
# 系統自動使用舊流程
```

### 場景 2：遷移到標準 CICD 流程

```bash
# 重命名腳本檔案
mv build.sh build.sh
mv pre-build.sh plan.sh
mv post-build.sh test.sh
mv deploy.sh deploy.sh
mv pre-deploy.sh release.sh
mv post-deploy.sh operate.sh

# 系統自動偵測並使用新流程
kde project deploy myapp
```

### 場景 3：自定義 Pipeline

```bash
# 在 project.env 中定義
KDE_CICD_STAGES="lint,build,test,deploy"

# 建立對應的腳本檔案
touch lint.sh build.sh test.sh deploy.sh

# 執行
kde project deploy myapp
```

## 技術細節

### Pipeline 執行流程

```
kde project deploy myapp
  ↓
載入 project.env
  ↓
偵測 Pipeline 類型
  ↓
┌──────────────────┬───────────────────┬──────────────────┐
│ 自定義 Pipeline  │ 標準 CICD 流程 │ 舊機制（相容）   │
├──────────────────┼───────────────────┼──────────────────┤
│ KDE_PIPELINE_    │ plan.sh 等檔案    │ build.sh,        │
│ STAGES 已定義    │ 存在              │ deploy.sh 等     │
└──────────────────┴───────────────────┴──────────────────┘
  ↓                  ↓                   ↓
執行對應的 Pipeline
  ↓
顯示執行結果
```

### 階段命名規則

- 使用小寫字母、數字和連字號
- 連字號會自動轉換為底線（環境變數命名）
- 範例：`security-scan` → `KDE_CICD_STAGE_security_scan_SCRIPT`

### 預設行為

- **腳本**：如果未指定 `KDE_CICD_STAGE_{stage}_SCRIPT`，使用 `{stage}.sh`
- **映像**：如果未指定 `KDE_CICD_STAGE_{stage}_IMAGE`，使用 `DEPLOY_IMAGE`
- **CI 階段映像**：plan、code、build、test 預設使用 `DEVELOP_IMAGE`
- **CD 階段映像**：release、deploy、operate、monitor 預設使用 `DEPLOY_IMAGE`

## 測試建議

### 基本測試

```bash
# 1. 測試舊流程（向後相容）
kde project deploy old-project

# 2. 測試標準 CICD 流程
kde project deploy standard-project

# 3. 測試自定義 Pipeline
kde project deploy custom-project
```

### 驗證項目

- [ ] 舊專案繼續正常運作
- [ ] 新的標準 CICD 流程 正確執行
- [ ] 自定義 Pipeline 正確執行
- [ ] 階段跳過功能正常
- [ ] Fail Fast 模式正常
- [ ] 錯誤訊息清晰明確

## 已知限制

1. **並行執行**：目前所有階段都是順序執行，未來可能支援並行執行
2. **回滾機制**：自動回滾功能目前為占位符，需要進一步實作
3. **階段依賴**：階段之間沒有顯式的依賴關係定義

## 未來計劃

- [ ] 支援階段並行執行
- [ ] 實作完整的自動回滾機制
- [ ] 支援階段條件執行
- [ ] 支援階段重試機制
- [ ] 提供 Pipeline 視覺化工具
- [ ] 支援 Pipeline 模板

## 相關文件

- [設計原則](./principle.md)
- [自定義 Pipeline 指南](./custom-pipeline.md)
- [Pipeline 遷移指南](./pipeline-migration-guide.md)
- [標準 CICD 流程 範例](./examples/standard-devops-loops-example.md)
- [自定義 Pipeline 範例](./examples/custom-pipeline-example.md)

## 問題回報

如果遇到問題，請提供以下資訊：

1. 使用的 Pipeline 類型（舊機制/標準/自定義）
2. `project.env` 配置內容
3. 錯誤訊息和日誌
4. 預期行為和實際行為

## 總結

這次重構實現了：

- ✅ 靈活的 Pipeline 配置機制
- ✅ 完整的 CICD 流程 支援
- ✅ 自定義階段和順序
- ✅ 完全向後相容
- ✅ 清晰的文件和範例
- ✅ 自動偵測機制

使用者可以根據需求選擇最適合的方式，從簡單開始，按需擴展！
