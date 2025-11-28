# KDE 權限控管詳細指南

## 權限控管概覽

KDE 採用多層級的權限控管機制，確保環境和專案的安全性：

1. **[K8s 環境權限](#k8s-環境權限)** - 透過 kubeconfig 管理集群存取
2. **[專案權限](#專案權限)** - 透過 Git 倉庫權限控制程式碼存取
3. **[雲端服務權限](#雲端服務權限)** - 管理外部服務的認證和授權

## K8s 環境權限

### 概述

KDE 使用 Kubernetes 原生的 kubeconfig 機制來管理環境存取權限。每個環境都有獨立的 kubeconfig 配置檔案，確保環境之間的隔離性。

### Kubeconfig 檔案位置

```bash
# 環境 kubeconfig 位置
environments/<env_name>/kubeconfig/config
```

### 權限管理機制

#### 1. 環境隔離

每個環境擁有獨立的 kubeconfig：

```bash
# 開發環境
environments/dev-env/kubeconfig/config

# 測試環境
environments/test-env/kubeconfig/config

# 生產環境
environments/prod-env/kubeconfig/config
```

**特點**：

- 環境間完全隔離
- 不同環境可使用不同的認證方式
- 支援多種 K8s 認證機制

#### 2. RBAC 權限控制

KDE 遵循 Kubernetes RBAC (Role-Based Access Control) 最佳實踐：

**角色定義**：

- **Cluster Admin** - 完整的集群管理權限
- **Namespace Admin** - 特定命名空間的管理權限
- **Developer** - 開發相關的資源操作權限
- **Viewer** - 唯讀權限

**權限配置範例**：

```yaml
# ClusterRole 範例
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: kde-developer
rules:
  - apiGroups: [""]
    resources: ["pods", "services", "configmaps"]
    verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
  - apiGroups: ["apps"]
    resources: ["deployments", "statefulsets"]
    verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
```

#### 3. ServiceAccount 管理

KDE 為不同的操作使用專用的 ServiceAccount：

```bash
# 部署專案時使用的 ServiceAccount
kubectl create serviceaccount kde-deploy-sa -n <namespace>

# 為 ServiceAccount 綁定角色
kubectl create rolebinding kde-deploy-binding \
  --clusterrole=kde-developer \
  --serviceaccount=<namespace>:kde-deploy-sa \
  -n <namespace>
```

### Kubeconfig 配置類型

#### 1. Kind/K3D 本地環境

**特點**：

- 自動生成 kubeconfig
- 使用證書認證
- 完整的管理權限

**配置檔案**：

```yaml
apiVersion: v1
kind: Config
clusters:
  - cluster:
      certificate-authority-data: <base64-encoded-ca>
      server: https://127.0.0.1:<port>
    name: kind-dev-env
contexts:
  - context:
      cluster: kind-dev-env
      user: kind-dev-env
    name: kind-dev-env
current-context: kind-dev-env
users:
  - name: kind-dev-env
    user:
      client-certificate-data: <base64-encoded-cert>
      client-key-data: <base64-encoded-key>
```

#### 2. 外部 K8s 環境

**特點**：

- 需要手動提供 kubeconfig
- 支援多種認證方式
- 可限制權限範圍

### 權限最佳實踐

#### 1. 最小權限原則

只授予完成任務所需的最小權限：

```bash
# 不要使用
kubectl create clusterrolebinding admin-binding \
  --clusterrole=cluster-admin \
  --user=developer

# 應該使用
kubectl create rolebinding developer-binding \
  --clusterrole=edit \
  --user=developer \
  -n specific-namespace
```

#### 2. 環境分離

不同環境使用不同的權限配置：

```bash
# 開發環境 - 較寬鬆的權限
environments/dev-env/kubeconfig/config

# 生產環境 - 嚴格的權限
environments/prod-env/kubeconfig/config
```

#### 3. 定期審計

定期檢查和更新權限設定：

```bash
# 列出所有 RoleBindings
kubectl get rolebindings -A

# 列出所有 ClusterRoleBindings
kubectl get clusterrolebindings

# 查看詳細權限
kubectl describe rolebinding <binding-name> -n <namespace>
```

### 權限故障排除

#### 1. 權限不足錯誤

**錯誤訊息**：

```
Error from server (Forbidden): pods is forbidden: User "user" cannot create resource "pods" in API group "" in the namespace "default"
```

**解決方法**：

```bash
# 1. 檢查當前權限
kubectl auth can-i create pods -n default

# 2. 檢查用戶的 RoleBindings
kubectl get rolebindings -n default -o wide

# 3. 授予必要權限
kubectl create rolebinding user-pod-creator \
  --clusterrole=edit \
  --user=user \
  -n default
```

#### 2. Kubeconfig 無效

**問題**：

- 無法連接到集群
- 認證失敗

**檢查步驟**：

```bash
# 1. 檢查 kubeconfig 是否正確
kubectl config view

# 2. 測試連接
kubectl cluster-info

# 3. 檢查證書有效期
kubectl config view --raw -o jsonpath='{.users[0].user.client-certificate-data}' | \
  base64 -d | openssl x509 -text -noout

# 4. 檢查 server URL 是否正確
kubectl config view -o jsonpath='{.clusters[0].cluster.server}'
```

## 專案權限

### 概述

KDE 使用 Git 倉庫的權限機制來控制專案的存取。透過 Git 的認證和授權系統，確保只有授權的用戶才能存取和修改專案程式碼。

### Git 權限管理

#### 1. 倉庫存取權限

**公開倉庫**：

```bash
# 任何人都可以讀取
kde project fetch myapp https://github.com/user/public-repo.git main
```

**私有倉庫**：

```bash
# 需要認證才能存取
kde project fetch myapp https://github.com/user/private-repo.git main
# 系統會提示輸入認證資訊
```

#### 2. Git 認證方式

**HTTPS 認證**：

**方式 1：使用個人存取令牌 (PAT)**

```bash
# GitHub PAT
git clone https://<username>:<token>@github.com/user/repo.git

# 或設定 Git credential helper
git config --global credential.helper store
```

**方式 2：使用 SSH 金鑰**

```bash
# 使用 SSH URL
kde project fetch myapp git@github.com:user/repo.git main

# 需要先設定 SSH 金鑰
ssh-keygen -t ed25519 -C "your_email@example.com"
ssh-add ~/.ssh/id_ed25519
```

#### 3. 權限層級

**Git 平台權限**（以 GitHub 為例）：

- **Read** - 可以克隆和讀取倉庫
- **Write** - 可以推送變更
- **Admin** - 完整的管理權限

**KDE 專案操作所需權限**：

| 操作       | 所需 Git 權限 |
| ---------- | ------------- |
| fetch 專案 | Read          |
| pull 更新  | Read          |
| 部署專案   | Read          |
| 修改程式碼 | Write         |
| 刪除分支   | Write/Admin   |

### 專案配置安全

#### 1. 敏感資訊管理

**不要直接儲存**：

```bash
# ❌ 不要這樣做
# project.env
DATABASE_PASSWORD=my-secret-password
API_KEY=my-api-key
```

**使用 K8s Secrets**：

```bash
# ✓ 應該這樣做
kubectl create secret generic app-secrets \
  --from-literal=database-password=my-secret-password \
  --from-literal=api-key=my-api-key \
  -n <namespace>
```

**在 deploy.sh 中使用**：

```bash
# deploy.sh
kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: myapp
  namespace: ${NAMESPACE}
spec:
  containers:
  - name: app
    image: myapp:latest
    env:
    - name: DATABASE_PASSWORD
      valueFrom:
        secretKeyRef:
          name: app-secrets
          key: database-password
EOF
```

#### 2. .gitignore 配置

確保敏感檔案不會被提交：

```bash
# .gitignore
*.env
*.key
*.pem
kubeconfig/
secrets/
```

### 權限檢查與驗證

#### 1. 檢查 Git 存取權限

```bash
# 測試 SSH 連線
ssh -T git@github.com

# 測試倉庫存取
git ls-remote https://github.com/user/repo.git

# 檢查當前用戶
git config user.name
git config user.email
```

#### 2. 檢查專案配置

```bash
# 查看專案 Git 配置
cat environments/<env_name>/namespaces/<project_name>/project.env

# 檢查倉庫狀態
cd environments/<env_name>/namespaces/<project_name>/<repo_name>
git status
git remote -v
```

### 權限最佳實踐

#### 1. 使用部署金鑰

為每個專案建立專用的部署金鑰：

```bash
# 1. 生成部署金鑰
ssh-keygen -t ed25519 -f deploy_key -C "deploy@myapp"

# 2. 添加到 Git 平台
# 在 GitHub/GitLab 的倉庫設定中添加公鑰（唯讀）

# 3. 在 KDE 中使用
export GIT_SSH_COMMAND="ssh -i /path/to/deploy_key"
kde project fetch myapp git@github.com:user/repo.git main
```

#### 2. 使用有限權限的令牌

建立具有最小權限的 PAT：

```bash
# GitHub PAT 權限建議
- repo (如果是私有倉庫)
- read:repo (如果只需要讀取)

# 避免授予不必要的權限
- admin:repo_hook
- delete_repo
```

#### 3. 定期輪換憑證

```bash
# 定期更新 Git 認證資訊
# 1. 生成新的 PAT 或 SSH 金鑰
# 2. 更新 Git 配置
# 3. 刪除舊的憑證
```

### 權限故障排除

#### 1. Git 認證失敗

**錯誤訊息**：

```
fatal: Authentication failed for 'https://github.com/user/repo.git/'
```

**解決方法**：

```bash
# 1. 檢查認證資訊
git config --list | grep credential

# 2. 清除舊的認證
git credential-cache exit

# 3. 重新認證
git clone https://<username>:<new-token>@github.com/user/repo.git

# 或使用 SSH
git clone git@github.com:user/repo.git
```

#### 2. 權限不足

**錯誤訊息**：

```
ERROR: Permission to user/repo.git denied to username.
```

**解決方法**：

```bash
# 1. 檢查倉庫權限
# 在 Git 平台上確認用戶權限

# 2. 檢查 SSH 金鑰
ssh -T git@github.com

# 3. 檢查使用的帳號
git config user.name
git config user.email
```

## 雲端服務權限

### 概述

KDE 整合多種雲端服務，每個服務都有獨立的認證和授權機制。

### Ngrok 權限管理

#### 1. Token 配置

```bash
# ngrok.env 檔案位置
/opt/kde/ngrok.env

# 內容格式
NGROK_TOKEN=your_ngrok_token_here
```

**安全性建議**：

```bash
# 設定適當的檔案權限
chmod 600 /opt/kde/ngrok.env

# 確保只有擁有者可以讀寫
ls -l /opt/kde/ngrok.env
# 輸出應該是：-rw------- 1 user user ... ngrok.env
```

#### 2. Token 管理

```bash
# 獲取 Ngrok Token
# 1. 登入 https://dashboard.ngrok.com/
# 2. 在 "Your Authtoken" 頁面獲取 token
# 3. 設定到 ngrok.env

# 定期輪換 Token
# 1. 在 Ngrok Dashboard 重新生成 token
# 2. 更新 ngrok.env
# 3. 重新啟動 ngrok 服務
```

### Cloudflare Tunnel 權限管理

#### 1. 認證流程

```bash
# 首次使用需要登入
kde cloudflare-tunnel myapp.example.com ingress

# 系統會引導完成 OAuth 認證
# 1. 開啟瀏覽器
# 2. 登入 Cloudflare 帳號
# 3. 授權 KDE 存取
```

#### 2. 憑證管理

**憑證位置**：

```bash
~/.cloudflared/cert.pem
~/.cloudflared/config.yml
```

**權限設定**：

```bash
# 確保憑證安全
chmod 600 ~/.cloudflared/cert.pem
chmod 600 ~/.cloudflared/config.yml
```

#### 3. Tunnel Token

```bash
# Tunnel Token 儲存在 K8s Secret 中
kubectl get secret cloudflare-tunnel-token -n <namespace>

# 查看 Token
kubectl get secret cloudflare-tunnel-token -n <namespace> \
  -o jsonpath='{.data.token}' | base64 -d
```

### Telepresence 權限管理

#### 1. K8s 權限要求

Telepresence 需要以下 K8s 權限：

```yaml
# 必要權限
- pods: get, list, watch, create, delete
- deployments: get, list, watch, update, patch
- services: get, list, watch
- configmaps: get, list, watch
- secrets: get, list, watch
```

## 安全性最佳實踐

有關安全性最佳實踐的詳細資訊，請參考以下資源：

- [Kubernetes RBAC 最佳實踐](https://kubernetes.io/docs/concepts/security/rbac-good-practices/)
- [Kubernetes 安全最佳實踐](https://kubernetes.io/docs/concepts/security/security-checklist/)
- [Git 安全性指南](https://git-scm.com/book/en/v2/Git-on-the-Server-Generating-Your-SSH-Public-Key)

## 故障排除總覽

### 常見權限問題

#### 1. 無法存取 K8s 環境

```bash
# 檢查步驟
1. 檢查 kubeconfig 是否存在
   ls -la environments/<env_name>/kubeconfig/config

2. 檢查 kubeconfig 權限
   cat environments/<env_name>/kubeconfig/config

3. 測試連接
   kubectl cluster-info

4. 檢查權限
   kubectl auth can-i --list
```

#### 2. 無法存取 Git 倉庫

```bash
# 檢查步驟
1. 測試 Git 連接
   git ls-remote <repo_url>

2. 檢查認證
   git config --list | grep credential

3. 檢查 SSH 金鑰
   ssh -T git@github.com

4. 重新認證
   git credential-cache exit
```

## 參考資源

### Kubernetes RBAC

- [Kubernetes RBAC 官方文件](https://kubernetes.io/docs/reference/access-authn-authz/rbac/)

### Git 認證

- [GitHub 個人存取令牌](https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/creating-a-personal-access-token)
- [GitHub SSH 金鑰](https://docs.github.com/en/authentication/connecting-to-github-with-ssh)

### 雲端服務

- [Ngrok 認證](https://ngrok.com/docs/secure-tunnels/tunnels/ssh-reverse-tunnel-agent/)
- [Cloudflare Tunnel 文件](https://developers.cloudflare.com/cloudflare-one/connections/connect-apps/)
- [Telepresence RBAC 權限](https://www.telepresence.io/docs/latest/reference/rbac/)
