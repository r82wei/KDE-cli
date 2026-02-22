# KDE-CLI Pipeline 配置模式與範例

## project.env 完整配置參考

| 環境變數 | 說明 | 預設值 |
|---------|------|--------|
| `KDE_PIPELINE_STAGES` | Pipeline 流程定義 | `build,deploy` |
| `KDE_PIPELINE_STAGE_<stage>_IMAGE` | 階段容器映像 | `DEPLOY_IMAGE` |
| `KDE_PIPELINE_STAGE_<stage>_SCRIPT` | 階段腳本檔案 | `<stage>.sh`（若存在） |
| `KDE_PIPELINE_STAGE_<stage>_SKIP` | 跳過此階段 | `false` |
| `KDE_PIPELINE_STAGE_<stage>_MANUAL_ONLY` | 只能 `--manual` 觸發 | `false` |
| `KDE_PIPELINE_STAGE_<stage>_ALLOW_FAILURE` | 失敗不中斷 Pipeline | `false` |
| `KDE_PIPELINE_STAGE_<stage>_PAUSE` | 執行後暫停等確認 | `false` |
| `KDE_PIPELINE_STAGE_<stage>_MOUNT_<name>` | 階段專屬掛載 | 無 |
| `KDE_MOUNT_<name>` | 所有階段共用掛載 | 無 |
| `KDE_PIPELINE_FAIL_FAST` | 任何失敗立即停止 | `true` |

---

## 範例 1：Node.js 最簡配置

```bash
# project.env
GIT_REPO_URL=https://github.com/user/myapp.git
GIT_REPO_BRANCH=main
DEVELOP_IMAGE=node:20
DEPLOY_IMAGE=r82wei/deploy-env:1.0.0

KDE_PIPELINE_STAGES="build,deploy"
KDE_PIPELINE_STAGE_build_IMAGE=node:20
KDE_PIPELINE_STAGE_build_SCRIPT=build.sh
KDE_PIPELINE_STAGE_deploy_IMAGE=r82wei/deploy-env:1.0.0
KDE_PIPELINE_STAGE_deploy_SCRIPT=deploy.sh
```

```bash
# build.sh
#!/bin/bash
set -e
npm install
npm run build
```

```bash
# deploy.sh
#!/bin/bash
set -e
NAMESPACE=myapp
kubectl create namespace ${NAMESPACE} --dry-run=client -o yaml | kubectl apply -f -
kubectl apply -f k8s/ -n ${NAMESPACE}
kubectl rollout status deployment/myapp -n ${NAMESPACE}
```

---

## 範例 2：完整 CI/CD Pipeline（build → test → release → deploy）

```bash
# project.env
KDE_PIPELINE_STAGES="build,test,release,deploy"

KDE_PIPELINE_STAGE_build_IMAGE=node:20
KDE_PIPELINE_STAGE_build_SCRIPT=build.sh

KDE_PIPELINE_STAGE_test_IMAGE=node:20
KDE_PIPELINE_STAGE_test_SCRIPT=test.sh

KDE_PIPELINE_STAGE_release_IMAGE=docker:latest
KDE_PIPELINE_STAGE_release_SCRIPT=release.sh
KDE_PIPELINE_STAGE_release_MOUNT_DOCKER=${HOME}/.docker:/root/.docker:ro

KDE_PIPELINE_STAGE_deploy_IMAGE=r82wei/deploy-env:1.0.0
KDE_PIPELINE_STAGE_deploy_SCRIPT=deploy.sh

DOCKER_REGISTRY=registry.example.com
```

```bash
# release.sh（建置並推送 Docker 映像）
#!/bin/bash
set -e
VERSION=$(cat package.json | jq -r .version)
IMAGE_NAME="${DOCKER_REGISTRY}/myapp:${VERSION}"

docker build -t ${IMAGE_NAME} .
docker push ${IMAGE_NAME}

# 傳遞給 deploy 階段
echo "APP_IMAGE=${IMAGE_NAME}" >> .pipeline.env
echo "APP_VERSION=${VERSION}" >> .pipeline.env
```

```bash
# deploy.sh（讀取上游變數部署）
#!/bin/bash
set -e
source .pipeline.env

helm upgrade --install myapp ./helm/myapp \
    --namespace myapp \
    --create-namespace \
    --set image.tag=${APP_VERSION} \
    --wait
```

---

## 範例 3：安全優先模式（含 lint、security scan）

```bash
# project.env
KDE_PIPELINE_STAGES="test,lint,build,security-scan,deploy"

KDE_PIPELINE_STAGE_test_IMAGE=node:20
KDE_PIPELINE_STAGE_test_SCRIPT=test.sh

# lint 只能手動觸發，允許失敗
KDE_PIPELINE_STAGE_lint_IMAGE=node:20
KDE_PIPELINE_STAGE_lint_SCRIPT=lint.sh
KDE_PIPELINE_STAGE_lint_MANUAL_ONLY=true
KDE_PIPELINE_STAGE_lint_ALLOW_FAILURE=true

KDE_PIPELINE_STAGE_build_IMAGE=node:20
KDE_PIPELINE_STAGE_build_SCRIPT=build.sh

# security-scan 預設跳過（手動開啟）
KDE_PIPELINE_STAGE_security-scan_IMAGE=aquasec/trivy:latest
KDE_PIPELINE_STAGE_security-scan_SCRIPT=security-scan.sh
KDE_PIPELINE_STAGE_security-scan_SKIP=true

KDE_PIPELINE_STAGE_deploy_IMAGE=r82wei/deploy-env:1.0.0
KDE_PIPELINE_STAGE_deploy_SCRIPT=deploy.sh
```

```bash
# 執行方式
kde proj pipeline myapp                       # 正常：跳過 lint(MANUAL_ONLY) 和 security-scan(SKIP)
kde proj pipeline myapp --manual              # 含 lint，仍跳過 security-scan
kde proj pipeline myapp --only lint --manual  # 只執行 lint
kde proj pipeline myapp --only security-scan  # 只執行 security-scan
```

---

## 範例 4：部署前預覽確認（PAUSE 模式）

```bash
# project.env
KDE_PIPELINE_STAGES="build,preview,deploy"

KDE_PIPELINE_STAGE_build_IMAGE=node:20
KDE_PIPELINE_STAGE_build_SCRIPT=build.sh

KDE_PIPELINE_STAGE_preview_IMAGE=r82wei/deploy-env:1.0.0
KDE_PIPELINE_STAGE_preview_SCRIPT=preview.sh
KDE_PIPELINE_STAGE_preview_PAUSE=true          # 執行後暫停等使用者確認

KDE_PIPELINE_STAGE_deploy_IMAGE=r82wei/deploy-env:1.0.0
KDE_PIPELINE_STAGE_deploy_SCRIPT=deploy.sh
```

```bash
# preview.sh（顯示 diff，讓使用者確認）
#!/bin/bash
helm diff upgrade myapp ./helm/myapp -f values.yaml
# 或
kubectl diff -f manifests/
# Pipeline 會在此暫停，輸入 y 繼續，N/Enter 取消
```

---

## 範例 5：Go 專案

```bash
# project.env
DEVELOP_IMAGE=golang:1.21
DEPLOY_IMAGE=r82wei/deploy-env:1.0.0

KDE_PIPELINE_STAGES="test,build,deploy"
KDE_PIPELINE_STAGE_test_IMAGE=golang:1.21
KDE_PIPELINE_STAGE_test_SCRIPT=test.sh
KDE_PIPELINE_STAGE_build_IMAGE=golang:1.21
KDE_PIPELINE_STAGE_build_SCRIPT=build.sh
KDE_PIPELINE_STAGE_deploy_IMAGE=r82wei/deploy-env:1.0.0
KDE_PIPELINE_STAGE_deploy_SCRIPT=deploy.sh
```

---

## 範例 6：Python 專案

```bash
# project.env
DEVELOP_IMAGE=python:3.11
DEPLOY_IMAGE=r82wei/deploy-env:1.0.0

KDE_PIPELINE_STAGES="test,build,deploy"
KDE_PIPELINE_STAGE_test_IMAGE=python:3.11
KDE_PIPELINE_STAGE_test_SCRIPT=test.sh
KDE_PIPELINE_STAGE_build_IMAGE=python:3.11
KDE_PIPELINE_STAGE_build_SCRIPT=build.sh
KDE_PIPELINE_STAGE_deploy_IMAGE=r82wei/deploy-env:1.0.0
KDE_PIPELINE_STAGE_deploy_SCRIPT=deploy.sh
```

---

## 範例 7：使用 Helm 部署

```bash
# project.env
DEPLOY_IMAGE=r82wei/deploy-env:1.0.0
HELM_CONFIG_HOME=${PROJECT_PATH}/.helm/config
HELM_CACHE_HOME=${PROJECT_PATH}/.helm/cache
HELM_DATA_HOME=${PROJECT_PATH}/.helm/data
HELM_PLUGINS=${PROJECT_PATH}/.helm/plugins

NAMESPACE=myapp
RELEASE_NAME=myapp
CHART_PATH=${PROJECT_PATH}/myapp/helm/myapp
```

```bash
# deploy.sh
#!/bin/bash
set -e
helm upgrade --install ${RELEASE_NAME} ${CHART_PATH} \
    --namespace ${NAMESPACE} \
    --create-namespace \
    --set image.tag=${APP_VERSION} \
    --wait
echo "✅ Helm 部署完成"
```

---

## 範例 8：掛載 SSH 金鑰進行 Git 操作

```bash
# project.env
KDE_MOUNT_SSH=${HOME}/.ssh:${HOME}/.ssh:ro
```

```bash
# build.sh 或任何腳本內可直接使用 SSH
git pull
git push
```

---

## 範例 9：DooD（在 Pipeline 容器內建置 Docker 映像）

```bash
# project.env
KDE_PIPELINE_STAGE_release_IMAGE=docker:latest
KDE_PIPELINE_STAGE_release_SCRIPT=release.sh
KDE_PIPELINE_STAGE_release_MOUNT_DOCKER=${HOME}/.docker:/root/.docker:ro
```

```bash
# release.sh
#!/bin/bash
set -e
# DooD：docker socket 由 KDE-CLI 自動掛載
docker build -t myapp:latest .
docker push registry.example.com/myapp:latest
echo "APP_IMAGE=registry.example.com/myapp:latest" >> .pipeline.env

# 若要載入到本地 Kind/K3D 集群
# 回到宿主機執行：kde load-image myapp:latest
```

---

## 腳本最佳實踐

```bash
#!/bin/bash
set -e          # 遇到錯誤立即退出

# 良好的錯誤訊息
echo "🔨 開始建置..."
echo "✅ 建置完成"

# 檢查必要變數
if [[ -z "${NAMESPACE}" ]]; then
    echo "❌ 錯誤：NAMESPACE 未設定"
    exit 1
fi

# 互動式讀取敏感資訊（寫入 .env，不版控）
if [[ -z "${DATABASE_PASSWORD}" ]]; then
    read -sp "請輸入資料庫密碼: " DB_PASSWORD
    echo ""
    echo "DATABASE_PASSWORD=${DB_PASSWORD}" >> .env
    source .env
fi

# 等待 Pod 就緒
kubectl -n ${NAMESPACE} wait \
    --for=condition=ready pod \
    -l app=${APP_NAME} \
    --timeout=300s
```

---

## 多環境差異配置

同一份 `project.env` 搭配不同環境的 `k8s.env`，實現環境差異化：

```bash
# environments/dev-env/k8s.env
ENV_TYPE=kind
STORAGE_CLASS=local-path

# environments/prod-env/k8s.env
ENV_TYPE=k8s
STORAGE_CLASS=standard
```

```bash
# deploy.sh 根據 ENV_TYPE 判斷
if [[ "${ENV_TYPE}" == "kind" ]] || [[ "${ENV_TYPE}" == "k3d" ]]; then
    # 本地環境：使用 local-path PVC
    kubectl apply -f k8s/pvc-local.yaml
else
    # 生產環境：使用雲端 StorageClass
    kubectl apply -f k8s/pvc-prod.yaml
fi
```

---

## PVC Hot Reload 完整範例（Node.js）

```bash
# deploy.sh
#!/bin/bash
set -e
NAMESPACE=myapp
APP_NAME=myapp

kubectl create namespace ${NAMESPACE} --dry-run=client -o yaml | kubectl apply -f -

# PVC 名稱 "source-code" → 自動對應 namespaces/myapp/source-code/ 資料夾
kubectl apply -f - <<EOF
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: source-code
  namespace: ${NAMESPACE}
spec:
  accessModes: [ReadWriteOnce]
  storageClassName: local-path
  resources:
    requests:
      storage: 1Gi
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ${APP_NAME}
  namespace: ${NAMESPACE}
spec:
  replicas: 1
  selector:
    matchLabels:
      app: ${APP_NAME}
  template:
    metadata:
      labels:
        app: ${APP_NAME}
    spec:
      containers:
      - name: ${APP_NAME}
        image: node:20
        command: ["/bin/sh", "-c", "cd /app && npm install && npm run dev"]
        workingDir: /app
        ports:
        - containerPort: 3000
        volumeMounts:
        - name: source
          mountPath: /app
      volumes:
      - name: source
        persistentVolumeClaim:
          claimName: source-code
EOF

kubectl -n ${NAMESPACE} rollout status deployment/${APP_NAME}
```

---

## 常見 Pipeline 問題排除

```bash
# 腳本沒有執行權限
chmod +x environments/<env>/namespaces/<project>/*.sh

# 查看階段容器內的環境變數
kde proj pipeline myapp --only build --manual
# 容器內執行：
env | sort
env | grep KDE
echo $PROJECT_PATH

# 查看 .pipeline.env 是否正確生成
cat environments/<env>/namespaces/<project>/.pipeline.env

# KDE CLI 層級除錯
KDE_DEBUG=true kde proj pipeline myapp

# 腳本層級除錯（加入 build.sh 開頭）
set -x
```
