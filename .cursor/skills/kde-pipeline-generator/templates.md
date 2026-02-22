# Pipeline 腳本模板

## Node.js

### build.sh
```bash
#!/bin/bash
set -e

echo "=== [build] 安裝依賴 ==="
npm install

echo "=== [build] 建置應用 ==="
npm run build

echo "✅ build 完成"
```

### test.sh
```bash
#!/bin/bash
set -e

echo "=== [test] 執行測試 ==="
npm test

echo "✅ test 完成"
```

### lint.sh
```bash
#!/bin/bash
set -e

echo "=== [lint] 執行 Lint ==="
npm run lint

echo "✅ lint 完成"
```

---

## Go

### build.sh
```bash
#!/bin/bash
set -e

echo "=== [build] 下載依賴 ==="
go mod download

echo "=== [build] 編譯 ==="
go build -o bin/${APP_NAME} ./...

echo "✅ build 完成"
```

### test.sh
```bash
#!/bin/bash
set -e

echo "=== [test] 執行測試 ==="
go test ./...

echo "✅ test 完成"
```

### lint.sh
```bash
#!/bin/bash
set -e

echo "=== [lint] 執行 Lint ==="
# 需要 golangci/golangci-lint 映像
# project.env 中設定：KDE_PIPELINE_STAGE_lint_IMAGE=golangci/golangci-lint:latest
golangci-lint run ./...

echo "✅ lint 完成"
```

---

## Python

### build.sh
```bash
#!/bin/bash
set -e

echo "=== [build] 安裝依賴 ==="
if [ -f "requirements.txt" ]; then
    pip install -r requirements.txt
elif [ -f "pyproject.toml" ]; then
    pip install -e .
elif [ -f "Pipfile" ]; then
    pip install pipenv && pipenv install
fi

echo "✅ build 完成"
```

### test.sh
```bash
#!/bin/bash
set -e

echo "=== [test] 執行測試 ==="
pytest

echo "✅ test 完成"
```

### lint.sh
```bash
#!/bin/bash
set -e

echo "=== [lint] 執行 Lint ==="
flake8 .
# 或使用 ruff：ruff check .

echo "✅ lint 完成"
```

---

## Java (Maven)

### build.sh
```bash
#!/bin/bash
set -e

echo "=== [build] Maven 建置 ==="
mvn clean package -DskipTests

echo "✅ build 完成"
```

### test.sh
```bash
#!/bin/bash
set -e

echo "=== [test] Maven 測試 ==="
mvn test

echo "✅ test 完成"
```

---

## Java (Gradle)

### build.sh
```bash
#!/bin/bash
set -e

echo "=== [build] Gradle 建置 ==="
gradle build -x test

echo "✅ build 完成"
```

### test.sh
```bash
#!/bin/bash
set -e

echo "=== [test] Gradle 測試 ==="
gradle test

echo "✅ test 完成"
```

---

## Rust

### build.sh
```bash
#!/bin/bash
set -e

echo "=== [build] Cargo 建置 ==="
cargo build --release

echo "✅ build 完成"
```

### test.sh
```bash
#!/bin/bash
set -e

echo "=== [test] Cargo 測試 ==="
cargo test

echo "✅ test 完成"
```

---

## Release（DooD - 建置並推送 Docker 映像）

適用於所有技術棧，需要 `docker:latest` 或 `docker:24-cli` 映像，並掛載 Docker config。

```bash
# project.env 需加入：
# KDE_PIPELINE_STAGE_release_IMAGE=docker:latest
# KDE_PIPELINE_STAGE_release_MOUNT_DOCKER=${HOME}/.docker:/root/.docker:ro
# DOCKER_REGISTRY=registry.example.com
```

### release.sh
```bash
#!/bin/bash
set -e

# 取得版本號（優先使用 git tag，fallback 到 git commit hash）
VERSION=$(git tag --points-at HEAD 2>/dev/null | head -n1)
if [[ -z "${VERSION}" ]]; then
    VERSION=$(git rev-parse --short HEAD 2>/dev/null || echo "latest")
fi

IMAGE_NAME="${DOCKER_REGISTRY}/${APP_NAME}:${VERSION}"
IMAGE_LATEST="${DOCKER_REGISTRY}/${APP_NAME}:latest"

echo "=== [release] 建置 Docker 映像：${IMAGE_NAME} ==="
docker build -t "${IMAGE_NAME}" -t "${IMAGE_LATEST}" .

echo "=== [release] 推送映像到 Registry ==="
docker push "${IMAGE_NAME}"
docker push "${IMAGE_LATEST}"

# 傳遞給 deploy 階段
echo "APP_IMAGE=${IMAGE_NAME}" >> .pipeline.env
echo "APP_VERSION=${VERSION}" >> .pipeline.env

echo "✅ release 完成：${IMAGE_NAME}"
```

---

## Deploy（kubectl raw YAML）

### deploy.sh
```bash
#!/bin/bash
set -e

NAMESPACE=${NAMESPACE:-${APP_NAME}}
APP_PORT=${APP_PORT:-8080}

echo "=== [deploy] 建立 Namespace ==="
kubectl create namespace "${NAMESPACE}" --dry-run=client -o yaml | kubectl apply -f -

echo "=== [deploy] 部署應用 ==="
kubectl apply -f k8s/ -n "${NAMESPACE}"

echo "=== [deploy] 等待 Pod 就緒 ==="
kubectl -n "${NAMESPACE}" rollout status deployment/"${APP_NAME}" --timeout=300s

echo "✅ deploy 完成（namespace: ${NAMESPACE}）"
```

### undeploy.sh（kubectl）
```bash
#!/bin/bash
set -e

NAMESPACE=${NAMESPACE:-${APP_NAME}}

echo "=== [undeploy] 移除應用資源 ==="
kubectl delete -f k8s/ -n "${NAMESPACE}" --ignore-not-found

echo "✅ undeploy 完成"
# 注意：不刪除整個 namespace，避免誤刪其他資源
```

---

## Deploy（Helm）

```bash
# project.env 需加入：
# HELM_CONFIG_HOME=${PROJECT_PATH}/.helm/config
# HELM_CACHE_HOME=${PROJECT_PATH}/.helm/cache
# HELM_DATA_HOME=${PROJECT_PATH}/.helm/data
# HELM_PLUGINS=${PROJECT_PATH}/.helm/plugins
# HELM_CHART_PATH=./helm/<project_name>   （或 ./charts/<project_name>）
```

### deploy.sh（Helm）
```bash
#!/bin/bash
set -e

NAMESPACE=${NAMESPACE:-${APP_NAME}}
RELEASE_NAME=${APP_NAME}
CHART_PATH=${HELM_CHART_PATH:-./helm/${APP_NAME}}

echo "=== [deploy] Helm 部署：${RELEASE_NAME} ==="

# 若有 release 階段傳遞的映像
if [[ -f ".pipeline.env" ]]; then
    source .pipeline.env
fi

helm upgrade --install "${RELEASE_NAME}" "${CHART_PATH}" \
    --namespace "${NAMESPACE}" \
    --create-namespace \
    ${APP_IMAGE:+--set image.repository="${APP_IMAGE%:*}"} \
    ${APP_VERSION:+--set image.tag="${APP_VERSION}"} \
    --wait \
    --timeout 5m

echo "✅ deploy 完成（release: ${RELEASE_NAME}, namespace: ${NAMESPACE}）"
```

### undeploy.sh（Helm）
```bash
#!/bin/bash
set -e

NAMESPACE=${NAMESPACE:-${APP_NAME}}
RELEASE_NAME=${APP_NAME}

echo "=== [undeploy] Helm 卸載：${RELEASE_NAME} ==="
helm uninstall "${RELEASE_NAME}" --namespace "${NAMESPACE}" --ignore-not-found

echo "✅ undeploy 完成"
```

---

## Deploy（Kustomize）

### deploy.sh（Kustomize）
```bash
#!/bin/bash
set -e

NAMESPACE=${NAMESPACE:-${APP_NAME}}

echo "=== [deploy] 建立 Namespace ==="
kubectl create namespace "${NAMESPACE}" --dry-run=client -o yaml | kubectl apply -f -

echo "=== [deploy] Kustomize 部署 ==="
kubectl apply -k . -n "${NAMESPACE}"

echo "=== [deploy] 等待 Pod 就緒 ==="
kubectl -n "${NAMESPACE}" rollout status deployment/"${APP_NAME}" --timeout=300s

echo "✅ deploy 完成（namespace: ${NAMESPACE}）"
```

### undeploy.sh（Kustomize）
```bash
#!/bin/bash
set -e

NAMESPACE=${NAMESPACE:-${APP_NAME}}

echo "=== [undeploy] Kustomize 移除 ==="
kubectl delete -k . -n "${NAMESPACE}" --ignore-not-found

echo "✅ undeploy 完成"
```

---

## Deploy（本地 PVC Hot Reload，適用 Kind/K3D）

當不使用 private registry 時，透過 PVC 掛載 source code 到 Pod，實現 Hot Reload。

### deploy.sh（PVC Hot Reload）
```bash
#!/bin/bash
set -e

NAMESPACE=${NAMESPACE:-${APP_NAME}}
APP_PORT=${APP_PORT:-8080}

echo "=== [deploy] 建立 Namespace ==="
kubectl create namespace "${NAMESPACE}" --dry-run=client -o yaml | kubectl apply -f -

echo "=== [deploy] 部署（含 PVC 掛載）==="
kubectl apply -n "${NAMESPACE}" -f - <<EOF
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
        image: ${DEVELOP_IMAGE}
        command: ["/bin/sh", "-c", "cd /app && <啟動指令>"]
        workingDir: /app
        ports:
        - containerPort: ${APP_PORT}
        volumeMounts:
        - name: source
          mountPath: /app
      volumes:
      - name: source
        persistentVolumeClaim:
          claimName: source-code
---
apiVersion: v1
kind: Service
metadata:
  name: ${APP_NAME}
  namespace: ${NAMESPACE}
spec:
  selector:
    app: ${APP_NAME}
  ports:
  - port: ${APP_PORT}
    targetPort: ${APP_PORT}
  type: ClusterIP
EOF

kubectl -n "${NAMESPACE}" wait --for=condition=ready pod \
    -l app="${APP_NAME}" --timeout=300s

echo "✅ deploy 完成（PVC source-code 對應 namespaces/${APP_NAME}/source-code/）"
```

**各語言啟動指令替換**：

| 技術棧 | 替換 `<啟動指令>` |
|--------|----------------|
| Node.js | `npm install && npm run dev` |
| Python | `pip install -r requirements.txt && python app.py` |
| Go | `go run ./...` |
| Ruby | `bundle install && ruby app.rb` |

---

## Security Scan（可選階段）

### security-scan.sh

```bash
# project.env 設定：
# KDE_PIPELINE_STAGE_security-scan_IMAGE=aquasec/trivy:latest
# KDE_PIPELINE_STAGE_security-scan_ALLOW_FAILURE=true
```

```bash
#!/bin/bash
set -e

echo "=== [security-scan] 掃描映像 ==="
if [[ -f ".pipeline.env" ]]; then
    source .pipeline.env
fi

trivy image --exit-code 1 --severity HIGH,CRITICAL "${APP_IMAGE:-${APP_NAME}:latest}"

echo "✅ security-scan 完成"
```
