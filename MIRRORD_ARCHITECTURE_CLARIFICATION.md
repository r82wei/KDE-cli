# Mirrord 架構實作說明

## 當前實作方案

### 架構設計

```
┌─────────────────────────────────────────────────────────────┐
│ 本地機器                                                     │
│                                                               │
│ 1. 使用者執行: kde mirrord mirror -n myapp --pod myapp-pod   │
│                                                               │
│ 2. 建立 Mirrord Session Container                            │
│    ├── 包含 mirrord CLI                                      │
│    ├── 包含 kubectl                                          │
│    ├── 掛載 kubeconfig                                       │
│    └── 驗證 K8s 連線和目標 Pod                                │
│                                                               │
│ 3. 啟動開發容器 (透過 DooD)                                   │
│    ├── 使用 Session Container 的網路                         │
│    ├── 掛載專案程式碼                                         │
│    ├── 載入環境變數                                           │
│    └── **需要安裝 mirrord CLI**                               │
│                                                               │
│ 4. 使用者在開發容器內執行                                     │
│    └── mirrord exec --config /tmp/mirrord-config.json <cmd>  │
│                                                               │
└─────────────────────────────────────────────────────────────┘
                          │
                          │ K8s API + Network Tunnel
                          ▼
┌─────────────────────────────────────────────────────────────┐
│ Kubernetes 集群                                              │
│                                                               │
│ ┌─────────────────────────┐                                  │
│ │ 目標 Pod (myapp-pod)     │                                  │
│ │ ├── mirrord Agent 注入   │ ◄─── mirrord 自動注入            │
│ │ └── 流量鏡像/攔截        │                                  │
│ └─────────────────────────┘                                  │
│                                                               │
└─────────────────────────────────────────────────────────────┘
```

### entrypoint.sh 當前功能

當前的 `entrypoint.sh` 執行以下任務：

1. **驗證環境**
   - 檢查必要的環境變數（MIRRORD_TARGET_NAMESPACE, MIRRORD_TARGET_POD）
   - 驗證 K8s 連線
   - 驗證目標 Pod 狀態

2. **建立配置**
   - 根據工作模式（mirror/steal/connect）建立 mirrord 配置檔案
   - 配置檔案位於 `/tmp/mirrord-config.json`

3. **保持容器運行**
   - 提供網路環境
   - 等待開發容器使用此網路

### 問題：開發容器如何使用 mirrord？

**方案 A（推薦）：開發容器也安裝 mirrord CLI**

優點：
- 使用者可以直接在開發容器內執行 `mirrord exec <command>`
- 符合 mirrord 的原生使用方式
- 配置簡單，容易理解

缺點：
- 開發容器需要包含 mirrord CLI（增加映像大小）
- 需要在開發容器內掛載 kubeconfig

實作方式：
```bash
# 在開發容器內
mirrord exec --config /tmp/mirrord-config.json npm run dev
```

**方案 B：透過 Session Container 執行**

優點：
- mirrord CLI 只在 Session Container 中
- 開發容器保持輕量

缺點：
- 使用者體驗較差（需要透過特殊方式執行）
- 實作複雜

實作方式：
```bash
# 在 Session Container 中
docker exec mirrord-session mirrord exec --config /tmp/mirrord-config.json -- \
  docker exec dev-container npm run dev
```

### 建議的改進方向

#### 選項 1：雙容器架構（當前）+ 開發容器安裝 mirrord

**修改點**：
1. 開發容器映像需要包含 mirrord CLI
2. `exec_project_develop_container()` 函式需要：
   - 掛載 kubeconfig 到開發容器
   - 掛載 mirrord 配置檔案到開發容器
   - 設定 `KUBECONFIG` 環境變數

**使用流程**：
```bash
# 1. 使用者執行
kde mirrord mirror -n myapp --pod myapp-pod

# 2. 系統自動：
#    - 建立 Session Container
#    - 建立 mirrord 配置
#    - 啟動開發容器（共享 Session 網路）
#    - 進入開發容器

# 3. 使用者在開發容器內：
mirrord exec --config /tmp/mirrord-config.json npm run dev
```

#### 選項 2：單容器架構（簡化）

**優點**：
- 架構簡單
- 沒有 Session Container
- 直接在開發容器內使用 mirrord

**修改點**：
1. 不需要 Session Container
2. 直接啟動開發容器
3. 開發容器需要：
   - 安裝 mirrord CLI
   - 掛載 kubeconfig
   - 掛載 mirrord 配置

**使用流程**：
```bash
# 1. 使用者執行
kde mirrord mirror -n myapp --pod myapp-pod

# 2. 系統自動：
#    - 建立 mirrord 配置
#    - 啟動開發容器
#    - 掛載配置和 kubeconfig
#    - 進入開發容器

# 3. 使用者在開發容器內：
mirrord exec --config /tmp/mirrord-config.json npm run dev
```

### 當前 entrypoint.sh 的完整性

**已實作**：
- ✅ 環境變數驗證
- ✅ K8s 連線驗證
- ✅ Pod 狀態檢查
- ✅ Mirrord 配置建立
- ✅ 清理函式

**缺少的功能**：
- ❌ 實際執行 `mirrord exec` 的機制
- ❌ 與開發容器的整合方式

**原因**：
因為 mirrord 的設計是 `mirrord exec <command>` 包裝使用者的程式，而不是像 Telepresence 那樣建立一個持續的連線。所以：

- **Telepresence**: 執行 `telepresence connect`，建立持續連線
- **Mirrord**: 執行 `mirrord exec <cmd>`，僅在 `<cmd>` 運行期間有效

### 下一步建議

1. **決定架構方案**（選項 1 或選項 2）
2. **更新開發容器映像**（加入 mirrord CLI）
3. **修改 `scripts/utils/mirrord.sh`**（調整開發容器啟動邏輯）
4. **提供使用者說明**（如何在開發容器內使用 mirrord）

### 實際使用範例

假設採用**選項 1（雙容器 + 開發容器安裝 mirrord）**：

```bash
# 終端 1：使用者操作
$ kde mirrord mirror -n express --pod express-api-abc123

# 系統輸出：
>>> 建立 Mirrord Session Container...
>>> 驗證 Pod 狀態...
>>> 建立 mirrord 配置...
>>> 啟動開發容器...
>>> 已進入開發容器

# 在開發容器內
user@dev-container:/project$ mirrord exec --config /tmp/mirrord-config.json npm run dev

# mirrord 開始工作
>>> Injecting agent to pod express-api-abc123...
>>> Mirroring traffic to local process...
>>> Your app is now running with mirrord!

# 使用者的程式現在可以：
# - 接收來自 Pod 的鏡像流量
# - 存取 K8s 內部服務
# - 使用 Pod 的環境變數
```

### 總結

**entrypoint.sh 當前狀態**：
- ✅ **基礎設施完整**：驗證、配置建立都已實作
- ⚠️ **執行機制待定**：需要決定如何讓開發容器使用 mirrord
- 📝 **需要文檔說明**：使用者需要知道如何在開發容器內使用 mirrord

**建議**：
優先採用**選項 1（雙容器 + 開發容器安裝 mirrord）**，因為：
- 符合當前架構設計
- 使用者體驗較好
- 與 Telepresence 模式一致
