# 自定義 Pipeline 範例

這個範例展示如何使用自定義 Pipeline 來建立符合特定需求的 CI/CD 流程。

## 專案結構

```
environments/dev/namespaces/secure-app/
├── project.env
├── lint.sh
├── security-scan.sh
├── build.sh
├── unit-test.sh
├── integration-test.sh
├── build-image.sh
├── deploy-staging.sh
├── smoke-test.sh
├── deploy-production.sh
├── healthcheck.sh
└── secure-app-repo/
    └── ... (git repository)
```

## 配置檔案

### project.env

```bash
# Git 設定
GIT_REPO_URL=https://github.com/user/secure-app.git
GIT_REPO_BRANCH=main

# 映像設定
DEVELOP_IMAGE=node:20
DEPLOY_IMAGE=r82wei/deploy-env:1.0.0

# 自定義 Pipeline 階段
KDE_CICD_STAGES="lint,security-scan,build,unit-test,integration-test,build-image,deploy-staging,smoke-test,deploy-production,healthcheck"

# 階段配置
KDE_CICD_STAGE_lint_SCRIPT=lint.sh
KDE_CICD_STAGE_lint_IMAGE=node:20

KDE_CICD_STAGE_security_scan_SCRIPT=security-scan.sh
KDE_CICD_STAGE_security_scan_IMAGE=aquasec/trivy:latest

KDE_CICD_STAGE_build_SCRIPT=build.sh
KDE_CICD_STAGE_build_IMAGE=node:20

KDE_CICD_STAGE_unit_test_SCRIPT=unit-test.sh
KDE_CICD_STAGE_unit_test_IMAGE=node:20

KDE_CICD_STAGE_integration_test_SCRIPT=integration-test.sh
KDE_CICD_STAGE_integration_test_IMAGE=node:20

KDE_CICD_STAGE_build_image_SCRIPT=build-image.sh
KDE_CICD_STAGE_build_image_IMAGE=docker:latest

KDE_CICD_STAGE_deploy_staging_SCRIPT=deploy-staging.sh
KDE_CICD_STAGE_deploy_staging_IMAGE=r82wei/deploy-env:1.0.0

KDE_CICD_STAGE_smoke_test_SCRIPT=smoke-test.sh
KDE_CICD_STAGE_smoke_test_IMAGE=node:20

KDE_CICD_STAGE_deploy_production_SCRIPT=deploy-production.sh
KDE_CICD_STAGE_deploy_production_IMAGE=r82wei/deploy-env:1.0.0

KDE_CICD_STAGE_healthcheck_SCRIPT=healthcheck.sh
KDE_CICD_STAGE_healthcheck_IMAGE=r82wei/deploy-env:1.0.0

# 錯誤處理
KDE_DEVOPS_FAIL_FAST=true
KDE_DEVOPS_AUTO_ROLLBACK=true

# Helm 設定
HELM_CONFIG_HOME=${PROJECT_PATH}/.helm/config
HELM_CACHE_HOME=${PROJECT_PATH}/.helm/cache
HELM_DATA_HOME=${PROJECT_PATH}/.helm/data
HELM_PLUGINS=${PROJECT_PATH}/.helm/plugins

# 應用設定
APP_VERSION=1.0.0
STAGING_NAMESPACE=secure-app-staging
PRODUCTION_NAMESPACE=secure-app-production
```

## Pipeline 階段腳本

### lint.sh - 程式碼檢查

```bash
#!/bin/bash
set -e

echo "📝 Lint：程式碼風格檢查"

cd secure-app-repo

# 安裝依賴
npm install

# ESLint 檢查
echo "執行 ESLint..."
npm run lint

# Prettier 格式檢查
echo "執行 Prettier 格式檢查..."
npm run format:check

# TypeScript 類型檢查
echo "執行 TypeScript 類型檢查..."
npm run type-check

echo "✅ Lint 完成"
```

### security-scan.sh - 安全掃描

```bash
#!/bin/bash
set -e

echo "🔒 Security Scan：安全掃描"

cd secure-app-repo

# 依賴安全掃描
echo "執行 npm audit..."
npm audit --audit-level=moderate

# 使用 Trivy 掃描程式碼
echo "執行 Trivy 程式碼掃描..."
trivy fs --severity HIGH,CRITICAL .

# 檢查機密資訊洩漏（使用 gitleaks 或類似工具）
if command -v gitleaks &> /dev/null; then
    echo "執行 gitleaks 掃描..."
    gitleaks detect --source . --verbose
fi

echo "✅ 安全掃描完成"
```

### build.sh - 建置專案

```bash
#!/bin/bash
set -e

echo "🔨 Build：建置專案"

cd secure-app-repo

# 清理舊的建置產物
rm -rf dist

# 安裝依賴
npm ci --production=false

# 建置
echo "建置專案..."
npm run build

# 驗證建置產物
if [ ! -d "dist" ]; then
    echo "❌ 建置失敗：dist 目錄不存在"
    exit 1
fi

echo "建置產物大小："
du -sh dist

echo "✅ 建置完成"
```

### unit-test.sh - 單元測試

```bash
#!/bin/bash
set -e

echo "🧪 Unit Test：單元測試"

cd secure-app-repo

# 執行單元測試
echo "執行單元測試..."
npm run test:unit -- --coverage

# 檢查測試覆蓋率
echo "測試覆蓋率報告："
npm run test:coverage:report

# 驗證最低覆蓋率（例如 80%）
COVERAGE=$(npm run test:coverage:json | jq '.total.lines.pct')
if (( $(echo "$COVERAGE < 80" | bc -l) )); then
    echo "❌ 測試覆蓋率不足：${COVERAGE}% < 80%"
    exit 1
fi

echo "✅ 單元測試完成（覆蓋率：${COVERAGE}%）"
```

### integration-test.sh - 整合測試

```bash
#!/bin/bash
set -e

echo "🔗 Integration Test：整合測試"

cd secure-app-repo

# 啟動測試資料庫（如果需要）
if [ -f "docker-compose.test.yml" ]; then
    echo "啟動測試服務..."
    docker-compose -f docker-compose.test.yml up -d
    sleep 10
fi

# 執行整合測試
echo "執行整合測試..."
npm run test:integration

# 清理測試服務
if [ -f "docker-compose.test.yml" ]; then
    echo "清理測試服務..."
    docker-compose -f docker-compose.test.yml down
fi

echo "✅ 整合測試完成"
```

### build-image.sh - 建置 Docker 映像

```bash
#!/bin/bash
set -e

echo "🐳 Build Image：建置 Docker 映像"

cd secure-app-repo

# 取得版本號
VERSION=${APP_VERSION:-$(node -p "require('./package.json').version")}
echo "版本：${VERSION}"

# 建置 Docker 映像
echo "建置 Docker 映像..."
docker build \
    -t secure-app:${VERSION} \
    -t secure-app:latest \
    --build-arg VERSION=${VERSION} \
    .

# 使用 Trivy 掃描映像
echo "掃描 Docker 映像..."
trivy image --severity HIGH,CRITICAL secure-app:${VERSION}

# 載入映像到 K8s 環境（kind/k3d）
if [ -n "${K8S_CONTAINER_NAME}" ]; then
    echo "載入映像到 K8s 環境..."
    kde load-image secure-app:${VERSION}
fi

echo "✅ Docker 映像建置完成"
```

### deploy-staging.sh - 部署到測試環境

```bash
#!/bin/bash
set -e

echo "🚀 Deploy Staging：部署到測試環境"

cd secure-app-repo

# 建立 Namespace
kubectl create namespace ${STAGING_NAMESPACE} --dry-run=client -o yaml | kubectl apply -f -

# 使用 Helm 部署
echo "部署到測試環境..."
helm upgrade --install secure-app ./helm \
    --namespace ${STAGING_NAMESPACE} \
    --set image.tag=${APP_VERSION} \
    --set environment=staging \
    --create-namespace \
    --wait \
    --timeout 5m

# 等待 Pod 就緒
echo "等待 Pod 就緒..."
kubectl wait --for=condition=ready pod \
    -l app=secure-app \
    -n ${STAGING_NAMESPACE} \
    --timeout=300s

echo "✅ 部署到測試環境完成"
```

### smoke-test.sh - 冒煙測試

```bash
#!/bin/bash
set -e

echo "💨 Smoke Test：冒煙測試"

# 取得服務端點
SERVICE_URL=$(kubectl get svc secure-app -n ${STAGING_NAMESPACE} -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
if [ -z "${SERVICE_URL}" ]; then
    SERVICE_URL="localhost"
    # Port forward 到本地
    kubectl port-forward -n ${STAGING_NAMESPACE} svc/secure-app 8080:80 &
    PORT_FORWARD_PID=$!
    sleep 5
fi

# 健康檢查
echo "健康檢查..."
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://${SERVICE_URL}:8080/health)
if [ "${HTTP_CODE}" != "200" ]; then
    echo "❌ 健康檢查失敗：HTTP ${HTTP_CODE}"
    [ -n "${PORT_FORWARD_PID}" ] && kill ${PORT_FORWARD_PID}
    exit 1
fi

# API 測試
echo "API 測試..."
RESPONSE=$(curl -s http://${SERVICE_URL}:8080/api/version)
if [ -z "${RESPONSE}" ]; then
    echo "❌ API 測試失敗：無回應"
    [ -n "${PORT_FORWARD_PID}" ] && kill ${PORT_FORWARD_PID}
    exit 1
fi

# 清理 port forward
[ -n "${PORT_FORWARD_PID}" ] && kill ${PORT_FORWARD_PID}

echo "✅ 冒煙測試完成"
```

### deploy-production.sh - 部署到生產環境

```bash
#!/bin/bash
set -e

echo "🚀 Deploy Production：部署到生產環境"

cd secure-app-repo

# 確認部署（可選）
read -p "確認要部署到生產環境？(yes/no): " CONFIRM
if [ "${CONFIRM}" != "yes" ]; then
    echo "❌ 部署已取消"
    exit 1
fi

# 建立 Namespace
kubectl create namespace ${PRODUCTION_NAMESPACE} --dry-run=client -o yaml | kubectl apply -f -

# 備份當前版本（用於回滾）
echo "備份當前版本..."
CURRENT_VERSION=$(helm list -n ${PRODUCTION_NAMESPACE} -o json | jq -r '.[0].app_version // "none"')
echo "當前版本：${CURRENT_VERSION}"

# 使用 Helm 部署（金絲雀發布）
echo "部署到生產環境（金絲雀發布）..."
helm upgrade --install secure-app ./helm \
    --namespace ${PRODUCTION_NAMESPACE} \
    --set image.tag=${APP_VERSION} \
    --set environment=production \
    --set replicaCount=3 \
    --set canary.enabled=true \
    --set canary.weight=20 \
    --create-namespace \
    --wait \
    --timeout 10m

# 等待 Pod 就緒
echo "等待 Pod 就緒..."
kubectl wait --for=condition=ready pod \
    -l app=secure-app \
    -n ${PRODUCTION_NAMESPACE} \
    --timeout=600s

echo "✅ 部署到生產環境完成"
echo "當前版本：${CURRENT_VERSION} → ${APP_VERSION}"
```

### healthcheck.sh - 健康檢查

```bash
#!/bin/bash
set -e

echo "📊 Healthcheck：健康檢查"

# 檢查測試環境
echo "檢查測試環境..."
kubectl get pods -n ${STAGING_NAMESPACE} -l app=secure-app
STAGING_STATUS=$(kubectl get pods -n ${STAGING_NAMESPACE} -l app=secure-app -o jsonpath='{.items[0].status.phase}')
echo "測試環境狀態：${STAGING_STATUS}"

# 檢查生產環境
echo "檢查生產環境..."
kubectl get pods -n ${PRODUCTION_NAMESPACE} -l app=secure-app
PRODUCTION_STATUS=$(kubectl get pods -n ${PRODUCTION_NAMESPACE} -l app=secure-app -o jsonpath='{.items[0].status.phase}')
echo "生產環境狀態：${PRODUCTION_STATUS}"

# 檢查資源使用情況
echo "資源使用情況："
kubectl top pods -n ${PRODUCTION_NAMESPACE} -l app=secure-app || echo "Metrics server 未啟用"

# 檢查最近的事件
echo "最近的事件："
kubectl get events -n ${PRODUCTION_NAMESPACE} --sort-by='.lastTimestamp' | tail -10

# 驗證健康狀態
if [ "${STAGING_STATUS}" != "Running" ]; then
    echo "⚠️  測試環境狀態異常"
fi

if [ "${PRODUCTION_STATUS}" != "Running" ]; then
    echo "❌ 生產環境狀態異常"
    exit 1
fi

echo "✅ 健康檢查完成"
```

## 使用方式

### 完整流程

```bash
# 建立專案
kde project create secure-app

# 執行完整 Pipeline
kde project deploy secure-app
```

輸出：
```
📋 執行自定義 Pipeline

📋 階段列表: lint security-scan build unit-test integration-test build-image deploy-staging smoke-test deploy-production healthcheck

🔄 執行階段: lint
   📄 腳本: lint.sh
   🐳 映像: node:20
...
✅ 階段 lint 執行完成

🔄 執行階段: security-scan
   📄 腳本: security-scan.sh
   🐳 映像: aquasec/trivy:latest
...
✅ 階段 security-scan 執行完成

...

✅ Pipeline 執行完成（執行了 10 個階段）
```

### 只執行部分階段

編輯 `.env` 檔案（臨時覆寫）：

```bash
# 只執行到測試階段
KDE_CICD_STAGES="lint security-scan build unit-test integration-test"
```

或者跳過生產部署：

```bash
# 跳過生產部署
KDE_CICD_STAGE_deploy_production_SKIP=true
```

## 環境特定配置

### 開發環境 (.env)

```bash
# 跳過耗時的階段
KDE_CICD_STAGE_security_scan_SKIP=true
KDE_CICD_STAGE_integration_test_SKIP=true
KDE_CICD_STAGE_deploy_production_SKIP=true

# 快速開發模式
KDE_CICD_STAGES="lint build unit-test deploy-staging"
```

### 生產環境 (.env)

```bash
# 完整流程，不跳過任何階段
KDE_DEVOPS_FAIL_FAST=true
KDE_DEVOPS_AUTO_ROLLBACK=true

# 使用生產配置
APP_VERSION=1.0.0
STAGING_NAMESPACE=secure-app-staging
PRODUCTION_NAMESPACE=secure-app-production
```

## 進階場景

### 場景 1：快速 Hotfix

```bash
# .env
KDE_CICD_STAGES="lint build deploy-production healthcheck"
KDE_CICD_STAGE_security_scan_SKIP=true
KDE_CICD_STAGE_unit_test_SKIP=true
KDE_CICD_STAGE_integration_test_SKIP=true
```

### 場景 2：安全優先模式

```bash
# project.env
KDE_CICD_STAGES="security-scan,lint,build,unit-test,integration-test,security-scan,build-image,security-scan,deploy-staging,smoke-test,deploy-production,healthcheck"

# 在關鍵階段都執行安全掃描
```

### 場景 3：金絲雀部署

```bash
# 階段 1：部署金絲雀
KDE_CICD_STAGES="build build-image deploy-canary verify-canary"

# 階段 2：全量部署
KDE_CICD_STAGES="deploy-full healthcheck"
```

## 最佳實踐

1. **階段命名**：使用清晰、描述性的名稱
2. **錯誤處理**：在每個腳本開頭使用 `set -e`
3. **日誌輸出**：提供清晰的進度訊息和結果
4. **資源清理**：確保測試資源在完成後被清理
5. **環境隔離**：使用不同的 namespace 隔離環境
6. **版本管理**：追蹤和記錄每次部署的版本
7. **回滾準備**：保留足夠的資訊以支援快速回滾

## 除錯技巧

### 進入特定階段的環境

```bash
# 使用該階段的映像進入容器
kde project exec secure-app dev

# 手動執行腳本
./lint.sh
./security-scan.sh
```

### 查看詳細日誌

```bash
# 開啟除錯模式（在 kde.env 中）
KDE_DEBUG=true

# 執行 Pipeline
kde project deploy secure-app 2>&1 | tee pipeline.log
```

### 跳過失敗繼續執行

```bash
# 在 project.env 中設定
KDE_DEVOPS_FAIL_FAST=false
```

## 總結

自定義 Pipeline 提供：
- ✅ 完全自訂的階段和順序
- ✅ 每階段獨立配置
- ✅ 靈活的錯誤處理
- ✅ 環境特定配置
- ✅ 易於擴展和維護

適合：
- 有特殊流程需求的專案
- 需要整合多種工具的場景
- 金絲雀部署、藍綠部署等進階部署策略
- 安全性要求高的專案
