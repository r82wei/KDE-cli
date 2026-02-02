# 自定義 Pipeline 配置指南

## 概述

KDE 支援兩種 Pipeline 模式：

1. **標準 CICD 流程**（預設）- Build → Test → Release → Deploy
2. **自定義 Pipeline** - 靈活定義階段、順序和執行環境

## 標準 CICD 流程（預設）

不設定 `KDE_PIPELINE_STAGES` 時，使用標準的 8 階段流程：

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
KDE_PIPELINE_STAGES="code build test deploy monitor"

# 每個階段的配置
KDE_PIPELINE_STAGE_code_SCRIPT=lint-strict.sh
KDE_PIPELINE_STAGE_code_IMAGE=node:20

KDE_PIPELINE_STAGE_build_SCRIPT=build.sh
KDE_PIPELINE_STAGE_build_IMAGE=node:20

KDE_PIPELINE_STAGE_test_SCRIPT=test-all.sh
KDE_PIPELINE_STAGE_test_IMAGE=node:20-test

KDE_PIPELINE_STAGE_deploy_SCRIPT=deploy.sh
KDE_PIPELINE_STAGE_deploy_IMAGE=r82wei/deploy-env:1.0.0

KDE_PIPELINE_STAGE_monitor_SCRIPT=healthcheck.sh
KDE_PIPELINE_STAGE_monitor_IMAGE=r82wei/deploy-env:1.0.0
```

### 階段配置變數

每個階段支援以下配置變數：

| 變數模式 | 說明 | 範例 |
|---------|------|------|
| `KDE_PIPELINE_STAGE_{stage}_SCRIPT` | 腳本路徑 | `KDE_PIPELINE_STAGE_build_SCRIPT=build.sh` |
| `KDE_PIPELINE_STAGE_{stage}_IMAGE` | Docker 映像 | `KDE_PIPELINE_STAGE_build_IMAGE=node:20` |

### 預設行為

- **腳本**：如果未指定，使用 `{stage}.sh`
- **映像**：如果未指定，使用 `DEPLOY_IMAGE`
- **跳過**：如果腳本不存在 or 沒有設定 KDE_PIPELINE_STAGE${stage}_* 相關設定

## 使用範例

### 範例 1：快速開發模式

只執行 build 和 deploy：

```bash
# project.env
KDE_PIPELINE_STAGES="build deploy"

KDE_PIPELINE_STAGE_build_SCRIPT=build.sh
KDE_PIPELINE_STAGE_build_IMAGE=node:20

KDE_PIPELINE_STAGE_deploy_SCRIPT=deploy-quick.sh
KDE_PIPELINE_STAGE_deploy_IMAGE=r82wei/deploy-env:1.0.0
```

### 範例 2：安全優先模式

加入安全掃描：

```bash
# project.env
KDE_PIPELINE_STAGES="code build security-scan test deploy monitor"

KDE_PIPELINE_STAGE_code_SCRIPT=lint.sh
KDE_PIPELINE_STAGE_code_IMAGE=node:20

KDE_PIPELINE_STAGE_build_SCRIPT=build.sh
KDE_PIPELINE_STAGE_build_IMAGE=node:20

KDE_PIPELINE_STAGE_security_scan_SCRIPT=security-scan.sh
KDE_PIPELINE_STAGE_security_scan_IMAGE=aquasec/trivy:latest

KDE_PIPELINE_STAGE_test_SCRIPT=test.sh
KDE_PIPELINE_STAGE_test_IMAGE=node:20

KDE_PIPELINE_STAGE_deploy_SCRIPT=deploy.sh
KDE_PIPELINE_STAGE_deploy_IMAGE=r82wei/deploy-env:1.0.0

KDE_PIPELINE_STAGE_monitor_SCRIPT=monitor.sh
KDE_PIPELINE_STAGE_monitor_IMAGE=r82wei/deploy-env:1.0.0
```

### 範例 3：多環境配置

在不同環境使用不同腳本：

```bash
# project.env（共用配置）
DEPLOY_ENV=development
KDE_PIPELINE_STAGES="lint build test deploy"

# 根據環境使用不同腳本
KDE_PIPELINE_STAGE_deploy_SCRIPT=deploy-${DEPLOY_ENV}.sh
KDE_PIPELINE_STAGE_deploy_IMAGE=r82wei/deploy-env:1.0.0
```

然後在 `.env` 中覆寫環境：

```bash
# .env（生產環境）
DEPLOY_ENV=production
```

### 範例 4：漸進式部署

加入金絲雀部署和驗證：

```bash
# project.env
KDE_PIPELINE_STAGES="build test deploy-canary verify-canary deploy-full monitor"

KDE_PIPELINE_STAGE_build_SCRIPT=build.sh
KDE_PIPELINE_STAGE_build_IMAGE=node:20

KDE_PIPELINE_STAGE_test_SCRIPT=test.sh
KDE_PIPELINE_STAGE_test_IMAGE=node:20

KDE_PIPELINE_STAGE_deploy_canary_SCRIPT=deploy-canary.sh
KDE_PIPELINE_STAGE_deploy_canary_IMAGE=r82wei/deploy-env:1.0.0

KDE_PIPELINE_STAGE_verify_canary_SCRIPT=verify-canary.sh
KDE_PIPELINE_STAGE_verify_canary_IMAGE=r82wei/deploy-env:1.0.0

KDE_PIPELINE_STAGE_deploy_full_SCRIPT=deploy-full.sh
KDE_PIPELINE_STAGE_deploy_full_IMAGE=r82wei/deploy-env:1.0.0

KDE_PIPELINE_STAGE_monitor_SCRIPT=monitor.sh
KDE_PIPELINE_STAGE_monitor_IMAGE=r82wei/deploy-env:1.0.0
```

### 範例 5：完整的自定義 Pipeline

```bash
# project.env
# 定義完整的自定義 Pipeline
KDE_PIPELINE_STAGES="validate,lint,security,build,unit-test,integration-test,package,deploy-staging,smoke-test,deploy-production,monitor"

# Validate 階段
KDE_PIPELINE_STAGE_validate_SCRIPT=validate-config.sh
KDE_PIPELINE_STAGE_validate_IMAGE=r82wei/deploy-env:1.0.0

# Lint 階段
KDE_PIPELINE_STAGE_lint_SCRIPT=lint.sh
KDE_PIPELINE_STAGE_lint_IMAGE=node:20

# Security 階段
KDE_PIPELINE_STAGE_security_SCRIPT=security-scan.sh
KDE_PIPELINE_STAGE_security_IMAGE=aquasec/trivy:latest

# Build 階段
KDE_PIPELINE_STAGE_build_SCRIPT=build.sh
KDE_PIPELINE_STAGE_build_IMAGE=node:20

# Unit Test 階段
KDE_PIPELINE_STAGE_unit_test_SCRIPT=unit-test.sh
KDE_PIPELINE_STAGE_unit_test_IMAGE=node:20

# Integration Test 階段
KDE_PIPELINE_STAGE_integration_test_SCRIPT=integration-test.sh
KDE_PIPELINE_STAGE_integration_test_IMAGE=node:20

# Package 階段
KDE_PIPELINE_STAGE_package_SCRIPT=package.sh
KDE_PIPELINE_STAGE_package_IMAGE=node:20

# Deploy Staging 階段
KDE_PIPELINE_STAGE_deploy_staging_SCRIPT=deploy-staging.sh
KDE_PIPELINE_STAGE_deploy_staging_IMAGE=r82wei/deploy-env:1.0.0

# Smoke Test 階段
KDE_PIPELINE_STAGE_smoke_test_SCRIPT=smoke-test.sh
KDE_PIPELINE_STAGE_smoke_test_IMAGE=node:20

# Deploy Production 階段
KDE_PIPELINE_STAGE_deploy_production_SCRIPT=deploy-production.sh
KDE_PIPELINE_STAGE_deploy_production_IMAGE=r82wei/deploy-env:1.0.0

# Monitor 階段
KDE_PIPELINE_STAGE_monitor_SCRIPT=monitor.sh
KDE_PIPELINE_STAGE_monitor_IMAGE=grafana/grafana:latest

# 錯誤處理
KDE_DEVOPS_FAIL_FAST=true
KDE_DEVOPS_AUTO_ROLLBACK=true
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
KDE_PIPELINE_STAGE_test_SKIP=true  # 跳過 test 階段
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
KDE_PIPELINE_STAGE_deploy_staging_SKIP=true
KDE_PIPELINE_STAGE_deploy_production_SKIP=true

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

## 與標準 CICD 流程對照

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

### Q: 如何回到標準 CICD 流程？

A: 移除或註解 `KDE_PIPELINE_STAGES`：

```bash
# project.env
# KDE_PIPELINE_STAGES="build test deploy"  # 註解掉
```

### Q: 可以混用標準和自定義階段嗎？

A: 可以，在自定義 Pipeline 中使用標準階段名稱：

```bash
KDE_PIPELINE_STAGES="code build test deploy monitor"
# 這些會執行標準的 code.sh, build.sh 等
```

### Q: 如何只執行特定階段？

A: 定義只包含該階段的 Pipeline：

```bash
# .env（臨時覆寫）
KDE_PIPELINE_STAGES="test"
```

### Q: 階段名稱有限制嗎？

A: 建議使用小寫字母、數字和連字號，避免特殊字元。

## 進階技巧

### 條件執行

使用環境變數控制階段：

```bash
# project.env
IS_PRODUCTION=${IS_PRODUCTION:-false}

# 根據環境決定階段
if [[ "${IS_PRODUCTION}" == "true" ]]; then
    KDE_PIPELINE_STAGES="lint security build test deploy-production monitor"
else
    KDE_PIPELINE_STAGES="lint build test deploy-staging"
fi
```

### 並行執行（未來功能）

計畫支援並行執行：

```bash
# 未來可能的語法
KDE_PIPELINE_STAGES="build, (unit-test + integration-test), deploy"
```

## 總結

自定義 Pipeline 提供：
- ✅ 完全的階段控制
- ✅ 靈活的執行順序
- ✅ 自定義階段名稱
- ✅ 每階段獨立配置
- ✅ 向後相容標準 CICD 流程

選擇適合你的模式，從簡單開始，按需擴展！



