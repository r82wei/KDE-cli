# CI/CD Pipeline 配置指南

## 概述

KDE 支援兩種 Pipeline 模式：

1. **標準 DevOps Loops**（預設）- Build → Test → Release → Deploy 階段
2. **自定義 Pipeline** - 靈活定義階段、順序和執行環境

## 標準 DevOps Loops（預設）

不設定 `KDE_PIPELINE_STAGES` 時，使用預設流程：

```
Build → Test → Release → Deploy
```

### 執行
```bash
kde project deploy myapp
```

## 自定義 Pipeline

### 基本配置

在 `project.env` 中定義自定義 Pipeline：

```bash
# 定義要執行的階段（空格或逗號分隔）
KDE_PIPELINE_STAGES="TEST BUILD DEPLOY"

# 每個階段的配置
KDE_STAGE_TEST_SCRIPT=${PROJECT_PATH}/test-all.sh
KDE_STAGE_TEST_IMAGE=node:20-test

KDE_STAGE_BUILD_SCRIPT=${PROJECT_PATH}/build.sh
KDE_STAGE_BUILD_IMAGE=node:20

KDE_STAGE_DEPLOY_SCRIPT=${PROJECT_PATH}/deploy.sh
KDE_STAGE_DEPLOY_IMAGE=r82wei/deploy-env:1.0.0
```

### 階段配置變數

每個階段支援以下配置變數：

| 變數模式 | 說明 | 範例 |
|---------|------|------|
| `KDE_STAGE_{stage}_SCRIPT` | 腳本路徑 | `KDE_STAGE_build_SCRIPT=build.sh` |
| `KDE_STAGE_{stage}_IMAGE` | Docker 映像 | `KDE_STAGE_build_IMAGE=node:20` |

### 預設行為

- **腳本**：如果未指定，使用 `{stage}.sh`
- **映像**：如果未指定，使用 `DEPLOY_IMAGE`
- **跳過**：沒有設定 Docker 映像、腳本路徑或是腳本檔案不存在

## 使用範例

### 範例 1：快速開發模式

只執行 build 和 deploy：

```bash
# project.env
KDE_PIPELINE_STAGES="build deploy"

KDE_STAGE_build_SCRIPT=build.sh
KDE_STAGE_build_IMAGE=node:20

KDE_STAGE_deploy_SCRIPT=deploy-quick.sh
KDE_STAGE_deploy_IMAGE=r82wei/deploy-env:1.0.0
```

### 範例 2：安全優先模式

加入安全掃描：

```bash
# project.env
KDE_PIPELINE_STAGES="code build security-scan test deploy monitor"

KDE_STAGE_code_SCRIPT=lint.sh
KDE_STAGE_code_IMAGE=node:20

KDE_STAGE_build_SCRIPT=build.sh
KDE_STAGE_build_IMAGE=node:20

KDE_STAGE_security_scan_SCRIPT=security-scan.sh
KDE_STAGE_security_scan_IMAGE=aquasec/trivy:latest

KDE_STAGE_test_SCRIPT=test.sh
KDE_STAGE_test_IMAGE=node:20

KDE_STAGE_deploy_SCRIPT=deploy.sh
KDE_STAGE_deploy_IMAGE=r82wei/deploy-env:1.0.0

KDE_STAGE_monitor_SCRIPT=monitor.sh
KDE_STAGE_monitor_IMAGE=r82wei/deploy-env:1.0.0
```

### 範例 3：多環境配置

在不同環境使用不同腳本：

```bash
# project.env（共用配置）
DEPLOY_ENV=development
KDE_PIPELINE_STAGES="lint build test deploy"

# 根據環境使用不同腳本
KDE_STAGE_deploy_SCRIPT=deploy-${DEPLOY_ENV}.sh
KDE_STAGE_deploy_IMAGE=r82wei/deploy-env:1.0.0
```

然後在 `.env` 中覆寫環境：

```bash
# .env（生產環境）
DEPLOY_ENV=production
```

## 錯誤處理

### Fail Fast 模式

```bash
# project.env
KDE_DEVOPS_FAIL_FAST=true  # 任何階段失敗立即停止
```

### 自動回滾

```bash
# project.env
KDE_DEVOPS_AUTO_ROLLBACK=true  # deploy 相關階段失敗時自動回滾
```

### 跳過特定階段

```bash
# project.env 或 .env
KDE_STAGE_test_SKIP=true  # 跳過 test 階段
```

## 執行和除錯

### 執行自定義 Pipeline

```bash
kde project deploy myapp
```

### 查看執行過程

Pipeline 會顯示：
- 📋 階段列表
- 🔄 當前執行的階段
- 📄 使用的腳本
- 🐳 使用的映像
- ✅ 階段完成狀態
- ❌ 錯誤訊息

### 除錯模式

```bash
# 在 kde.env 中啟用
KDE_DEBUG=true
```

## 與標準 DevOps Loops 對照

| 標準階段 | 自定義階段範例 | 說明 |
|---------|---------------|------|
| Plan | validate, check-env | 環境驗證 |
| Code | lint, format-check | 程式碼檢查 |
| Build | build, compile | 建置 |
| Test | unit-test, integration-test, e2e-test | 測試 |
| Release | version, package, publish | 發布 |
| Deploy | deploy-staging, deploy-production | 部署 |
| Operate | scale, config-update | 運維 |
| Monitor | healthcheck, metrics, monitor | 監控 |

## 常見問題

### Q: 如何回到標準 DevOps Loops？

移除或註解 `KDE_PIPELINE_STAGES`：

```bash
# project.env
# KDE_PIPELINE_STAGES="build test deploy"  # 註解掉
```

### Q: 可以混用標準和自定義階段嗎？

可以，在自定義 Pipeline 中使用標準階段名稱：

```bash
KDE_PIPELINE_STAGES="code build test deploy monitor"
# 這些會執行標準的 code.sh, build.sh 等
```

### Q: 如何只執行特定階段？

定義只包含該階段的 Pipeline：

```bash
# .env（臨時覆寫）
KDE_PIPELINE_STAGES="test"
```

### Q: 階段名稱有限制嗎？

建議使用小寫字母、數字和連字號，避免特殊字元。

## 最佳實踐

### 1. 階段命名

使用清晰的階段名稱：
- ✅ `security-scan`, `unit-test`, `deploy-staging`
- ❌ `s1`, `test1`, `deploy`

### 2. 腳本組織

將腳本放在專案目錄：
```
namespaces/myapp/
├── project.env
├── lint.sh
├── security-scan.sh
├── build.sh
├── unit-test.sh
├── integration-test.sh
├── deploy-staging.sh
├── deploy-production.sh
└── monitor.sh
```

### 3. 環境隔離

使用不同環境：
```bash
# 開發環境 (.env)
DEPLOY_ENV=development
KDE_STAGE_deploy_staging_SKIP=true
KDE_STAGE_deploy_production_SKIP=true

# 生產環境 (.env)
DEPLOY_ENV=production
KDE_DEVOPS_AUTO_ROLLBACK=true
```

### 4. 漸進式採用

從簡單開始：
```bash
# 階段 1：基本
KDE_PIPELINE_STAGES="build deploy"

# 階段 2：加入測試
KDE_PIPELINE_STAGES="build test deploy"

# 階段 3：加入安全檢查
KDE_PIPELINE_STAGES="security build test deploy"

# 階段 4：完整流程
KDE_PIPELINE_STAGES="lint security build test deploy monitor"
```

## 詳細配置指南

更多進階配置與範例，請參考 [自定義 Pipeline 配置指南](./custom-pipeline.md)。
